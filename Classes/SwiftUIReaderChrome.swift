//
//  SwiftUIReaderChrome.swift
//  PocketSword
//
//  Wave 7: the iOS 27 reading chrome. `ReaderScreen` wraps the Wave 6
//  `SwiftUIReaderWebView` in a `NavigationStack` and owns every control that used
//  to live in `PSModuleViewController`'s UIKit navigation bar:
//
//  - a `UISegmentedControl` in `navigationItem.titleView` holding
//    [back-white.png | "Gen 23:23" | forward-white.png] with hardcoded 50/95/50pt
//    segment widths, and
//  - three `UIBarButtonItem`s: history/search (left), the `textformat` display
//    menu and the `microphone` voice button (right).
//
//  The placements are deliberate and follow the plan's iOS 27 chrome brief:
//
//  - Reference and chapter navigation sit at `.principal` with
//    `visibilityPriority(.high)`, so a constrained width sheds the study actions
//    before it sheds the ability to move between chapters. This is the one
//    control the reader cannot do without.
//  - Focus mode is pinned with `.topBarPinnedTrailing`, which keeps it reachable
//    while the bar is minimized — it is the control that *un*-minimizes reading,
//    so it must not itself be collapsible.
//  - Secondary study actions (the per-module display toggles, History & Search,
//    and voice reference) go in a `ToolbarOverflowMenu`.
//  - `toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)` quiets the
//    chrome during ordinary reading. NOTE the spelling: the SDK symbol is
//    `toolbarMinimizationBehavior(_:for:)`, not the `toolbarMinimizeBehavior` the
//    plan named — the latter is the *tab bar* API (`tabBarMinimizeBehavior`).
//
//  The display toggles are still PER-MODULE and still gated on the BAKED feature
//  set — see `ReaderDisplayToggle.toggles(forModule:store:)`, which is a pure
//  function precisely so the six-rows-for-KJV / zero-rows-for-MHCC contract is
//  assertable without the simulator. It writes the same `"<pref>_<ModuleName>"`
//  keys the UIKit menu wrote; the wire format is unchanged.
//

import SwiftUI
import UIKit

// SWORD feature names, mirrored byte-for-byte from `globals.h`'s @"literal"
// #defines (Obj-C string #defines do not import into Swift). Same approach and
// same literals as PSModuleViewController's private SWRender enum, which this
// replaces for the display-menu path.
private enum ReaderFeature {
    static let strongs = "Strongs"                  // SWMOD_FEATURE_STRONGS
    static let confStrongs = "StrongsNumbers"       // SWMOD_CONF_FEATURE_STRONGSNUMBERS
    static let morph = "Morph"                      // SWMOD_FEATURE_MORPH
    static let headings = "Headings"                // SWMOD_FEATURE_HEADINGS
    static let footnotes = "Footnotes"              // SWMOD_FEATURE_FOOTNOTES
    static let scriptRef = "Scripref"               // not Scriptref
    static let redLetterWords = "RedLetterWords"
    static let typeBibles = "Biblical Texts"        // SWMOD_CATEGORY_BIBLES
}

/// One row of the per-tab display menu: a boolean toggle over a per-module
/// preference key.
struct ReaderDisplayToggle: Identifiable, Equatable {
    /// Stable identity for `ForEach`, and the accessibility-identifier suffix.
    /// Matches the UIKit `UIAction.Identifier` suffixes ("strongs", "morph",
    /// "headings", "footnotes", "xref", "redLetter", "vpl") so the identifiers
    /// the XCUITests look for do not change meaning.
    let id: String
    /// The localization KEY, resolved by the view. Kept as a key rather than a
    /// resolved string so this stays a pure value type.
    let titleKey: String
    /// The unsuffixed preference name; the module name is appended by
    /// `UserDefaults.ps*(…forModule:)`.
    let preference: String

    /// The rows a module's advertised features earn it, in the UIKit menu's
    /// order.
    ///
    /// Feature gating reads the BAKED feature set (`content_meta`'s
    /// `module.<name>.features`), which holds exactly what
    /// `-[SwordModule hasFeature:]` answered — including its matching of
    /// `GlobalOptionFilter` entries (bare and OSIS/GBF/ThML/UTF8-prefixed), not
    /// just `Feature=` lines. That is why KJV earns Footnotes / Headings /
    /// RedLetter despite declaring only `Feature=StrongsNumbers`.
    ///
    /// Measured consequence, unchanged from the UIKit menu and verified against
    /// the live engine before it was deleted: **KJV yields six rows, not seven.**
    /// It has no `OSISScripref` filter and no `Feature=Scripref`, so
    /// Cross-references was never in its menu. MHCC declares neither, so it
    /// yields **zero** rows and the caller hides the control rather than
    /// presenting an empty menu.
    static func toggles(
        forModule moduleName: String?,
        store: PSContentStore?
    ) -> [ReaderDisplayToggle] {
        guard let moduleName, let store else { return [] }

        func has(_ feature: String) -> Bool {
            store.moduleHasFeature(moduleName, feature)
        }

        var toggles: [ReaderDisplayToggle] = []
        if has(ReaderFeature.strongs) || has(ReaderFeature.confStrongs) {
            toggles.append(
                ReaderDisplayToggle(
                    id: "strongs",
                    titleKey: "PreferencesStrongsPreferencesTitle",
                    preference: Defaults.strongsPreference
                )
            )
        }
        if has(ReaderFeature.morph) {
            toggles.append(
                ReaderDisplayToggle(
                    id: "morph",
                    titleKey: "PreferencesMorphTagsTitle",
                    preference: Defaults.morphPreference
                )
            )
        }
        if has(ReaderFeature.headings) {
            toggles.append(
                ReaderDisplayToggle(
                    id: "headings",
                    titleKey: "PreferencesHeadingsTitle",
                    preference: Defaults.headingsPreference
                )
            )
        }
        if has(ReaderFeature.footnotes) {
            toggles.append(
                ReaderDisplayToggle(
                    id: "footnotes",
                    titleKey: "PreferencesFootnotesTitle",
                    preference: Defaults.footnotesPreference
                )
            )
        }
        if has(ReaderFeature.scriptRef) {
            toggles.append(
                ReaderDisplayToggle(
                    id: "xref",
                    titleKey: "PreferencesCrossReferencesTitle",
                    preference: Defaults.scriptRefsPreference
                )
            )
        }
        if has(ReaderFeature.redLetterWords) {
            toggles.append(
                ReaderDisplayToggle(
                    id: "redLetter",
                    titleKey: "PreferencesRedLetterTitle",
                    preference: Defaults.redLetterPreference
                )
            )
        }
        // Verse-per-line is a rendering-side option only — it never went through
        // -setPreferences — and is gated on the module being a Bible rather than
        // on a feature.
        if store.moduleMeta(moduleName, key: "type") == ReaderFeature.typeBibles {
            toggles.append(
                ReaderDisplayToggle(
                    id: "vpl",
                    titleKey: "PreferencesVPLTitle",
                    preference: Defaults.vplPreference
                )
            )
        }
        return toggles
    }
}

/// Observable state behind the reading chrome. The hosting view controller owns
/// one of these per tab and pushes into it exactly where it used to push into the
/// segmented control and bar-button items.
@MainActor
@Observable
final class ReaderChromeModel {
    /// The reference shown in the centre of the bar, already munged through
    /// `+createTitleRefString:` by the host — the same string the middle segment
    /// displayed.
    var title: String = ""
    /// The un-munged reference, used as the control's accessibility label (which
    /// is what `setVoiceOverForRefSegmentedControlSubviews` did for the title
    /// segment).
    var accessibilityReference: String = ""
    var isNextEnabled: Bool = true
    var isPreviousEnabled: Bool = true
    /// Focus mode (the old "fullscreen"): hides the navigation bar and the tab
    /// bar so only the chapter remains.
    var isFocused: Bool = false
    /// Empty when the active module advertises nothing, which hides the control.
    var displayToggles: [ReaderDisplayToggle] = []
    /// Mirrors each toggle's current per-module value, keyed by
    /// `ReaderDisplayToggle.id`. Held in the model rather than read live inside
    /// the view body so a write goes through Observation and refreshes the menu.
    var displayToggleValues: [String: Bool] = [:]
    /// Whether the voice-reference action is offered. Gated on both the feature
    /// flag and on-device speech availability, exactly as the UIKit mic button
    /// was.
    var isVoiceAvailable: Bool = false
    /// Drives the reference picker popover/sheet.
    var isPresentingReferencePicker: Bool = false
    /// The Bible tab shows voice reference; the commentary tab does not. Also
    /// used for the accessibility-identifier prefix, matching the UIKit menu's
    /// "bible."/"commentary." `UIAction.Identifier` prefixes.
    var isBibleTab: Bool = true

    @ObservationIgnored var onPreviousChapter: (@MainActor () -> Void)?
    @ObservationIgnored var onNextChapter: (@MainActor () -> Void)?
    @ObservationIgnored var onHistoryAndSearch: (@MainActor () -> Void)?
    @ObservationIgnored var onVoiceReference: (@MainActor () -> Void)?
    @ObservationIgnored var onToggleFocus: (@MainActor () -> Void)?
    /// Applies a display-toggle flip: write the per-module pref, then redisplay.
    @ObservationIgnored var onDisplayToggle: (@MainActor (ReaderDisplayToggle) -> Void)?

    var identifierPrefix: String {
        isBibleTab ? "bible" : "commentary"
    }

    /// Rebuilds the toggle rows and their current values for `moduleName`.
    func reloadDisplayToggles(
        forModule moduleName: String?,
        store: PSContentStore? = PSContentStore.shared,
        defaults: UserDefaults = .standard
    ) {
        displayToggles = ReaderDisplayToggle.toggles(
            forModule: moduleName,
            store: store
        )
        guard let moduleName else {
            displayToggleValues = [:]
            return
        }
        displayToggleValues = Dictionary(
            uniqueKeysWithValues: displayToggles.map {
                ($0.id, defaults.psBool($0.preference, forModule: moduleName))
            }
        )
    }
}

/// The Read workspace: the active pane, its iOS 27 chrome, the mode switch, and
/// the study surfaces the reader raises.
///
/// Wave 8 folded `PSModuleViewController` into this. The WebView, the toolbar and
/// the reference picker are unchanged from Wave 7; what is new is everything the
/// UIKit host used to do around them — the Bible/commentary switch (two tabs, now
/// one workspace), the study popup and verse menu (presented from here rather than
/// by the coordinator), the bookmark editor, the voice sheet, and the Focus-mode
/// chapter toast that replaces `MBProgressHUD`.
struct ReaderScreen: View {
    let reading: ReadingWorkspaceModel

    private var chrome: ReaderChromeModel { reading.activePane.chrome }

    var body: some View {
        @Bindable var reading = reading

        NavigationStack {
            readerPanes
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ReaderReferenceControl(
                            chrome: chrome,
                            makeReferencePicker: {
                                makeReferencePicker(reading: reading)
                            }
                        )
                    }
                    .visibilityPriority(.high)

                    ToolbarItem(placement: .topBarPinnedTrailing) {
                        Button {
                            chrome.onToggleFocus?()
                        } label: {
                            Image(
                                systemName: chrome.isFocused
                                    ? "arrow.down.right.and.arrow.up.left"
                                    : "arrow.up.left.and.arrow.down.right"
                            )
                        }
                        .accessibilityLabel(
                            Text(
                                chrome.isFocused
                                    ? "VoiceOverExitFocusModeButton"
                                    : "VoiceOverFocusModeButton"
                            )
                        )
                        .accessibilityIdentifier("reading.focus-mode")
                    }

                    // The Bible/commentary switch, at the bar's LEADING edge.
                    //
                    // It was `.bottomBar` first, and that was wrong on iOS 27:
                    // the floating tab bar occupies the bottom, so the picker
                    // landed on top of it (measured on device — picker at y=798,
                    // tab bar at y=795) and taps went to the tab bar instead.
                    // There is no bottom edge to put a bar on any more.
                    //
                    // Not `.principal` either: that slot holds the reference
                    // control, which Wave 7 gave `.high` visibility priority
                    // precisely so a constrained width sheds everything else
                    // before it sheds chapter navigation.
                    ToolbarItem(placement: .topBarLeading) {
                        ReadingModePicker(reading: reading)
                    }
                }
                .toolbarOverflowMenu {
                    Button {
                        chrome.onHistoryAndSearch?()
                    } label: {
                        Label(
                            "VoiceOverHistoryAndSearchButton",
                            systemImage: "magnifyingglass"
                        )
                    }
                    .accessibilityIdentifier("reading.history-search")

                    if chrome.isBibleTab && chrome.isVoiceAvailable {
                        Button {
                            chrome.onVoiceReference?()
                        } label: {
                            Label(
                                "VoiceOverVoiceRefButton",
                                systemImage: "microphone"
                            )
                        }
                        .accessibilityIdentifier("reading.voice-reference")
                    }

                    if !chrome.displayToggles.isEmpty {
                        Section("VoiceOverDisplaySettingsButton") {
                            ForEach(chrome.displayToggles) { toggle in
                                ReaderDisplayToggleButton(
                                    chrome: chrome,
                                    toggle: toggle
                                )
                            }
                        }
                    }
                }
                // Quiet the chrome while reading; it comes back on a scroll up.
                .toolbarMinimizationBehavior(
                    .onScrollDown,
                    for: .navigationBar
                )
                // Focus mode deliberately KEEPS the navigation bar. It hides the
                // tab bar (in `WorkspaceTabs`, via `toolbarVisibility`) and the
                // status bar, which is what actually buys the screen back.
                //
                // Do NOT add `toolbarVisibility(.hidden)` here. It was tried and
                // hides the whole bar INCLUDING the `.topBarPinnedTrailing` Focus
                // control, which is the only way back out — verified on device:
                // the hierarchy contained zero buttons and the reader was a trap.
                // Pinning that item is pointless if the bar it is pinned to is
                // hidden. The bar also still minimizes on scroll down, so ordinary
                // reading in Focus mode is uninterrupted either way.
                .navigationBarTitleDisplayMode(.inline)
                .statusBarHidden(reading.isFocused)
                // Focus mode hides the TAB bar (not this one), which is what
                // actually buys the screen back. Wave 7 did this with
                // `setTabBarHidden(_:animated:)` on the `UITabBarController`.
                //
                // It must be applied HERE, to content inside the tab — putting it
                // on the `TabView` itself does nothing at all, which cost a
                // round-trip to discover: the Focus control flipped to "exit"
                // while the tab bar stayed put.
                .toolbarVisibility(
                    reading.isFocused ? .hidden : .automatic,
                    for: .tabBar
                )
                .sheet(item: $reading.studyPopup) { popup in
                    StudyPopupSheet(
                        content: popup.content,
                        findAllOccurrences: reading.startStrongsSearch
                    )
                }
                .sheet(item: $reading.bookmarkDraft) { draft in
                    NavigationStack {
                        BookmarkEditorView(draft: draft)
                    }
                }
                .sheet(isPresented: $reading.isPresentingVoiceReference) {
                    VoiceReferenceSheet(reading: reading)
                }
                .confirmationDialog(
                    verseMenuTitle,
                    item: $reading.verseMenuTarget,
                    titleVisibility: .visible
                ) { target in
                    Button("VerseContextualMenuAddBookmark") {
                        reading.addBookmark(for: target)
                    }
                    Button("VerseContextualMenuCommentary") {
                        reading.showInCommentary(verse: target.verse)
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }

    /// BOTH panes stay in the hierarchy, with the inactive one hidden.
    ///
    /// This is not a stylistic choice. `displayChapter` renders the polled pane and
    /// defers a `refToShow` / `jsToShow` into the other, which that pane applies
    /// when it next appears — so the inactive pane has to exist to receive the
    /// deferral. Rendering only the active pane (a plain `if`) would tear down its
    /// `WebPage`, losing both the pending work and the scroll position, which is
    /// the Wave 6 blank-page failure mode in a new disguise.
    ///
    /// On the safe area: **Wave 9 resolved this**, and the resolution lives in
    /// `ChapterTextView` rather than here. The reader is now a native scroll view
    /// that ignores the vertical safe area while its *content* carries the insets
    /// (`contentMargins(… for: .scrollContent)`), so the chapter flows edge-to-edge
    /// and scrolls beneath the translucent bars with no line obscured at rest.
    ///
    /// Both halves of that tradeoff were wrong once each before: Wave 6 let the
    /// WebView extend under the floating tab bar with no content inset and lines
    /// painted permanently behind it; Wave 7 kept it inside the safe area, which
    /// fixed the overlap and left the chapter letterboxed. Do not add an
    /// `ignoresSafeArea` here — the scroll view owns it now, and adding a second one
    /// at this level would inset nothing and reintroduce the overlap.
    private var readerPanes: some View {
        ZStack {
            ChapterTextView(pane: reading.bible)
                .opacity(reading.mode == .bible ? 1 : 0)
                .accessibilityHidden(reading.mode != .bible)
            ChapterTextView(pane: reading.commentary)
                .opacity(reading.mode == .commentary ? 1 : 0)
                .accessibilityHidden(reading.mode != .commentary)
        }
        .overlay(alignment: .top) {
            ChapterToast(text: reading.chapterToast)
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { old, new in
            // Rotation, or an iPad split-view resize. There are no measured verse
            // offsets to rebuild any more — Wave 6 needed `resetArrays()` because
            // `versepos` was width-dependent, and identity is not — so all this pair
            // does is re-anchor each pane on the verse it was showing and SUPPRESS
            // the transient scroll callbacks the transition emits, which would
            // otherwise be mistaken for a user scroll and overwrite the persisted
            // position.
            //
            // The two calls are deliberately back to back:
            // `restoreAfterSizeChange` keeps the suppression alive until its own
            // deferred scroll has landed, so the window is not zero-length. Do not
            // try to "pair" them across separate callbacks.
            guard old != .zero, old != new else { return }
            reading.prepareForSizeChange()
            reading.restoreAfterSizeChange()
        }
    }

    /// The verse menu's title — "Verse 12".
    private var verseMenuTitle: String {
        guard let verse = reading.verseMenuTarget?.verse else { return "" }
        return String.localizedStringWithFormat(
            String(localized: "RefSelectorVerseTitle"),
            verse
        )
    }

    /// Builds the reference picker, preserving the contract the deleted
    /// `PSRefSelectorController` had and Wave 7's `makeReferencePicker` kept: a
    /// selection closes the picker and applies book/chapter/verse. The
    /// `NotificationUpdateSelectedReference` post in between is gone — the
    /// coordinator that observed it is gone, and this is a direct call now.
    private func makeReferencePicker(
        reading: ReadingWorkspaceModel
    ) -> ReferencePickerView {
        let model = ReferencePickerModel(
            books: (PSBookOSISResolver.shared?.books ?? [])
                .map(ReferencePickerBook.init),
            currentReference: PSModuleController.getCurrentBibleRef(),
            // The same rule `PSRefSelectorController.setupNavigation` used: the
            // iPhone presentation adapts to a sheet, which needs an explicit
            // Cancel; an iPad popover is dismissed by tapping outside it.
            showsCancel: UIDevice.current.userInterfaceIdiom == .phone
        )
        let chrome = reading.activePane.chrome
        model.onCancel = {
            chrome.isPresentingReferencePicker = false
        }
        model.onSelection = { selection in
            chrome.isPresentingReferencePicker = false
            reading.selectReference(
                bookName: selection.bookName,
                chapter: selection.chapter,
                verse: selection.verse
            )
        }
        return ReferencePickerView(model: model)
    }
}

/// The Bible/commentary switch.
///
/// Replaces two tab-bar items with one control, which is the point of merging them
/// into a single workspace: they are two views of the same reference, and the old
/// pair made switching a navigation act rather than a display choice.
///
/// A `Menu` rather than a segmented `Picker`, for the same reason the Library's
/// section switch is: it has to fit in a toolbar slot alongside chapter navigation
/// and the study actions, and a two-segment control there is both cramped and
/// unlabelled. The menu shows which mode is active by name.
private struct ReadingModePicker: View {
    let reading: ReadingWorkspaceModel

    var body: some View {
        @Bindable var reading = reading

        Menu {
            Picker("WorkspaceRead", selection: $reading.mode) {
                Label("TabBarTitleBible", systemImage: "book.closed")
                    .tag(ReadingMode.bible)
                Label("TabBarTitleCommentary", systemImage: "text.book.closed")
                    .tag(ReadingMode.commentary)
            }
            .pickerStyle(.inline)
        } label: {
            Image(
                systemName: reading.mode == .bible
                    ? "book.closed"
                    : "text.book.closed"
            )
        }
        .accessibilityLabel(
            Text(
                reading.mode == .bible
                    ? "TabBarTitleBible"
                    : "TabBarTitleCommentary"
            )
        )
        .accessibilityIdentifier("reading.mode")
    }
}

/// The Focus-mode chapter toast.
///
/// This is `+[PSTabBarControllerDelegate displayTitle:]`, which showed a
/// text-only `MBProgressHUD` on the key window for 0.75 s whenever a chapter
/// changed while in Focus mode (where there is no visible reference to read).
/// Retiring it removes the app target's last Objective-C dependency — the vendored
/// `MBProgressHUD` was the only `CompileC` unit in the build.
private struct ChapterToast: View {
    let text: String?

    var body: some View {
        ZStack {
            if let text {
                Text(text)
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: .capsule)
                    .transition(.opacity)
                    .accessibilityIdentifier("reading.chapter-toast")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: text)
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}


/// [‹ | Gen 23:23 | ›] — the replacement for the three-segment
/// `UISegmentedControl` that lived in `navigationItem.titleView`.
///
/// The old control was `isMomentary` with hardcoded 50/95/50pt segment widths and
/// arrow images (`back-white.png` / `forward-white.png`) whose accessibility
/// labels had to be re-applied on every title change, because
/// `-setTitle:forSegmentAt:` rebuilt the subviews. Three plain buttons need none
/// of that: each carries its own label permanently.
private struct ReaderReferenceControl: View {
    let chrome: ReaderChromeModel
    let makeReferencePicker: () -> ReferencePickerView

    var body: some View {
        @Bindable var chrome = chrome

        HStack(spacing: 4) {
            Button {
                chrome.onPreviousChapter?()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!chrome.isPreviousEnabled)
            .accessibilityLabel(Text("VoiceOverPreviousChapterButton"))
            .accessibilityIdentifier("reading.previous-chapter")

            Button {
                chrome.isPresentingReferencePicker = true
            } label: {
                Text(chrome.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    // Roughly the old 95pt title segment, but as a floor rather
                    // than a fixed width so a long reference and larger Dynamic
                    // Type sizes can grow instead of truncating.
                    .frame(minWidth: 95)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(chrome.accessibilityReference))
            .accessibilityIdentifier("reading.reference-picker")
            // Anchored on the button itself, so the popover's arrow points at the
            // reference it is changing. Attaching it to the NavigationStack
            // instead collapsed it to a 320x49 strip at the bottom of the screen.
            //
            // NO `presentationCompactAdaptation(.popover)`: letting iPhone adapt
            // to a sheet is both the system default and what the legacy chrome
            // did — `toggleNavigation` presented a full modal on iPhone and a
            // popover only on iPad (`PSResizing.iPad()`).
            .popover(isPresented: $chrome.isPresentingReferencePicker) {
                makeReferencePicker()
                    .frame(minWidth: 320, minHeight: 480)
            }

            Button {
                chrome.onNextChapter?()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!chrome.isNextEnabled)
            .accessibilityLabel(Text("VoiceOverNextChapterButton"))
            .accessibilityIdentifier("reading.next-chapter")
        }
    }
}

/// One display toggle. Rendered as a `Button` with a checkmark rather than a
/// SwiftUI `Toggle` so it matches the UIKit menu's `UIAction.state` presentation
/// and so the flip goes through the host's write-then-redisplay path rather than
/// a binding that would have to own the pref key.
private struct ReaderDisplayToggleButton: View {
    let chrome: ReaderChromeModel
    let toggle: ReaderDisplayToggle

    var body: some View {
        let isOn = chrome.displayToggleValues[toggle.id] ?? false
        Button {
            chrome.onDisplayToggle?(toggle)
        } label: {
            // A checkmark only when on, matching the UIKit menu's `UIAction.state`.
            // The icon is omitted entirely when off rather than being an empty
            // `Image(systemName: "")`, which is not a real symbol.
            if isOn {
                Label {
                    Text(LocalizedStringKey(toggle.titleKey))
                } icon: {
                    Image(systemName: "checkmark")
                }
            } else {
                Text(LocalizedStringKey(toggle.titleKey))
            }
        }
        .accessibilityIdentifier(
            "\(chrome.identifierPrefix).\(toggle.id)"
        )
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
