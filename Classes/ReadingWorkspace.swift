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
//  `ReaderPaneModel` is one reading surface: the chapter document (Wave 9), the
//  `ReaderChromeModel` (Wave 7), and the per-pane scroll/verse bookkeeping
//  that used to be `PSModuleViewController`'s ivars. Two of these exist for the
//  app's lifetime, matching the two view controllers they replace — the Bible
//  pane and the commentary pane both stay loaded, because `-displayChapter:`
//  loads BOTH and relies on the other one still being there to receive its
//  `refToShow` / `pendingRestore` deferral.
//
//  ── Wave 9: the WebView is gone from this file ─────────────────────────────
//
//  `ReaderPaneModel` used to own a `ReaderWebPageModel`, build an HTML page and
//  steer it with JavaScript. It now owns a `ChapterDocument` and a
//  `ScrollPosition`. See the type's own doc comment for the one-for-one table of
//  what replaced what; the headline is that the `versepos` pixel-offset table, the
//  `pocketsword:` URL bridge, the two JS resources and the position poll are all
//  deleted rather than ported, because a native scroll view addresses a verse by
//  IDENTITY instead of by measured offset.
//
//  ── What is preserved verbatim, and why it looks odd ───────────────────────
//
//  * **The `refToShow` / `pendingRestore` deferral.** `displayChapter` renders the
//    polled pane immediately and hands the *other* pane a pending ref + restore
//    instruction that it applies on next appearance. That is what makes tapping a
//    verse's "commentary" action land on the right verse without rendering MHCC on
//    every Bible chapter change. `applyPendingWork()` is the old
//    `-viewWillAppear:` body, in its original branch order.
//  * **`RestorePositionType` / `PollingType`** keep their meanings and their
//    three-way shapes. The `RestoreNoPosition` on BOTH `nextChapter` and
//    `prevChapter` is the deliberate Wave-5-era fix recorded in CLAUDE.md — do
//    not "restore" the asymmetry.
//  * **`bibleScrollPosition` / `commentaryScrollPosition`** are raw `UserDefaults`
//    string keys with no `Defaults` constant, written as `"%d"` of a `CGFloat`.
//    Unchanged: they are persisted, and `displayChapter`'s `.scroll` arm reads
//    them straight back into a `.offset(_:)` restore.
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

/// One reading surface: the chapter document, its chrome, and its scroll/verse
/// state.
///
/// Two exist for the app's lifetime. This is `PSModuleViewController` minus the
/// `UIViewController` — and, as of Wave 9, minus the WebView too.
///
/// ── What Wave 9 changed here ──────────────────────────────────────────────
///
/// The pane used to own a `ReaderWebPageModel`, render a chapter to an HTML string,
/// and steer it by evaluating JavaScript. It now owns a `ChapterDocument` and a
/// `ScrollPosition`. The replacements, one for one:
///
/// | before (JS / WebKit) | after (native) |
/// |---|---|
/// | `render(ref:extraJS:)` → HTML string | `render(ref:restore:)` → `ChapterDocument` |
/// | `versePositions` (the `arraydump:` offset table) | nothing — identity, not pixels |
/// | `scrollToVerse(n)` → `window.scrollTo(0, versepos[n])` | `scrollPosition.scrollTo(id:)` |
/// | `scrollToPosition(y)` | `scrollPosition.scrollTo(y:)` |
/// | `startDetLocPoll()` / `stopDetLocPoll()` | nothing — see below |
/// | `resetArrays()` after rotation | nothing — identity is width-independent |
/// | `HighlightBookmarks.js` | `ChapterVerse.highlightColour` in the document |
/// | `SearchWebView.js` | `searchHighlightTerms`, applied while rendering |
///
/// **The poll was already dead.** `startDetLocPoll`'s `setInterval` was commented
/// out in the shipped JS, so the `pocketsword:currentverse:` bridge never fired and
/// verse tracking ran entirely off the offset table plus scroll callbacks. Wave 9
/// does not reimplement a poll; `scrollOffsetChanged` is the whole of it.
///
/// **`jsToShow` became `pendingRestore`.** The deferral itself is unchanged and
/// still load-bearing (see `displayChapter`), but what is deferred is now a typed
/// restore instruction rather than a string of JavaScript.
/// One geometry sample from the reading scroll view.
///
/// `offset` is `contentOffset.y + contentInsets.top` — the value that has always
/// been persisted, unchanged. The two heights ride along because the MODEL cannot
/// otherwise tell three cases apart, and telling them apart is the whole of the
/// launch-restore fix:
///
///  * a scroll view that has **not been laid out yet** publishes all-zero geometry.
///    Its `offset` of 0 is not where the reader is, it is the absence of an answer.
///    Measured at launch: the first publish is `off=0 size=0 container=0`, it arrives
///    ~130 ms BEFORE the restore's hop runs, and `scrollOffsetChanged` persisted it —
///    so the reader wrote 0 over `bibleScrollPosition` and then restored the 0 it had
///    just written. Self-perpetuating: once the key is 0, so is every later launch.
///  * an offset restore that has **landed** reports the value that was asked for.
///  * an offset restore that **cannot** land — the chapter is shorter than the offset
///    it was left at, because the font grew — reports the largest offset the geometry
///    allows, which is `contentSize.height - containerSize.height` exactly, in this
///    same space. (Measured on KJV Genesis 1: content 1874, container 675, and the
///    scroll view pins at 1199.)
struct ReaderScrollSample: Equatable {
    var offset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat

    /// The largest `offset` this geometry can reach.
    var maxOffset: CGFloat { max(0, contentHeight - containerHeight) }

    /// Whether this sample is an answer at all.
    var isLaidOut: Bool { contentHeight > 0 && containerHeight > 0 }
}

@MainActor
@Observable
final class ReaderPaneModel {
    let mode: ReadingMode
    @ObservationIgnored let chrome: ReaderChromeModel

    /// The rendered chapter. Replaces the HTML string handed to a `WebPage`.
    ///
    /// It is only ever replaced WHOLESALE, which is what makes the paragraph cache
    /// below safe: assigning it regroups the rows exactly once.
    var document = ChapterDocument() {
        didSet { paragraphs = document.paragraphs }
    }

    /// `document.verses` regrouped into flowing paragraphs — the prose layout's row
    /// set — derived once per document instead of once per body evaluation.
    ///
    /// `ChapterDocument.paragraphs` walks and reallocates every verse on each call,
    /// and it had two hot callers: `ChapterTextView.body`'s `ForEach` (re-evaluated
    /// on every scroll-driven invalidation, over 176 verses in Psalm 119) and
    /// `rowID(containing:)` on every scroll-to-verse. Cached HERE rather than stored
    /// on `ChapterDocument` so the value type keeps its synthesized conformances —
    /// the parity tests build on those — and so the cache cannot go stale: the only
    /// way to change the rows is to assign `document`.
    private(set) var paragraphs: [ChapterParagraph] = []

    /// Where the scroll view is. `ScrollPosition` addresses a verse by IDENTITY,
    /// which is what lets the `versepos` pixel table and its rotation re-measure go.
    var scrollPosition = ScrollPosition(idType: Int.self)

    /// Verse-per-line, read per-module. Drives the row unit in `ChapterTextView`;
    /// the document itself is layout-agnostic.
    var versePerLine = false

    /// Resolved font/size/line-height for this render.
    var textStyle = ChapterTextRenderer.Style.current()

    /// The terms to highlight in the rendered text — what `SearchWebView.js` did by
    /// walking the DOM and inserting `<span class="PocketSwordHighlight">`.
    ///
    /// Pushed into `textStyle` on assignment, so an existing render re-highlights
    /// without reloading the chapter. Clearing it is assigning `[]`, where the JS
    /// needed a whole second function to unwrap the spans it had inserted.
    ///
    /// A list rather than one string because an "all words" / "any words" query
    /// matches on several, and the results list already highlights each of them —
    /// highlighting only the first in the reader would disagree with the row the
    /// user tapped.
    var searchHighlightTerms: [String] = [] {
        didSet {
            guard searchHighlightTerms != oldValue else { return }
            textStyle.highlightTerms = searchHighlightTerms
        }
    }

    /// A chapter this pane should render the next time it appears, with the
    /// position to restore. Set by `displayChapter` for the pane it did NOT poll.
    @ObservationIgnored var refToShow: String?
    @ObservationIgnored var pendingRestore: PaneRestore?

    /// What a deferred (or immediate) render should restore.
    ///
    /// This is `jsToShow` as a value instead of a string of JavaScript. The three
    /// cases are the three things the old JS said: `scrollToVerse(n)`,
    /// `scrollToPosition(y)`, or nothing.
    enum PaneRestore: Equatable {
        case verse(Int)
        case offset(CGFloat)
        case none
    }

    @ObservationIgnored private var currentShownVerse = 1
    @ObservationIgnored private var verseToShow = 0
    /// Suppresses the transient scroll callbacks a size change produces, so a
    /// mid-transition offset is not mistaken for the user scrolling. Wave 6's
    /// finding, still needed: a rotation republishes geometry before the content
    /// settles.
    @ObservationIgnored private var isRestoringAfterTransition = false
    /// Which size change the suppression above belongs to. `restoreAfterSizeChange`
    /// clears the flag from a deferred hop, and only if no newer transition has
    /// started — so two rotations in quick succession cannot have the first one's
    /// hop re-enable persisting while the second is still settling.
    @ObservationIgnored private var sizeChangeGeneration = 0
    /// The last scroll offset seen, clamped at 0 (see `scrollOffsetChanged`).
    @ObservationIgnored private var lastScrollOffset: CGFloat = 0
    /// An offset restore that has been requested but not yet observed to have landed.
    /// Two things read it, and both are load-bearing: `scrollOffsetChanged` (do not
    /// persist a position from before the restore lands) and `restoreAfterSizeChange`
    /// (do not re-anchor on a verse while an offset restore is still in flight).
    @ObservationIgnored private var outstandingOffsetRestore: CGFloat?

    @ObservationIgnored weak var workspace: ReadingWorkspaceModel?

    init(mode: ReadingMode) {
        self.mode = mode
        self.chrome = ReaderChromeModel()
        chrome.isBibleTab = (mode == .bible)
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

    /// Renders `ref` into this pane now and applies `restore`.
    ///
    /// Where the WebView path built an HTML page (shell + CSS + 4 KB of navigation
    /// JS + six `&nbsp;` pads) and handed it to `WebPage.load`, this builds a
    /// `ChapterDocument` and assigns it. Everything downstream of the document —
    /// bookmark highlight colours, verse anchors, link targets — is already in the
    /// value, so there is nothing to inject afterwards.
    func render(ref: String?, restore: PaneRestore) {
        guard let module = moduleName, let ref else {
            document = ChapterDocument()
            return
        }
        // ── `lastRef` is persisted HERE, and it has to be. ──
        //
        // It used to be a side effect of `-getBibleChapter:withExtraJS:` /
        // `-getCommentaryChapter:withExtraJS:`, which wrote it just before
        // returning the HTML. The native reader does not call either, so nothing was
        // updating it — and because `lastRef` is what `getCurrentBibleRef()` reads,
        // and the chrome title is built from that, paging to Genesis 2 moved the TEXT
        // while the toolbar still said "Genesis 1". Found on device; the persisted
        // ref was stale too, so a relaunch would have reopened the wrong chapter.
        //
        // Written before the document is built, matching the original ordering
        // relative to the highlight lookup: `PSBookmarks.getBookmarksForCurrentRef()`
        // reads `lastRef`, so a bookmark on the chapter being opened has to see the
        // new value.
        UserDefaults.standard.set(
            PSModuleController.createRefString(ref),
            forKey: Defaults.lastRef
        )
        versePerLine = UserDefaults.standard.psBool(
            Defaults.vplPreference, forModule: module
        )
        // Re-resolve font/size (a Settings change re-renders through
        // `resetBibleAndCommentaryView`), but carry the search highlight across —
        // rebuilding the style from defaults alone would silently drop it, so a
        // chapter turn while search results were highlighted would lose the yellow.
        var style = ChapterTextRenderer.Style.current()
        style.highlightTerms = searchHighlightTerms
        textStyle = style
        document = PSContentReader.shared.chapterDocument(
            module: module,
            ref: ref,
            kind: mode == .bible ? .bible : .commentary
        ) ?? ChapterDocument()
        apply(restore)
    }

    /// Move the scroll view, by identity or by offset.
    ///
    /// In prose mode a verse may sit inside a paragraph whose row id is an earlier
    /// verse, so the target is resolved to the enclosing row — otherwise
    /// `scrollTo(id:)` would silently do nothing for any verse that does not open a
    /// paragraph, which is most of them.
    ///
    /// **The scroll is applied in a separate update from the document assignment,
    /// and that is load-bearing.** Setting `document` and then mutating
    /// `scrollPosition` synchronously puts both in one SwiftUI update, and the scroll
    /// target is then resolved against the row set that is being replaced — so the
    /// request is simply dropped and the scroll view keeps its old *content offset*
    /// against new row heights. Measured on device: flipping Verse Per Line at
    /// Genesis 1:1 landed on verse 6, while the persisted position still correctly
    /// read verse 1. The same path serves the font change and every display toggle,
    /// so it would have moved the reader on all of them.
    ///
    /// This is not the Wave 6 "jerky jump" in disguise: that was a scroll applied
    /// after the first PAINT of a newly-loaded page (`window.onload` plus a 250 ms
    /// timeout). This is one update later on an already-visible chapter, which is
    /// what makes the target resolvable at all.
    private func apply(_ restore: PaneRestore) {
        switch restore {
        case .verse(let verse):
            guard verse > 0 else { return }
            // A newer instruction supersedes an offset restore that has not landed.
            outstandingOffsetRestore = nil
            currentShownVerse = verse
            verseToShow = 0
            let target = rowID(containing: verse)
            Task { @MainActor [weak self] in
                self?.scrollPosition.scrollTo(id: target, anchor: .top)
            }
        case .offset(let offset):
            guard offset > 0 else {
                outstandingOffsetRestore = nil
                return
            }
            lastScrollOffset = offset
            // Recorded BEFORE the hop, because the window it protects opens
            // immediately: the scroll view publishes geometry — and
            // `scrollOffsetChanged` persisted it — long before the hop runs. Measured
            // at launch: 130 ms before, the first publish reporting a scroll view
            // that has no content at all.
            outstandingOffsetRestore = offset
            Task { @MainActor [weak self] in
                self?.scrollPosition.scrollTo(y: offset)
            }
        case .none:
            // A chapter change lands at the top, which is what
            // `RestoreNoPosition` meant.
            outstandingOffsetRestore = nil
            lastScrollOffset = 0
            currentShownVerse = 1
            Task { @MainActor [weak self] in
                self?.scrollPosition.scrollTo(edge: .top)
            }
        }
    }

    /// The old `-viewWillAppear:` body, in its original branch order.
    ///
    /// The order is load-bearing: a pending ref wins over a pending restore, which
    /// wins over a pending verse scroll. Collapsing these into "do whatever is set"
    /// would re-render a chapter that was only meant to scroll.
    func applyPendingWork() {
        if let ref = refToShow {
            render(ref: ref, restore: pendingRestore ?? .none)
            refToShow = nil
            pendingRestore = nil
        } else if let restore = pendingRestore {
            apply(restore)
            pendingRestore = nil
        } else if verseToShow > 0 {
            scrollToVerse(verseToShow)
        }
    }

    // MARK: Verse position

    func setVerseToShow(_ verse: Int) {
        verseToShow = verse
    }

    func scrollToVerse(_ verse: Int) {
        apply(.verse(verse))
    }

    /// The id of the row that displays `verse`.
    ///
    /// In verse-per-line mode every verse is its own row, so this is the identity.
    /// In prose mode rows are paragraphs keyed by their FIRST verse, so a verse in
    /// the middle of a paragraph has to resolve to that paragraph's id. This is the
    /// one place the prose layout costs something: the scroll lands at the top of
    /// the verse's paragraph rather than exactly on the verse.
    private func rowID(containing verse: Int) -> Int {
        if versePerLine { return verse }
        var candidate = verse
        for paragraph in paragraphs {
            guard let first = paragraph.verses.first?.number,
                  let last = paragraph.verses.last?.number else { continue }
            if verse >= first && verse <= last {
                candidate = first
                break
            }
        }
        return candidate
    }

    /// A scroll came to rest at `offset`: work out which verse that is and persist
    /// it.
    ///
    /// The WebView version walked the `versepos` pixel table. There is no table now,
    /// so the visible verse is derived from the scroll offset against the rows the
    /// scroll view reports. `ScrollPosition` does not expose "which id is at the
    /// top", so the offset is kept and the verse is only advanced when the reader
    /// actually moves — which is all the title needs.
    func scrollOffsetChanged(_ sample: ReaderScrollSample) {
        guard !isRestoringAfterTransition else { return }
        // ── A scroll view with no content has not answered the question. ──
        //
        // Its `offset` of 0 is the absence of a position, not the top of the chapter,
        // and persisting it is half of what killed the launch scroll restore: the
        // first publish arrives before the restore's hop runs, so the reader wrote 0
        // over the key and then restored the 0 it had just written.
        guard sample.isLaidOut else { return }
        let normalized = max(0, sample.offset)
        if let target = outstandingOffsetRestore {
            if abs(normalized - target) <= Self.scrollThreshold {
                // Landed. `lastScrollOffset` and the persisted key both already hold
                // the target, so there is nothing to write.
                outstandingOffsetRestore = nil
                return
            }
            if target > sample.maxOffset,
               normalized >= sample.maxOffset - Self.scrollThreshold {
                // **Unreachable, and pinned as close as it can get.** The chapter is
                // shorter than the offset it was left at — a bigger font, or a
                // re-render with fewer rows. That IS the position now, so give up on
                // the target and persist the truth; suppressing forever would stop
                // saving the user's scrolls for the rest of the session.
                outstandingOffsetRestore = nil
            } else {
                // Still in flight. Every offset published between the request and the
                // landing is the scroll view saying where it WAS, and persisting one
                // of them overwrites the value being restored.
                return
            }
        }
        // The two-point threshold is the legacy one, and it matters: without it a
        // sub-pixel geometry republish counts as a scroll and rewrites the persisted
        // position on every layout pass.
        guard abs(lastScrollOffset - normalized) > Self.scrollThreshold else { return }
        lastScrollOffset = normalized
        persistPosition(verse: currentShownVerse, scrollOffset: normalized)
    }

    /// The legacy two-point dead zone, named because the restore gate above compares
    /// against it too — a restore counts as landed to the same tolerance a scroll
    /// counts as moved.
    private static let scrollThreshold: CGFloat = 2

    /// A finger landed on the reader: abandon any restore still in flight.
    ///
    /// This is what makes `outstandingOffsetRestore` a gate rather than a timeout. If
    /// a restore ever neither lands nor pins, the user's first touch resumes normal
    /// persistence instead of suppressing it for the rest of the session.
    func userBeganScrolling() {
        outstandingOffsetRestore = nil
    }

    /// The topmost visible verse changed, as reported by the view.
    ///
    /// The verse and the offset are persisted from two different places because only
    /// the view knows which row is at the top — see `tracksTopmostVerse`. Both write
    /// through `persistPosition`, so the pair stays consistent whichever moves first.
    func topmostVerseChanged(_ verse: Int) {
        // The clamp lives in `persistPosition`, so comparing the RAW value here
        // would let verse 0 through as "changed" forever (0 != 1) and rewrite the
        // position on every layout pass.
        let clamped = max(1, verse)
        guard !isRestoringAfterTransition, clamped != currentShownVerse else { return }
        persistPosition(verse: clamped, scrollOffset: lastScrollOffset)
    }

    /// Automatic Focus mode: a user scroll that comes to rest enters Focus mode if
    /// the preference is on. Gated on the END of a scroll, not on each callback, so
    /// a slow drag does not toggle repeatedly.
    func userScrollEnded() {
        guard UserDefaults.standard.bool(
            forKey: Defaults.fullscreenModePreference
        ) else {
            return
        }
        workspace?.enterFocusMode()
    }

    /// Called by the view when a link in the chapter text is tapped.
    func handle(link: InlineLink) {
        route(link)
    }

    /// Writes the verse and scroll offset this pane is showing, and retitles the
    /// chrome. `"%d"` of a `CGFloat` is the original's formatting — the persisted
    /// value has always been a truncated integer in a string.
    private func persistPosition(verse: Int, scrollOffset: CGFloat) {
        // Clamped at the single write point, so no caller can persist verse 0.
        //
        // The jsToShow-era code could not write a 0 because `currentVerse()` opened
        // with `if(now < 5) return 1;`. The native reader CAN: the intro slot is loop
        // counter 0 (`ChapterVerse.isIntro`), so a chapter whose first row is an
        // intro reports "verse 0" as the topmost row, and MHCC has one in most
        // chapters. Seen on device as a "Gen 2:0" toolbar title, and worse than
        // cosmetic — the value is persisted, and a `.verse` restore reads it back, so
        // `scrollToVerse(0)` would silently do nothing on the next launch.
        let verse = max(1, verse)
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

    // MARK: Chrome

    /// Pushes a reference into the chrome, munged through `+createTitleRefString:`
    /// exactly as the old segmented control's middle segment was. The un-munged
    /// form becomes the accessibility label.
    func setTitle(_ title: String?) {
        // Assigned only on an actual change. `persistPosition` calls this on every
        // ~2pt of scroll, and an `@Observable` setter runs `withMutation` regardless
        // of whether the value differs — so re-assigning an identical title
        // invalidated the `.principal` toolbar item and `ReaderReferenceControl`
        // dozens of times per swipe. The guard is value-based rather than
        // event-based on purpose: it cannot leave the title stale, because every
        // real change still gets through.
        let munged = PSModuleController.createTitleRefString(title) ?? ""
        if chrome.title != munged {
            chrome.title = munged
        }
        let reference = PSModuleController.getCurrentBibleRef() ?? ""
        if chrome.accessibilityReference != reference {
            chrome.accessibilityReference = reference
        }
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

    // MARK: Size changes

    /// Rotation, or an iPad split-view resize.
    ///
    /// Wave 6 needed a full re-measure here: `resetArrays()` rebuilt the `versepos`
    /// pixel table against the new width, then scrolled back to the remembered
    /// verse, because a width change invalidates every measured offset. Not doing it
    /// restored the wrong verse (Gen 2:4 came back as Gen 2:2).
    ///
    /// **Identity is width-independent, so there is nothing to re-measure.** All
    /// that survives is suppressing the transient scroll callbacks the transition
    /// itself produces — otherwise a mid-rotation offset is mistaken for a user
    /// scroll and overwrites the persisted position.
    func prepareForSizeChange() {
        sizeChangeGeneration += 1
        isRestoringAfterTransition = true
    }

    /// **The suppression has to outlive this call, which is why the scroll is not
    /// delegated to `apply`.** `ReaderScreen` calls `prepareForSizeChange()` and
    /// `restoreAfterSizeChange()` back to back in one `onGeometryChange` action, and
    /// `apply` only SCHEDULES its scroll — so clearing the flag on the way out left
    /// a zero-length window and the whole mechanism inert: every transient callback
    /// the rotation emitted still reached `persistPosition` and overwrote the saved
    /// position with a mid-transition value.
    ///
    /// The scroll is inlined rather than delegated to `apply`, so the clear happens
    /// inside the same deferred hop, immediately after the scroll it is waiting for —
    /// one `Task` rather than two, so the ordering is structural instead of relying on
    /// main-actor FIFO. The generation check is what stops a second size change's
    /// suppression being cleared by the first one's hop; because
    /// `prepareForSizeChange` bumps it, the newest restore always matches, so the flag
    /// cannot wedge on.
    func restoreAfterSizeChange() {
        let generation = sizeChangeGeneration
        // ── An OFFSET restore still in flight wins over `currentShownVerse`, and
        // that is the other half of the dead launch scroll. ──
        //
        // The reader's size settles in STEPS at launch — measured (402, 0) →
        // (402, 623) → (402, 675) as the navigation bar and the floating tab bar come
        // in, and `(402, 0)` is not `CGSize.zero`, so `ReaderScreen`'s `old != .zero`
        // guard does not stop it. The rotation hook therefore fires during LAUNCH,
        // after `displayChapter(restore: .scroll)` has asked for `.offset(500)` and
        // before that request's hop has run. Re-anchoring on `currentShownVerse`
        // (still 1, because an offset restore names no verse) queued a
        // `scrollTo(id:)` that landed 11 ms AFTER the offset scroll and dragged the
        // reader back — and because `rowID(containing: 1)` resolves to the intro row,
        // "back" was the absolute top. The two scrolls are one line apart in the log.
        //
        // A `.verse` restore never showed this, which is exactly why verse restores
        // worked and offset restores did not: `apply(.verse(n))` sets
        // `currentShownVerse = n` first, so re-anchoring re-issues the SAME scroll.
        // Only the offset arm left no record of what was being restored.
        //
        // The re-issue below is belt-and-braces, NOT the mechanism: an identical
        // `scrollTo(y:)` is a no-op once the binding already holds that value, and at
        // launch `apply`'s hop has already run. What fixes the dead scroll is not
        // issuing the `scrollTo(id:)` at all. Do not "simplify" the wrong half.
        let pendingOffset = outstandingOffsetRestore
        // Cleared unconditionally, exactly as before: `verseToShow` is consumed by
        // `applyPendingWork`'s third branch, and leaving a stale one set would let a
        // later appearance scroll to a verse the user never asked for.
        verseToShow = 0
        var verseTarget: Int?
        if pendingOffset == nil {
            let verse = max(1, currentShownVerse)
            currentShownVerse = verse
            verseTarget = rowID(containing: verse)
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let pendingOffset {
                self.scrollPosition.scrollTo(y: pendingOffset)
            } else if let verseTarget {
                self.scrollPosition.scrollTo(id: verseTarget, anchor: .top)
            }
            guard self.sizeChangeGeneration == generation else { return }
            self.isRestoringAfterTransition = false
        }
    }

    // MARK: Bookmark highlighting

    /// Re-render so bookmark colours are picked up.
    ///
    /// `HighlightBookmarks.js` used to reach into the live DOM and set
    /// `style.backgroundColor` on each `vvv{n}` span, with a matching
    /// `PS_RemoveHighlights` loop to clear them. Both are gone: the highlight is a
    /// property of the document (`ChapterVerse.highlightColour`, filled by
    /// `PSContentReader` from the same `PSBookmarks` lookup), so re-rendering is
    /// both the add and the remove — and it cannot drift out of step with the text
    /// the way a DOM mutation could.
    ///
    /// Position is preserved by rendering at the current offset, which is what the
    /// `bookmarksChanged` path always wanted: the user recoloured a verse, they did
    /// not navigate.
    func redoBookmarkHighlights() {
        let offset = lastScrollOffset
        render(ref: PSModuleController.getCurrentBibleRef(), restore: .offset(offset))
    }
}

// MARK: - Link routing

extension ReaderPaneModel {

    /// Routes a tapped chapter link to its study surface.
    ///
    /// This is what the `WKNavigationDelegate` policy chain was — formerly split
    /// across `PSModuleViewController.navigationPolicy(for:)` (Strong's, morph,
    /// footnotes) and the coordinator's own delegate (bible refs, `search://`,
    /// lexicon entries), then merged in Wave 8, and now reduced to a switch over a
    /// typed enum.
    ///
    /// Three whole classes of case are gone rather than ported, because the native
    /// reader has no navigation to intercept:
    ///
    ///  * **The `pocketsword:` JS bridge** (`currentverse` / `versemenu` /
    ///    `arraydump`). Verse position and offsets are now the pane's own state, and
    ///    a verse-number tap arrives as `.verseMenu` from the text itself.
    ///  * **`bible://` and `search://`.** Those schemes existed so JS could talk to
    ///    the app; nothing emits them now. `search://` is reached by the study
    ///    popup's own "Find all occurrences" button, which calls
    ///    `startStrongsSearch` directly.
    ///  * **The `.allow` arm.** There is no web navigation to allow — MHCC's own
    ///    `sword://` scripture links are handled by the view's `openURL` falling
    ///    through to `.systemAction`, which reaches `AppSession`'s router.
    func route(_ link: InlineLink) {
        switch link {
        case .verseMenu(let verse):
            // Bible only. A commentary's verse anchor was `href="#verse%ld"` rather
            // than `pocketsword:versemenu:`, so tapping one has never done
            // anything — preserved deliberately (SwordModule.mm:1116). The renderer
            // does not even attach the link on a commentary, so this is belt and
            // braces.
            if mode == .bible {
                workspace?.presentVerseMenu(verse: verse)
            }
        case .strongs(let type, let value):
            let (entry, popup) = strongsPopup(type: type, value: value)
            present(entry: entry, popup: popup)
        case .morph(let type, let value):
            present(entry: morphEntry(type: type, value: value), popup: nil)
        case .note(let kind, let value, let module, let passage):
            // Only `n` renders a body; the `x` branch was proven unreachable for
            // the shipped content (all 6,959 KJV notes are type='study' with an
            // empty refList) and deleted in SWORD_REMOVAL_PLAN.md Phase 4 step 8.
            guard kind == "n" else { return }
            present(
                entry: footnoteEntry(value: value, module: module, passage: passage),
                popup: nil
            )
        case .scriptRef(let value):
            // Unreachable for the shipped corpus. Logged rather than silently
            // dropped so that if a future module does emit one, it says so.
            alog("chapter carries a scriptRef link, which the shipped content never "
                 + "did — ignoring: \(value)")
        }
    }

    private func present(entry: String?, popup: PSInfoPopupContent?) {
        if let popup {
            workspace?.showStudyPopup(popup)
            return
        }
        if let entry {
            workspace?.showStudyPopup(PSInfoPopupContent(html: entry))
        }
    }

    /// A Strong's number tapped in the chapter text. The lexicon is chosen by the
    /// link's own `type=Hebrew|Greek`, not by a preference — the roles are fixed.
    private func strongsPopup(
        type: String,
        value: String
    ) -> (String?, PSInfoPopupContent?) {
        let hebrew = type == "Hebrew"
        let module = hebrew
            ? BundledModules.strongsHebrew
            : BundledModules.strongsGreek
        let rawNumber = value
        let reference = "\(hebrew ? "H" : "G")\(rawNumber)"

        var entry = PSContentReader.entry(module: module, key: rawNumber)
        let hasDefinition = entry != nil
        // The raw entry is what the popup's lemma parser reads. Wave 9: it is now
        // also what the popup RENDERS — `createStrongsInfoHTMLString` is gone, so
        // there is no longer a shelled copy alongside the raw one.
        let rawEntry = hasDefinition ? entry : nil
        if entry == nil {
            entry = NSLocalizedString(
                hebrew
                    ? "NoHebrewStrongsNumbersModuleInstalled"
                    : "NoGreekStrongsNumbersModuleInstalled",
                comment: ""
            )
        }
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

    private func morphEntry(type: String, value: String) -> String? {
        let module = BundledModules.morphGreek
        var entry: String?
        if type.hasPrefix("strongMorph") {
            entry = NSLocalizedString("MorphHebrewNotSupported", comment: "")
        } else {
            entry = PSContentReader.entry(module: module, key: value)
            if entry == nil {
                entry = NSLocalizedString(
                    "NoMorphGreekModuleInstalled",
                    comment: ""
                )
            }
        }
        return entry
    }

    /// A footnote body.
    ///
    /// `passage` still arrives URL-encoded (`Genesis+4%3A1`), because that is the
    /// form the token payload carries and `PSContentReader.noteBody` decodes it
    /// itself — see `decodePassage`. The module on the LINK is preferred over the
    /// pane's, matching what the anchor named.
    private func footnoteEntry(value: String, module: String, passage: String) -> String? {
        let lookupModule = module.isEmpty ? moduleName : module
        guard let lookupModule else { return nil }
        var entry = PSContentReader.shared.noteBody(
            module: lookupModule,
            osisRef: passage,
            marker: value
        )
        // The `*x` / `*n` unescaping the popup path has always applied. The
        // markers are the note-anchor classes; the leading `*` is an artifact of
        // how the filters emitted them.
        entry = entry?.replacingOccurrences(of: "*x", with: "x")
        entry = entry?.replacingOccurrences(of: "*n", with: "n")
        return entry
    }

}

// The `showRef` arm that used to sit here — `referenceOrLexiconPopup(for:)`, the
// lexicon-entry and "module not installed" placeholder pair — is DELETED by Wave 9,
// and the deletion is licensed by a measurement rather than by inspection.
//
// It was only ever reachable from a `passagestudy.jsp?action=showRef` anchor inside
// chapter text, and the corpus scan re-derived what Phase 4 step 8 first proved:
// across all 2,378 chapter rows and all 1,322 stored headings there is **no
// `showRef` anchor at all**. The 14,989 baked `sword://` lexicon→lexicon links that
// arm also served live in the *dictionary* entries, not in chapter records, and they
// are handled where they occur — `DictionaryEntryView` in `SwiftUILibraryViews`,
// which has its own link routing.
//
// `PSRefLinkRouter` is untouched and still tested: it remains the predicate for the
// `sword://` URL path in `AppSession`. What is gone is only this reader-side caller.

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
        // Wave 9: these were two strings of JavaScript (`scrollToPosition(y);` /
        // `scrollToVerse(n);` plus a `startDetLocPoll();`) spliced into the page's
        // boot script. They are typed restore instructions now — same three cases,
        // same per-pane independence, no code generation.
        var bibleRestore = ReaderPaneModel.PaneRestore.none
        var commentaryRestore = ReaderPaneModel.PaneRestore.none
        var versePosition = defaults.string(forKey: Defaults.bibleVersePosition)

        switch position {
        case .scroll:
            if let scroll = defaults.string(forKey: "bibleScrollPosition") {
                bibleRestore = .offset(CGFloat((scroll as NSString).doubleValue))
            }
            if let scroll = defaults.string(forKey: "commentaryScrollPosition") {
                commentaryRestore = .offset(CGFloat((scroll as NSString).doubleValue))
            }
        case .verse:
            if let verse = versePosition {
                bibleRestore = .verse((verse as NSString).integerValue)
                bible.setVerseToShow((verse as NSString).integerValue)
            }
            versePosition = defaults.string(forKey: Defaults.commentaryVersePosition)
            if let verse = versePosition {
                commentaryRestore = .verse((verse as NSString).integerValue)
                commentary.setVerseToShow((verse as NSString).integerValue)
            }
        case .none:
            break
        }

        switch polling {
        case .bible:
            bible.render(ref: ref, restore: bibleRestore)
            commentary.refToShow = ref
            commentary.pendingRestore = commentaryRestore
        case .commentary:
            commentary.render(ref: ref, restore: commentaryRestore)
            bible.refToShow = ref
            bible.pendingRestore = bibleRestore
        case .none:
            bible.refToShow = ref
            bible.pendingRestore = bibleRestore
            commentary.refToShow = ref
            commentary.pendingRestore = commentaryRestore
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
        pane.pendingRestore = nil
        displayChapter(
            PSModuleController.getCurrentBibleRef(),
            polling: mode == .bible ? .bible : .commentary,
            restore: position
        )
    }

    /// A font or font-size change (`resetBibleAndCommentaryView`, posted by
    /// `SettingsModel.onReadingAppearanceChanged`): re-render the pane the user is
    /// on, and leave the other one's deferral alone.
    ///
    /// **`polling: .none` was a faithful port that stopped being correct.** The
    /// Obj-C original passed `NoViewPoll`, and that worked because the font UI was
    /// its own TAB: neither reader was on screen, and each drained its deferral from
    /// `-viewWillAppear:` on the way back. Both SwiftUI panes stay in the view
    /// hierarchy for the app's lifetime, so the only drain left is `mode`'s `didSet`
    /// — a font change therefore changed nothing visible until the user switched
    /// Bible ⇄ commentary. Polling the active pane renders it now; `displayChapter`
    /// still hands the inactive pane `refToShow` + `pendingRestore`, so the deferral
    /// that stops every appearance change from also rendering MHCC is unchanged.
    private func redisplayWithDefaults() {
        redisplay(pane: mode, restore: .verse)
    }

    /// A bookmark change re-renders the Bible pane at its current SCROLL offset,
    /// not its verse — the user has not navigated, only recoloured.
    private func redisplayAfterBookmarksChange() {
        bible.refToShow = nil
        bible.pendingRestore = nil
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
        // Paging away from the chapter a search result landed on ends that
        // result's highlight. Without this the yellow follows the reader through
        // every subsequent chapter until the app relaunches, which is what
        // `PS_RemoveAllHighlights` existed to prevent — the JS had to unwrap the
        // spans it had inserted, where clearing state is an empty array.
        activePane.searchHighlightTerms = []
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

    /// Focus mode toggles the chrome only.
    ///
    /// It used to bracket the flip with `stopDetLocPoll()` / `startDetLocPoll()`,
    /// because hiding the bars changes the viewport and the JS offset table had to be
    /// re-measured against it. There is no offset table and no poll, so the safe-area
    /// republish is all that is needed and SwiftUI does that itself.
    func toggleFocusMode() {
        isFocused.toggle()
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

        studyPopup = nil
        savedSearchResultsMode = mode
        // Drive the search model DIRECTLY rather than parking a
        // `PSSearchHistoryItem` for `configure(...)` to pick up.
        //
        // The seeded-item route worked exactly once per launch and then silently
        // showed stale results: `SearchView` calls `configure(...)` from a `.task`
        // behind a `@State private var configured` guard, so the second Strong's
        // search never applied its item. Tapping H1254 showed H430's results —
        // reported from a device and reproduced on iOS 27.
        //
        // `savedSearchHistoryItem` is deliberately NOT set here. It is the
        // *reader's* memory of the last search, written when the user leaves the
        // search workspace, and pre-loading it with a query that has not run yet
        // would make the reader restore a resultless item.
        session?.search.startStrongsQuery(
            term,
            currentBookName: currentSearchBookName
        )
        session?.selectedWorkspace = .search
    }

    /// Highlights every occurrence of a search term in the pane that produced the
    /// results.
    ///
    /// `SearchWebView.js` did this by walking the DOM and wrapping each match in a
    /// `<span class="PocketSwordHighlight">` with an inline yellow background, and
    /// `PS_RemoveAllHighlights` undid it by unwrapping and re-normalising. Both are
    /// gone: the term is state on the pane, and the renderer applies it while
    /// building the text — so it cannot get out of step with the content, and
    /// clearing it is assigning nil.
    ///
    /// **This is called from the search-result hand-off, and was not before.** The
    /// renderer half was built in Wave 9 and the pane state with it, but nothing
    /// ever set it: the final audit found `highlightSearchTerm` had zero callers,
    /// and tracing it back through `git` showed the only one it ever had was a
    /// commented-out debug line in the Obj-C original
    /// (`// [self highlightSearchTerm: @"and" forTab: BibleTab];`,
    /// `PSTabBarControllerDelegate.mm:209`). So the reader has never highlighted a
    /// searched term, in any era — the results list highlighted its own rows and
    /// the chapter you landed on did not. Wiring it is the smaller change than
    /// deleting a working renderer, and it is what the results list already implies.
    ///
    /// Takes the term LIST rather than one string, because that is what the search
    /// side actually has: `SearchModel.highlightTerms` splits an all/any-words query
    /// into its words, honours quoted phrases, drops one-character noise, and
    /// returns **empty** for a Strong's search — where the matched text is a lemma
    /// the marker points at, not text present in the verse.
    func highlightSearchTerms(_ terms: [String], mode: ReadingMode) {
        let pane = mode == .bible ? bible : commentary
        pane.searchHighlightTerms = terms.filter { !$0.isEmpty }
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
