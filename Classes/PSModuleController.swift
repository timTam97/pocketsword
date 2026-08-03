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

    // Declared as implicitly-unwrapped optionals to preserve the bridged surface of
    // the original Obj-C `@property (strong) SwordModule *` declarations (which the
    // Clang importer surfaced to Swift as `SwordModule!`). Keeps both the
    // `.default().primaryBible` (non-optional deref) and `.default()?.primaryBible?`
    // (optional-chained) Swift call sites from Waves 1-3 compiling unchanged.
    @objc var primaryBible: SwordModule!
    @objc var primaryCommentary: SwordModule!
    @objc var primaryDictionary: SwordDictionary!
    @objc var swordManager: SwordManager!
    @objc var busyTimer: Timer?

    // MARK: - Primary module NAMES
    //
    // SWORD_REMOVAL_PLAN.md Phase 5 step 5. Every surviving consumer of the three
    // `primary*` properties above only reads `.name` off them, so step 7 replaces
    // the objects with plain `String?` names. These accessors are the seam: call
    // sites move onto them in this commit, and in step 7 they stop delegating to a
    // `SwordModule` and become the stored properties themselves. Splitting it that
    // way keeps the call-site churn and the bridge deletion in separate commits.

    /// The Bible being read, by name.
    @objc var primaryBibleName: String? { primaryBible?.name }

    /// The commentary being read, by name.
    @objc var primaryCommentaryName: String? { primaryCommentary?.name }

    /// The lexicon being browsed, by name.
    @objc var primaryDictionaryName: String? { primaryDictionary?.name }

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
            // unfortunately, the sword::InstallMgr won't create these directories &
            // will silently fail if they don't exist!
            try? FileManager.default.createDirectory(atPath: AppPaths.modulePath + "mods.d",
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
            if !FileManager.default.fileExists(atPath: AppPaths.modulePath + "mods.d") {
                alog("Couldn't create mods.d")
            }
            // use default path
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

        // migration of modules, for v1.3.0: will allow backup of modules with iTunes sync...
        if FileManager.default.fileExists(atPath: AppPaths.modulePathOld + "mods.d") {
            // need to migrate from the old to the new...
            var fromPath = AppPaths.modulePathOld + "mods.d"
            var toPath = AppPaths.modulePath + "mods.d"
            do {
                try FileManager.default.moveItem(atPath: fromPath, toPath: toPath)
                alog("moved mods.d from \(fromPath) to \(toPath)")
            } catch {
                alog("failed to move mods.d folder")
            }
            fromPath = AppPaths.modulePathOld + "modules"
            toPath = AppPaths.modulePath + "modules"
            do {
                try FileManager.default.moveItem(atPath: fromPath, toPath: toPath)
                dlog("moved modules from \(fromPath) to \(toPath)")
            } catch {
                dlog("failed to move modules folder")
            }
        }

        swordManager = SwordManager.default()

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

        setPreferences()
        reloadLastBible()
        reloadLastCommentary()
    }

    // MARK: - Preferences

    @objc(setPreferences)
    func setPreferences() {
        guard let swordManager = swordManager else { return }
        let defaults = UserDefaults.standard
        let redLetter = defaults.bool(forKey: Defaults.redLetterPreference)
        let strongs = defaults.bool(forKey: Defaults.strongsPreference)
        let morphs = defaults.bool(forKey: Defaults.morphPreference)
        let greekAccents = defaults.bool(forKey: Defaults.greekAccentsPreference)
        let hvp = defaults.bool(forKey: Defaults.hvpPreference)
        let hebrewCantillation = defaults.bool(forKey: Defaults.hebrewCantillationPreference)
        let scriptRefs = defaults.bool(forKey: Defaults.scriptRefsPreference)
        let footnotes = defaults.bool(forKey: Defaults.footnotesPreference)
        let headings = defaults.bool(forKey: Defaults.headingsPreference)

        swordManager.setGlobalOption(SW.optionScriptRefs, value: scriptRefs ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionStrongs, value: strongs ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionMorphs, value: morphs ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionHeadings, value: headings ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionFootnotes, value: footnotes ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionRedLetterWords, value: redLetter ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionGreekAccents, value: greekAccents ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionHebrewPoints, value: hvp ? SW.on : SW.off)
        swordManager.setGlobalOption(SW.optionHebrewCantillation, value: hebrewCantillation ? SW.on : SW.off)

        // constants:
        swordManager.setGlobalOption(SW.optionVariants, value: SW.optionVariantsPrimary) // could make this an option?
        swordManager.setGlobalOption(SW.optionGlosses, value: SW.on)
    }

    // MARK: - Module install

    // note: this will install all the modules contained within a supplied ZIP file.
    @objc(installModulesFromZip:ofType:removeZip:internalModule:)
    func installModulesFromZip(_ zippedModule: String!, ofType modType: ModuleType, removeZip temporaryZip: Bool, internalModule: Bool) {
        guard let zippedModule = zippedModule else { return }

        // unfortunately, the sword::InstallMgr won't create these directories &
        // will silently fail if they don't exist!
        try? FileManager.default.createDirectory(atPath: AppPaths.modulePath + "mods.d",
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
        if !FileManager.default.fileExists(atPath: AppPaths.modulePath + "mods.d") {
            alog("Couldn't create mods.d")
        }

        dlog("\n\n\(zippedModule)\n\n")
        let outfile = (AppPaths.mmmPath as NSString).appendingPathComponent("out")

        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: outfile)

        // unzip the archive
        SSZipArchive.unzipFile(atPath: zippedModule, toDestination: outfile)

        // install the module/s contained in the archive:
        swordManager?.installModules(fromPath: outfile)
        _ = PSResizing.addSkipBackupAttribute(toItemAtPath: AppPaths.modulePath)

        reload()

        if temporaryZip {
            try? fileManager.removeItem(atPath: zippedModule)
        }
        try? fileManager.removeItem(atPath: outfile)

        if (primaryBible == nil && modType == bible) || (primaryCommentary == nil && modType == commentary) {
            NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
        }
    }

    // MARK: - Loaded check

    @objc(isLoaded:)
    func isLoaded(_ module: String) -> Bool {
        if let primaryBible = primaryBible, primaryBible.name == module {
            return true
        } else if let primaryCommentary = primaryCommentary, primaryCommentary.name == module {
            return true
        } else if let primaryDictionary = primaryDictionary, primaryDictionary.name == module {
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
        primaryBible = swordManager?.module(withName: newText)
        UserDefaults.standard.set(newText, forKey: Defaults.lastBible)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .refSelectorResetBooks, object: nil)
        NotificationCenter.default.post(name: .newPrimaryBible, object: nil)
    }

    @objc(loadPrimaryCommentary:)
    func loadPrimaryCommentary(_ newText: String!) {
        primaryCommentary = swordManager?.module(withName: newText)
        NotificationCenter.default.post(name: .newPrimaryCommentary, object: nil)
        UserDefaults.standard.set(newText, forKey: Defaults.lastCommentary)
        UserDefaults.standard.synchronize()
    }

    @objc(loadPrimaryDictionary:)
    func loadPrimaryDictionary(_ newText: String!) {
        // The `primaryDictionary.releaseKeys()` that was here is GONE (Phase 5 step
        // 5). `-releaseKeys` was SwordDictionary-only, and it existed because
        // -[SwordDictionary allKeys] built a large in-memory key array by walking the
        // module. The reader memoises its keys from an immutable read-only store, so
        // there is nothing to release — and dropping them would only force the next
        // lookup to re-query.
        if let newText = newText {
            primaryDictionary = swordManager?.module(withName: newText) as? SwordDictionary
            UserDefaults.standard.set(newText, forKey: Defaults.lastDictionary)
            UserDefaults.standard.synchronize()
        } else {
            primaryDictionary = nil
            UserDefaults.standard.removeObject(forKey: Defaults.lastDictionary)
            UserDefaults.standard.synchronize()
        }
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
        if primaryBible != nil {
            ret = destination.ref
            UserDefaults.standard.set("1", forKey: Defaults.bibleVersePosition)
        }
        if primaryCommentary != nil, ret == nil {
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
        if primaryBible != nil {
            ret = destination.ref
            verse = destinationVerseMax
            UserDefaults.standard.set(String(format: "%ld", verse), forKey: Defaults.bibleVersePosition)
        }
        if primaryCommentary != nil {
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

    @objc(reload)
    func reload() {
        var restoreBible = false
        var restoreCommentary = false
        var restoreDictionary = false
        var ch: String?
        var dictLoc: String?
        var bibleName: String?
        var commentaryName: String?
        var dictionaryName: String?

        if let primaryBible = primaryBible {
            restoreBible = true
            ch = (primaryBible.keyText() ?? "").components(separatedBy: ":").first
            bibleName = primaryBible.name
        }

        if let primaryCommentary = primaryCommentary {
            restoreCommentary = true
            // doesn't matter that we may write over ch, they'll be the same.
            ch = (primaryCommentary.keyText() ?? "").components(separatedBy: ":").first
            commentaryName = primaryCommentary.name
        }

        if let primaryDictionary = primaryDictionary {
            restoreDictionary = true
            dictLoc = primaryDictionary.keyText()
            dictionaryName = primaryDictionary.name
        }

        swordManager?.reInit()
        setPreferences()

        if restoreBible {
            primaryBible = swordManager?.module(withName: bibleName)
            if let primaryBible = primaryBible {
                primaryBible.setVerseKeyText(ch)
            }
        }

        if restoreCommentary {
            primaryCommentary = swordManager?.module(withName: commentaryName)
            if let primaryCommentary = primaryCommentary {
                primaryCommentary.setVerseKeyText(ch)
            }
        }

        if restoreDictionary {
            primaryDictionary = swordManager?.module(withName: dictionaryName) as? SwordDictionary
            if let primaryDictionary = primaryDictionary {
                primaryDictionary.setKeyString(dictLoc)
            }
        }

        NotificationCenter.default.post(name: .refSelectorResetBooks, object: nil)
    }

    // MARK: - Remove module

    /// Uninstalls a module. There is no user-facing removal any more (no module
    /// list, no swipe-to-delete) — the only callers are bootstrap-internal:
    /// PSLaunchViewController's StrongsRealGreek update and its one-time
    /// non-bundled-module cleanup sweep.
    ///
    /// Deliberately does NOT set the `Defaults*Removed` "user removed this bundled
    /// module, don't re-seed it" flags: with the removal UI gone a set flag can
    /// never be cleared by the user, which would permanently suppress a bundled
    /// module (see the DefaultsModuleChoiceRetired migration in
    /// PSLaunchViewController). It also drops the module-count notifications, the
    /// next-dictionary auto-promotion, and the lexicon-pref "None" reset — the
    /// lexicon roles are hardcoded now.
    @objc(removeModule:)
    @discardableResult
    func removeModule(_ name: String!) -> Bool {
        dlog("Removing module: \(name ?? "")")

        let moduleToRemove = swordManager?.module(withName: name)
        var success = false

        let primaryBibleName: String? = primaryBible?.name
        let primaryCommentaryName: String? = primaryCommentary?.name
        let primaryDictionaryName: String? = primaryDictionary?.name

        if let moduleToRemove = moduleToRemove {
            if moduleToRemove.typeString() == SW.categoryDictionaries {
                // need to remove the dictionary cache, if it exists
                (moduleToRemove as? SwordDictionary)?.removeCache()
            }
            success = swordManager?.removeModuleNamed(name) ?? false
        }

        if name == primaryBibleName {
            primaryBible = nil
            UserDefaults.standard.removeObject(forKey: Defaults.lastBible)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
        } else if name == primaryCommentaryName {
            primaryCommentary = nil
            UserDefaults.standard.removeObject(forKey: Defaults.lastCommentary)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
        } else if name == primaryDictionaryName {
            primaryDictionary = nil
            UserDefaults.standard.removeObject(forKey: Defaults.lastDictionary)
            UserDefaults.standard.synchronize()
        }

        reload()

        return success
    }

    // MARK: - Reload last bible / commentary

    @objc(reloadLastBible)
    func reloadLastBible() {
        let defaults = UserDefaults.standard
        let lastModule = defaults.string(forKey: Defaults.lastBible)

        if let lastModule = lastModule {
            primaryBible = swordManager?.module(withName: lastModule)
        }

        if primaryBible == nil,
           let bibles = swordManager?.modules(forType: SW.categoryBibles), bibles.count > 0 {
            primaryBible = bibles[0] as? SwordModule
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            var prefs = defaults.persistentDomain(forName: bundleId) ?? [:]
            if let name = primaryBible?.name {
                prefs[Defaults.lastBible] = name
            }
            defaults.setPersistentDomain(prefs, forName: bundleId)
            UserDefaults.standard.synchronize()
        }
        NotificationCenter.default.post(name: .refSelectorResetBooks, object: nil)
        NotificationCenter.default.post(name: .newPrimaryBible, object: nil)
    }

    @objc(reloadLastCommentary)
    func reloadLastCommentary() {
        let defaults = UserDefaults.standard
        let lastModule = defaults.string(forKey: Defaults.lastCommentary)

        if let lastModule = lastModule {
            primaryCommentary = swordManager?.module(withName: lastModule)
        }

        if primaryCommentary == nil,
           let commentaries = swordManager?.modules(forType: SW.categoryCommentaries), commentaries.count > 0 {
            primaryCommentary = commentaries[0] as? SwordModule
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            var prefs = defaults.persistentDomain(forName: bundleId) ?? [:]
            if let name = primaryCommentary?.name {
                prefs[Defaults.lastCommentary] = name
            }
            defaults.setPersistentDomain(prefs, forName: bundleId)
            UserDefaults.standard.synchronize()
        }
        NotificationCenter.default.post(name: .newPrimaryCommentary, object: nil)
    }

    // MARK: - Chapter text

    // Grabs the bible text for a given chapter (e.g. "Gen 1")
    @objc(getBibleChapter:withExtraJS:)
    func getBibleChapter(_ chapter: String!, withExtraJS extraJS: String!) -> String! {
        if primaryBible == nil {
            reload()
            reloadLastBible()

            if primaryBible == nil {
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
        if let name = primaryBible?.name {
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
        if primaryCommentary == nil {
            reload()
            reloadLastCommentary()

            if primaryCommentary == nil {
                return PSModuleController.createHTMLString(String(format: "<center>%@</center>", NSLocalizedString("NoModulesInstalled", comment: "")),
                                                          usingPreferences: true, withJS: "",
                                                          usingModuleForPreferences: nil, fixedWidth: true)
            }
            NotificationCenter.default.post(name: .newPrimaryCommentary, object: nil)
        }
        var text: String?
        if let name = primaryCommentary?.name {
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
