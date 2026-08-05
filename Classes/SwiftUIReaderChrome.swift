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

/// The reading surface plus its iOS 27 chrome.
struct ReaderScreen: View {
    let chrome: ReaderChromeModel
    let reader: ReaderWebPageModel
    /// Built on demand so the picker's book list is only constructed when the
    /// picker opens, and so the host keeps ownership of the notification contract
    /// it posts into.
    let makeReferencePicker: () -> ReferencePickerView

    var body: some View {
        NavigationStack {
            // No `ignoresSafeArea` here — but read the tradeoff before "fixing"
            // this in either direction, because both directions have been wrong.
            //
            // A bare `ignoresSafeArea(edges: .bottom)` reproduces the Wave 6
            // defect: the chapter paints PAST the floating tab bar, with lines
            // permanently hidden behind it. Confirmed on device in Wave 7 and
            // reverted.
            //
            // Staying inside the safe area, as here, is the safe half of the
            // tradeoff and NOT the target design. It letterboxes: the scroll view
            // ends at the chrome, so the reader shows black bands top and bottom
            // instead of content flowing edge-to-edge beneath translucent bars.
            //
            // The real answer is BOTH — a full-height scroll view whose *content*
            // carries safe-area insets, so nothing is ever obscured at rest but
            // the text still scrolls under the chrome. That is deliberately NOT
            // attempted here: for a WebView the insets have to come from the HTML
            // (`viewport-fit=cover` + `env(safe-area-inset-*)` in
            // `createHTMLString`, replacing `chapterPage`'s six hardcoded
            // `<p>&nbsp;</p>` pads), and every verse offset that
            // `versePositionArray` / `scrollToVerse` / `scrollHappened` measure
            // sits downstream of that, with the chapter-body fixtures and
            // `chapter-loop-counters.tsv` pinning the surrounding output.
            //
            // Wave 9 DELETES this WebView for a `LazyVStack`, where the same
            // result is a `contentMargins` / `safeAreaPadding` call and native
            // scrolling handles it. It is logged as a Wave 9 acceptance criterion
            // in SWIFTUI_MIGRATION_PLAN.md. Do not pay for it twice here.
            SwiftUIReaderWebView(model: reader)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ReaderReferenceControl(
                            chrome: chrome,
                            makeReferencePicker: makeReferencePicker
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
                }
                .toolbarOverflowMenu {
                    Button {
                        chrome.onHistoryAndSearch?()
                    } label: {
                        Label(
                            "VoiceOverHistoryAndSearchButton",
                            systemImage: "clock.arrow.circlepath"
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
                // tab bar (in the host, via setTabBarHidden) and the status bar,
                // which is what actually buys the screen back.
                //
                // Do NOT add `toolbarVisibility(.hidden)` here. It was tried and
                // hides the whole bar INCLUDING the `.topBarPinnedTrailing` Focus
                // control, which is the only way back out — verified on device:
                // the hierarchy contained zero buttons and the reader was a trap.
                // Pinning that item is pointless if the bar it is pinned to is
                // hidden. The bar also still minimizes on scroll down, so ordinary
                // reading in Focus mode is uninterrupted either way.
                .navigationBarTitleDisplayMode(.inline)
                .statusBarHidden(chrome.isFocused)
        }
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
