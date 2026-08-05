//
//  ReadingWorkspace.swift
//  PocketSword
//
//  Wave 8: the reading workspace, owned by SwiftUI.
//
//  This file is where `PSTabBarControllerDelegate` and `PSModuleViewController`
//  went. Between them those two carried ~2,150 lines of UIKit coordination; what
//  was actually *reading* behaviour is here as two `@Observable` models plus a
//  view, and what was UIKit plumbing (a `UITabBarController`, a
//  `UINavigationController` per tab, thirteen `NotificationCenter` observers, an
//  Obj-C `@objc` surface for callers that no longer exist) is gone.
//
//  ── The shape ──────────────────────────────────────────────────────────────
//
//  `ReadingWorkspaceModel` is the coordinator. It owns the two `ReaderPaneModel`s
//  (Bible and commentary), the chapter-load fan-out that was `-displayChapter:`,
//  the study-popup routing that was the coordinator's `WKNavigationDelegate`, and
//  the Focus-mode / verse-menu / bookmark-highlight state. `ReadingModeSwitcher`
//  in `PocketSwordApp.swift` renders whichever pane is active.
//
//  `ReaderPaneModel` is one reading surface: the `ReaderWebPageModel` (Wave 6),
//  the `ReaderChromeModel` (Wave 7), and the per-pane scroll/verse bookkeeping
//  that used to be `PSModuleViewController`'s ivars. Two of these exist for the
//  app's lifetime, matching the two view controllers they replace — the Bible
//  pane and the commentary pane both stay loaded, because `-displayChapter:`
//  loads BOTH and relies on the other one still being there to receive its
//  `refToShow` / `jsToShow` deferral.
//
//  ── What is preserved verbatim, and why it looks odd ───────────────────────
//
//  * **The `refToShow` / `jsToShow` deferral.** `displayChapter` renders the
//    polled pane immediately and hands the *other* pane a pending ref + JS that
//    it applies on next appearance. That is what makes tapping a verse's
//    "commentary" action land on the right verse without rendering MHCC on every
//    Bible chapter change. `applyPendingWork()` is the old `-viewWillAppear:`
//    body, in its original branch order (ref, then JS, then verse, then poll).
//  * **`RestorePositionType` / `PollingType`** keep their meanings and their
//    three-way shapes. The `RestoreNoPosition` on BOTH `nextChapter` and
//    `prevChapter` is the deliberate Wave-5-era fix recorded in CLAUDE.md — do
//    not "restore" the asymmetry.
//  * **`bibleScrollPosition` / `commentaryScrollPosition`** are raw `UserDefaults`
//    string keys with no `Defaults` constant, written as `"%d"` of a `CGFloat`.
//    Unchanged: they are persisted, and `displayChapter`'s `.scroll` arm reads
//    them straight back into a `scrollToPosition(...)` JS call.
//  * **The duplicated-branch quirk in `searchDidFinish`** is NOT reproduced,
//    because the method is gone: the SwiftUI search workspace tells the model its
//    module kind directly (`SearchModel.moduleKind`), so there is nothing to
//    infer from the view hierarchy. That was the one place the old code guessed
//    at "which pane is on screen" and got it wrong (both arms tested the Bible
//    pane).
//
//  ── What the cutover deleted outright ─────────────────────────────────────
//
//  * `visibleReader` / `isReaderVisible(in:)` — "which pane is on screen" was a
//    `view.isDescendant(of:)` walk because the coordinator had no state for it.
//    It is now `mode`, a stored `ReadingMode`.
//  * `setShownTabTo:` — matched view controllers by comparing `.title` to
//    `BibleTabTitleString`. Now an assignment to `AppSession.selectedWorkspace`
//    plus `mode`.
//  * The `toggleNavigation` / `toggleMultiList` / `showInfoPane` / `hideInfoPane`
//    / `rotateInfoPane` / `showBibleTab` / `showCommentaryTab` /
//    `updateSelectedReference` notifications as a *transport*. The posts that
//    survive do so only because something outside this file still posts them
//    (`bookmarksChanged`, `redisplayPrimary*`, `resetBibleAndCommentaryView`,
//    `newPrimary*`); everything the reader used to say to itself through
//    `NotificationCenter` is now a method call.
//  * **The History/Search multi-list, outright.** It was a `UITabBarController`
//    presented modally from the reader, holding History and Search as its two
//    tabs, and it existed because the six-tab UIKit tab bar had no room for
//    either. The four-workspace tab bar has a Search workspace and a Library
//    workspace, so both are one tap away and a modal that reproduces them would
//    be a second way to reach the same screens. "Find all occurrences" now
//    *switches to* the Search workspace with its query seeded, rather than
//    presenting a sheet over the reader.
//    This is also what retires the `suppressMultiListPresentAnimation` /
//    `toggleMultiListFromMenu` pair that Waves 6 and 7 both had to carry: the
//    iOS 27 floating-tab-bar AnimationKit assertion needed a UIKit sheet
//    dismissing as a UIKit sheet presented, and there is no longer a UIKit sheet
//    on either side.
//  * `MBProgressHUD`, via `+displayTitle:`. Focus mode's chapter-change toast is
//    a SwiftUI overlay on the reader (`ReaderScreen`'s `chapterToast`), so the
//    last Objective-C dependency in the app target is gone with it.
//

import Foundation
import Observation
import SwiftUI
import WebKit

/// How much of the previous position a chapter load restores.
///
/// The three cases and their raw values are the old C enum's
/// (`RestoreScrollPosition` = 1, ...). The raw values no longer matter — nothing
/// persists or bridges them — but they are kept so a stale integer in a crash log
/// still reads the same.
enum RestorePositionType: Int {
    case scroll = 1
    case verse = 2
    case none = 3
}

/// Which pane a chapter load renders immediately; the other gets the deferral.
enum PollingType: Int {
    case bible = 1
    case commentary = 2
    case none = 3
}

/// SWORD `passagestudy` attribute names, mirrored byte-for-byte from the
/// `@"literal"` `#define`s in `globals.h` (Obj-C string `#define`s do not import
/// into Swift). Same literals as `PSModuleController`'s private `SW` enum; these
/// are only the ones the study-popup routing below reads out of `+dataForLink:`.
private enum SWRender {
    static let attrType = "type"
    static let attrAction = "action"
    static let attrValue = "value"
    static let attrModule = "modulename"

    static let featureGreekDef = "GreekDef"
    static let featureHebrewDef = "HebrewDef"
}

// MARK: - Study popup

/// A study popup the reader wants shown: a Strong's entry, a morph tag, a
/// footnote, or a lexicon entry.
///
/// This is the value the coordinator's `showInfo(_:)` used to take, now carried
/// by a `sheet(item:)` binding instead of a `NotificationShowInfoPane` post.
/// `PSInfoPopupContent` (the parsed lemma/transliteration/search-term bundle) is
/// unchanged — only how it reaches the presenter is.
struct StudyPopup: Identifiable, Equatable {
    let id = UUID()
    let content: PSInfoPopupContent

    static func == (lhs: StudyPopup, rhs: StudyPopup) -> Bool {
        lhs.id == rhs.id
    }
}

/// The verse-menu action sheet's subject.
struct VerseMenuTarget: Identifiable, Equatable {
    var id: Int { verse }
    let verse: Int
    /// The book-and-chapter reference the verse belongs to, already munged
    /// through `+createRefString:` — what the bookmark editor persists.
    let chapterRef: String
}

/// A bookmark the user is adding from the verse menu.
struct BookmarkDraft: Identifiable, Equatable {
    let id = UUID()
    let chapterRef: String
    let verse: String

    var reference: String {
        "\(chapterRef):\(verse)"
    }

    static func == (lhs: BookmarkDraft, rhs: BookmarkDraft) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - One reading pane

/// One reading surface: the WebView, its chrome, and its scroll/verse state.
///
/// Two exist for the app's lifetime. This is `PSModuleViewController` minus the
/// `UIViewController` — the reader model, the chrome model, and the ivars that
/// tracked position (`versePositionArray`, `currentShownVerse`, `verseToShow`,
/// `refToShow`, `jsToShow`, `finishedLoading`).
@MainActor
@Observable
final class ReaderPaneModel {
    let mode: ReadingMode
    @ObservationIgnored let reader: ReaderWebPageModel
    @ObservationIgnored let chrome: ReaderChromeModel

    /// A chapter this pane should render the next time it appears, with the JS to
    /// run after it. Set by `displayChapter` for the pane it did NOT poll.
    @ObservationIgnored var refToShow: String?
    @ObservationIgnored var jsToShow: String?

    /// Verse pixel offsets, reported by the page's `arraydump:` bridge call.
    @ObservationIgnored private var versePositions: [CGFloat] = []
    @ObservationIgnored private var currentShownVerse = 1
    @ObservationIgnored private var verseToShow = 0
    @ObservationIgnored private var finishedLoading = false
    /// Suppresses the transient scroll callbacks a rotation produces, so a
    /// mid-transition offset is not mistaken for the user scrolling. Wave 6.
    @ObservationIgnored private var isRestoringAfterTransition = false

    @ObservationIgnored weak var workspace: ReadingWorkspaceModel?

    init(mode: ReadingMode) {
        self.mode = mode
        self.reader = ReaderWebPageModel()
        self.chrome = ReaderChromeModel()
        chrome.isBibleTab = (mode == .bible)
        reader.delegate = self
    }

    // MARK: Chapter text

    /// The pref keys this pane reads and writes. The Bible pane and the
    /// commentary pane keep entirely separate verse/scroll positions, which is
    /// what lets one land on John 3:20 while the other sits at John 3:1.
    private var versePositionKey: String {
        mode == .bible
            ? Defaults.bibleVersePosition
            : Defaults.commentaryVersePosition
    }

    /// The raw scroll-offset key. Deliberately a literal: `"bibleScrollPosition"`
    /// / `"commentaryScrollPosition"` never had a `Defaults` constant, and both
    /// are persisted, so the strings are load-bearing.
    private var scrollPositionKey: String {
        mode == .bible ? "bibleScrollPosition" : "commentaryScrollPosition"
    }

    func loadHTML(_ html: String) {
        reader.loadHTMLString(
            html,
            baseURL: URL(fileURLWithPath: Bundle.main.resourcePath ?? "")
        )
    }

    func evaluateJavaScript(
        _ script: String,
        completion: ((Any?) -> Void)? = nil
    ) {
        reader.evaluateJavaScript(script, completion: completion)
    }

    func highlightAllOccurrences(of term: String) {
        reader.highlightAllOccurrences(of: term)
    }

    /// Renders `ref` into this pane now, with `extraJS` appended to the page's
    /// boot script.
    func render(ref: String?, extraJS: String) {
        let controller = PSModuleController.default()
        let html: String?
        switch mode {
        case .bible:
            html = controller?.getBibleChapter(ref, withExtraJS: extraJS)
        case .commentary:
            html = controller?.getCommentaryChapter(ref, withExtraJS: extraJS)
        }
        loadHTML(html ?? "")
    }

    /// The old `-viewWillAppear:` body, in its original branch order.
    ///
    /// The order is load-bearing: a pending ref wins over pending JS, which wins
    /// over a pending verse scroll, which wins over merely restarting the
    /// position poll. Collapsing these into "do whatever is set" would double-run
    /// the poll and re-render a chapter that was only meant to scroll.
    func applyPendingWork() {
        if let ref = refToShow {
            render(
                ref: ref,
                extraJS: "\(jsToShow ?? "")\nstartDetLocPoll();\n"
            )
            refToShow = nil
            jsToShow = nil
        } else if let js = jsToShow {
            evaluateJavaScript("\(js); startDetLocPoll();")
            jsToShow = nil
        } else if verseToShow > 0 {
            scrollToVerse(verseToShow)
        } else if finishedLoading {
            evaluateJavaScript("startDetLocPoll();")
        }
        if finishedLoading {
            scrollHappened(reader.lastScrollOffset)
        }
    }

    func stopPositionPolling() {
        evaluateJavaScript("stopDetLocPoll();")
    }

    // MARK: Verse position

    func setVerseToShow(_ verse: Int) {
        verseToShow = verse
    }

    func scrollToVerse(_ verse: Int) {
        guard verse > 0 else { return }
        evaluateJavaScript("scrollToVerse(\(verse));")
        verseToShow = 0
    }

    /// Maps a scroll offset to the verse it lands on and persists it.
    ///
    /// The loop is the original's: walk until the first verse whose offset
    /// exceeds `newOffsetY`, then clamp — index 0 means "verse 1", and landing
    /// past the end backs up one. Do not replace this with a binary search over
    /// `firstIndex(where:)`; the clamping at both ends is what keeps the title
    /// from flickering to verse 0 at the top of a chapter.
    private func scrollHappened(_ newOffsetY: CGFloat) {
        guard !versePositions.isEmpty else { return }
        var verse = 0
        while verse < versePositions.count {
            if newOffsetY < versePositions[verse] {
                break
            }
            verse += 1
        }
        if verse == 0 {
            verse = 1
        } else if verse == versePositions.count {
            verse -= 1
        }
        guard verse != currentShownVerse else { return }
        persistPosition(verse: verse, scrollOffset: newOffsetY)
    }

    /// Writes the verse and scroll offset this pane is showing, and retitles the
    /// chrome. `"%d"` of a `CGFloat` is the original's formatting — the persisted
    /// value has always been a truncated integer in a string.
    private func persistPosition(verse: Int, scrollOffset: CGFloat) {
        currentShownVerse = verse
        let verseString = String(format: "%d", Int32(verse))
        let defaults = UserDefaults.standard
        defaults.set(
            String(format: "%d", Int32(scrollOffset)),
            forKey: scrollPositionKey
        )
        defaults.set(verseString, forKey: versePositionKey)

        let ref = "\(PSModuleController.getCurrentBibleRef() ?? ""):\(verseString)"
        setTitle(ref)
    }

    private func saveVersePositions(_ positions: [CGFloat]) {
        guard !positions.isEmpty else { return }
        versePositions = positions
        if verseToShow > 0 {
            scrollToVerse(verseToShow)
        }
    }

    // MARK: Chrome

    /// Pushes a reference into the chrome, munged through `+createTitleRefString:`
    /// exactly as the old segmented control's middle segment was. The un-munged
    /// form becomes the accessibility label.
    func setTitle(_ title: String?) {
        chrome.title = PSModuleController.createTitleRefString(title) ?? ""
        chrome.accessibilityReference = PSModuleController.getCurrentBibleRef() ?? ""
    }

    /// The active module for this pane, by name — the primary Bible on the Bible
    /// pane, the primary commentary on the commentary pane. Drives both the
    /// display-toggle gating and the per-module pref keys those toggles write.
    var moduleName: String? {
        mode == .bible
            ? PSModuleController.default()?.primaryBibleName
            : PSModuleController.default()?.primaryCommentaryName
    }

    var redisplayNotification: Notification.Name {
        mode == .bible ? .redisplayPrimaryBible : .redisplayPrimaryCommentary
    }

    func rebuildDisplayToggles() {
        chrome.reloadDisplayToggles(forModule: moduleName)
    }

    /// The commentary pane's empty state: no commentary installed means there is
    /// nothing to page through, so the title becomes the app name and both
    /// chapter buttons go dead.
    func refreshForModuleChange() {
        rebuildDisplayToggles()
        guard mode == .commentary, moduleName == nil else { return }
        chrome.title = "PocketSword"
        chrome.accessibilityReference = "PocketSword"
        chrome.isNextEnabled = false
        chrome.isPreviousEnabled = false
    }

    // MARK: Rotation

    /// Re-measures verse offsets after a size change and restores the verse the
    /// reader was on.
    ///
    /// Wave 6 established every part of this: the poll is stopped *before* the
    /// transition so mid-flight offsets are discarded, `resetArrays()` re-measures
    /// against the new width, and the JS hands back `window.pageYOffset` so the
    /// persisted scroll offset matches where the page actually ended up rather
    /// than where it was before rotating.
    func prepareForSizeChange() {
        isRestoringAfterTransition = true
        stopPositionPolling()
    }

    func restoreAfterSizeChange() {
        let verse = max(1, currentShownVerse)
        let js = """
            resetArrays();
            scrollToVerse(\(verse));
            startDetLocPoll();
            return window.pageYOffset;
            """
        evaluateJavaScript(js) { [weak self] result in
            guard let self else { return }
            let offset = (result as? NSNumber)
                .map { CGFloat($0.doubleValue) }
                ?? self.reader.lastScrollOffset
            self.persistPosition(verse: verse, scrollOffset: offset)
            self.isRestoringAfterTransition = false
        }
    }

    // MARK: Bookmark highlighting

    func highlightBookmarks() {
        let shownBookmarks = PSBookmarks.getBookmarksForCurrentRef()
        guard shownBookmarks.count > 0 else { return }

        if let path = Bundle.main.path(
            forResource: "HighlightBookmarks",
            ofType: "js"
        ),
        let jsCode = try? String(contentsOfFile: path, encoding: .utf8) {
            evaluateJavaScript(jsCode)
        }
        for case let bookmark as PSBookmark in shownBookmarks {
            guard let rgbHexString = bookmark.rgbHexString,
                  let bref = bookmark.ref else {
                continue
            }
            let parts = bref.components(separatedBy: ":")
            guard parts.count > 1 else { continue }
            evaluateJavaScript(
                String(
                    format: "PS_HighlightVerseWithHexColour('%@','%@')",
                    parts[1],
                    PSBookmarkFolder.rgbString(fromHexString: rgbHexString)
                )
            )
        }
    }

    /// Clears highlight spans. The loop bound is the verse maximum of the chapter
    /// currently on screen, resolved from `lastRef` through the baked
    /// versification table; 0 on an unresolvable ref clears nothing, which is the
    /// same no-op the engine's -1-vs-0 path produced.
    func removeBookmarkHighlights() {
        var verses = 0
        if let resolver = PSBookOSISResolver.shared,
           let ref = PSModuleController.getCurrentBibleRef(),
           let (book, chapter) = resolver.resolve(ref: ref) {
            verses = resolver.verseMax(book: book, chapter: chapter) ?? 0
        }
        evaluateJavaScript(String(format: "PS_RemoveHighlights('%d')", Int32(verses)))
    }

    func redoBookmarkHighlights() {
        removeBookmarkHighlights()
        highlightBookmarks()
    }
}

// MARK: - ReaderWebPageModelDelegate

extension ReaderPaneModel: ReaderWebPageModelDelegate {
    func readerWebPageModel(
        _ model: ReaderWebPageModel,
        didScrollTo offset: CGFloat
    ) {
        guard !isRestoringAfterTransition else { return }
        scrollHappened(offset)
    }

    func readerWebPageModelDidStartNavigation(_ model: ReaderWebPageModel) {
        finishedLoading = false
    }

    func readerWebPageModelDidFinishNavigation(_ model: ReaderWebPageModel) {
        finishedLoading = true
        if verseToShow > 0 {
            scrollToVerse(verseToShow)
        } else {
            scrollHappened(model.lastScrollOffset)
        }
    }

    /// Automatic Focus mode: a user scroll that comes to rest enters Focus mode
    /// if the preference is on. Gated on the *end* of a scroll, not on each
    /// callback, so a slow drag does not toggle repeatedly.
    func readerWebPageModelDidEndUserScroll(_ model: ReaderWebPageModel) {
        guard UserDefaults.standard.bool(
            forKey: Defaults.fullscreenModePreference
        ) else {
            return
        }
        workspace?.enterFocusMode()
    }

    func readerWebPageModel(
        _ model: ReaderWebPageModel,
        decidePolicyFor request: URLRequest
    ) -> WKNavigationActionPolicy {
        navigationPolicy(for: request)
    }

    /// The reader's link/bridge router, formerly split across
    /// `PSModuleViewController.navigationPolicy(for:)` (Strong's, morph,
    /// footnotes) and the coordinator's own `WKNavigationDelegate` (bible refs,
    /// `search://`, lexicon entries). Both halves are here now, because there is
    /// only one navigation delegate left.
    private func navigationPolicy(
        for request: URLRequest
    ) -> WKNavigationActionPolicy {
        autoreleasepool {
            guard let url = request.url else { return .allow }

            // The page's own JS bridge: verse position, verse menu, offsets dump.
            if let event = ReaderBridgeEvent(url: url) {
                switch event {
                case .currentVerse(let verse, let scrollPosition):
                    if !isRestoringAfterTransition {
                        persistPosition(verse: verse, scrollOffset: scrollPosition)
                    }
                case .verseMenu(let verse):
                    if mode == .bible {
                        workspace?.presentVerseMenu(verse: verse)
                    }
                case .versePositions(let positions):
                    saveVersePositions(positions)
                }
                return .cancel
            }

            // `bible://` — an internal link to a verse to show in the Bible pane.
            if url.scheme == "bible" {
                if let data = PSModuleController.data(forLink: url),
                   (data[SWRender.attrAction] as? String) == "showRef" {
                    workspace?.openBibleReference(
                        (data[SWRender.attrValue] as? String) ?? ""
                    )
                    return .cancel
                }
            }

            // `search://H0430` — a Strong's link asking for every occurrence.
            // The FTS5 engine handles H0xxx/Hxxx equivalence internally, so this
            // no longer builds `lemma:` expressions with `||` operators.
            if url.scheme == "search" {
                if let term = url.host {
                    workspace?.startStrongsSearch(term)
                }
                return .cancel
            }

            // `sword://` in the commentary pane loads normally — MHCC's own
            // scripture links are the only source, and letting them navigate is
            // what makes them work.
            if url.scheme == "sword" {
                dlog("\nCOMMENTARY: requestString: \(url.absoluteString)")
                return .allow
            }

            guard let data = PSModuleController.data(forLink: url) else {
                return .allow
            }
            return studyPolicy(for: data)
        }
    }

    /// Routes a parsed `passagestudy.jsp` link to its popup.
    private func studyPolicy(
        for data: [AnyHashable: Any]
    ) -> WKNavigationActionPolicy {
        let action = data[SWRender.attrAction] as? String
        var entry: String?
        var popup: PSInfoPopupContent?

        switch action {
        case "showStrongs":
            (entry, popup) = strongsPopup(for: data)
        case "showMorph":
            entry = morphEntry(for: data)
        case "showNote" where (data[SWRender.attrType] as? String) == "n":
            entry = footnoteEntry(for: data)
        case "showRef":
            (entry, popup) = referenceOrLexiconPopup(for: data)
        default:
            return .allow
        }

        if let popup {
            workspace?.showStudyPopup(popup)
            return .cancel
        }
        if let entry {
            workspace?.showStudyPopup(PSInfoPopupContent(html: entry))
            return .cancel
        }
        return .allow
    }

    /// A Strong's number tapped in the chapter text. The lexicon is chosen by the
    /// link's own `type=Hebrew|Greek`, not by a preference — the roles are fixed.
    private func strongsPopup(
        for data: [AnyHashable: Any]
    ) -> (String?, PSInfoPopupContent?) {
        let hebrew = (data[SWRender.attrType] as? String) == "Hebrew"
        let module = hebrew
            ? BundledModules.strongsHebrew
            : BundledModules.strongsGreek
        let rawNumber = (data[SWRender.attrValue] as? String) ?? ""
        let reference = "\(hebrew ? "H" : "G")\(rawNumber)"

        var entry = PSContentReader.entry(module: module, key: rawNumber)
        let hasDefinition = entry != nil
        // The raw (pre-shell) entry is what the popup's lemma parser reads.
        let rawEntry = hasDefinition ? entry : nil
        if entry == nil {
            entry = NSLocalizedString(
                hebrew
                    ? "NoHebrewStrongsNumbersModuleInstalled"
                    : "NoGreekStrongsNumbersModuleInstalled",
                comment: ""
            )
        }
        entry = PSModuleController.createStrongsInfoHTMLString(
            entry,
            usingModuleForPreferences: module
        )
        guard let entry else { return (nil, nil) }
        return (
            entry,
            PSInfoPopupContent(
                strongsHTML: entry,
                rawEntry: rawEntry,
                reference: reference,
                // "Find all occurrences" is Bible-only: the commentary has no
                // Strong's index to search.
                allowsSearch: hasDefinition && mode == .bible
            )
        )
    }

    private func morphEntry(for data: [AnyHashable: Any]) -> String? {
        let module = BundledModules.morphGreek
        var entry: String?
        if (data[SWRender.attrType] as? String)?
            .hasPrefix("strongMorph") == true {
            entry = NSLocalizedString("MorphHebrewNotSupported", comment: "")
        } else {
            entry = PSContentReader.entry(
                module: module,
                key: data[SWRender.attrValue] as? String
            )
            if entry == nil {
                entry = NSLocalizedString(
                    "NoMorphGreekModuleInstalled",
                    comment: ""
                )
            }
        }
        return PSModuleController.createInfoHTMLString(
            entry,
            usingModuleForPreferences: module
        )
    }

    private func footnoteEntry(for data: [AnyHashable: Any]) -> String? {
        let module = moduleName
        var entry = PSContentReader.footnoteBody(module: module, data: data)
        // The `*x` / `*n` unescaping the popup path has always applied. The
        // markers are the note-anchor classes; the leading `*` is an artifact of
        // how the filters emitted them.
        entry = entry?.replacingOccurrences(of: "*x", with: "x")
        entry = entry?.replacingOccurrences(of: "*n", with: "n")
        return PSModuleController.createInfoHTMLString(
            entry,
            usingModuleForPreferences: module
        )
    }

    /// A `showRef` link: either a lexicon entry (the only kind the shipped
    /// content actually contains — all 14,989 baked `sword://` links) or a
    /// reference naming a module the user does not have.
    ///
    /// The `scriptRef` EXPANSION is gone (SWORD_REMOVAL_PLAN.md Phase 4 step 8)
    /// and stays gone: the app's own bible-ref links carry the `bible` scheme and
    /// are intercepted before here. What is KEPT is the not-installed
    /// placeholder, the one user-visible outcome that arm still has.
    private func referenceOrLexiconPopup(
        for data: [AnyHashable: Any]
    ) -> (String?, PSInfoPopupContent?) {
        let store = PSContentStore.shared
        guard let module = data[SWRender.attrModule] as? String,
              !module.isEmpty else {
            // No module named means "the primary Bible", which always exists —
            // so there is no placeholder to show and nothing to pop up.
            return (nil, nil)
        }

        let moduleType = store?.moduleMeta(module, key: "type")
        // `PSRefLinkRouter` reproduces `+moduleTypeForModuleTypeString:`'s
        // `ret = bible` default, which a naive type-string comparison gets wrong
        // for an unrecognised type. A nil type means "not a module we ship", and
        // that default sends it down the bible arm — exactly as an uninstalled
        // module did before.
        if PSRefLinkRouter.destination(
            forModuleName: module,
            moduleType: moduleType
        ) == .bibleRef {
            guard moduleType == nil else { return (nil, nil) }
            let placeholder = "<p style=\"color:grey;text-align:center;"
                + "font-style:italic;\">\(module) "
                + "\(NSLocalizedString("ModuleNotInstalled", comment: "is not installed."))</p>"
            return (
                PSModuleController.createInfoHTMLString(
                    placeholder,
                    usingModuleForPreferences: nil
                ),
                nil
            )
        }

        guard let store else {
            let placeholder = "<p style=\"color:grey;text-align:center;"
                + "font-style:italic;\">\(module) "
                + "\(NSLocalizedString("ModuleNotInstalled", comment: "is not installed."))</p>"
            return (placeholder, nil)
        }

        var entry = PSContentReader.entry(
            module: module,
            key: data[SWRender.attrValue] as? String
        )
        let rawValue = (data[SWRender.attrValue] as? String) ?? ""
        let hasGreekDef = store.moduleHasFeature(module, SWRender.featureGreekDef)
        let hasHebrewDef = store.moduleHasFeature(module, SWRender.featureHebrewDef)

        // A lexicon that declares BOTH already carries its own G/H prefix; one
        // that declares a single language does not, so the leading zeroes are
        // stripped and the prefix added. `H0` vs `G` is not a typo — the Hebrew
        // side re-pads, matching what the search index was built with.
        var strongsReference: String?
        if hasGreekDef && hasHebrewDef {
            strongsReference = rawValue
        } else if hasGreekDef {
            strongsReference = "G\(rawValue.drop(while: { $0 == "0" }))"
        } else if hasHebrewDef {
            strongsReference = "H0\(rawValue.drop(while: { $0 == "0" }))"
        }

        if let strongsReference {
            let rawEntry = entry
            entry = PSModuleController.createStrongsInfoHTMLString(
                entry,
                usingModuleForPreferences: module
            )
            guard let entry else { return (nil, nil) }
            return (
                entry,
                PSInfoPopupContent(
                    strongsHTML: entry,
                    rawEntry: rawEntry,
                    reference: strongsReference,
                    allowsSearch: true
                )
            )
        }

        // A non-Strong's lexicon entry renders in the Strong's *font* — the old
        // code swapped the global font pref around the shell build and put it
        // back. Preserved, because the shell reads the pref rather than taking a
        // font argument.
        let defaults = UserDefaults.standard
        let fontName = defaults.object(forKey: Defaults.fontNamePreference)
        defaults.set(AppConstants.strongsFontName, forKey: Defaults.fontNamePreference)
        entry = PSModuleController.createInfoHTMLString(
            entry,
            usingModuleForPreferences: module
        )
        defaults.set(fontName, forKey: Defaults.fontNamePreference)
        return (entry, nil)
    }
}

// MARK: - The workspace

/// The reading workspace: two panes, the chapter-load fan-out between them, and
/// the study surfaces they raise.
///
/// This is what `PSTabBarControllerDelegate` was, minus the tab bar. Its public
/// surface is what the SwiftUI views and the app-level router call — there is no
/// `@objc` on any of it, because there is no Objective-C caller left in the
/// target.
@MainActor
@Observable
final class ReadingWorkspaceModel {
    /// Which pane is showing. Replaces the coordinator's `visibleReader`
    /// `view.isDescendant(of:)` walk with actual state.
    var mode: ReadingMode = .bible {
        didSet {
            guard mode != oldValue else { return }
            session?.reading.mode = mode
            activePane.applyPendingWork()
            activePane.rebuildDisplayToggles()
        }
    }

    /// Focus mode: the chapter alone, with the tab bar and status bar hidden.
    /// Both panes follow the one flag, so leaving Focus mode on and switching
    /// panes stays in Focus mode — which is what the old `isFullScreen` per-VC
    /// pair did in practice, because the verse menu's commentary action
    /// explicitly propagated it.
    var isFocused = false {
        didSet {
            guard isFocused != oldValue else { return }
            bible.chrome.isFocused = isFocused
            commentary.chrome.isFocused = isFocused
        }
    }

    /// A brief reference toast, shown on a chapter change while in Focus mode.
    /// This is `+[PSTabBarControllerDelegate displayTitle:]` — an MBProgressHUD
    /// text-only HUD auto-hidden after 0.75 s — as SwiftUI state. Retiring it is
    /// what removes the app target's last Objective-C dependency.
    var chapterToast: String?

    /// The study popup (Strong's / morph / footnote / lexicon), presented as a
    /// sheet by the reader rather than posted through `NotificationShowInfoPane`.
    var studyPopup: StudyPopup?
    var verseMenuTarget: VerseMenuTarget?
    var bookmarkDraft: BookmarkDraft?
    var isPresentingVoiceReference = false

    let bible = ReaderPaneModel(mode: .bible)
    let commentary = ReaderPaneModel(mode: .commentary)

    @ObservationIgnored private weak var session: AppSession?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// The search-history item carried between the reader and the search
    /// workspace, so reopening search restores the last query and its results.
    @ObservationIgnored var savedSearchHistoryItem: PSSearchHistoryItem?
    @ObservationIgnored var savedSearchResultsMode: ReadingMode = .bible

    var activePane: ReaderPaneModel {
        mode == .bible ? bible : commentary
    }

    init(session: AppSession? = nil) {
        self.session = session
        bible.workspace = self
        commentary.workspace = self
        // The back-edge: `AppSession.open(_:)` sets `mode` when a sword:// URL names
        // a commentary, and it has no other way to reach this object.
        session?.readingWorkspace = self
        configureChrome(bible)
        configureChrome(commentary)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Start

    /// Renders the persisted chapter and starts observing the notifications that
    /// still have posters outside this file.
    ///
    /// Five of the coordinator's thirteen observers survive, and only because
    /// something else posts them: `resetBibleAndCommentaryView` (a font/size
    /// change, via `SettingsModel`), `redisplayPrimary{Bible,Commentary}` (a
    /// display-toggle flip and the `sword://` router), `bookmarksChanged` (the
    /// bookmark store), and `newPrimary{Bible,Commentary}` (module load). The
    /// other eight were the reader talking to itself and are now method calls.
    func start() {
        _ = PSModuleController.default()

        // Observers are registered BEFORE anything posts. The `.newPrimaryBible`
        // post below is what builds the display-toggle rows, and getting this
        // order wrong is silent: the reader works, but the overflow menu has no
        // display section at all. Verified on device — the KJV menu showed only
        // "History and Search" until this moved above the post.
        //
        // The old coordinator got away with posting first because the two reader
        // view controllers had already registered in `viewDidLoad` (its `init`
        // forced `_ = cvc.view` to make that happen), AND `setDelegate` called
        // `rebuildSettingsMenu()` directly. There is no view to force-load now, so
        // the ordering carries the whole burden — and both panes are primed
        // explicitly at the end, which is the equivalent of that direct call.
        observe(.resetBibleAndCommentaryView) { [weak self] in
            self?.redisplayWithDefaults()
        }
        observe(.redisplayPrimaryBible) { [weak self] in
            self?.redisplay(pane: .bible, restore: .verse)
        }
        observe(.redisplayPrimaryCommentary) { [weak self] in
            self?.redisplay(pane: .commentary, restore: .verse)
        }
        observe(.bookmarksChanged) { [weak self] in
            self?.redisplayAfterBookmarksChange()
        }
        observe(.newPrimaryBible) { [weak self] in
            self?.bible.refreshForModuleChange()
        }
        observe(.newPrimaryCommentary) { [weak self] in
            self?.commentary.refreshForModuleChange()
        }

        // The mic action is gated on BOTH the feature flag and on-device speech
        // availability, as `PSModuleViewController.setDelegate` was. Bible pane
        // only — `ReaderScreen` also checks `isBibleTab`, but setting it on both
        // keeps the two panes' chrome models honest.
        if PSFeatureFlags.voiceReferenceEnabled {
            Task { [weak self] in
                if case .available = await PSVoiceRefSession.availability() {
                    self?.bible.chrome.isVoiceAvailable = true
                }
            }
        }

        // Now the posts, and a direct prime of both panes. The post is what a
        // module *change* goes through; priming directly is what covers the first
        // render, where nothing has changed yet.
        NotificationCenter.default.post(name: .newPrimaryBible, object: nil)
        bible.refreshForModuleChange()
        commentary.refreshForModuleChange()

        let lastRef = PSModuleController.getCurrentBibleRef()
        // A launch that is *replaying* a sword:// URL restores the verse it names;
        // an ordinary launch restores the scroll offset it left off at.
        let restore: RestorePositionType =
            session?.lastOpenedURL == nil ? .scroll : .verse
        session?.lastOpenedURL = nil
        displayChapter(lastRef, polling: .bible, restore: restore)
    }

    private func observe(
        _ name: Notification.Name,
        _ handler: @escaping @MainActor () -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observers.append(observer)
    }

    private func configureChrome(_ pane: ReaderPaneModel) {
        let chrome = pane.chrome
        chrome.onPreviousChapter = { [weak self] in
            self?.previousChapter()
        }
        chrome.onNextChapter = { [weak self] in
            self?.nextChapter()
        }
        chrome.onHistoryAndSearch = { [weak self] in
            self?.session?.selectedWorkspace = .search
        }
        chrome.onVoiceReference = { [weak self] in
            self?.presentVoiceReference()
        }
        chrome.onToggleFocus = { [weak self] in
            self?.toggleFocusMode()
        }
        chrome.onDisplayToggle = { [weak self, weak pane] toggle in
            guard let self, let pane else { return }
            self.applyDisplayToggle(toggle, on: pane)
        }
    }

    /// Flips a per-module display pref and re-renders. The key is
    /// `"<pref>_<ModuleName>"`, unchanged — that format is persisted.
    private func applyDisplayToggle(
        _ toggle: ReaderDisplayToggle,
        on pane: ReaderPaneModel
    ) {
        guard let module = pane.moduleName else { return }
        let defaults = UserDefaults.standard
        let current = defaults.psBool(toggle.preference, forModule: module)
        defaults.psSet(!current, forPref: toggle.preference, module: module)
        NotificationCenter.default.post(
            name: pane.redisplayNotification,
            object: nil
        )
        pane.rebuildDisplayToggles()
    }

    // MARK: Chapter loading

    /// Loads `ref` into one pane and defers it into the other.
    ///
    /// A faithful port of `-displayChapter:withPollingType:restoreType:`. Three
    /// things here are deliberate:
    ///
    ///  1. **Only the polled pane renders.** The other is handed `refToShow` +
    ///     `jsToShow` and renders on next appearance, which is what stops every
    ///     Bible chapter change from also rendering MHCC.
    ///  2. **The two panes' JS is built separately** from their own verse-position
    ///     prefs, because they track position independently.
    ///  3. **The title's verse defaults differ by restore type.** `.scroll` reads
    ///     the commentary's own persisted verse for the commentary title;
    ///     `.none` forces both to "1". Collapsing them retitles one pane wrongly
    ///     on a chapter page.
    func displayChapter(
        _ ref: String?,
        polling: PollingType,
        restore position: RestorePositionType
    ) {
        let defaults = UserDefaults.standard
        var bibleJS = ""
        var commentaryJS = ""
        var versePosition = defaults.string(forKey: Defaults.bibleVersePosition)

        switch position {
        case .scroll:
            if let scroll = defaults.string(forKey: "bibleScrollPosition") {
                bibleJS += "scrollToPosition(\(scroll));\n"
            }
            if let scroll = defaults.string(forKey: "commentaryScrollPosition") {
                commentaryJS += "scrollToPosition(\(scroll));\n"
            }
        case .verse:
            if let verse = versePosition {
                bibleJS += "scrollToVerse(\(verse));\n"
                bible.setVerseToShow((verse as NSString).integerValue)
            }
            versePosition = defaults.string(forKey: Defaults.commentaryVersePosition)
            if let verse = versePosition {
                commentaryJS += "scrollToVerse(\(verse));\n"
                commentary.setVerseToShow((verse as NSString).integerValue)
            }
        case .none:
            break
        }

        switch polling {
        case .bible:
            bibleJS += "startDetLocPoll();\n"
            bible.render(ref: ref, extraJS: bibleJS)
            commentary.refToShow = ref
            commentary.jsToShow = commentaryJS
        case .commentary:
            commentaryJS += "startDetLocPoll();\n"
            commentary.render(ref: ref, extraJS: commentaryJS)
            bible.refToShow = ref
            bible.jsToShow = bibleJS
        case .none:
            bible.refToShow = ref
            bible.jsToShow = bibleJS
            commentary.refToShow = ref
            commentary.jsToShow = commentaryJS
        }

        var bibleVerse = versePosition ?? "1"
        var commentaryVerse = versePosition ?? "1"
        switch position {
        case .scroll:
            commentaryVerse = defaults.string(
                forKey: Defaults.commentaryVersePosition
            ) ?? "1"
        case .verse:
            break
        case .none:
            bibleVerse = "1"
            commentaryVerse = "1"
        }

        let refString = PSModuleController.createRefString(ref) ?? ""
        let controller = PSModuleController.default()
        if controller?.primaryBibleName != nil {
            bible.setTitle("\(refString):\(bibleVerse)")
        }
        if controller?.primaryCommentaryName != nil {
            commentary.setTitle("\(refString):\(commentaryVerse)")
        }

        updateChapterButtonState()
    }

    /// The three-way next/previous enablement. Both panes get the same state,
    /// because both navigate the same versification.
    private func updateChapterButtonState() {
        let current = PSModuleController.getCurrentBibleRef()
        let atLast = current == PSModuleController.getLastRefAvailable()
        let atFirst = current == PSModuleController.getFirstRefAvailable()
        for pane in [bible, commentary] {
            pane.chrome.isNextEnabled = !atLast
            pane.chrome.isPreviousEnabled = !atFirst
        }
    }

    func redisplay(pane mode: ReadingMode, restore position: RestorePositionType) {
        let pane = mode == .bible ? bible : commentary
        pane.refToShow = nil
        pane.jsToShow = nil
        displayChapter(
            PSModuleController.getCurrentBibleRef(),
            polling: mode == .bible ? .bible : .commentary,
            restore: position
        )
    }

    private func redisplayWithDefaults() {
        displayChapter(
            PSModuleController.getCurrentBibleRef(),
            polling: .none,
            restore: .verse
        )
    }

    /// A bookmark change re-renders the Bible pane at its current SCROLL offset,
    /// not its verse — the user has not navigated, only recoloured.
    private func redisplayAfterBookmarksChange() {
        bible.refToShow = nil
        bible.jsToShow = nil
        displayChapter(
            PSModuleController.getCurrentBibleRef(),
            polling: .bible,
            restore: .scroll
        )
    }

    // MARK: Chapter paging

    /// Both directions restore NO position, i.e. land at the START of the chapter
    /// they move to.
    ///
    /// `previousChapter` used to pass `.verse`, which reads the *shared*
    /// `Defaults{Bible,Commentary}VersePosition` — the verse you were on in the
    /// chapter you are LEAVING. Paging back from John 3:20 therefore restored
    /// "verse 20" into John 2, dumping you near the bottom of a chapter you had
    /// just arrived at. Chapter paging is not a position-restoring operation.
    func nextChapter() {
        page(forward: true)
    }

    func previousChapter() {
        page(forward: false)
    }

    private func page(forward: Bool) {
        activePane.setVerseToShow(0)
        let current = PSModuleController.getCurrentBibleRef()
        let boundary = forward
            ? PSModuleController.getLastRefAvailable()
            : PSModuleController.getFirstRefAvailable()
        guard current != boundary else { return }

        guard let controller = PSModuleController.default(),
              let ref = forward
                ? controller.setToNextChapter()
                : controller.setToPreviousChapter() else {
            return
        }

        if isFocused {
            showChapterToast(ref)
        }
        displayChapter(
            ref,
            polling: mode == .bible ? .bible : .commentary,
            restore: .none
        )
        session?.library.recordHistory(mode: mode)
    }

    /// The 0.75 s reference toast, formerly an MBProgressHUD. Each show cancels
    /// the previous one's dismissal by identity, so paging quickly does not clear
    /// the toast early.
    private func showChapterToast(_ ref: String?) {
        let title = PSModuleController.createRefString(ref)
        chapterToast = title
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard let self, self.chapterToast == title else { return }
            self.chapterToast = nil
        }
    }

    // MARK: Reference selection

    /// Applies a book/chapter/verse selection from the reference picker or the
    /// voice sheet.
    ///
    /// The same-chapter fast path is preserved: selecting a verse in the chapter
    /// already on screen scrolls both panes rather than re-rendering, which is
    /// the difference between an instant jump and a visible reload.
    func selectReference(bookName: String, chapter: Int, verse: Int) {
        let ref = "\(bookName) \(chapter)"
        let verseString = "\(verse)"
        let controller = PSModuleController.default()

        if PSModuleController.getCurrentBibleRef() == ref {
            bible.scrollToVerse(verse)
            commentary.scrollToVerse(verse)
            if controller?.primaryBibleName != nil {
                bible.setTitle("\(ref):\(verseString)")
            }
            if controller?.primaryCommentaryName != nil {
                commentary.setTitle("\(ref):\(verseString)")
            }
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(verseString, forKey: Defaults.bibleVersePosition)
        defaults.set(verseString, forKey: Defaults.commentaryVersePosition)
        displayChapter(
            ref,
            polling: mode == .bible ? .bible : .commentary,
            restore: .verse
        )
        session?.library.recordHistory(mode: mode)
    }

    /// A `bible://` link tapped in the chapter text: switch to the Bible pane and
    /// go, honouring a `:verse` suffix if the link carries one.
    func openBibleReference(_ reference: String) {
        mode = .bible
        session?.selectedWorkspace = .read

        let parts = reference.components(separatedBy: ":")
        if parts.count > 1 {
            UserDefaults.standard.set(
                parts[1],
                forKey: Defaults.bibleVersePosition
            )
            displayChapter(parts[0], polling: .bible, restore: .verse)
        } else {
            displayChapter(reference, polling: .bible, restore: .none)
        }
        session?.library.recordHistory(mode: .bible)
    }

    /// Opens a reference chosen in the Library or Search workspace. Routed
    /// through the same `sword://` path the URL router uses, so a bookmark, a
    /// history row and an external link all take one code path.
    func openLibraryReference(_ reference: String, module: String?) {
        var components = URLComponents()
        components.scheme = "sword"
        components.host = module
        components.path = "/\(reference)"
        guard let url = components.url else { return }
        session?.open(url)
    }

    // MARK: Focus mode

    func toggleFocusMode() {
        activePane.stopPositionPolling()
        isFocused.toggle()
        activePane.evaluateJavaScript("startDetLocPoll();")
    }

    func enterFocusMode() {
        guard !isFocused else { return }
        toggleFocusMode()
    }

    func exitFocusMode() {
        guard isFocused else { return }
        toggleFocusMode()
    }

    // MARK: Study surfaces

    func showStudyPopup(_ content: PSInfoPopupContent) {
        studyPopup = StudyPopup(content: content)
    }

    func presentVerseMenu(verse: Int) {
        let chapterRef = PSModuleController.createRefString(
            PSModuleController.getCurrentBibleRef()
        ) ?? ""
        verseMenuTarget = VerseMenuTarget(verse: verse, chapterRef: chapterRef)
    }

    func addBookmark(for target: VerseMenuTarget) {
        bookmarkDraft = BookmarkDraft(
            chapterRef: target.chapterRef,
            verse: "\(target.verse)"
        )
    }

    /// The verse menu's "show in commentary" action: carry the verse across,
    /// switch panes, and keep Focus mode if it was on.
    func showInCommentary(verse: Int) {
        commentary.setVerseToShow(verse)
        mode = .commentary
        session?.selectedWorkspace = .read
    }

    func presentVoiceReference() {
        guard PSFeatureFlags.voiceReferenceEnabled,
              PSModuleController.default()?.primaryBibleName != nil else {
            return
        }
        isPresentingVoiceReference = true
    }

    /// "Find all occurrences" from a Strong's popup: dismiss the popup, seed the
    /// Search workspace with a Strong's query, and switch to it.
    ///
    /// The `suppressMultiListPresentAnimation` workaround that Waves 6 and 7 both
    /// had to carry is GONE, and this is the change that retires it. It existed
    /// because a UIKit `pageSheet` dismissing while another UIKit sheet was
    /// presented forced the iOS 27 floating tab bar to lay out inside a
    /// transition's alongside-animation block, tripping an AnimationKit assertion
    /// (`_UITabBarVisualProvider_FloatingAccessibility layoutSubviews`,
    /// `EXC_BREAKPOINT`, no app frames on the stack). Wave 7 re-tested and found
    /// the workaround still necessary, correctly noting the assertion was in the
    /// UIKit tab bar the coordinator still owned.
    ///
    /// There is now no second present at all: the popup dismisses and the tab
    /// selection changes. Verify on device — rotate with the Strong's popup open,
    /// then tap "Find all occurrences" — before trusting this paragraph.
    func startStrongsSearch(_ term: String) {
        guard !term.isEmpty else { return }

        let item = PSSearchHistoryItem()
        item.searchTermToDisplay = term
        item.strongsSearch = true
        savedSearchHistoryItem = item
        savedSearchResultsMode = mode

        studyPopup = nil
        session?.selectedWorkspace = .search
    }

    /// Highlights every occurrence of a search term in the pane that produced the
    /// results.
    func highlightSearchTerm(_ term: String, mode: ReadingMode) {
        let pane = mode == .bible ? bible : commentary
        pane.highlightAllOccurrences(of: term)
    }

    // MARK: Search hand-off

    /// The module choices the search workspace offers — the two readable modules,
    /// in pane order.
    var searchModuleChoices: [SearchModuleChoice] {
        let controller = PSModuleController.default()
        var choices: [SearchModuleChoice] = []
        if let bibleName = controller?.primaryBibleName {
            choices.append(SearchModuleChoice(id: bibleName, kind: .bible))
        }
        if let commentaryName = controller?.primaryCommentaryName {
            choices.append(
                SearchModuleChoice(id: commentaryName, kind: .commentary)
            )
        }
        return choices
    }

    /// The module search should preselect: whichever pane the reader is on.
    var preferredSearchModule: String? {
        mode == .bible
            ? PSModuleController.default()?.primaryBibleName
            : PSModuleController.default()?.primaryCommentaryName
    }

    /// The book name for the "current book" search scope, taken off `lastRef` by
    /// dropping the trailing chapter number.
    var currentSearchBookName: String? {
        guard let reference = PSModuleController.getCurrentBibleRef(),
              let lastSpace = reference.range(of: " ", options: .backwards) else {
            return nil
        }
        return String(reference[..<lastSpace.lowerBound])
    }

    /// The search-history item to restore when the search workspace opens.
    ///
    /// Preserves the coordinator's two-armed rule: an item whose results belong
    /// to the pane now on screen is restored WITH its results; an item from the
    /// other pane is restored as a query only (and consumed, so it does not come
    /// back a third time).
    func searchHistoryItemToRestore() -> PSSearchHistoryItem? {
        if savedSearchResultsMode == mode,
           let item = savedSearchHistoryItem,
           item.results != nil {
            return item
        }
        if let item = savedSearchHistoryItem,
           item.searchTerm != nil
            || (item.searchTermToDisplay?.count ?? 0) > 0 {
            savedSearchHistoryItem = nil
            return item
        }
        return nil
    }

    // MARK: Size changes

    func prepareForSizeChange() {
        bible.prepareForSizeChange()
        commentary.prepareForSizeChange()
    }

    func restoreAfterSizeChange() {
        bible.restoreAfterSizeChange()
        commentary.restoreAfterSizeChange()
    }
}
