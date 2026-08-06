//
//  PocketSwordApp.swift
//  PocketSword
//
//  Wave 8: the SwiftUI application. This file is the app's entry point and its
//  navigation, replacing `PocketSwordAppDelegate` + `PocketSwordSceneDelegate` +
//  `PSLaunchViewController` + `PSTabBarControllerDelegate`'s tab construction.
//
//  ── Four workspaces, not six tabs ─────────────────────────────────────────
//
//  The UIKit app had six tabs — Bible, Commentary, Dictionary, Bookmarks,
//  Preferences, About — of which the last two only appeared under a system
//  "More" list, and History and Search were not tabs at all but a modally
//  presented `UITabBarController`. That shape came from the tab bar being the
//  only navigation the app had.
//
//  This is **Read / Search / Library / Settings**:
//
//  - **Read** merges the Bible and Commentary tabs into one workspace with a mode
//    switch, because they are two views of the same reference — the old pair kept
//    separate scroll positions and separate chapter buttons for what the user
//    experiences as one act of reading. Both panes stay alive (see
//    `ReadingWorkspace.swift`); only which one is on screen changes.
//  - **Search** is a real workspace with `TabRole.search`, so the system gives it
//    its iOS 26+ search-tab treatment. It was a modal sheet.
//  - **Library** collects Dictionary, Bookmarks and History — three lists of
//    things you look up rather than read.
//  - **Settings** collects Preferences and About, which were two "More" rows.
//
//  ── Launch ─────────────────────────────────────────────────────────────────
//
//  `PSLaunchViewController`'s job was to be the root view controller while
//  `LaunchCoordinator.prepare()` ran on a background thread, then hand over via
//  the `@objc PSLaunchDelegate` handshake so the scene delegate could swap the
//  window's root. That whole dance is a `switch` on `LaunchPhase` here: the same
//  coordinator runs in a `Task`, and the view goes from `LaunchView` to the tab
//  bar when it finishes. `PSLaunchDelegate` and the handshake are deleted.
//
//  The **order** is still load-bearing: nothing may touch `PSModuleController`,
//  the content store or the reader until `prepare()` has returned, because the
//  one-shot migrations it runs (`DefaultsLastRefValidated` in particular) can
//  rewrite `lastRef` out from under a render. `ReadingWorkspaceModel.start()` is
//  therefore called from the `.ready` transition, not from `init`.
//
//  ── Orientation ────────────────────────────────────────────────────────────
//
//  The rotation-lock preference used to be enforced by overriding
//  `-supportedInterfaceOrientations` on `UITabBarController` and
//  `UINavigationController` through Obj-C categories (preserved as Swift
//  `extension … open override`, which is legal but is still swizzling-by-subclass
//  applied to classes the app does not own). SwiftUI owns those controllers now,
//  so that hook is gone; iOS 27's
//  `UIWindowSceneDelegate.supportedInterfaceOrientations(for:)` is the supported
//  replacement and is what `PocketSwordSceneOrientationDelegate` implements.
//

import BackgroundTasks
import SwiftUI
import UIKit

/// Where launch has got to. `LaunchCoordinator.prepare()` returning nil means the
/// content store could not be opened at all, which is fatal in the reader (see
/// `PSContentReader`'s header) — so it is surfaced rather than silently retried.
enum LaunchPhase: Equatable {
    case preparing
    case ready
    case failed
}

@main
struct PocketSwordApp: App {
    /// The app delegate survives for exactly two things UIKit still owns: the
    /// `BGTaskScheduler` registration (which must happen before
    /// `didFinishLaunching` returns) and the scene-orientation hook. It holds no
    /// app state — that is all in `AppSession`.
    @UIApplicationDelegateAdaptor(PocketSwordAppDelegate.self)
    private var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(
                session: appDelegate.session,
                reading: appDelegate.readingWorkspace,
                launchCoordinator: appDelegate.launchCoordinator
            )
            .onOpenURL { url in
                appDelegate.session.open(url)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                // The old `sceneWillResignActive` did exactly this. Everything
                // that writes a pref already synchronizes; this is the belt to
                // that braces, for a background kill.
                UserDefaults.standard.synchronize()
            case .active:
                // `sceneWillEnterForeground`'s reset check. `reset_PocketSword`
                // is set from the Settings bundle, so it can arrive while the app
                // is suspended.
                if UserDefaults.standard.bool(forKey: "reset_PocketSword") {
                    appDelegate.launchCoordinator.resetPreferences()
                }
            @unknown default:
                break
            }
        }
    }
}

/// Launch gate. Shows the spinner while `LaunchCoordinator` runs, then the app.
private struct RootView: View {
    let session: AppSession
    let reading: ReadingWorkspaceModel
    let launchCoordinator: LaunchCoordinator

    @State private var phase: LaunchPhase = .preparing

    var body: some View {
        ZStack {
            switch phase {
            case .preparing:
                LaunchView()
            case .ready:
                WorkspaceTabs(session: session, reading: reading)
            case .failed:
                LaunchFailureView()
            }
        }
        .task {
            guard phase == .preparing else { return }
            phase = await prepare()
            if phase == .ready {
                // Only now: the migrations can rewrite `lastRef`, and the reader
                // renders from it.
                reading.start()
                session.replayPendingURL()
            }
        }
    }

    /// Runs the launch coordinator off the main actor, as
    /// `-performSelectorInBackground:` did. It touches the file system and the
    /// defaults plist and takes long enough to be worth not blocking on.
    private func prepare() async -> LaunchPhase {
        let coordinator = launchCoordinator
        let result = await Task.detached(priority: .userInitiated) {
            coordinator.prepare()
        }.value

        guard let result else {
            alog("Launch preparation failed; the content store is unavailable.")
            return .failed
        }
        if result.shouldDisableIdleTimer {
            // A UIKit side effect that must be on the main thread — a Wave 1
            // Main Thread Checker termination came from doing this on the
            // bootstrap thread.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        return .ready
    }
}

/// Shown when the baked content store cannot be opened. There is no fallback
/// render path (SWORD_REMOVAL_PLAN.md Phase 5 step 1), so this is a dead end by
/// design — better than a blank reader.
private struct LaunchFailureView: View {
    var body: some View {
        ContentUnavailableView {
            Label("LaunchFailedTitle", systemImage: "exclamationmark.triangle")
        } description: {
            Text("LaunchFailedMessage")
        }
        .accessibilityIdentifier("launch.failed")
    }
}

// MARK: - The four workspaces

struct WorkspaceTabs: View {
    let session: AppSession
    let reading: ReadingWorkspaceModel

    var body: some View {
        @Bindable var session = session

        // NOTE: no `accessibilityIdentifier` on the `Tab`s. It does not reach the
        // tab-bar button — verified in the iOS 27 hierarchy, where the four
        // buttons expose only their localized labels ("Read", "Library",
        // "Settings", "Search"). The XCUITests therefore match tabs by label.
        //
        // NOTE ALSO the resulting ORDER: Read, Library, Settings, Search. `Search`
        // is declared second but `TabRole.search` moves it to the trailing
        // position, which is the system's convention for a search tab and is why
        // the role exists.
        TabView(selection: $session.selectedWorkspace) {
            Tab(
                "WorkspaceRead",
                systemImage: "book",
                value: Workspace.read
            ) {
                ReadWorkspace(session: session, reading: reading)
            }

            Tab(
                "WorkspaceSearch",
                systemImage: "magnifyingglass",
                value: Workspace.search,
                // The system's search-tab treatment: on iPhone it takes the
                // trailing position and can host the search field itself.
                role: .search
            ) {
                SearchWorkspace(session: session, reading: reading)
            }

            Tab(
                "WorkspaceLibrary",
                systemImage: "books.vertical",
                value: Workspace.library
            ) {
                LibraryWorkspace(session: session, reading: reading)
            }

            Tab(
                "WorkspaceSettings",
                systemImage: "gearshape",
                value: Workspace.settings
            ) {
                SettingsWorkspace(session: session)
            }
        }
        // Quiet the tab bar while reading, matching the navigation bar's
        // `toolbarMinimizationBehavior(.onScrollDown)`. Wave 7 set this on the
        // `UITabBarController`; it is the same behaviour, now on `TabView`.
        .tabBarMinimizeBehavior(.onScrollDown)
        // NOTE: Focus mode's tab-bar hiding is NOT here. `toolbarVisibility(_:for:
        // .tabBar)` has to be applied to the content *inside* a tab, not to the
        // `TabView` — applied here it silently does nothing, verified on device
        // (the Focus control flipped to "exit" with the tab bar still visible).
        // It lives on `ReaderScreen`'s `NavigationStack` instead.
    }
}

// MARK: - Read

private struct ReadWorkspace: View {
    let session: AppSession
    let reading: ReadingWorkspaceModel

    var body: some View {
        ReaderScreen(reading: reading)
    }
}

// MARK: - Search

private struct SearchWorkspace: View {
    let session: AppSession
    let reading: ReadingWorkspaceModel

    var body: some View {
        SearchView(
            search: session.search,
            moduleChoices: reading.searchModuleChoices,
            preferredModule: reading.preferredSearchModule,
            currentBookName: reading.currentSearchBookName,
            restoredHistoryItem: reading.searchHistoryItemToRestore(),
            openResult: { reference, module in
                reading.savedSearchHistoryItem = session.search.historyItem()
                reading.savedSearchResultsMode = session.search.moduleKind
                reading.openLibraryReference(reference, module: module)
                session.selectedWorkspace = .read
            }
        )
    }
}

// MARK: - Library

/// Dictionary, Bookmarks and History, as one workspace.
///
/// These were three separate destinations: two tabs (Dictionary, Bookmarks) and
/// one half of the modal multi-list (History). They are grouped because all three
/// are lists you consult rather than read, and because a four-workspace tab bar
/// has no room to spend three slots on them.
///
/// The section switch sits at `.principal`, replacing the per-section title — the
/// same shape Mail uses for its mailbox switcher, and the reason each section view
/// keeps its own `NavigationStack`: Bookmarks needs a `path`-driven stack for
/// folder descent and Dictionary needs one for entry push, so the picker has to be
/// declared inside each of them rather than around all three.
///
/// It was a `tabViewBottomAccessory` first, which did not work and could not:
/// that modifier declares ONE accessory for the whole `TabView` (the shape the
/// Music mini-player uses), so a per-section control has no business there.
/// Verified on device — it rendered nothing at all.
private struct LibraryWorkspace: View {
    let session: AppSession
    let reading: ReadingWorkspaceModel

    @State private var section: LibrarySection = .bookmarks

    var body: some View {
        switch section {
        case .bookmarks:
            BookmarksView(
                library: session.library,
                section: $section,
                openBookmark: { reference in
                    reading.openLibraryReference(reference, module: nil)
                    session.selectedWorkspace = .read
                }
            )
        case .history:
            HistoryView(
                library: session.library,
                section: $section,
                openHistoryEntry: { entry in
                    reading.openLibraryReference(
                        entry.reference ?? "",
                        module: entry.moduleName
                    )
                    session.selectedWorkspace = .read
                }
            )
        case .dictionary:
            DictionaryView(
                library: session.library,
                section: $section
            )
        }
    }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case bookmarks
    case history
    case dictionary

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .bookmarks: "BookmarksTitle"
        case .history: "HistoryTitle"
        case .dictionary: "TabBarTitleDictionary"
        }
    }

    var systemImage: String {
        switch self {
        case .bookmarks: "bookmark"
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        }
    }

    var identifier: String {
        "workspace.library.\(rawValue)"
    }
}

/// The Library's section switch, for the `.principal` toolbar slot.
///
/// A `Menu` rather than a segmented `Picker`: three segments of icon-only labels
/// read as a mystery-meat toolbar, and the current section is worth naming. This
/// shows the active section's title and swaps between them, which is also what
/// makes the section discoverable by its name in the accessibility hierarchy.
struct LibrarySectionPicker: View {
    @Binding var section: LibrarySection

    var body: some View {
        Menu {
            Picker("WorkspaceLibrary", selection: $section) {
                ForEach(LibrarySection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Text(section.title)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
        .accessibilityIdentifier("library.section")
    }
}

// MARK: - Settings

/// Preferences and About. Both were rows under the tab bar's system "More" list,
/// reachable only by tapping through it.
private struct SettingsWorkspace: View {
    let session: AppSession

    var body: some View {
        NavigationStack {
            SettingsView(
                settings: session.settings,
                // The iPad's larger reading pane takes a larger maximum, as it
                // always has.
                maximumFontSize: UIDevice.current.userInterfaceIdiom == .phone
                    ? 20
                    : 36
            )
            .navigationTitle("PreferencesTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        AboutView(information: .current())
                            .navigationTitle("AboutTitle")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(Text("AboutTitle"))
                    .accessibilityIdentifier("workspace.settings.about")
                }
            }
        }
    }
}
