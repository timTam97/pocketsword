//
//  PSModuleController.swift
//  PocketSword
//
//  Swift port (Wave 4) of the former PSModuleController.{h,mm}. PSModuleController
//  is the app-level singleton holding the user's primary Bible / commentary /
//  dictionary, building the HTML shells (+createHTMLString:/+createInfoHTMLString:),
//  unpacking bundled starter modules (-installModulesFromZip:...), and exposing the
//  ref-string helpers (+createRefString:/+getCurrentBibleRef/+getFirstRefAvailable).
//
//  The 9 direct sword:: seams that previously lived in PSModuleController.mm have
//  been extracted into Foundation-only @objc methods on the permanent Obj-C++
//  Sword* facades, so this file is C++-free:
//    - LocaleMgr book-name translation -> +[SwordManager translateToSystemLocale:]
//    - InstallMgr module removal        -> -[SwordManager removeModuleNamed:]
//    - module key-text get/set          -> -[SwordModule keyText] / -setVerseKeyText:
//      (the dictionary location uses -keyText / -setKeyString:)
//
//  The @objc surface reproduces the original Obj-C public API 1:1 (selectors
//  preserved) so existing Obj-C++ callers (PSTabBarControllerDelegate, the render
//  cluster, the launch VC, the app delegate, SwordModule) and the Wave 1-3 Swift
//  callers keep compiling unchanged. PSModuleController itself stays Obj-C-visible.
//
//  Copyright 2008-2012 CrossWire Bible Society – http://www.crosswire.org
//  GPL v2 (see the original header).
//

import Foundation
import UIKit

// The SWORD option / category / attribute names are @"literal" #defines in the
// Obj-C facade headers (SwordManager.h / SwordModule.h). Obj-C string #defines do
// NOT import into Swift, so these mirror the literals byte-for-byte (same approach
// as PSModuleSelectorController.swift's category constants). Wire strings unchanged.
private enum SW {
    // global options (SW_OPTION_*) — values per SwordManager.h
    static let optionScriptRefs = "Cross-references"
    static let optionStrongs = "Strong's Numbers"
    static let optionMorphs = "Morphological Tags"
    static let optionHeadings = "Headings"
    static let optionFootnotes = "Footnotes"
    static let optionRedLetterWords = "Words of Christ in Red"
    static let optionGreekAccents = "Greek Accents"
    static let optionHebrewPoints = "Hebrew Vowel Points"
    static let optionHebrewCantillation = "Hebrew Cantillation"
    static let optionVariants = "Textual Variants"
    static let optionVariantsPrimary = "Primary Reading"
    static let optionGlosses = "Glosses"
    static let on = "On"
    static let off = "Off"

    // module categories (SWMOD_CATEGORY_*)
    static let categoryBibles = "Biblical Texts"
    static let categoryCommentaries = "Commentaries"
    static let categoryDictionaries = "Lexicons / Dictionaries"

    // passagestudy attribute keys (ATTRTYPE_*) — values per SwordModule.h
    static let attrType = "type"
    static let attrPassage = "passage"
    static let attrModule = "modulename"
    static let attrAction = "action"
    static let attrValue = "value"
}

@objc(PSModuleController)
final class PSModuleController: NSObject {

    // MARK: - Properties (selectors preserved for Obj-C / Swift callers)

    // MARK: - The three primary modules, by NAME
    //
    // SWORD_REMOVAL_PLAN.md Phase 5 step 7. These were `SwordModule!` /
    // `SwordDictionary!` objects plus a `SwordManager!`. Every consumer only ever read
    // `.name` off them — step 5 moved the call sites onto the `*Name` accessors, and
    // this step makes the names the stored properties and deletes the objects and the
    // manager outright.
    //
    // `nil` means "not resolved yet", which `getBibleChapter` / `getCommentaryChapter`
    // handle by calling `reloadLast*` — the same shape as before, without a module
    // lookup behind it.

    /// The Bible being read, by name.
    @objc var primaryBibleName: String?

    /// The commentary being read, by name.
    @objc var primaryCommentaryName: String?

    /// The lexicon being browsed, by name.
    @objc var primaryDictionaryName: String?

    @objc var busyTimer: Timer?

    // MARK: - Singleton

    private static var instance: PSModuleController?

    /// + (PSModuleController *)defaultModuleController — Obj-C selector preserved;
    /// imported into Swift as `default()` (the importer strips the redundant
    /// "ModuleController" type suffix). Returns an implicitly-unwrapped optional to
    /// match the original `id`-return call sites (`.default().primaryBible` and
    /// `.default()!` both compile).
    @objc(defaultModuleController)
    class func `default`() -> PSModuleController! {
        if instance == nil {
            // The `mods.d` creation that was here is GONE (Phase 5 step 9): it existed
            // because sword::InstallMgr silently failed if the directory was absent,
            // and there is no InstallMgr and nothing to install.
            instance = PSModuleController()
        }
        return instance
    }

    @objc(releaseDefaultModuleController)
    class func releaseDefaultModuleController() {
        instance = nil
    }

    // MARK: - First / last available ref (static state, preserved exactly)

    private static var lastRefAvailable: String = "Revelation 22"
    private static var firstRefAvailable: String = "Genesis 1"

    @objc(setFirstRefAvailable:)
    class func setFirstRefAvailable(_ first: String!) {
        firstRefAvailable = first
    }

    @objc(setLastRefAvailable:)
    class func setLastRefAvailable(_ last: String!) {
        lastRefAvailable = last
    }

    @objc(getFirstRefAvailable)
    class func getFirstRefAvailable() -> String! {
        return firstRefAvailable
    }

    @objc(getLastRefAvailable)
    class func getLastRefAvailable() -> String! {
        return lastRefAvailable
    }

    // MARK: - Init

    @objc override init() {
        super.init()

        // The Caches -> Documents mods.d/modules migration that was here is GONE
        // (Phase 5 step 9). It dated from v1.3.0 and moved SWORD's module trees so
        // iTunes would back them up; there are no module trees now, and step 9's
        // DefaultsSwordRetired one-shot deletes both locations outright. Moving a
        // directory in order to then delete it would be theatre.

        // The first/last available refs, derived from the baked versification table.
        //
        // SWORD_REMOVAL_PLAN.md Phase 4: this used to round-trip "Genesis" and
        // "Revelation of John" through +[SwordManager translateToSystemLocale:].
        // That looks like a semantic change and is not — the round-trip was
        // **identity on every device**:
        //   - There is no `en` locale conf. All 118 confs in locales.d.zip were
        //     checked and none has Meta/Name = "en"; the only English locale is
        //     SWLocale(0) (swlocale.cpp:63-69), built with SWConfig(0), which sets
        //     Meta/Name + bookAbbrevs and has **no [Text] section** — so
        //     `translate` returns its input.
        //   - +initLocale is only called at all when preferredLanguages.first is
        //     not "en" (PSLaunchViewController), so on an English device the
        //     system locale manager is never even pointed elsewhere.
        // Asserted 66/66 in PSRefSemanticsTests.testTranslateBookNameIsIdentityForAll66.
        //
        // The values are byte-identical to the static defaults above
        // ("Genesis 1" / "Revelation 22"): the table's first book is Genesis and
        // its last is Revelation, whose longName "Revelation of John" munges to
        // "Revelation" through createRefString exactly as before.
        if let books = PSBookOSISResolver.shared?.books, let first = books.first, let last = books.last {
            PSModuleController.setFirstRefAvailable("\(first.name) 1")
            PSModuleController.setLastRefAvailable(
                PSModuleController.createRefString("\(last.longName) \(last.chapterCount)"))
        }

        // `setPreferences()` is gone — see the note above `reloadLastBible`. The
        // per-module option prefs are read by the reader at render time
        // (PSContentReader.options(forModule:)); nothing pushes them anywhere.
        reloadLastBible()
        reloadLastCommentary()
    }

    // MARK: - Preferences


    // MARK: - Module install


    // MARK: - Loaded check

    @objc(isLoaded:)
    func isLoaded(_ module: String) -> Bool {
        if let primaryBibleName, primaryBibleName == module {
            return true
        } else if let primaryCommentaryName, primaryCommentaryName == module {
            return true
        } else if let primaryDictionaryName, primaryDictionaryName == module {
            return true
        }
        return false
    }

    // MARK: - Current bible ref

    @objc(getCurrentBibleRef)
    class func getCurrentBibleRef() -> String! {
        let defaults = UserDefaults.standard
        if let lastRef = defaults.string(forKey: Defaults.lastRef) {
            return lastRef
        }
        defaults.set("Genesis 1", forKey: Defaults.lastRef)
        defaults.synchronize()
        return "Genesis 1"
    }

    // MARK: - Primary module loaders

    @objc(loadPrimaryBible:)
    func loadPrimaryBible(_ newText: String!) {
        primaryBibleName = newText
        UserDefaults.standard.set(newText, forKey: Defaults.lastBible)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .newPrimaryBible, object: nil)
    }

    @objc(loadPrimaryCommentary:)
    func loadPrimaryCommentary(_ newText: String!) {
        primaryCommentaryName = newText
        UserDefaults.standard.set(newText, forKey: Defaults.lastCommentary)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .newPrimaryCommentary, object: nil)
    }

    /// Load a lexicon as the primary dictionary.
    ///
    /// The `primaryDictionary.releaseKeys()` that used to open this method is GONE
    /// (Phase 5 step 5): `-releaseKeys` was SwordDictionary-only, and the reader
    /// memoises keys from an immutable read-only store, so there is nothing to release.
    @objc(loadPrimaryDictionary:)
    func loadPrimaryDictionary(_ newText: String!) {
        primaryDictionaryName = newText
        if let newText {
            UserDefaults.standard.set(newText, forKey: Defaults.lastDictionary)
        } else {
            UserDefaults.standard.removeObject(forKey: Defaults.lastDictionary)
        }
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .newPrimaryDictionary, object: nil)
    }

    // never called by the OS - must be called manually!
    @objc(didReceiveMemoryWarning)
    func didReceiveMemoryWarning() {
        // Deliberately a NO-OP as of Phase 5 step 5.
        //
        // Its only body was `primaryDictionary.releaseKeys()`, which dropped the
        // in-memory lexicon key array the engine had walked the module to build. The
        // reader's equivalent is memoised from an immutable, read-only, mmap-able
        // SQLite store, so there is nothing worth releasing.
        //
        // The METHOD is kept rather than deleted because it is called MANUALLY (the
        // name is a lie — the OS never invokes this), so removing it would mean
        // touching its callers for no benefit, and it is the obvious place to hang a
        // future release if one is ever needed.
    }

    // MARK: - Chapter navigation
    //
    // SWORD_REMOVAL_PLAN.md Phase 4: the arithmetic is the baked versification
    // table's, not `sword::VerseKey::setChapter` + `normalize`. Three things about
    // this deserve spelling out, because each is a place a "simplification" would
    // silently change behaviour:
    //
    //  1. **Both modules navigate the same versification.** KJV and MHCC are both
    //     KJV-versified (verified: the ref selector's system lookup always resolved
    //     to the one table), so the *destination* is computed once. What the
    //     per-module blocks below still do is the pref writes, whose conditional
    //     shape is preserved exactly — including the asymmetry that `next` leaves
    //     `commentaryVersePosition` alone when a bible is loaded while `prev` sets
    //     it from the bible's verse maximum.
    //
    //  2. **The verse maximum is the DESTINATION chapter's.** The old code called
    //     `-getVerseMax` *after* `-setToPreviousChapter` had already moved the key,
    //     so it read the chapter being navigated to, not the one being left. Reading
    //     the source chapter's would put the scroll position at the wrong verse on
    //     every backward move between chapters of different length.
    //
    //  3. **nil at the canon boundaries**, where SWORD clamped. `normalize`
    //     (versekey.cpp:1466-1493) pinned to the bound and merely set
    //     KEYERR_OUTOFBOUNDS, so `-setToNextChapter` at Rev 22 handed back the very
    //     ref it was given, and the callers' string-equality gate against
    //     get{First,Last}RefAvailable is what turned that into a no-op. That gate is
    //     kept — it lives in three places, one of which drives a 3-way button-enable
    //     state, and restructuring it is a UI change that does not belong in a
    //     substitution commit — and the nil is a second, structural guard behind it.
    //     Returning the clamped ref instead would turn a no-op into a full re-render.

    /// The table's answer for a move from the current ref, or nil at the canon
    /// boundary / for a ref the table cannot resolve.
    ///
    /// Returns the **un-munged `longName`** form ("Revelation of John 22"), which is
    /// what `-setToNextChapter` genuinely returned: `VerseKey::freshtext`
    /// (versekey.cpp:378) built its key text from `getBookName()` =
    /// `translate(getLongName())` = identity here. Every call site munges it
    /// downstream through `createRefString`, and 18 of the 66 books have
    /// `name != longName`, so returning `name` would be an off-by-a-munge visible on
    /// Revelation and the five numbered books.
    private func navigate(from ref: String?, forward: Bool)
        -> (ref: String, book: PSVersificationBook, chapter: Int)? {
        guard let resolver = PSBookOSISResolver.shared,
              let ref = ref,
              let (book, chapter) = resolver.resolve(ref: ref) else { return nil }
        guard let destination = forward
                ? resolver.nextChapter(book: book, chapter: chapter)
                : resolver.previousChapter(book: book, chapter: chapter) else { return nil }
        return (resolver.displayRef(destination), destination.book, destination.chapter)
    }

    @objc(setToNextChapter)
    func setToNextChapter() -> String! {
        guard let destination = navigate(from: PSModuleController.getCurrentBibleRef(),
                                         forward: true) else { return nil }

        var ret: String? = nil
        if primaryBibleName != nil {
            ret = destination.ref
            UserDefaults.standard.set("1", forKey: Defaults.bibleVersePosition)
        }
        if primaryCommentaryName != nil, ret == nil {
            ret = destination.ref
            UserDefaults.standard.set("1", forKey: Defaults.commentaryVersePosition)
        }
        UserDefaults.standard.synchronize()
        return ret
    }

    @objc(setToPreviousChapter)
    func setToPreviousChapter() -> String! {
        guard let destination = navigate(from: PSModuleController.getCurrentBibleRef(),
                                         forward: false) else { return nil }
        // The DESTINATION chapter's maximum — see note 2 above.
        let destinationVerseMax = PSBookOSISResolver.shared?
            .verseMax(book: destination.book, chapter: destination.chapter) ?? 0

        var ret: String? = nil
        var verse = 0
        if primaryBibleName != nil {
            ret = destination.ref
            verse = destinationVerseMax
            UserDefaults.standard.set(String(format: "%ld", verse), forKey: Defaults.bibleVersePosition)
        }
        if primaryCommentaryName != nil {
            if ret == nil {
                ret = destination.ref
                verse = destinationVerseMax
                UserDefaults.standard.set(String(format: "%ld", verse), forKey: Defaults.commentaryVersePosition)
            } else if verse != 0 {
                UserDefaults.standard.set(String(format: "%ld", verse), forKey: Defaults.commentaryVersePosition)
            }
        }
        UserDefaults.standard.synchronize()
        return ret
    }

    // MARK: - Reload


    // MARK: - Remove module


    // MARK: - Reload last bible / commentary

    // `reload()` and `removeModule(_:)` are GONE (SWORD_REMOVAL_PLAN.md Phase 5).
    //
    // `reload()` existed to `reInit` the SwordManager and save/restore each primary
    // module's key text across that re-init. With no manager there is nothing to
    // re-initialise, and the primaries are now plain names that no re-init can
    // invalidate.
    //
    // `removeModule(_:)` uninstalled a module through InstallMgr. Its only callers were
    // bootstrap-internal (the StrongsRealGreek update and the non-bundled-module
    // cleanup sweep), and both went with the seeding in step 9. There has been no
    // user-facing removal since the module list was retired.

    // MARK: - Reload last bible / commentary

    /// Resolve the primary Bible from `lastBible`, falling back to the bundled one.
    ///
    /// Phase 5 step 7: this used to ask SwordManager for the module and, failing that,
    /// take the first of `modules(forType: "Biblical Texts")`. There is no manager and
    /// no module list — the app ships exactly one Bible — so a persisted name is
    /// honoured only if it names a module we actually ship.
    @objc(reloadLastBible)
    func reloadLastBible() {
        let defaults = UserDefaults.standard
        let last = defaults.string(forKey: Defaults.lastBible)
        if let last, PSContentStore.shared?.moduleMeta(last, key: "type") != nil {
            primaryBibleName = last
        } else {
            primaryBibleName = BundledModules.bible
            defaults.set(BundledModules.bible, forKey: Defaults.lastBible)
            defaults.synchronize()
        }
    }

    /// Resolve the primary commentary from `lastCommentary`. Same shape as
    /// `reloadLastBible` — see there for why the module-list fallback is gone.
    @objc(reloadLastCommentary)
    func reloadLastCommentary() {
        let defaults = UserDefaults.standard
        let last = defaults.string(forKey: Defaults.lastCommentary)
        if let last, PSContentStore.shared?.moduleMeta(last, key: "type") != nil {
            primaryCommentaryName = last
        } else {
            primaryCommentaryName = BundledModules.commentary
            defaults.set(BundledModules.commentary, forKey: Defaults.lastCommentary)
            defaults.synchronize()
        }
    }

    // MARK: - Chapter text

    // Grabs the bible text for a given chapter (e.g. "Gen 1")
    @objc(getBibleChapter:withExtraJS:)
    func getBibleChapter(_ chapter: String!, withExtraJS extraJS: String!) -> String! {
        if primaryBibleName == nil {
            // `reload()` (a SwordManager reInit) is gone; reloadLastBible resolves the
            // name from `lastBible` or falls back to the bundled Bible, so the
            // "still nil" arm below is unreachable in practice. It is KEPT because it is
            // the only user-visible statement of "no content at all".
            reloadLastBible()

            if primaryBibleName == nil {
                return PSModuleController.createHTMLString(String(format: "<center>%@</center>", NSLocalizedString("NoModulesInstalled", comment: "")),
                                                          usingPreferences: true, withJS: "",
                                                          usingModuleForPreferences: nil, fixedWidth: true)
            }
            NotificationCenter.default.post(name: .newPrimaryBible, object: nil)
        }
        // SWORD_REMOVAL_PLAN.md Phase 5 step 1: the reader is the ONLY render path.
        // The `getChapter(_:withExtraJS:)` fallback arm is gone — there is no engine
        // behind it — so a nil here reaches the user as a blank pane. That is why
        // the reader's own failure policy now splits into fatal (the store is
        // unusable at all) and loud-and-nil (this one chapter is bad); see
        // PSContentReader's header.
        var text: String?
        if let name = primaryBibleName {
            text = PSContentReader.shared.chapterPage(module: name, ref: chapter,
                                                      kind: .bible, extraJS: extraJS)
        }

        UserDefaults.standard.set(PSModuleController.createRefString(chapter), forKey: Defaults.lastRef)
        UserDefaults.standard.synchronize()
        return text
    }

    // Grabs the commentary text for a given chapter (e.g. "Gen 1")
    @objc(getCommentaryChapter:withExtraJS:)
    func getCommentaryChapter(_ chapter: String!, withExtraJS extraJS: String!) -> String! {
        if primaryCommentaryName == nil {
            reloadLastCommentary()

            if primaryCommentaryName == nil {
                return PSModuleController.createHTMLString(String(format: "<center>%@</center>", NSLocalizedString("NoModulesInstalled", comment: "")),
                                                          usingPreferences: true, withJS: "",
                                                          usingModuleForPreferences: nil, fixedWidth: true)
            }
            NotificationCenter.default.post(name: .newPrimaryCommentary, object: nil)
        }
        var text: String?
        if let name = primaryCommentaryName {
            text = PSContentReader.shared.chapterPage(module: name, ref: chapter,
                                                      kind: .commentary, extraJS: extraJS)
        }

        UserDefaults.standard.set(PSModuleController.createRefString(chapter), forKey: Defaults.lastRef)
        UserDefaults.standard.synchronize()
        return text
    }

    // MARK: - Ref string helpers

    @objc(createRefString:)
    class func createRefString(_ ref: String!) -> String! {
        guard let ref = ref else { return nil }
        return ref
            .replacingOccurrences(of: "III ", with: "3 ")
            .replacingOccurrences(of: "II ", with: "2 ")
            .replacingOccurrences(of: "I ", with: "1 ")
            .replacingOccurrences(of: " of John ", with: " ")
    }

    @objc(createTitleRefString:)
    class func createTitleRefString(_ newTitle: String!) -> String! {
        let mutableTitle = NSMutableString(string: "")
        let titleToDisplay: String
        let verseRange = (newTitle as NSString).range(of: " ", options: .backwards)
        var titleMask = NSRangeFromString("0 3")
        if verseRange.location != NSNotFound { // only @"PocketSword" won't be here.
            let rest = (newTitle as NSString).substring(to: verseRange.location) // cuts off the @"3:16" part.
            let spaceRange = (rest as NSString).range(of: " ")
            if spaceRange.location != NSNotFound { // the book name contains a space.
                if spaceRange.location == 1 { // single char, so probably a number, as in "1 Cor", so keep this
                    mutableTitle.appendFormat("%c ", (newTitle as NSString).character(at: 0))
                    titleMask.location = 2
                } else if spaceRange.location == 2 { // double char, so probably a number followed by . as in "1. Cor", so keep this.
                    mutableTitle.appendFormat("%c%c ", (newTitle as NSString).character(at: 0), (newTitle as NSString).character(at: 1))
                    titleMask.location = 3
                }
            }
            mutableTitle.append((newTitle as NSString).substring(with: titleMask))
            mutableTitle.append((newTitle as NSString).substring(from: verseRange.location))
            titleToDisplay = mutableTitle as String
        } else {
            titleToDisplay = newTitle
        }
        return titleToDisplay
    }

    // MARK: - HTML shells

    @objc(createInfoHTMLString:usingModuleForPreferences:)
    class func createInfoHTMLString(_ body: String!, usingModuleForPreferences moduleName: String!) -> String! {
        let html = createHTMLString(body, usingPreferences: true,
                                    withJS: "<script type=\"text/javascript\">\n<!--\n document.documentElement.style.webkitTouchCallout = \"none\";\n-->\n</script>",
                                    usingModuleForPreferences: moduleName, fixedWidth: true)
        guard let html = html else { return nil }

        // Info popups are hosted in a frosted-glass sheet (see
        // PSInfoPopupViewController): a transparent body lets the blurred
        // chapter show through instead of a solid Canvas rectangle. Injected
        // after the base <style> so source order wins.
        let transparentCSS = "<style type=\"text/css\">html, body { background-color: transparent; }</style>"
        return html.replacingOccurrences(of: "</head>", with: "\(transparentCSS)\n</head>")
    }

    class func createStrongsInfoHTMLString(_ body: String!, usingModuleForPreferences moduleName: String?) -> String! {
        let wrappedBody = "<main class=\"strongs-definition\">\(body ?? "")</main>"
        guard let baseHTML = createInfoHTMLString(wrappedBody, usingModuleForPreferences: moduleName) else {
            return nil
        }

        let strongsCSS = """
        <style type="text/css">
        :root {
            --study-accent: #0B6670;
            --study-muted: #5D6365;
            --study-rule: #D5DDDE;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --study-accent: #67C5CA;
                --study-muted: #A9B0B2;
                --study-rule: #394245;
            }
        }
        body {
            margin: 0;
            padding: 0;
            text-align: left;
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-style: normal;
            font-weight: 400;
            line-height: 1.55;
        }
        main.strongs-definition {
            box-sizing: border-box;
            padding: 18px 20px 28px;
            text-align: left;
            overflow-wrap: anywhere;
        }
        main.strongs-definition > a[name]:first-child {
            display: none;
        }
        main.strongs-definition > a[name]:first-child + br {
            display: none;
        }
        main.strongs-definition b {
            font-family: inherit;
            font-weight: 600;
        }
        main.strongs-definition i {
            font-family: inherit;
        }
        main.strongs-definition a {
            color: var(--study-accent);
            text-decoration-line: underline;
            text-decoration-color: color-mix(in srgb, var(--study-accent) 55%, transparent);
            text-decoration-thickness: 0.08em;
            text-underline-offset: 0.14em;
        }
        main.strongs-definition a:focus-visible {
            outline: 2px solid var(--study-accent);
            outline-offset: 3px;
        }
        main.strongs-definition q {
            color: var(--study-muted);
        }
        main.strongs-definition hr {
            height: 1px;
            border: 0;
            background: var(--study-rule);
        }
        </style>
        """

        return baseHTML.replacingOccurrences(of: "</head>", with: "\(strongsCSS)\n</head>")
    }

    // careful of the '%' in the string below! Embedded literally here (no
    // stringWithFormat), mirroring the original RUBY_CSS macro.
    private static let rubyCSS = """
    ruby
    {
    \tdisplay: inline-table;
    \ttext-align: center;
    \twhite-space: nowrap;
    \ttext-indent: 0;
    \tmargin: 0;
    \tvertical-align: -10%;
    }

    ruby > rb, ruby > rbc
    {
    \tdisplay: table-row-group;
    \tline-height: 110%;
    }

    ruby > rt, ruby > rbc + rtc
    {
    \tdisplay: table-header-group;
    \tvertical-align: top;
    \tfont-size: 60%;
    \tline-height: 40%;
    \tletter-spacing: 0;
    }

    ruby > rbc + rtc + rtc
    {
    \tdisplay: table-footer-group;
    \tfont-size: 60%;
    \tline-height: 40%;
    \tletter-spacing: 0;
    }

    rbc > rb, rtc > rt
    {
    \tdisplay: table-cell;
    \tletter-spacing: 0;
    }

    rtc > rt[rbspan] { display: table-caption; }

    rp { display: none; }

    """

    // allows you to add extra javascript into the <head> html object.
    @objc(createHTMLString:usingPreferences:withJS:usingModuleForPreferences:fixedWidth:)
    class func createHTMLString(_ body: String!, usingPreferences usePrefs: Bool, withJS javascript: String!, usingModuleForPreferences moduleName: String!, fixedWidth: Bool) -> String! {
        var fontName: String = AppConstants.defaultFontName
        var fontSize = "14"
        let linkColor = "fuchsia"

        // Font name + size are GLOBAL only. The per-module "<pref>_<mod>" font keys
        // used to override these, but the font picker now lives solely in the
        // Preferences pane (one font for the whole app), so `moduleName` no longer
        // affects typography — it is still used further down for the RTL check.
        var fs = UserDefaults.standard.integer(forKey: Defaults.fontSizePreference)
        if usePrefs {
            fontName = (UserDefaults.standard.object(forKey: Defaults.fontNamePreference) as? String) ?? fontName

            if fontName.isEmpty {
                fontName = AppConstants.defaultFontName
            }
            fs = (fs == 0) ? 14 : fs
            fontSize = String(format: "%ld", fs)
        } else {
            fs = 14
        }
        let fontSizeMinusOne = String(format: "<font style=\"font-size: %dpt;line-height: 0%%;\">", Int(fs - 2))
        let finalBody = (body ?? "").replacingOccurrences(of: "<font size=\"-1\">", with: fontSizeMinusOne)
        var iPadPadding = ""
        var lineHeight = "1.4"
        var smallPadding = 3, mediumPadding = 4, largePadding = 5, hugePadding = 6 // was 3, 3, 3, 5.
        var smallIndent = 3, mediumIndent = 3, largeIndent = 3, hugeIndent = 3 // was 3, 2, 1, 1
        var lgMarginLeft = 1
        var lgMarginRight = 0
        var lgVersePadding = "left"
        var lgVersePaddingInt = "1.7"
        var lgVerseWidth = 1
        if PSResizing.iPad() {
            iPadPadding = "padding: 10px;\n"
            lineHeight = "1.6"
            if fs <= 24 {
                // increase indenting!
                lgMarginLeft = 3
                smallPadding = 5; mediumPadding = 5; largePadding = 5
                hugePadding = 7
                smallIndent = 5
                mediumIndent = 3
                largeIndent = 1
                hugeIndent = 1
                lgVersePaddingInt = "4"
                lgVerseWidth = 3
            }
        }
        if let moduleName = moduleName {
            // check if module is RTL or LTR — from content_meta as of Phase 5 step 5,
            // not from a live module. `moduleName` is passed in for this check ALONE:
            // the font is global, so nothing else here is per-module.
            if PSContentStore.shared?.moduleIsRTL(moduleName) == true {
                lgMarginRight = lgMarginLeft
                lgMarginLeft = 0
                lgVersePadding = "right"
            }
        }

        let viewportString = "<meta name='viewport' content='width=device-width' />\n"

        // Swift does not support C-style backslash line-continuation inside string
        // literals, so the original .mm format strings are expressed here as Swift
        // multiline (""") literals. The %@ / %d / %% format tokens are preserved
        // verbatim; the cosmetic leading-whitespace indentation that the old `\n\`
        // continuations carried is dropped (whitespace-insignificant HTML/CSS).
        let headerFormat = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
        "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
        <html dir="ltr" xmlns="http://www.w3.org/1999/xhtml"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd"
        xml:lang="en" >
        <head>
        %@<meta name="color-scheme" content="light dark" />
        <style type="text/css">
        :root { color-scheme: light dark; }
        html { -webkit-text-size-adjust: none; /* Never autoresize text */ }
        body { color: CanvasText; background-color: Canvas; font-size: %@pt; font-family: %@; line-height: %@; %@ }
        @media (prefers-color-scheme: dark) { span.WordOfChrist { color: #FF7070; } }

        """
        let returnString = NSMutableString(format: headerFormat as NSString,
                                           (fixedWidth ? viewportString : ""),
                                           fontSize, fontName, lineHeight, iPadPadding)

        let bodyCSSFormat = """
        i.transChangeAdded { color: gray; }
        a { color: %@; /* linkColour */ text-decoration: none; }
        a.verse { font-size: 70%%; vertical-align: super; line-height: 130%%; color: CanvasText; }
        a.x { color: gray; font-size: 70%%; vertical-align: super; line-height: 0%%; font-variant: small-caps; }
        a.n { color: gray; font-size: 70%%; vertical-align: super; line-height: 0%%; font-variant: small-caps; }
        a.strongs { color: gray; text-decoration: none; vertical-align: super; font-size: 70%%; font-style: italic; }
        a.morph { color: gray; text-decoration: none; vertical-align: super; font-size: 70%%; font-style: italic; }
        span.WordOfChrist { color: #D03030; }
        span.underline { border-bottom: 1px solid; }
        """
        returnString.appendFormat(bodyCSSFormat as NSString, linkColor)

        let lgCSSFormat = """
        blockquote.lg {
        \tmargin: 0.5em %dem 0.5em %dem;
        }
        blockquote.lg > a.verse {
        \tposition: relative;
        \tfloat: %@;
        \t%@: -%@em;
        \twidth: %dem;
        \ttext-align: center;
        \tline-height: inherit;
        }
        div.indentedLineOfWidth-0 {
        \t-webkit-padding-start: %dem;
        \ttext-indent: -%dem;
        }
        div.indentedLineOfWidth-2 {
        \t-webkit-padding-start: %dem;
        \ttext-indent: -%dem;
        }
        div.indentedLineOfWidth-4 {
        \t-webkit-padding-start: %dem;
        \ttext-indent: -%dem;
        }
        div.indentedLineOfWidth-6 {
        \t-webkit-padding-start: %dem;
        \ttext-indent: -%dem;
        }
        %@
        </style>
        %@
        <title>PocketSword</title>
        </head>
        """
        returnString.appendFormat(lgCSSFormat as NSString,
                                  lgMarginRight, lgMarginLeft,
                                  lgVersePadding, lgVersePadding, lgVersePaddingInt, lgVerseWidth,
                                  smallPadding, smallIndent,
                                  mediumPadding, mediumIndent,
                                  largePadding, largeIndent,
                                  hugePadding, hugeIndent,
                                  PSModuleController.rubyCSS, (javascript ?? ""))

        returnString.appendFormat("<body>\n<div>%@</div>\n</body>\n</html>", finalBody)

        return returnString as String
    }

    // MARK: - Link data parsing

    @objc(dataForLink:)
    class func data(forLink aURL: URL!) -> [AnyHashable: Any]! {
        // there are two types of links
        // our generated sword:// links and study data beginning with file://
        var ret: [AnyHashable: Any]? = nil

        // The old Obj-C sent -scheme to a possibly-nil NSURL, which returned nil
        // (no crash) so the method fell through and returned nil. The Swift param
        // is URL! and would trap on aURL.scheme, so guard to preserve that parity:
        // a nil link yields a nil dictionary. (WKNavigationAction.request.url is
        // optional, so this path is reachable.)
        guard let aURL = aURL else { return nil }

        let scheme = aURL.scheme
        if scheme == "sword" || scheme == "bible" {
            // in this case host is the module and path the reference
            var dict = [AnyHashable: Any]()
            if let host = aURL.host {
                dict[SW.attrModule] = host
            } else {
                dict[SW.attrModule] = NSNull()
            }
            let value = (aURL.path.removingPercentEncoding ?? aURL.path)
                .replacingOccurrences(of: "/", with: "")
                .replacingOccurrences(of: "+", with: " ")
            dict[SW.attrValue] = value
            dict[SW.attrType] = "scriptRef"
            dict[SW.attrAction] = "showRef"
            ret = dict
        } else if scheme == "file" || scheme == "applewebdata" {
            let path = aURL.path
            let query = aURL.query
            if (path as NSString).lastPathComponent == "passagestudy.jsp" {
                let data = (query ?? "").components(separatedBy: "&")
                var type = "x"
                var module = ""
                var passage = ""
                var value = "1"
                var action = ""
                for entry in data {
                    if entry.hasPrefix("type=") {
                        type = entry.components(separatedBy: "=")[1]
                    } else if entry.hasPrefix("module=") {
                        module = entry.components(separatedBy: "=")[1]
                    } else if entry.hasPrefix("passage=") {
                        passage = entry.components(separatedBy: "=")[1]
                    } else if entry.hasPrefix("action=") {
                        action = entry.components(separatedBy: "=")[1]
                    } else if entry.hasPrefix("value=") {
                        value = entry.components(separatedBy: "=")[1]
                    } else {
                        alog("[ExtTextViewController -dataForLink:] unknown parameter: \(entry)\n")
                    }
                }
                var dict = [AnyHashable: Any]()
                dict[SW.attrModule] = module
                dict[SW.attrPassage] = passage
                dict[SW.attrValue] = value
                dict[SW.attrAction] = action
                dict[SW.attrType] = type
                ret = dict
            }
        }
        return ret
    }
}
