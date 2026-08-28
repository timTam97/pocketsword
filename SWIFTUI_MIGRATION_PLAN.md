# PocketSword iOS 27 SwiftUI Redesign

## Execution Status

**Last updated:** 2026-08-28

**Overall state:** **Complete.** All nine waves plus the final
all-configuration/verification/static-audit pass are done. **WebKit is gone from
the app target** — `import WebKit` appears nowhere, both JavaScript resources and
all three HTML shells are deleted, and the reader is a native SwiftUI `ScrollView`
+ `LazyVStack` over `AttributedString`. As of the final pass WebKit is no longer
even *linked*: the framework was still in the Frameworks phase, required rather
than weak, so the app loaded it at launch for zero symbols.

**Wave 9's acceptance criterion is met: the reader is edge-to-edge.** Measured on
the iPhone 17 Pro — the scroll view is the full `402x874` window with `136pt`/`113pt`
content margins, verse 1 starting at the navigation bar's own bottom edge (y≈116) and
content scrolling beneath the floating tab bar at y=791. No black bands, no line
obscured at rest, in either orientation. The letterboxing carried since Wave 7 is
resolved, and so is the Wave 6 overlap — for the first time both halves are right at
once.

Nothing remains. The final pass's results are in the "Final pass" section at the
end of this document.

Wave 8 cut the app over to a SwiftUI lifecycle and four workspaces. `@main` is
now `PocketSwordApp`, and the UIKit coordination layer is deleted: no
`UITabBarController`, no `UINavigationController`, no scene delegate driving
launch, no `PSTabBarControllerDelegate`, no `PSModuleViewController`. **28 files
and ~9,500 lines were removed**, against ~3,100 added.

**The app target now contains no Objective-C implementation at all.** The
vendored `MBProgressHUD` is gone — its only consumer was the Focus-mode chapter
toast — so `misc/PocketSword_Prefix.pch` and `GCC_PREFIX_HEADER` went with it and
a clean build reports **`CompileC` 0**, where it reported 1 throughout the
SWORD-removal era. `Classes/globals.h` survives as a header of enums and
constants (`PSSearchType` / `PSSearchRange` / the `ATTRTYPE_*` literals), still
dual-maintained with `AppConstants.swift`, and is the only thing either bridging
header imports.

**The `startStrongsSearch` workaround is retired**, which Waves 6 and 7 both
expected and neither achieved. Wave 7 diagnosed it correctly: the iOS 27
floating-tab-bar AnimationKit assertion needed a UIKit sheet dismissing while a
UIKit sheet was presented, from a tab bar the coordinator owned. Wave 8 removed
all three — "Find all occurrences" changes the tab selection instead of
presenting a second sheet. `suppressMultiListPresentAnimation` and
`toggleMultiListFromMenu` are deleted.

> **Historical, and superseded by the paragraph at the top of this section.** Wave
> 8 recorded here that "the reader is still letterboxed, not edge-to-edge, and this
> remains Wave 9's acceptance criterion". That was true when written and Wave 9
> fixed it; the sentence survived the Wave 9 documentation pass and sat 34 lines
> below its own contradiction until the final pass caught it. Kept as a dated note
> rather than deleted, because the two-directions-wrong history (Wave 6 overlap,
> Wave 7 letterboxing) is the reason the criterion existed at all.

### Wave 8: what the four workspaces replaced

| Before | After |
|---|---|
| Bible tab + Commentary tab | **Read**, one workspace, mode picker in the bottom bar |
| Search — half of a modal `UITabBarController` | **Search**, a workspace with `TabRole.search` |
| History — the other half of that modal | **Library** → History |
| Dictionary tab, Bookmarks tab | **Library** → Dictionary / Bookmarks |
| Preferences + About, rows under the system "More" list | **Settings**, with About pushed from its toolbar |

The multi-list modal is gone outright rather than reproduced: with Search and
Library each one tap away, a sheet that showed the same two screens would be a
second route to them.

The letterboxing detail, unchanged since Wave 7: content stops at the toolbar and
at the floating tab bar instead of scrolling beneath them, leaving a black band at
each end. This is the safe half of a tradeoff whose other half (Wave 6's overlap)
hid text outright. Fixing it properly belongs to Wave 9's native reader, where it
is a one-call `contentMargins`; doing it in the WebView would mean moving the
insets into the HTML and disturbing fixture-pinned verse-offset math for a view
Wave 9 deletes.

Wave 6 replaced the reader with a SwiftUI `WebPage`/`WebView` surface and is
verified on the iOS 27 iPhone 17 Pro simulator: nonblank Bible and commentary
content, next/previous chapter navigation, scrolling, the expected portrait and
landscape reader frames with no text painting outside them, rotation position
restoration in both directions, Strong's lookup, Strong's "Find all occurrences"
search, the verse menu, bookmark-highlight refresh, and relaunch restoration. The
full shared scheme is green (116 passed, 0 failed, the 2 `PSREF_EXHAUSTIVE` tests
skipped, all 5 XCUITests passed) and a separate generic iOS device build
succeeds with `CompileC` still 1, so the target remains pure Swift.

Runtime verification also surfaced a **pre-existing** iOS 27 floating-tab-bar
crash on the rotate-then-Strong's-search path. It was confirmed pre-existing by
reproducing the identical stack on `108e8a3` with the whole Wave 6 worktree
stashed, and is now worked around in `startStrongsSearch`.

### Verified environment

- Xcode 27.0 beta 4 (`27A5228h`) is installed at
  `/Applications/Xcode-beta.app`.
- The iOS 27.0 SDK and iOS 27.0 beta 4 simulator runtime are installed.
- The command-line default still points to Xcode 26.6, so every migration
  command must set:
  `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- The pre-migration app target builds successfully for a generic iOS device
  with the iOS 27 SDK:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    xcodebuild -project PocketSword.xcodeproj \
    -scheme PocketSword \
    -configuration Debug \
    -sdk iphoneos \
    -derivedDataPath /tmp/pocketsword-swiftui-baseline \
    CODE_SIGNING_ALLOWED=NO \
    build
  ```

- Xcode MCP can access the installed iOS 27 simulators and is the primary
  verification path for this migration.
- Simulator discovery from shell commands was blocked earlier in this migration by
  `CoreSimulatorService connection became invalid`. As of Wave 7 it works:
  `xcrun simctl list devices available` reports the booted iPhone 17 Pro, and
  `xcodebuild ... -destination 'platform=iOS Simulator,id=<UUID>' test` runs the
  suite. Target the simulator **by `id`**, not by `name` — the name form is what
  produced the "Unable to find a destination" failures CLAUDE.md records.
- The Wave 1 Xcode scheme is green on the iPhone 17 Pro iOS 27 simulator:
  76 standard unit tests passed, the 2 `PSREF_EXHAUSTIVE` opt-in tests skipped,
  and 3 deterministic XCUITests passed.

### Wave checklist

- [x] Repository and persistence-contract audit
- [x] Confirm Xcode 27, iOS 27 SDK, and baseline device build
- [x] Wave 1: Baseline settings, XCUITest target, and deterministic baselines
- [x] Wave 2: Typed domain values, observable models, coordinators, and stores
- [x] Wave 3: Supporting SwiftUI screens
- [x] Wave 4: Library workspace
- [x] Wave 5: Search workspace and background indexing
- [x] Wave 6: SwiftUI WebKit reader
- [x] Wave 7: iOS 27 toolbar and reading chrome
- [x] Wave 8: SwiftUI app lifecycle and four-workspace cutover
- [x] Wave 9: Native SwiftUI reader and WebKit removal
- [x] Final all-configuration builds, tests, UI verification, and static audit

### Current repository facts

- **The app target is pure Swift with no Objective-C implementation.** As of
  Wave 8 the only non-Swift file is `Classes/globals.h`, a header of enums and
  constants; `externals/` and the prefix header are gone, and `CompileC` is 0.
- **UIKit is no longer the lifecycle or the navigation.** `PocketSwordAppDelegate`
  survives as a `@UIApplicationDelegateAdaptor` holding two things UIKit still
  owns — the `BGTaskScheduler` registration, which must complete before
  `didFinishLaunching` returns, and iOS 27's
  `supportedInterfaceOrientations(for:)` on a minimal scene delegate, which is
  how the rotation-lock preference is now enforced. Everything else is SwiftUI.
- UIKit types still appear where SwiftUI has no equivalent and the type is a
  *value or a leaf*: `UIDevice.current.userInterfaceIdiom` for the iPad checks and
  `UIFont`/`UIColor`/`UIImage`/`UIApplication` inside the search highlighter, the
  study palette and the About screen. None of them is a view controller. One
  zero-size `UIViewRepresentable` reports the hosting scene's interface orientation
  to Settings; Wave 9 deleted both WebView wrappers (the study popup and the
  dictionary entry) along with WebKit. Four files
  (`PSBookmarkObject`, `PSModuleController`, `PSChapterDocument`, `PSRefParser`)
  still carry an `import UIKit` that nothing in them uses; harmless, and left alone
  rather than churned.
- Baked content, reference parsing, FTS5 search, bookmark serialization, history
  serialization/iCloud merge, and voice-reference parsing already exist in
  Swift and must remain the behavior-preserving foundation.
- The Xcode project uses explicit file and target membership.
- `PocketSword` is the shared scheme containing `PocketSwordTests`.
- Project, app, unit-test, and UI-test deployment settings are aligned at 27.0.
- `PocketSwordUITests` is part of the shared `PocketSword` scheme. Wave 8 rewrote
  it for the four workspaces: it covers all four tabs, both reading modes, the
  Library section switch, Settings/About, the reference picker, Focus mode, the
  display toggles, and bookmark folder CRUD/reordering, all through stable
  accessibility identifiers.
- `AppSession` now owns observable reading, settings, library, and search models.
  Typed stores preserve the legacy defaults keys for reading position, modules,
  font, display, rotation, fullscreen, idle-timer, history, and search
  preferences.
- `LegacyStateBridge` is **deleted** (Wave 8). It existed to mirror UIKit
  notification state into `AppSession` during the mixed migration. Its two jobs
  now sit where the data lives: `AppSession.start()` seeds reading state and wires
  the settings side effects, and `LibraryModel.startObservingChanges()` refreshes
  bookmarks/history off `bookmarksChanged` / `historyChanged`.
- Bookmark nodes carry runtime UUIDs that are deliberately excluded from the
  positional plist schema. History and search result snapshots use natural
  persisted reference/module/date identities.
- `LaunchCoordinator` owns preference reset and all one-shot launch migrations. As
  of Wave 8 it is driven straight from `RootView`'s `.task` through a
  `LaunchPhase` switch; `PSLaunchViewController` and the `@objc PSLaunchDelegate`
  handshake are deleted. The **order remains load-bearing**: nothing may touch
  `PSModuleController`, the content store or the reader until `prepare()` returns,
  because `DefaultsLastRefValidated` can rewrite `lastRef` out from under a
  render — so `ReadingWorkspaceModel.start()` is called from the `.ready`
  transition, never from `init`.
- `HistoryStore` owns the iCloud observer, notification interpretation, legacy
  recursive merge/dedup/cap behavior, and local/cloud write-back.
- Wave 3 has replaced launch, book/chapter/verse reference selection, voice
  reference, Preferences, font picker, and About content with SwiftUI views
  hosted by thin UIKit adapters until the app-lifecycle cutover.
- Wave 4 has replaced Dictionary, Bookmarks, and History with SwiftUI views.
  Dictionary selection/search and linked entries use the baked content store;
  bookmark CRUD, colors, recursive navigation, and iOS 27 drag reordering use
  the typed bookmark store; History uses the existing iCloud-backed store and
  natural row identities.
- Wave 5 has replaced the live search controller with a SwiftUI workspace.
  `SearchModel` now owns module selection, persisted filters, 250 ms debouncing,
  generation-based stale-result rejection, Strong's mode, history restoration,
  result snapshots, and highlighted full-verse results. (`PSModuleSearchController`
  was still compiled at the end of Wave 5; Wave 8 deleted it.)
- Wave 6 replaced the reading surface with a SwiftUI WebKit surface in
  `SwiftUIReaderViews.swift` — `ReaderWebPageModel` owning `WebPage`, typed
  `NavigationDeciding`, ordered JavaScript calls, navigation events and WebView
  scroll callbacks — and deleted the old `PSWebView.swift` wrapper. **Wave 9 then
  deleted all of it**: the reading surface today is `SwiftUINativeReader.swift`, a
  `ScrollView` + `LazyVStack` over `AttributedString`, and neither
  `SwiftUIReaderViews.swift` nor `ReaderWebPageModel` exists.
- Wave 7 replaced the reading chrome with `SwiftUIReaderChrome.swift`.
  `ReaderScreen` wraps the reader in a `NavigationStack` and owns chapter
  navigation, the reference picker, Focus mode, and the study-action overflow
  menu; `ReaderChromeModel` is the observable state the host pushes into. The
  per-module display toggles are built by the pure
  `ReaderDisplayToggle.toggles(forModule:store:)`, still gated on the baked
  feature set and still writing `"<pref>_<ModuleName>"`.
  At the end of Wave 7 `PSModuleViewController` was a thin host keeping the
  coordinator contracts, and Focus mode called `setTabBarHidden(_:animated:)`;
  **Wave 8 deleted that controller** and Focus mode is now
  `toolbarVisibility(_:for: .tabBar)` applied to content *inside* a tab.
  `PSRefSelectorController.swift` is deleted.
- Search index builds persist an interrupted module and submit a
  `BGProcessingTaskRequest`. The launch-registered background manager restarts
  the same transactional `PSSearchEngine` build, cancels cleanly on expiration,
  retries expired work, and clears the pending marker after success, after the
  bounded retry budget (`maxBuildAttempts`) is spent, or when the user's own
  foreground build finishes. A *failed* background build keeps its marker and asks
  for another slot — it used to clear the marker AND report no retry, which killed
  both recovery mechanisms at once and left the user with no index; an expiration
  is handled first and deliberately spends no budget, because
  `PSSearchEngine.build` throws `.cancelled` on expiry and would otherwise be
  billed as a failure.
- The SwiftUI reference picker preserves the existing notification payload,
  direct chapter/verse-one jumps, current-reference highlighting, and the
  64-entry first-match short-book index contract.
- Voice-reference speech and parsing remain in `PSVoiceRefSession` and
  `PSVoiceRefParser`; `VoiceReferenceModel` now maps session states into the
  SwiftUI sheet. Permission recovery uses `openSettings`.
- MessageUI is no longer used by the live About path; feedback uses `mailto:`.

### Execution rules

- Update this document whenever a wave changes state, a migration decision is
  made, or verification produces a new result.
- Preserve all persisted wire formats and defaults keys byte-for-byte.
- Keep Swift 5 language mode and minimal concurrency checking for this
  migration.
- Do not mark a wave complete until its project wiring and available
  verification have passed.
- Record build, test, runtime, accessibility, and visual verification
  separately; one does not imply another.

### Execution log

- **2026-08-04:** Read the migration plan and audited the current project,
  lifecycle, UIKit ownership, content reader, search engine, bookmark store,
  history store, reference parsers, voice session, localization, test scheme,
  and Xcode membership.
- **2026-08-04:** Confirmed Xcode 27 beta after the stable command-line selection
  initially reported Xcode 26.6.
- **2026-08-04:** Completed a successful pre-migration Debug device build with
  Xcode 27 beta and the iOS 27 SDK. No simulator runtime behavior or tests were
  observed in this step.
- **2026-08-04:** Reached the installed iOS 27 simulator outside the sandbox.
  The first unit-test attempt correctly exposed the known baseline mismatch:
  `PocketSwordTests` targeted iOS 26 while the app module required iOS 27.
- **2026-08-04:** Began Wave 1 by aligning project/test deployment targets at
  iOS 27 and adding `PocketSwordUITests` to the shared scheme.
- **2026-08-04:** The first combined unit/UI run exposed a launch-time Main
  Thread Checker termination: `PSLaunchViewController` set
  `UIApplication.isIdleTimerDisabled` from its background bootstrap thread.
  Moved that UIKit side effect onto the existing main-thread completion handoff.
- **2026-08-04:** Completed Wave 1. The Xcode MCP run on iPhone 17 Pro discovered
  all 78 unit tests; 76 passed and the 2 explicitly opt-in exhaustive tests
  skipped. Added and passed 3 XCUITests covering reading/library destinations,
  Settings/About, and History/Search. The Debug generic-device build also
  succeeds with Xcode 27.
- **2026-08-04:** Started Wave 2 with typed `Workspace`, `ReadingMode`,
  `BibleReference`, and `URLRoute` values plus `@MainActor @Observable`
  `AppSession` and `ReadingModel`. Extracted pure `sword://` parsing and routing
  into `URLRouter`; the UIKit app delegate still owns the existing defaults,
  module, notification, and history side effects while mirroring accepted routes
  into `AppSession`.
- **2026-08-04:** Added six routing/session tests for installed and foreign
  modules, canonical persisted references, chapter-only links, out-of-range
  verse positions, rejection, and observable state. The full Xcode MCP run on
  iPhone 17 Pro is green: 82 unit tests passed, the 2 exhaustive opt-in tests
  skipped, and all 3 XCUITests passed (87 total).
- **2026-08-04:** Continued Wave 2 with typed `SettingsStore` and
  `ReadingStateStore`, observable `SettingsModel`, and the temporary
  `LegacyStateBridge`. The existing UIKit preferences controller now reads and
  writes through `SettingsModel`; accepted URL routes persist through the typed
  reading store without changing wire keys or value types. Added five focused
  store/model/bridge tests. The full Xcode MCP run on iPhone 17 Pro is green:
  87 unit tests passed, the 2 exhaustive opt-in tests skipped, and all 3
  XCUITests passed (92 total results). A focused rerun of the five new tests also
  passed after clearing the bridge's actor-isolation warnings.
- **2026-08-04:** Expanded Wave 2 with `BookmarkStore`, `HistoryStore`,
  `LibraryModel`, runtime-only bookmark UUIDs, typed bookmark colors and tree
  snapshots, and natural history-row IDs. The legacy history controller now
  delegates clear/delete persistence to `HistoryStore`, and bookmark/history
  notifications refresh `LibraryModel`.
- **2026-08-04:** Added `SearchOptionsStore`, `SearchModel`, natural search-result
  IDs, and an observable cancellable `SearchIndexCoordinator`. The legacy search
  controller mirrors options/query/results into the model, and the existing
  index-build sheet now uses the shared coordinator without changing its modal
  UI or background-task behavior.
- **2026-08-04:** Added seven more focused store/model/coordinator tests (12 new
  Wave 2 tests in total). The latest full Xcode MCP run on iPhone 17 Pro is
  green: 94 unit tests passed, the 2 exhaustive opt-in tests skipped, and all 3
  XCUITests passed (99 total results). A separate Xcode MCP generic iOS device
  build also succeeded.
- **2026-08-04:** Completed Wave 2 by extracting `LaunchCoordinator` from
  `PSLaunchViewController` and moving iCloud notification handling plus the
  byte-locked recursive merge/dedup/cap implementation from
  `PSHistoryController` into `HistoryStore`. Added three focused launch/cloud
  tests. The focused seven-test launch/history slice passed, followed by a green
  full Xcode MCP run on iPhone 17 Pro: 97 unit tests passed, the 2 exhaustive
  opt-in tests skipped, and all 3 XCUITests passed (102 total results).
- **2026-08-04:** Started Wave 3 with SwiftUI Preferences, live reading-font
  preview, font picker, and native About content. The existing UIKit tab
  coordinator hosts these views during the mixed migration, preserving the More
  navigation and accessibility identifiers. About feedback now uses `mailto:`
  instead of the live MessageUI path. Added settings-binding and mail-link unit
  coverage plus stable XCUITest identifiers for the font action, size slider,
  device toggles, and About header.
- **2026-08-04:** Verified the Wave 3 supporting-screen slice through Xcode MCP
  and live device interaction on iPhone 17 Pro. Font selection dismisses and
  updates the preview, only the selected font exposes selected/checkmark
  semantics, the About app icon and version render in the first viewport, and
  the full About list clears the tab bar without clipping. The final shared
  scheme run is green: 99 standard unit tests passed, the 2 exhaustive opt-in
  tests skipped, and all 3 XCUITests passed (104 total results).
- **2026-08-04:** Completed the remaining Wave 3 screens. `LaunchView` now owns
  the initialization surface; `ReferencePickerView` owns book, chapter, and
  verse navigation behind the existing notification contract; and
  `VoiceReferenceView` plus `VoiceReferenceModel` replace the UIKit voice sheet
  while retaining the existing speech session and parser.
- **2026-08-04:** Added stable reference-picker accessibility identifiers, a
  deterministic XCUITest that selects Genesis 1:1, and focused tests for
  reference validation/index identity and voice-session state mapping. The
  SwiftUI short-book scrub index preserves the legacy 64-title first-match
  behavior, including the `Jud` and `Phi` collisions.
- **2026-08-04:** Xcode MCP build-for-testing succeeds and the final shared
  scheme run is green on iPhone 17 Pro: 101 standard unit tests passed, the 2
  `PSREF_EXHAUSTIVE` opt-in tests skipped, and all 4 XCUITests passed (107 total
  results). Live portrait inspection confirmed the SwiftUI book list renders
  without clipping or overlap and marks the current book selected. The complete
  book/chapter/verse flow passed through XCUITest. The interaction session was
  interrupted before manual chapter/verse and landscape inspection, and live
  voice UI remains unavailable on the simulator because it has no audio input;
  voice rendering transitions are verified at the observable-model boundary.
- **2026-08-05:** Completed Wave 4 with SwiftUI Dictionary, Bookmarks, and
  History surfaces hosted by the existing UIKit coordinator. Added typed
  dictionary restore/filter/entry generation plus recursive bookmark add,
  rename, color, delete, access-date, and reorder mutations without changing
  the positional plist schema.
- **2026-08-05:** Live iPhone 17 Pro verification found and fixed two migration
  defects. Bookmark folder creation initially updated persistence without
  invalidating the view because the screen read directly from `BookmarkStore`;
  it now traverses `LibraryModel.bookmarks` so Observation refreshes the list.
  A redundant row context menu also intercepted the long press required by
  iOS 27 `.reorderable()` and was removed in favor of the existing swipe
  actions.
- **2026-08-05:** Live verification confirmed dictionary module selection,
  incremental search, nonblank entry HTML, and lexicon-to-lexicon navigation;
  bookmark creation, highlight colors, rename, confirmed deletion, and empty
  state; and History empty state, toolbar controls, Search switching, and close
  behavior without portrait clipping or overlap. A deterministic XCUITest
  additionally creates two folders, reorders them through the iOS 27 drag API,
  and cleans them up.
- **2026-08-05:** Wave 4 verification is green. The shared scheme on iPhone 17
  Pro passed 105 standard unit tests, skipped the 2 opt-in exhaustive tests,
  and passed all 5 XCUITests (112 total results). A separate Xcode MCP generic
  iOS device build also succeeded.
- **2026-08-05:** Completed Wave 5 with a dedicated SwiftUI search workspace
  hosted by the existing History/Search sheet. KJV and MHCC module selection,
  all/OT/NT/current-book scopes, all/any/exact matching, fuzzy and Strong's
  toggles, 250 ms debouncing, stale-result rejection, highlighted full verses,
  saved search restoration, and result-to-reader navigation now live in
  `SearchModel` and `SearchView`.
- **2026-08-05:** Added launch-registered `BGProcessingTaskRequest` recovery for
  interrupted transactional index builds. The pending module survives process
  interruption, task expiration cancels and resubmits, and focused tests cover
  both scheduling persistence and execution of the pending build through the
  same closure used by the system task handler. System-timed task delivery was
  not manually forced; registration, submission, expiration wiring, and
  recovery execution are verified at their deterministic seams.
- **2026-08-05:** Live iPhone 17 Pro verification found and fixed two SwiftUI
  search defects. Changing to a module without an index initially recreated the
  search host and cleared the query; the content now keeps a stable root, so
  KJV -> MHCC -> KJV preserves `love` and reruns 281 results. Search activation
  also hid toolbar-only module/options actions; both icon menus now remain in
  the persistent scope bar without overlap while the field is focused.
- **2026-08-05:** Live verification confirmed KJV and MHCC selection, the MHCC
  missing-index/build state, nonblank `love` results with visible yellow match
  highlighting, all match options, Fuzzy and Strong's controls, query-preserving
  module switching, and result navigation. With Fuzzy persisted on, selecting
  `Genesis 22:2` closed the sheet and moved the reader to `Gen 22:2`.
- **2026-08-05:** Wave 5 verification is green. The final shared-scheme run on
  iPhone 17 Pro passed 109 standard unit tests, skipped the 2
  `PSREF_EXHAUSTIVE` opt-in tests, and passed all 5 XCUITests (116 total
  results). A separate Xcode MCP generic iOS device build also succeeded.
- **2026-08-05:** Started Wave 6. Added `SwiftUIReaderViews.swift` using
  `WebPage`, SwiftUI `WebView`, `NavigationDeciding`,
  `webViewOnScrollGeometryChange`, and queued `callJavaScript` operations.
  `PSModuleViewController` now hosts this surface, while its existing chapter,
  bookmark, verse-menu, Strong's, morph, note, fullscreen, and coordinator
  contracts remain in place. Removed the obsolete `PSWebView.swift` wrapper.
- **2026-08-05:** Added typed parsing coverage for `pocketsword:currentverse`,
  `pocketsword:versemenu`, and `arraydump` bridge URLs, plus an XCUITest
  assertion that `reading.web-content` exists in both Bible and commentary.
  Xcode MCP build-for-testing succeeded, and the focused bridge-parser plus
  reading/library XCUITest slice passed 2/2. This accessibility-only XCUITest did
  not prove that chapter text was nonblank.
- **2026-08-05:** The first live iPhone 17 Pro run found a real Wave 6
  regression: the Bible WebView remained on its blank placeholder even though
  next/previous chapter titles changed. Commentary rendered nonblank content,
  but text extended beneath the floating tab bar, especially in landscape.
  Runtime logs also recorded `startDetLocPoll`/`stopDetLocPoll` reference errors.
- **2026-08-05:** Traced the blank Bible to cancellation of the placeholder
  navigation's per-load event task racing the immediately superseding Bible
  load. The current worktree no longer cancels that task, marks new loads
  synchronously, gates the appearance-time poll call on a finished page,
  restores the legacy two-point scroll callback threshold, and attempts to frame
  the hosted reader inside the controller safe area. Xcode MCP
  build-for-testing succeeds after these fixes. A subsequent launch still showed
  commentary text beneath the floating tab bar, and the user interrupted before
  the Bible load fix or rotation behavior could be rechecked.
- **2026-08-05:** Resumed live verification on iPhone 17 Pro. The Bible load
  race fix is effective: Genesis text rendered nonblank, next/previous chapter
  changed both reference and text, scrolling advanced the visible verse, and
  commentary rendered nonblank content. The active scheme was the shared
  `PocketSword` scheme on the iOS 27 iPhone 17 Pro simulator, and the launch log
  no longer contained the prior `startDetLocPoll`/`stopDetLocPoll` reference
  errors.
- **2026-08-05:** Hierarchy evidence isolated the remaining layout and rotation
  defects. In portrait, `reading.web-content` was
  `{{0,116},{402,675}}` and ended at the tab bar's `y=791`, but WebView text
  still painted beyond the host bounds. In landscape, the reader was
  `{{62,78},{750,260}}` while the tab bar began at `y=319`, producing a
  measured 19-point overlap. Rotating after scrolling from `Gen 2:4` restored
  `Gen 2:2` instead.
- **2026-08-05:** Applied but did not yet build the next fixes. The SwiftUI
  WebView and hosting view now clip to bounds; the host frame is capped at the
  converted tab-bar top with a deterministic geometry test for the observed
  portrait and landscape frames. Rotation now suppresses transient
  scroll-persistence callbacks, restores the captured `currentShownVerse` after
  `resetArrays()`, and records the resulting JavaScript `pageYOffset`. The
  fullscreen host now uses the tab-bar controller's live bounds. These edits
  are only code-complete at this checkpoint, not build- or runtime-verified.
- **2026-08-05:** Built the clipping/tab-bar-frame/rotation patch (Xcode MCP
  `BuildProject(buildForTesting: true)`, no diagnostics; `CompileC` remains 1)
  and ran the focused slice: `testReaderBridgeEventsPreserveNavigationPayloads`
  and `testReaderFrameStopsAtOverlappingTabBar` both pass. The scheme now
  exposes 118 enabled tests.
- **2026-08-05:** Live iPhone 17 Pro verification cleared every Wave 6 layout and
  rotation defect. Portrait `reading.web-content` is `{{0,116},{402,675}}` ending
  exactly at the tab bar's `y=791`; landscape is `{{62,78},{750,241}}` ending
  exactly at the tab bar's `y=319`, so the previously measured 19-point overlap is
  gone and text no longer paints outside the reader in either orientation. Bible
  and commentary both render nonblank, next/previous chapter changes reference and
  text, and scrolling advanced the title from `Gen 5:1` to `Gen 5:9`. Rotating to
  landscape and back preserved `Gen 5:9` **and** its scroll offset in both
  directions, so the earlier `Gen 2:4` -> `Gen 2:2` regression is fixed. The
  launch log contains no JavaScript reference errors.
- **2026-08-05:** Exercised the study surfaces through the SwiftUI reader. A
  Strong's link opened the H2421 Hebrew lexicon entry with its full definition;
  "Find all occurrences" returned 235 results with visible yellow match
  highlighting; the verse menu opened as "Verse 12" and carried the correct verse
  into Add Bookmark as `Genesis 5:12`; saving a bookmark into a yellow-highlight
  folder repainted verse 12 yellow live through `bookmarksChanged`; and a relaunch
  restored `Gen 5:9` with its scroll position. Test bookmarks and the test folder
  were deleted afterward.
- **2026-08-05:** Runtime verification found a crash that is **not** a migration
  regression. Rotating the device while the Strong's popup is open and then
  tapping "Find all occurrences" traps in
  `-[_UITabBarVisualProvider_FloatingAccessibility layoutSubviews]` with an
  AnimationKit assertion (`Missing animationAndComposerGetter`,
  `EXC_BREAKPOINT`), with no app frames on the stack. Confirmed pre-existing by
  stashing the whole Wave 6 worktree and reproducing the identical stack on
  `108e8a3`. A pageSheet takes the presenter's view off the window, so the tab bar
  controller cannot lay out while the popup is up; the deferred rotation's first
  layout is then forced to run inside the next sheet transition's
  alongside-animation block, where the iOS 27 floating tab bar's animatable
  properties assert. Worked around in `startStrongsSearch` by presenting the
  multi-list unanimated, which keeps that layout out of any animation block. Two
  other approaches were tried and did **not** work (deferring the present via
  `DispatchQueue.main.async`, and dismissing unanimated plus an explicit
  `layoutIfNeeded`); both are recorded in the code comment so they are not
  retried. Verified: the rotate-then-search sequence that reproduced twice now
  returns its 235 results, and the ordinary no-rotation path still works. Wave 7
  replaces this chrome with the native SwiftUI toolbar and should retire the
  workaround with it.

- **2026-08-05:** Wave 6 verification is green and the wave is complete. The full
  shared-scheme run on iPhone 17 Pro passed 116 standard tests, skipped the 2
  `PSREF_EXHAUSTIVE` opt-in tests, and passed all 5 XCUITests (118 total). A
  separate generic iOS device build with Xcode 27 beta also succeeds, and a clean
  device build still reports `CompileC` 1 (`MBProgressHUD.m` only), so deleting
  `PSWebView.swift` and adding `SwiftUIReaderViews.swift` did not disturb the
  pure-Swift invariant. `git diff --check` and
  `plutil -lint PocketSword.xcodeproj/project.pbxproj` pass.
- **2026-08-05:** Started Wave 7 by checking the iOS 27 SDK's own
  `SwiftUI.swiftinterface` rather than trusting this plan's symbol names, which
  found two corrections: the modifier is `toolbarMinimizationBehavior(_:for:)`
  (this plan said `toolbarMinimizeBehavior`, which is the tab-bar API), and item
  priority is `visibilityPriority(_:)` with `ToolbarItemVisibilityPriority`.
  `toolbarOverflowMenu`, `ToolbarOverflowMenu` and `.topBarPinnedTrailing` are all
  present as described.
- **2026-08-05:** Added `SwiftUIReaderChrome.swift` and reduced
  `PSModuleViewController` to a chrome host. The per-module display menu became
  the pure `ReaderDisplayToggle.toggles(forModule:store:)`, so the KJV-six-rows /
  MHCC-zero contract is assertable without the simulator for the first time —
  previously it could only be checked by counting rows in a live `UIMenu`.
  Deleted `PSRefSelectorController.swift`, which nothing instantiated once the
  picker moved into the reader. A device build succeeds with `CompileC` still 1.
- **2026-08-05:** Live iPhone 17 Pro verification found and fixed three Wave 7
  defects. An `ignoresSafeArea(edges: .bottom)` reintroduced the Wave 6
  paint-under-the-tab-bar defect; removing it fixed the overlap but leaves the
  reader letterboxed rather than edge-to-edge, which is now logged as a Wave 9
  acceptance criterion rather than papered over. The reference picker presented as an invisible
  320x49 strip because it was anchored on the `NavigationStack` with a forced
  compact popover adaptation; it now hangs off the reference button and adapts to
  a sheet on iPhone, which is also what the legacy chrome did. Focus mode was a
  trap: `toolbarVisibility(.hidden)` hid the pinned Focus control along with the
  bar, leaving zero buttons and no way out.
- **2026-08-05:** Live verification confirmed the finished chrome. `Gen 1:1` opens
  with Previous correctly disabled; next chapter moves both reference and text;
  the reference picker completes Genesis to Chapter 5 to Verse 5, dismisses, and
  lands scrolled to verse 5; the overflow menu shows History and Search plus
  exactly six KJV display rows with **no** cross-references row; toggling Strong's
  off re-renders without the `<0xxxx>` markers and holds position; Focus mode
  hides the tab bar and status bar, reclaims the space, flips the control to "Exit
  Focus Mode", and restores cleanly; landscape lays out correctly with no overlap;
  rotation preserves the reference; a Strong's link opens H8141 with its Hebrew
  lemma; and the commentary tab's overflow menu correctly has **no** display rows.
  The launch log contains no JavaScript reference errors.
- **2026-08-05:** Tested whether Wave 7 retires the `startStrongsSearch`
  workaround, as this plan expected. It does **not**. With the line removed, the
  rotate-then-"Find all occurrences" path still crashed
  (`applicationState: Crashed`, plus a fresh `.ips` whose signature matches the
  documented one: `AnimationKit`, `EXC_BREAKPOINT`,
  `_UITabBarVisualProvider_FloatingAccessibility`, `layoutSubviews`). Restoring the
  line made the same sequence return its 647 results. The assertion lives in the
  UIKit tab bar presenting a UIKit sheet, neither of which Wave 7 replaced, so the
  workaround is carried to Wave 8 and the negative result is recorded in the code.
- **2026-08-05:** The full Xcode MCP run then caught a defect the manual pass had
  missed: opening History & Search from the new overflow menu crashed with the same
  floating-tab-bar signature, because a menu is itself a presentation and tapping a
  row dismisses it as the multi-list goes up. Manual verification had only ever
  reached History & Search from the old bar-button item, so moving it into the menu
  changed its presentation context uncovered. Fixed with a `toggleMultiListFromMenu`
  that applies the same unanimated present; re-verified on device that the row now
  opens the History sheet with its entries.
- **2026-08-05:** Started Wave 8 by checking the iOS 27 SDK's own
  `SwiftUI.swiftinterface` for every symbol the cutover needs, which found one
  correction and one absence: `Tab(_:systemImage:value:role:)` and
  `TabRole.search` are present as described, `tabBarMinimizeBehavior` is a plain
  `View` modifier (not `for:`-qualified like the navigation-bar one), and
  **`BackgroundTask.appRefresh` is unavailable on iOS** — so the `.backgroundTask`
  scene modifier was dropped and `SearchIndexBackgroundManager` keeps sole
  ownership of the `BGTaskScheduler` registration, which is where it has to be
  anyway (before `didFinishLaunching` returns).
- **2026-08-05:** Completed the Wave 8 cutover. `@main PocketSwordApp` with a
  four-workspace `TabView`; `ReadingWorkspaceModel` + `ReaderPaneModel` replacing
  the coordinator and the reader view controllers; the study popup, verse menu,
  bookmark editor and voice sheet as SwiftUI presentations; 28 files deleted
  including the vendored `MBProgressHUD` and the prefix header. `AppSession` took
  over `sword://` routing from the app delegate, with the pending-URL hold the
  scene delegate used to own.
- **2026-08-05:** The first build attempt failed on the bridging header rather
  than on Swift, which was the useful ordering: `MBProgressHUD.h` could not be
  found because the library was deleted, and fixing that surfaced the three
  remaining references to deleted code (`PSResizing.iPad()` in
  `PSModuleController`, `PSHistoryController.addHistoryItem` in `AppSession`, and
  the `LegacyStateBridge` tests). Build green after those.
- **2026-08-05:** Retargeted the two `LegacyStateBridge` tests onto what replaced
  the bridge (`AppSession.start()` and `LibraryModel.startObservingChanges()`),
  keeping their original claims, and added a third pinning
  `HistoryStore.addEntry`'s persisted row shape — a writer that had no direct
  coverage before, because it was only reachable through a view controller. That
  new test immediately failed for a real reason: `addEntry` was reading the
  chapter reference through `PSModuleController.getCurrentBibleRef()`
  (`UserDefaults.standard`) while writing to an injected `defaults`, so a test
  seeding its own suite got the device's current chapter. Fixed by reading
  `lastRef` from the store's own `defaults` and injecting the module-name lookup.
- **2026-08-05:** 31 of 32 `AppStateStoresTests` passed on the first simulator
  run; the one failure was the new history test above, and it passed after the
  seam fix along with the three other retargeted tests. The initial attempt had
  reported all 32 "not run" — the active run destination was a physical device,
  locked and with an unsigned test bundle. Switched to the iPhone 17 Pro iOS 27
  simulator.
- **2026-08-05:** Swept the UIKit asset and dead-code residue Wave 7 deferred:
  `PSSearchIndexBuilder` (a modal progress sheet with no live instantiation since
  Wave 5 replaced it with `SearchView`'s inline states) and 16 tab-icon PNGs, all
  now SF Symbols. **Editing `project.pbxproj` while a test run was in flight
  crashed Xcode** and took the MCP connection with it — the run had to be
  restarted. Do all project-file surgery before starting a test run, not during.
- **2026-08-05:** The first full Wave 8 suite run was 118 unit tests passed, 2
  `PSREF_EXHAUSTIVE` skipped, and **5 XCUITest failures** — every one in the
  rewritten UI tests, and every one about failing to *find* a control rather than
  about behaviour. Live inspection on the iPhone 17 Pro then found why, and all
  three causes were real defects in the new navigation rather than test bugs: the
  `tabViewBottomAccessory` Library picker rendered nothing (that modifier declares
  one accessory for the whole `TabView`, not one per section), the `.bottomBar`
  reading-mode picker sat on top of the floating tab bar (y=798 against y=795, so
  taps went to the tab bar), and `Tab`'s `accessibilityIdentifier` never reaches
  the tab-bar button. Fixed by moving both pickers into `.principal` /
  `.topBarLeading` as `Menu`s and matching tabs by label.
- **2026-08-05:** Re-verified live after the fixes: launch to Genesis 1:1 with
  Strong's numbers; all four workspaces reachable in the order Read, Library,
  Settings, Search (`TabRole.search` moves Search to the trailing slot); the
  Library section menu switching Bookmarks → History with correct empty states and
  no Close button; and the reading-mode menu switching Bible → Commentary with
  MHCC's Genesis 1 rendering, which exercises the `refToShow` deferral across a
  pane switch. That run took the XCUITests from 5 failures to 2.
- **2026-08-05:** The two remaining XCUITest failures were **both real defects**,
  and both were "the state is right, the effect is absent" — exactly what a build
  cannot catch. `toolbarVisibility(_:for: .tabBar)` applied to the `TabView` does
  nothing, so Focus mode flipped its control to "Exit Focus Mode" with the tab bar
  still on screen; it has to be applied to content *inside* a tab. And
  `ReadingWorkspaceModel.start()` posted `.newPrimaryBible` before registering its
  observers, so the KJV overflow menu had no Display Settings section at all. The
  old coordinator survived that ordering because its `init` force-loaded both
  reader views and `setDelegate` rebuilt the menu directly; with no view to
  force-load, the order carries the whole burden. Fixed both, and re-verified on
  device: six KJV toggle rows in the documented order with no Cross-references row,
  and Focus mode hiding the tab bar, reclaiming the space, and restoring cleanly.
- **2026-08-05:** A physical-device report — "Strong's search is not working" —
  turned out to be a real Wave 8 regression that the green suite had missed
  entirely, and it only reproduces on the SECOND lookup: the first works, and every
  one after it shows the previous term's results. `startStrongsSearch` handed a
  `PSSearchHistoryItem` to `SearchView`, whose `configure(...)` runs once per
  launch behind a `@State` guard; the UIKit multi-list had been rebuilt on every
  present, so that hand-off used to fire every time. Replaced with
  `SearchModel.startStrongsQuery`, which the reader calls directly, and pinned by
  `testRepeatedStrongsQueriesEachRunTheirOwnTerm`. Verified H430 → 1,000 results
  then H1254 → 46 results with "created" highlighted. Also worth recording: the
  device could NOT be driven from here — `DeviceInteractionStartWorkspaceSession`
  lists only simulators even with the phone connected and selected as the run
  destination — so the reproduction was on the iOS 27 simulator.
- **2026-08-05:** A second device report on the same path: the query now filled in
  as `H430` but "Strong's Numbers" was unchecked, so it searched for the literal
  text and found nothing. `startStrongsQuery` had opened with
  `strongsSearch = strongsAvailable`, and that flag is only resolved by
  `applyModule` during `configure(...)` — which has not run when the user goes
  straight from the reader to a Strong's link on a fresh launch, so it read `false`
  and switched the mode off. `optionsDidChange` carried the identical mistake and
  would have re-cleared it anyway. Both now gate on `module != nil` before
  consulting the flag. Two tests added: one that deliberately never calls
  `configure`, and one that keeps MHCC (no Strong's) correctly switched off so the
  guard cannot degrade into "always on". Verified live on a fresh launch — 1,000
  results and the toggle checked.
  **Process note:** the second bug was hiding *behind* the first — the same tap
  path, but only reachable once the query stopped being stale. Fixing one symptom
  on a path this long does not mean the path works; re-drive it end to end.
- **2026-08-05:** Wave 8 verification is green and the wave is complete. The full
  Xcode MCP run on the iPhone 17 Pro iOS 27 simulator passed **123 tests, failed
  0**, and skipped the 2 `PSREF_EXHAUSTIVE` opt-in tests (125 total) — 118 unit
  tests plus 7 XCUITests over the four workspaces. All three configurations build
  for a generic iOS device (Debug, Release, Distribution), and a clean device build
  reports **`CompileC` 0** with `SwiftCompile` 51, so the target is not merely pure
  Swift but has no C-family translation unit at all. `Classes/` contains zero
  `UIViewController` subclasses. `git diff --check` and `plutil -lint` on the
  pbxproj, `Info.plist` and `Localizable.strings` all pass.
- **2026-08-05:** Wave 7 verification is green and the wave is complete. The full
  Xcode MCP run on iPhone 17 Pro passed **120 tests, failed 0**, and skipped the 2
  `PSREF_EXHAUSTIVE` opt-in tests (122 total). `testBookmarkFolderCrudAndReordering`
  — a Wave 4 test, untouched here — failed once under full-suite load and passed in
  isolation, so its long-press-then-drag wait went from 5 s to 15 s; the assertion
  is unchanged. A separate generic iOS device build with Xcode 27 beta also
  succeeds, and a clean device build still reports `CompileC` 1
  (`MBProgressHUD.m` only), so the target remains pure Swift. `git diff --check`
  and `plutil -lint PocketSword.xcodeproj/project.pbxproj` pass.
- **2026-08-06:** Ran the final pass — all three configurations clean, the full
  suite, the env-gated exhaustive tier, iPad and Dynamic Type verification, and a
  seven-lens static audit with every finding adversarially verified. It found six
  real defects that nine waves plus a green suite had passed over, all silent: the
  app's signing entitlements were being copied into the bundle as a resource; the
  search highlighter had **never once run** in any era (its only historical caller
  was a commented-out debug line, so tapping a search result has never highlighted
  the term); `WebKit.framework` was still linked, required rather than weak, for
  zero symbols; four localization keys were used but undefined and rendered as raw
  keys; `dlog()` was a no-op in every configuration because `-DDEBUG` was set via
  `OTHER_CFLAGS` and cannot reach Swift; and an XCUITest was silently creating its
  bookmark folders under truncated names and stranding them where its own
  exact-name cleanup could not see them. Fixed all six, plus the 32 unreferenced
  toggle icons and the About screen's attribution for a library deleted in Wave 8.
  Corrected 21 documentation-versus-reality defects, including this document
  contradicting itself about whether the reader was still letterboxed. Full details
  in the "Final pass" section.

### Wave 6 status

**Worktree state:** Complete but intentionally uncommitted.

Changed files:

- `Classes/SwiftUIReaderViews.swift` (new): `WebPage` model, navigation decider,
  bridge URL parser, scroll callbacks, and SwiftUI `WebView`.
- `Classes/PSModuleViewController.swift`: SwiftUI hosting adapter plus retained
  reader behavior and popup routing.
- `Classes/PSTabBarControllerDelegate.swift`: reader visibility, chapter load,
  JavaScript, and highlighting calls now use the hosting adapter, plus the
  unanimated multi-list present that works around the pre-existing iOS 27
  floating-tab-bar crash.
- `Classes/AppStateStoresTests.swift`: bridge URL parsing and reader-frame
  geometry tests.
- `Tests/PocketSwordUITests.swift`: `reading.web-content` reachability checks.
- `Classes/PSWebView.swift` (deleted) and
  `PocketSword.xcodeproj/project.pbxproj` (membership updated).

Not verified for Wave 6, and carried into Wave 7/8, whose chrome and cutover work
replaces these surfaces: a footnote link (the Strong's path was exercised
instead), fullscreen/Focus mode through the SwiftUI reader, iPad, Dynamic Type,
VoiceOver, and RTL.

Carry into Wave 7:

- The `startStrongsSearch` unanimated-present workaround should be retired when
  the native SwiftUI toolbar and sheet presentation replace this UIKit chrome.
  Re-test the rotate-then-Strong's-search path after that change; if the
  floating-tab-bar assertion is gone, drop the workaround and its
  `suppressMultiListPresentAnimation` flag.
  **Resolved in Wave 7: tested, still required. Carried to Wave 8.**

### Wave 7 status

**Worktree state:** Complete.

Changed files:

- `Classes/SwiftUIReaderChrome.swift` (new): `ReaderDisplayToggle` (the pure
  per-module toggle builder), `ReaderChromeModel`, `ReaderScreen`,
  `ReaderReferenceControl`.
- `Classes/PSModuleViewController.swift`: reduced to a chrome host. Deleted the
  segmented control, the three bar-button items, `rebuildSettingsMenu`'s `UIMenu`
  construction, `setSettingsMenu`, `segmentedControlAction`,
  `setVoiceOverForRefSegmentedControlSubviews`, `readerFrame`/`layoutReaderHost`,
  and `previousTabBarView`. Focus mode rewritten. Hosts the reference picker.
- `Classes/PSTabBarControllerDelegate.swift`: `toggleNavigation` reduced to a
  reader seam; `refSelectorController`/`refNavigationController` and the
  iPhone-sheet-vs-iPad-popover branch removed; added `visibleReader` and
  `toggleMultiListFromMenu`; set `tabBarMinimizeBehavior = .onScrollDown`.
- `Classes/PSRefSelectorController.swift` (deleted): nothing instantiated it once
  the picker moved into the reader, and the `refSelectorResetBooks` notification
  it observed has no poster anywhere in the tree.
- `Classes/AppStateStoresTests.swift`: dropped `testReaderFrameStopsAtOverlappingTabBar`
  (it pinned the deleted clamp); added three chrome/toggle tests.
- `Tests/PocketSwordUITests.swift`: reading identifiers updated; added Focus-mode
  and display-toggle tests.
- `en.lproj/Localizable.strings`: `VoiceOverFocusModeButton` /
  `VoiceOverExitFocusModeButton`.

Four defects were found and fixed. The first three came from live interaction; the
fourth was caught by the XCUITests, on a path manual verification had missed:

1. **Text painted under the floating tab bar.** An `ignoresSafeArea(edges:
   .bottom)` on the reader reintroduced the exact Wave 6 defect. Removed, which
   fixed the overlap.
   **Partially resolved, and knowingly so:** removing it is the safe half of a
   tradeoff, not the target design. The reader now *stops* at the chrome rather
   than flowing under it, so the chapter is letterboxed — black bands top and
   bottom. Both directions have now been wrong once each (Wave 6 overlap, Wave 7
   letterboxing); the answer is a full-height scroll view with inset *content*,
   which is a Wave 9 acceptance criterion because in a WebView it means moving the
   insets into the HTML and disturbing the fixture-pinned verse-offset math for a
   view Wave 9 deletes. See the Wave 9 section, and the long comment at the top of
   `ReaderScreen.body`.
2. **The reference picker presented as an invisible 320x49 strip.** It was a
   `.popover` on the `NavigationStack` with `presentationCompactAdaptation(.popover)`.
   Moved onto the reference `Button` (so the arrow points at what it changes) and
   the forced compact adaptation dropped — letting iPhone adapt to a sheet is both
   the system default and what the legacy chrome did (`toggleNavigation` presented
   a modal on iPhone, a popover only on iPad).
3. **Focus mode was a trap.** `toolbarVisibility(.hidden)` hid the navigation bar
   *including* the `.topBarPinnedTrailing` Focus control, so the hierarchy
   contained zero buttons and there was no way back out. Focus mode now keeps the
   bar and hides only the tab bar and status bar.
4. **Opening History & Search from the overflow menu crashed the app**, with the
   same floating-tab-bar AnimationKit signature as the Strong's path. A menu is
   itself a presentation, so tapping a row tears it down while the multi-list goes
   up in the same beat — the identical one-sheet-out/one-sheet-in shape. Fixed with
   the same remedy, via a new `toggleMultiListFromMenu` that sets
   `suppressMultiListPresentAnimation` before presenting. `toggleVoiceRef` is on
   the same menu but already guards on `presentedViewController == nil`, so it
   fails safe rather than crashing.

Defect 4 is worth noting as a process point: manual interaction had exercised
History & Search only from the *old* bar-button item, so moving it into the
overflow menu changed its presentation context and nothing in the manual pass
re-covered it. The XCUITest caught it.

Focus mode also no longer reparents views. It used to move the reader host into
`tabBarController.view`, stash the old root view, and reassign
`tabBarController.view` on exit while hand-animating `tabBar.alpha`. It now calls
`setTabBarHidden(_:animated:)` (iOS 18+) and lets `ReaderScreen` follow the same
`isFocused` flag.

**The `startStrongsSearch` workaround is still required.** Wave 7 was expected to
retire it. Re-tested with the SwiftUI toolbar in place and the line removed:
rotating with the Strong's popup open and then tapping "Find all occurrences"
still crashed, with the same signature in a fresh crash report (`AnimationKit`,
`EXC_BREAKPOINT`, `_UITabBarVisualProvider_FloatingAccessibility`,
`layoutSubviews`). The assertion is in the UIKit tab bar the coordinator still
owns, presenting a UIKit sheet — neither is what Wave 7 replaced. Restored, and
the code comment now records the negative result so it is not retried blindly.
Re-test after the Wave 8 cutover.

Not verified for Wave 7, carried into Wave 8: a footnote link, iPad (including
the picker's popover arm, which is now the system's adaptation rather than an
explicit branch), Dynamic Type, VoiceOver, and RTL.

Carry into Wave 8:

- Re-test **both** unanimated-present paths once the tab bar and the
  History/Search presentation are SwiftUI — the rotate-then-Strong's-search one and
  the overflow-menu one — and drop `suppressMultiListPresentAnimation` plus
  `toggleMultiListFromMenu` if the assertion is gone. Any *new* control that
  presents the multi-list from inside another presentation needs the same
  treatment until then.
- Three image resources are now unreferenced by code — `back-white.png`,
  `forward-white.png` (the old segmented-control arrows) and `history.png` (the
  old bar-button icon), all replaced by SF Symbols. They are still bundled; remove
  them with the rest of the UIKit asset sweep rather than piecemeal.
- `PSChapterSelectorController` is compiled but nothing instantiates it, and it is
  the only thing that instantiates `PSVerseSelectorController` — so that pair is
  dead as a unit (they predate the SwiftUI picker). `PSModuleSearchController` has
  likewise had no live instantiation since Wave 5. Both selector controllers still
  post `NotificationToggleNavigation`, which is now the only remaining poster of
  that notification; once they go, `toggleNavigation`'s observer registration can
  go with them. Sweep all of this when the UIKit coordinator is removed.
  **All three carries are resolved in Wave 8.**

### Wave 8 status

**Worktree state:** Complete and verified. The full shared scheme is green on the
iPhone 17 Pro iOS 27 simulator — **123 passed, 0 failed**, the 2
`PSREF_EXHAUSTIVE` opt-in tests skipped (125 total). Navigation and the reading
surface are runtime-verified; several study surfaces remain unexercised — see "Not
yet verified".

**Static audit:** a clean generic-device build (`-sdk iphoneos`, Debug, Xcode 27
beta) succeeds with **`CompileC` 0** and `SwiftCompile` 51. **All three
configurations build** for a generic device — Debug, Release and Distribution.
`Classes/` contains **zero `UIViewController` subclasses** and exactly one non-Swift
file (`globals.h`). `git diff --check` and `plutil -lint` on the pbxproj,
`Info.plist` and `Localizable.strings` all pass.

New files:

- `Classes/PocketSwordApp.swift`: `@main`, `WindowGroup`, the `LaunchPhase` gate
  that replaces `PSLaunchViewController`, the four-workspace `TabView`, and the
  Library/Settings workspace composition.
- `Classes/ReadingWorkspace.swift`: `ReadingWorkspaceModel` (what
  `PSTabBarControllerDelegate` was, minus the tab bar) and `ReaderPaneModel` (what
  `PSModuleViewController` was, minus the view controller). Two panes exist for
  the app's lifetime.
- `Classes/SwiftUIStudyViews.swift`: `StudyPopupSheet`, `BookmarkEditorView`,
  `VoiceReferenceSheet`.
- `Classes/PSInfoPopupContent.swift` and `Classes/VoiceReferenceModel.swift`: the
  halves of two deleted view-controller files that were worth keeping — the
  Strong's lemma/transliteration parser and the voice-session state mapping.

Deleted (28 files): `PSTabBarControllerDelegate`, `PSModuleViewController`,
`PSBibleViewController`, `PSCommentaryViewController`, `PSLaunchViewController`,
`PocketSwordSceneDelegate`, `LegacyStateBridge`, `PSInfoPopupViewController`,
`PSVoiceRefViewController`, `PSBookmarkAddViewController`,
`PSBookmarksNavigatorController`, `PSBookmarkFolderAddViewController`,
`PSBookmarkFolderColourSelectorViewController`, `PSBookmarkTableViewCell`,
`PSChapterSelectorController`, `PSVerseSelectorController`,
`PSModuleSearchController`, `PSDictionaryViewController`,
`PSDictionaryEntryViewController`, `PSDictionaryOverlayViewController`,
`PSPreferencesController`, `PSBasePreferencesController`,
`PSPreferencesFontTableViewController`, `PSAboutScreenController`,
`PSHistoryController`, `PSSearchIndexBuilder`, `SearchWebView`, `PSResizing`,
plus `externals/MBProgressHUD`, `misc/PocketSword_Prefix.pch`, and 16 unreferenced
tab-icon PNGs.

Five things in the cutover are worth spelling out, because each is a place a
later "simplification" would silently break reading:

1. **Both reader panes stay in the view hierarchy**, with the inactive one at
   `opacity(0)` and `accessibilityHidden`. This is not styling. `displayChapter`
   renders the polled pane and defers a `refToShow` / `jsToShow` into the *other*,
   which that pane applies on next appearance — so the inactive pane must exist to
   receive it. A plain `if` would tear down its `WebPage` and lose both the pending
   work and the scroll position, which is the Wave 6 blank-page failure in a new
   disguise.
2. **`ReadingWorkspaceModel.start()` runs only after `LaunchCoordinator.prepare()`
   returns.** The `DefaultsLastRefValidated` migration can rewrite `lastRef`, and
   the reader renders from it. `AppSession` holds an incoming `sword://` URL in
   `pendingURL` for the same reason, replaying it from the `.ready` transition —
   which is exactly what the deleted scene delegate's `_pendingLaunchURL` did.
3. **Six of the coordinator's twelve notification observers survive**, and only
   because something outside the reader still posts them:
   `resetBibleAndCommentaryView` (a font change), `redisplayPrimary{Bible,Commentary}`
   (a display-toggle flip, the URL router), `bookmarksChanged`, and
   `newPrimary{Bible,Commentary}`. That is six once the braces are expanded, which
   is what the code registers (`ReadingWorkspace.swift:873-890`) — this bullet said
   "five of thirteen" until the final pass counted them. The other eight were the
   reader talking to itself and are now method calls. `toggleNavigation`, `toggleMultiList`,
   `showInfoPane`, `hideInfoPane`, `rotateInfoPane`, `showBibleTab`,
   `showCommentaryTab` and `updateSelectedReference` have no posters left.
4. **`HistoryStore.addEntry` gained injectable seams, and that was a real fix.**
   Moving `+addHistoryItem:` off `PSHistoryController` exposed that it read the
   chapter reference through `PSModuleController.getCurrentBibleRef()` — which
   always reads `UserDefaults.standard` — while writing to an injected `defaults`.
   The first test written against it wrote the *device's* current chapter into a
   test suite's history. It now reads `lastRef` from its own `defaults` and takes a
   `moduleNameProvider`. Behaviour in the app is identical; the store is no longer
   half-injectable.
5. **`PSResizing` is deleted, not ported.** Twenty-odd of its methods computed
   manual frames for a UIKit layout that no longer exists
   (`resizeViewsOnAppear`, `resizeViewsOnRotate`, `statusBarHeight`,
   `mainScreenBounds`). Its two live uses went to their natural homes: `iPad()`
   became `UIDevice.current.userInterfaceIdiom != .phone` at the three call sites
   that wanted it, and `supportedInterfaceOrientations` became the scene delegate's
   iOS 27 hook.

**Focus mode and the tab bar.** Wave 7 hid the tab bar with
`setTabBarHidden(_:animated:)` on the `UITabBarController`; it is now
`toolbarVisibility(reading.isFocused ? .hidden : .automatic, for: .tabBar)` on the
`TabView`. Same behaviour, including the safe-area republish that lets the reader
re-inset. The navigation bar still deliberately stays visible in Focus mode — the
Wave 7 finding that `toolbarVisibility(.hidden)` also hides the
`.topBarPinnedTrailing` Focus control, leaving no way out, is unchanged and the
comment recording it is carried forward.

**Five defects were found by live inspection, all fixed.** Every one was invisible
to the build and to the unit suite, and three of the five made a control render or
do *nothing* rather than render wrongly — which is the failure mode a hierarchy
dump catches and a passing build never will:

1. **`tabViewBottomAccessory` cannot host a per-section control.** The Library's
   section picker was declared there and rendered **nothing at all** — the
   hierarchy dump for the Library workspace was 82 lines with no picker in it.
   That modifier declares ONE accessory for the whole `TabView` (the shape the
   Music mini-player uses), so a control that differs per section has no business
   in it. Moved to `.principal` in each section's own toolbar, replacing the
   per-section `navigationTitle`, which is also why each section keeps its own
   `NavigationStack`.
2. **The reading-mode picker at `.bottomBar` sat on top of the floating tab bar.**
   Measured on device: picker at y=798, tab bar at y=795. On iOS 27 the floating
   tab bar occupies the bottom edge, so there is no bottom bar to put anything in
   — taps went to the tab bar. Moved to `.topBarLeading`. (Not `.principal`: that
   is the reference control, which Wave 7 gave `.high` visibility priority.)
3. **`Tab`'s `accessibilityIdentifier` does not reach the tab-bar button.** The
   four buttons expose only their localized labels ("Read", "Library",
   "Settings", "Search"). The identifiers were removed rather than left as a
   comforting lie, and the XCUITests match tabs by label.
4. **`toolbarVisibility(_:for: .tabBar)` on the `TabView` does nothing**, so Focus
   mode did not hide the tab bar. On device the Focus control flipped to "Exit
   Focus Mode" with the tab bar still sitting there — the state was right and the
   effect was absent. The modifier has to be applied to the content *inside* a
   tab; it now sits on `ReaderScreen`'s `NavigationStack`. This is the direct
   replacement for Wave 7's `setTabBarHidden(_:animated:)`.
5. **`ReadingWorkspaceModel.start()` posted `.newPrimaryBible` before registering
   its observers**, so nothing ever built the display-toggle rows: the KJV overflow
   menu showed only "History and Search", with no Display Settings section at all.
   Observers are now registered first, and both panes are additionally primed by a
   direct `refreshForModuleChange()` call. The old coordinator got away with the
   opposite order for two reasons that no longer hold — its `init` force-loaded
   both reader views (`_ = cvc.view`) so they had already registered in
   `viewDidLoad`, and `setDelegate` called `rebuildSettingsMenu()` directly. There
   is no view to force-load now.

Both pickers became `Menu`s rather than segmented `Picker`s in the process: a
toolbar slot next to chapter navigation is too cramped for a segmented control,
and the menu names the active mode/section instead of leaving an icon to guess at.

Live inspection also confirmed the **tab order is Read, Library, Settings,
Search** — `Search` is declared second, and `TabRole.search` moves it to the
trailing position, which is what the role is for.

**Verified live on iPhone 17 Pro / iOS 27:** launch through to the reader with
Genesis 1:1 rendered and Strong's numbers visible; all four workspaces reachable;
the Library section menu opening and switching Bookmarks → History (correct empty
states, and no Close button, which is the intended change); the reading-mode menu
switching Bible → Commentary with MHCC's Genesis 1 commentary rendering — which
also exercises the `refToShow` deferral across a pane switch, the mechanism that
most needed a live check; the overflow menu showing **exactly the six KJV display
rows in the documented order** (Strong's Numbers, Morphological Tags, Headings,
Footnotes, Red Letter, Verse Per Line) with **no Cross-references row**; and Focus
mode hiding the tab bar and status bar, reclaiming the space, keeping its exit
control, and restoring all four tabs on exit.

### Wave 8 follow-up: Strong's search only worked once per launch

**Reported from a physical iPhone 17 Pro after Wave 8 landed, reproduced on the
iOS 27 simulator, fixed.** A sixth defect of the same family as the other five —
silent, with no crash and no failing test.

**Symptom.** The first "Find all occurrences" worked. Every subsequent one showed
the *previous* term's results: tapping H1254 (בּרא, "created") displayed H430's
1,000 rows for "God", with the search field still reading `H430`.

**Cause.** `startStrongsSearch` parked a `PSSearchHistoryItem` in
`savedSearchHistoryItem` and switched tabs, expecting `SearchView` to pick it up.
But `SearchView` applies a restored item only from `configure(...)`, which its
`.task` runs **once**, behind `@State private var configured`. On every later
switch to the Search workspace that guard short-circuits, so the seeded item was
never read. The hand-off worked in the UIKit era because the multi-list was
*constructed fresh on every present* — the coordinator built a new
`UIHostingController` each time, so `configure` genuinely did run once per search.
Turning that modal into a persistent workspace removed the thing the mechanism
depended on, and nothing failed loudly when it did.

**Fix.** `SearchModel.startStrongsQuery(_:currentBookName:)` — the reader drives
the model directly instead of leaving a note for the view to find. It also
deliberately does **not** inherit the persisted match-type/fuzzy options the way
`restore(_:)` does: a Strong's lookup is an exact lemma query, and picking up a
stale "any word" or fuzzy setting from the user's last free-text search is its own
wrong-results bug waiting to happen.

`savedSearchHistoryItem` is no longer written here. It is the *reader's* memory of
the last completed search, and pre-loading it with a query that has not run yet
made the reader restore a resultless item.

**Guarded by** `testRepeatedStrongsQueriesEachRunTheirOwnTerm`, which asserts two
successive lookups issue two different FTS5 expressions (and that a whitespace-only
term is ignored rather than clearing a good query). The test must *await* the
queries: `runSearch` dispatches to a global queue, and the first version of it raced
and read one expression where it wanted two.

**Verified:** H430 → 1,000 results for "God", then H1254 → 46 results with
"created" highlighted in Genesis 1:1, 1:21, 1:27 and 2:3.

#### Second round: the mode was filled in but switched off

The first fix exposed a second bug on the same path, again reported from the
device: the query now populated correctly as `H430`, but **"Strong's Numbers" was
unchecked**, so the engine searched for the literal text and returned "No Results
for H430".

`startStrongsQuery` opened with `strongsSearch = strongsAvailable`, and
`strongsAvailable` is only resolved by `applyModule` — which runs from
`configure(...)`. Going straight from the reader to a Strong's link on a fresh
launch means `configure` has never run, so the flag was still its `false` default
and the assignment turned the mode *off*. The same latent mistake sat in
`optionsDidChange`, which `SearchView` fires from
`.onChange(of: search.strongsSearch)` — so it would have re-cleared the mode even
if the first line had set it.

Both now check `module != nil` before consulting `strongsAvailable`: the mode is on
by definition for a Strong's term, and the module's real capability is honoured from
whichever side actually knows it (here if the module is resolved, otherwise by
`applyModule`'s own clearing during `configure`). MHCC, which advertises no
Strong's, still correctly gets the mode switched off —
`testStrongsQueryRespectsAModuleWithoutStrongs` pins that half so the guard cannot
be loosened into "always on".

`testStrongsQueryEnablesStrongsModeBeforeTheWorkspaceIsConfigured` pins the fix,
and deliberately does **not** call `configure(...)` first — that absence is the
entire point of the test.

**Verified on a fresh launch, reader → Strong's link → Find all occurrences with no
prior visit to Search:** 1,000 results for "God", and the options menu shows
"Strong's Numbers" checked.

**Not yet verified, and carried into Wave 9:**

- The retirement of the `startStrongsSearch` unanimated-present workaround — rotate
  with the Strong's popup open, then tap "Find all occurrences". The ordinary
  no-rotation path is now verified twice over; the *rotation* variant is not.
- The verse menu, the bookmark editor's flattened folder picker,
  `onGeometryChange`-driven rotation restore, the chapter toast, search-index
  building, and the launch-failure view.
- Still carried from Wave 7: a footnote link, iPad, Dynamic Type, VoiceOver, RTL.
- **The physical-device path cannot be driven from here.**
  `DeviceInteractionStartWorkspaceSession` offers only simulators even with the
  device connected and selected as the run destination, so this bug was reproduced
  on the iOS 27 simulator rather than on the reporting hardware. Worth re-checking
  on the device itself.

### Wave 9 status

**Worktree state:** Complete. WebKit is gone from the target.

**Static audit:** a clean generic-device build (`-sdk iphoneos`, Debug, Xcode 27
beta) succeeds with **`CompileC` 0** and `SwiftCompile` 52. **All three
configurations build** for a generic device — Debug, Release and Distribution.
`grep` over `Classes/*.swift` finds **zero** non-comment occurrences of
`import WebKit`, `WKWebView`, `WKNavigation` or `WebPage`, and zero
`UIViewController` / `UITableViewController` / `UIHostingController` subclasses.
The one `UIViewRepresentable` is the later PR #7 follow-up's zero-size scene
orientation reader, not a content or navigation host.
`Resources/` contains no `.js`. The only non-Swift file in `Classes/` is still
`globals.h`. Every `UITabBarController` / `UINavigationController` /
`UIVisualEffectView` / `UIStackView` / `UISegmentedControl` / `UIAction` mention that
remains is inside a comment; the live UIKit surface is `UIColor` / `UIFont` /
`UIDevice` / `UIApplication` leaf values plus the app-delegate adaptor.

New files:

- `Classes/PSChapterDocument.swift`: `InlineLink` / `InlineStyle` / `InlineRun` /
  `ChapterHeading` / `ChapterVerse` / `ChapterParagraph` / `ChapterDocument`, and
  `PSChapterDocumentBuilder` — the second emitter over the v2 token grammar.
- `Classes/SwiftUINativeReader.swift`: `ChapterTextRenderer` (runs →
  `AttributedString`), `ChapterTextView` (the `ScrollView` + `LazyVStack`),
  `EntryTextView` (lexicon entries and footnotes).
- `Classes/PSEntryDocument.swift`: `EntryLink` / `EntryBlock` / `EntryDocument` and
  the lexicon/note parser.
- `Classes/PSChapterDocumentParityTests.swift`: the differential gate.

Deleted: `Classes/SwiftUIReaderViews.swift` (the Wave 6 `WebPage`/`WebView` pair),
`Classes/PSChapterNavigationJS.swift`, `Resources/SearchWebView.js`,
`Resources/HighlightBookmarks.js`, `PSContentReader.chapterPage`,
`PSModuleController`'s `createHTMLString` / `createInfoHTMLString` /
`createStrongsInfoHTMLString` / `getBibleChapter:withExtraJS:` /
`getCommentaryChapter:withExtraJS:`, `StudyPopupWebView`, `DictionaryEntryWebView`,
and the reader's `referenceOrLexiconPopup` `showRef` arm.

**The design changed from the plan, on a measurement.** See "Wave 9 revision" above:
the chapter corpus is a closed set of six inline tags, so the token stream gets a
second emitter rather than SwiftSoup parsing HTML the app generates itself. No
third-party dependency was added; `externals/` is still empty.

**What the parity test buys.** `PSChapterDocumentParityTests` compares the native
document against the fixture-pinned HTML emitter on text, verse identity,
`entryCount` and every link target. Its exhaustive tier (`PSDOC_EXHAUSTIVE=1`) walks
all 1,189 chapters × 2 modules × 2 option endpoints — **4,756 comparisons, ~30 s** —
and passes. The HTML path is deliberately KEPT for exactly this reason: its fixtures
were captured from a SWORD engine that no longer exists, so it is a real oracle.

**A layout question the plan did not ask, and getting it wrong would have been
silent.** With verse-per-line OFF — the default, and how the app has always read —
the HTML ran verses together as flowing prose with superscript numbers inline; only
with the toggle ON did each verse get its own line. One `LazyVStack` row per verse
would have made every chapter verse-per-line and left the per-module VPL toggle with
nothing to do. The document therefore groups verses into `ChapterParagraph`s and the
view picks its unit. Paragraph breaks come from the KJV's own pilcrow, which is
trustworthy: measured over the module, **all 2,970 sit at the start of a verse's
visible text and none appears mid-verse**.

**Nine defects were found by driving the simulator, none of which the build or the
unit suite could see.** Four in the reader:

1. **`lastRef` stopped being written, so the toolbar lied.** It was a side effect of
   `-getBibleChapter:withExtraJS:`, which the native reader does not call. Paging to
   Genesis 2 moved the text while the title still read "Genesis 1", and the stale
   persisted ref would have reopened the wrong chapter on relaunch.
2. **The scroll target was dropped when the document changed in the same update.**
   Assigning `document` and mutating `scrollPosition` synchronously resolves the
   target against the row set being replaced. Flipping Verse Per Line at Genesis 1:1
   landed on verse 6 while the persisted position still correctly said verse 1 — and
   the same path serves the font change and every display toggle.
3. **The verse never advanced while scrolling.** `bibleVersePosition` stuck at 1 with
   the reader at verse 11, which also breaks relaunch restoration. The replacement
   for the JS `currentVerse()` scan has to live in the VIEW, since only the view
   knows where a row sits.
4. **The commentary rendered as one enormous paragraph.** MHCC has no pilcrows —
   measured: zero across all 28,904 records — so a chapter flowed into a single
   2,000-point block. A commentary now always breaks per verse, which is also what it
   always was: the assembler wrapped every commentary verse in its own `<p>`.

Three in the lexicon renderer, all in the six characters every entry opens with
(`<a name="04399"><b>4399</b></a><br />`): the key number rendered (the WebView hid
it with `a[name]:first-child { display: none }` — CSS this wave deleted); clearing
the pending text was not enough because `<b>` flushes, so the number was already a
run by the time `</a>` arrived; and `.bold` leaked into the Hebrew lemma. Plus:

8. **`persistPosition` could write verse 0.** The intro slot is loop counter 0, so a
   chapter whose first row is an intro reported verse 0 as topmost — the toolbar read
   "Gen 2:0", and the value is persisted, so a `.verse` restore would call
   `scrollToVerse(0)` and silently do nothing. The JS could not produce this:
   `currentVerse()` opened with `if(now < 5) return 1;`.
9. **Verse numbers were indistinguishable from Strong's markers.** In the WebView
   they differed by COLOUR alone (both 70% superscripts, one body-coloured and one
   grey); at 12pt in flowing prose the chapter read as one run of superscripts. They
   are 0.75em semibold now, so the distinction is structural rather than by hue.

**What the native reader deletes rather than ports**, because a scroll view addresses
a verse by IDENTITY and not by measured offset: the `versepos` offset table and the
`arraydump:` bridge that filled it; `scrollToVerse` / `scrollToPosition` /
`findPosition`; the rotation re-measure (Wave 6 needed `resetArrays()` because
offsets are width-dependent — identity is not, so the anchor survives a rotation for
free, verified on device); and the position poll. Worth recording: **the poll was
already dead** — its `setInterval` is commented out in the shipped JS, so the
`pocketsword:currentverse:` bridge never fired.

**An unexpected dividend: the chapter is now inspectable.** In the WebView the verse
text, Strong's links and footnote markers were invisible to XCUITest and to
VoiceOver — only the container had an identifier, which is why CLAUDE.md says to read
the screenshot. Every verse and every link is now a real accessibility element
carrying its `pslink://` target, so `testStrongsLinkOpensItsLexiconEntry` and
`testChapterScrollsUnderTheChromeEdgeToEdge` can assert things no previous wave
could.

**Verified live on iPhone 17 Pro / iOS 27:** Genesis 1 in prose with pilcrow
paragraph breaks and in verse-per-line; six KJV display rows in the documented order
with no Cross-references row; H430 → אלהים then H1254 → בּרא, so the second lookup
runs its own term (the Wave 8 regression stays fixed) and returns 46 results with
"created" highlighted in Gen 1:1/1:21/1:27/2:3; H776 and H4399 with lemma,
transliteration, definition and a tappable cross-link; the verse menu; MHCC Genesis 1
and 2 through the pane deferral; chapter paging; and rotation to landscape and back
preserving verse and offset.

**Not yet verified at the end of Wave 9, and carried into the final pass:** iPad,
Dynamic Type, VoiceOver, RTL (all carried since Wave 7), the bookmark editor's
flattened folder picker, the chapter toast, search-index building, and the
launch-failure view. Also still unverified on **physical hardware** —
`DeviceInteractionStartWorkspaceSession` offers only simulators. See the final-pass
section for which of these were closed and which are still open.

## Final pass: all-configuration builds, full suite, UI verification, static audit

**Ran 2026-08-06. Complete.** This is the last checklist item, and it was not a
formality: it found **six real defects** in code that nine waves, a green suite and
a clean build had all passed over. Every one was silent — nothing crashed, nothing
failed, nothing warned except where noted.

### Builds — all three configurations, clean, generic iOS device

`CompileC` **0** and `SwiftCompile` **52** on a clean Debug `-sdk iphoneos` build;
Release and Distribution also succeed (they report `SwiftCompile` 2 because
whole-module optimization batches the files, not because fewer are compiled). The
only remaining warning is one deliberately-retained deprecation, below.

### Tests

**146 tests: 143 passed, 0 failed, 3 skipped** — the 3 being exactly the env-gated
trio. Run separately with `PSREF_EXHAUSTIVE=1` and `PSDOC_EXHAUSTIVE=1` in the
scheme's `TestAction` (plus `shouldUseLaunchSchemeArgsEnv = "NO"`, or the block is
ignored), **all three pass with 0 skipped** — including
`testNativeDocumentMatchesHTMLForEveryChapter`, the 4,756-comparison native-reader
parity gate. The scheme was backed up and restored byte-for-byte afterwards.

Worth recording, because CLAUDE.md warns about exactly this: the two lexicon
XCUITests **actually ran** rather than skipping silently, because
`strongsPreference_KJV` was already true in the simulator's container plist.

### The six defects

1. **`Entitlements.plist` was in Copy Bundle Resources.** The app's own signing
   entitlements — keychain access group, ubiquity KVS identifier — were being copied
   into the bundle as a readable plist. Only the Distribution build warned, so only
   an archive would ever have surfaced it. Removed from the Resources phase;
   `CODE_SIGN_ENTITLEMENTS` and the file reference stay, since those are what
   actually sign the app. Verified absent from the built `.app`.
2. **The search highlighter had never run, in any era.** `highlightSearchTerm` had
   zero callers. Wave 9 built the renderer half (`ChapterTextRenderer.applyHighlight`)
   and the pane state, and nothing set it — and tracing it back through `git`, the
   only caller it *ever* had was a commented-out debug line in the Obj-C original
   (`// [self highlightSearchTerm: @"and" forTab: BibleTab];`). So tapping a search
   result has never highlighted the term in the chapter it opens, while the results
   list highlighted its own rows. Wired to the search-result hand-off, taking the
   term **list** (`SearchModel.highlightTerms`, which splits words, honours quoted
   phrases and returns empty for a Strong's query) rather than one string, and
   cleared on chapter paging — otherwise the yellow follows the reader forever, which
   is what `PS_RemoveAllHighlights` existed to prevent. Two unit tests pin it.
3. **`WebKit.framework` was still linked**, and *required* rather than weak, so every
   launch loaded the whole framework for zero symbols — Wave 9 removed all the code
   but not the link. `MessageUI.framework` likewise, weak-linked, for a feedback path
   that is a plain `mailto:` URL. Both unlinked; verified with `otool -L` on the built
   binary.
4. **Four localization keys were used but undefined**, so they rendered as raw key
   text. `CancelButtonTitle` on the search-index build sheet, and three lexicon /
   morph fallbacks displayed *as the popup body* — `NoMorphGreekModuleInstalled` is
   genuinely reachable, on 20 real KJV morph tags with no Robinson entry. Added, and
   reworded: "module not installed" means nothing now that all five modules ship
   inside `PSContent.sqlite` with no way to add or remove one. Also removed a
   duplicate `NoSearchIndexMsg` whose first definition advertised the deleted in-app
   index download and was shadowed by the second.
5. **`dlog()` was a no-op in all three configurations.** The app target set
   `OTHER_CFLAGS = "-DDEBUG"`, which reaches C — and the target has had no C
   translation unit since Wave 8. `SWIFT_ACTIVE_COMPILATION_CONDITIONS` was never
   set, so `#if DEBUG` was false everywhere and every `dlog` call compiled to
   nothing, including in Debug. Swapped for
   `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` on the app target's Debug config.
6. **`testBookmarkFolderCrudAndReordering` was creating its folders under truncated
   names.** It failed looking like the drag flake its own comment described, and was
   not: typing "UI Drag B" then tapping Save persisted **"UI Drag "**, losing the last
   character every time, because a SwiftUI `TextField`'s binding is not current for
   the final keystroke until the field commits and Save takes focus in the same beat.
   `XCUIElement.value` is useless as a check — it reported the full string while the
   app saved the prefix. The field is committed with a newline first now.
   The second half was worse than the red test: cleanup matched **exact** names, so
   each truncated folder was invisible to it and accumulated in `PSBookmarks.plist`,
   where it eventually tripped the store's duplicate-name guard with a failure
   pointing nowhere near the cause. One such stray was found on the simulator and is
   what made this reproduce. Cleanup is a prefix sweep now, so the suite repairs the
   device instead of degrading it — verified by watching the plist go from the stray
   plus two folders to an empty root.

**One deprecation is deliberately NOT fixed.** iOS 27 deprecates
`AVAudioNode.installTap(onBus:bufferSize:format:block:)` in favour of an
`error:`-taking variant, but that method is `NS_REFINED_FOR_SWIFT` and the Xcode 27
beta 4 SDK **ships no refinement for it**. The only spelling that type-checks is
`try inputNode.__installTap(onBus:bufferSize:format:error: ()) { … }` — a
double-underscore private name plus a placeholder `()` where `throws` should have
consumed the `NSError**`. Verified against the SDK; every other spelling fails.
Taking that to silence one warning would break when the refinement lands, so the
warning stays and the code comment records the finding.

The other iOS 27 AVFAudio deprecation **was** migrated:
`AVAudioSession.interruptionNotification` + `InterruptionType.began` →
`didBecomeInactiveNotification`. Not mechanical — the old notification fired *only*
for an interruption, while the new one also fires for the app's own
`setActive(false)`, so the handler now requires
`DeactivationContext.source == .system` or `deactivateAudioSession()` would report
`.audioInterrupted` on its own teardown.

### UI verification — what the final pass closed

**iPad is verified**, for the first time since it was deferred in Wave 7. On the
iPad Pro 11-inch / iOS 27: Genesis 1 renders in prose with pilcrow paragraph breaks;
the reference picker adapts to a **popover anchored on the reference button** with
Genesis check-marked, the short-book scrub index and the direct `1:1` jumps — the
arm Wave 7 left as "the system's adaptation rather than an explicit branch", never
exercised until now; Library shows its `library.section` principal-slot menu and
correct empty state; Settings shows the live reading preview, font/size controls and
three device toggles. No clipping or overlap in either orientation.

**Edge-to-edge is confirmed by frame measurement on both device classes**, which is
now possible because `reading.chapter-content` sits on the `ScrollView` itself:
iPhone 17 Pro `{{0,0},{402,874}}` against a 402x874 window with the tab bar at
y=795 *over* scrolling content; iPad portrait `{{0,0},{834,1210}}` and landscape
`{{0,0},{1210,834}}`. 149 Strong's links present as real accessibility elements.

**Dynamic Type is verified** at `accessibility-extra-large`
(`xcrun simctl ui <dev> content_size accessibility-extra-large` — note the
underscore; the hyphenated form is not a valid option): chapter text scales and
reflows without clipping, verse numbers stay distinguishable from body text, and the
chrome and tab bar survive. Restored to `large` afterwards.

**Still not verified, and honestly still open:** VoiceOver, RTL (the app ships
English only, so RTL has no in-app trigger), the bookmark editor's flattened folder
picker, the chapter toast, a live search-index build, and the launch-failure view.
**Physical hardware remains undrivable from here** —
`DeviceInteractionStartWorkspaceSession` lists only simulators even with a device
connected and selected.

Two process notes worth keeping: `xcrun simctl ui` **kills an attached
device-interaction session**, so change the content size and then re-establish the
session; and a workspace session binds to the run destination that was active when
it was *created*, so switch destinations first (`XcodeSwitchRunDestination`) and
start the session after.

### PR #7 code-review follow-up — 2026-08-20

The five review findings were fixed as one post-migration hardening pass:

1. Search module selection is disabled and rejected while an index build is active;
   coordinator refreshes cannot overwrite an in-flight build's state.
2. Foreground and background index builds share one serial gate, and a foreground
   takeover cancels the registered background operation before waiting for the gate.
3. Flowing prose now marks each verse with a SwiftUI `TextAttribute`; a
   `TextRenderer` records the laid-out run fragments so the toolbar and persistence
   follow the actual inline verse. Size changes preserve a settled nonzero offset
   instead of jumping to the paragraph's first verse.
4. Search input side effects moved from value-matched `.onChange` callbacks into the
   model properties, with explicit internal-mutation provenance. A user write now
   persists and schedules synchronously and cannot be swallowed by a later model sync.
5. Rotation lock reads the hosting `UIWindowScene.effectiveGeometry.interfaceOrientation`
   through a local representable rather than inferring orientation from window shape.

Verification on iPhone 17 Pro / iOS 27: the Debug app build passed; the full unit
tier ran **151 tests, 148 passed, 3 expected exhaustive-tier skips, 0 failures**;
the final focused state/concurrency rerun passed **50/50**; and the final UI suite
passed **13/13**, including a new small-scroll test that advances the visible verse
inside Genesis 1's first multi-verse paragraph. The review pass changed no persisted
wire formats.

### Search interaction follow-up — 2026-08-28

Search results now expose a long-press **Copy Verse** action that writes the
reference plus normalized verse text to the system pasteboard. Scrolling the
results list dismisses the keyboard immediately, and tapping the already-selected
Search tab requests focus for the existing search field instead of doing nothing.
The query, result set, module, and persisted search-option behavior are unchanged.

Verification on iPhone 17 Pro / iOS 27: the app and both test bundles built
successfully; focused pasteboard/reselection tests passed **2/2**; the focused
interaction XCUITest passed **1/1** and directly observed scroll dismissal,
same-tab keyboard restoration, the result context menu, and Copy Verse invocation;
the full unit tier passed **150 tests** with the 3 expected exhaustive-tier skips
(153 executed, 0 failures); and the full UI suite passed **14/14**. `git diff
--check` and the localization plist lint also pass. No persisted wire format or
defaults key changed.

### Static audit

Seven independent read-only audit lenses over the tree, each finding adversarially
verified: **56 findings, 49 survived refutation, 7 refuted**. The refuted ones
matter as much as the rest — they included a miscounted deletion list, a line-count
claim that was right under a scope the finder had not tested, and three
"stale comment" reports where the comment was accurate for the date it was written.

Positive results worth recording, all re-derived rather than trusted:

- **Pure Swift is structurally guaranteed, not just observed.** The app target's
  Sources phase is exactly 40 `.swift` files, the unit-test phase 8, the UI-test
  phase 1 — 49 total, cross-checked both directions against the 48 files in
  `Classes/` plus `Tests/`. Zero `.m`/`.mm`/`.cpp`/`.c` anywhere in the repo. Three
  headers exist (`globals.h` and the two bridging headers) and both bridging headers
  import `globals.h` and nothing else.
- **Zero non-comment WebKit occurrences** across `Classes/*.swift` — all 47 hits are
  comments — and zero `UIViewController` / `UITableViewController` /
  `UIHostingController` declarations. The sole `UIViewRepresentable` is the local
  scene orientation reader added by the PR #7 follow-up. One `#selector` remains,
  the `AVAudioSession` observer.
- **All 12 load-bearing reader/search invariants hold**, each with a file:line
  citation: the two emitters never call each other and share one gating table;
  `PSContentStore` is `SQLITE_OPEN_READONLY` behind a serial queue with `import
  zlib`; `PSSearchEngine` binds `SQLITE_TRANSIENT` everywhere, opens `FULLMUTEX`
  with a 2 s busy timeout and no serial queue, keeps `ORDER BY rowid`, and
  `dropIndex` does not remove the shared directory; the scroll application is still
  deferred by one update; `EntryTextView` claims `.handled` only with a handler; both
  paging directions still restore no position.
- **The `globals.h` ↔ `AppConstants.swift` wire-string contract is exact**: 78
  shared literals, byte-identical, zero divergences; 43/43 `Defaults*` macros mirror
  with the right keys including every macro-name≠key case; 23/23 notification
  literals match.
- **All eight per-file test counts in CLAUDE.md matched** before this pass added two.
- **No `.acorn` source documents are bundled** (27 files, 3.0 MB, on disk only), and
  the three PNGs Wave 7 flagged as unreferenced-but-bundled were already deleted in
  Wave 8.

Acted on: the 32 `disabled-*`/`enabled-*` toggle icons Wave 8 replaced with SF
Symbols were still in the Resources phase and are now removed (128 pbxproj lines,
28,698 bytes) — this closes Wave 7's deferred "UIKit asset sweep" carry. Also fixed
the About screen's **MBProgressHUD attribution**, which credited a library deleted in
Wave 8 on a screen whose whole job is attribution, and the test bridging header's
present-tense claim that the app target still contained it.

Left deliberately: nine loose launch-image PNGs (1.16 MB) that duplicate
`Images.xcassets/LaunchImage.launchimage` for a launch path that uses
`LaunchScreen.storyboard`, 15 further orphaned UIKit-era PNGs (29,775 B), four
`import UIKit` lines in files that use nothing from UIKit, and a handful of dead
constants/methods. All are inert, none affects behaviour, and each is a
documentation-free deletion that would add churn to a diff already carrying six
behaviour fixes. Recorded here so the next sweep has the list.

Also corrected in this pass: **21 documentation-versus-reality defects** across this
plan and CLAUDE.md, including this document's own Execution Status contradicting
itself (edge-to-edge "met" 34 lines above "still letterboxed"), the Summary still
prescribing SwiftSoup after the Wave 9 revision rejected it, "Current repository
facts" describing the deleted Wave 6 WebKit reader and `PSModuleViewController` in
the present tense, CLAUDE.md pinning the deployment target at 26.0 when all 12
assignments read 27.0, and a "five of thirteen observers" count whose own list
enumerates six.

## Summary

- Target iOS 27 exclusively and incrementally replace UIKit with a SwiftUI-owned app.
- Final navigation: **Read**, **Search**, **Library**, and **Settings**.
- Use quiet, system-native styling with SF Symbols and semantic colors; retain selectable study fonts.
- Preserve all bookmark, history/iCloud, search-history, defaults, baked-content, and `sword://` formats.
- Ship a SwiftUI WebKit reader first (Wave 6), then replace it with native SwiftUI
  rendering (Wave 9). **Not through SwiftSoup** — that was this plan's original
  prescription and the Wave 9 revision rejected it on a measurement; the token
  stream gets a second emitter instead, and no third-party dependency was added.
  See "Wave 9 revision" below.

## iOS 27 Baseline

- Set every project, app, and test Debug/Release/Distribution deployment setting to
  `27.0`. **Done in Wave 1** — all 12 `IPHONEOS_DEPLOYMENT_TARGET` assignments
  (4 targets × 3 configurations) read `27.0`, so the original "project defaults and
  tests remain 26" no longer applies.
- Install Xcode 27, the iOS 27 SDK, and an iOS 27 simulator runtime. **Done** —
  Xcode 27.0 beta 4 (`27A5228h`) at `/Applications/Xcode-beta.app`, with the iOS
  27.0 SDK and simulator runtime. A 26.6 install still exists and is still what
  `/usr/bin/xcodebuild` resolves, which is why every command sets `DEVELOPER_DIR`.
- Keep Swift 5 and minimal concurrency checking during this migration; handle Swift 6 separately.
- Treat `@State` as an SDK 27 macro: initialize state either at declaration or exactly once through an explicit initializer, never both, and do not compose wrappers on `@State`.
- Use trailing-closure `overlay`/`background` forms and avoid hard-coded `TupleView` types under SDK 27's unified `@ContentBuilder`.

## Architecture

- Add stable `@MainActor @Observable` models: `AppSession`, `ReadingModel`, `SearchModel`, `LibraryModel`, and `SettingsModel`.
- Add typed values: `Workspace`, `ReadingMode`, `BibleReference`, `ChapterDocument`
  and `InlineRun`. (This list originally also named `StudyLink`, `ChapterRequest`
  and `ChapterBlock`; none was ever created. Their jobs went to `InlineLink` /
  `EntryLink`, to plain `chapterDocument(module:ref:kind:)` arguments, and to
  `ChapterParagraph` / `ChapterVerse` / `ChapterHeading` respectively.)
- Extract behavior into `LaunchCoordinator`, `HistoryStore`, `BookmarkStore`, `SearchIndexCoordinator`, and `URLRouter`.
- Give bookmark nodes runtime UUIDs excluded from serialization; use natural stable IDs for dictionary, history, chapter, and search rows.
- Replace UIKit bookmark colors with a hex/RGB value type and convert to `SwiftUI.Color` in views.
- Keep the existing `.strings` localization system and use `LocalizedStringResource` for model-provided UI text.

## Migration Waves

1. **Baseline:** Align all targets at iOS 27, restore green builds and 78 unit tests under Xcode 27, add an XCUITest target, and capture deterministic workflow baselines.
2. **State extraction:** Move launch, routing, reading, settings, bookmarks, history sync, and search-index state out of controllers. Add a temporary NotificationCenter bridge for mixed UIKit/SwiftUI operation.
3. **Supporting screens:** Build SwiftUI launch, reference picker, voice-reference, Settings, font picker, and About views. Replace mail compose with `mailto:` and permission recovery with `openSettings`.
4. **Library:** Implement Dictionary, Bookmarks, and History. Use iOS 27 `.reorderable()`/`.reorderContainer` for bookmark movement, `swipeActionsContainer()` for row actions, and item-bound dialogs for rename/delete confirmation.
5. **Search:** Build the dedicated workspace with module selection, filters, debounced queries, highlighted results, history restoration, and cancellable indexing. Restart interrupted transactional builds through `BGProcessingTaskRequest`.
6. **Read/WebKit:** Use `WebPage`/`WebView` and `NavigationDeciding` for chapters, JavaScript restoration, links, notes, Strong's/morph actions, bookmarks, and highlighting. Use a single Bible/commentary pane on all devices.
7. **iOS 27 chrome:** Keep reference and chapter navigation at high toolbar priority, pin Focus mode with `.topBarPinnedTrailing`, place secondary study actions in `ToolbarOverflowMenu`, and minimize normal reading chrome with `toolbarMinimizeBehavior`.
8. **App cutover:** Introduce `@main PocketSwordApp`, `WindowGroup`, four-workspace `TabView`, `NavigationStack`, `onOpenURL`, and `scenePhase`. Remove the UIKit coordinator, app/scene delegates, controllers, notification routing, `PSResizing`, MessageUI, MBProgressHUD, and bridging headers.
9. **Native reader:** Expand the store's tokens **directly** into `ChapterDocument`
   (no HTML, no SwiftSoup — see the revision below), and render stable verse rows
   using `LazyVStack`, `AttributedString`, native scrolling, typed links, context
   menus, notes, headings, red letter, and bookmark colors. Remove WebKit and
   JavaScript resources after feature-parity acceptance. **Acceptance criterion:
   edge-to-edge reading** — see below.

### Wave 9 revision: token→document, not HTML→SwiftSoup

**Decided 2026-08-05, before any Wave 9 code.** This plan said "Add SwiftSoup via
SPM, parse the existing assembled HTML into `ChapterDocument`". That is **not** what
Wave 9 does, and the reason is a measurement rather than a preference.

The chapter corpus was scanned in full — all 2,378 chapter rows expanded through the
v2 token grammar, 61,190 non-empty records plus all 1,322 stored headings — and the
emitted HTML vocabulary is a **closed set of six inline tags**:

| tag | occurrences | attributes |
|---|---|---|
| `a` | 597,505 | `href`, `class` ∈ {`strongs` 374,047, `morph` 216,499, `n` 6,959} |
| `i` | 21,609 | `class="transChangeAdded"` (only value) |
| `font` | 6,892 | `size="-1"` (only value) |
| `p` / `b` | 2,506 each | none — always the `<p><b>…</b></p>` title pair |
| `span` | 2,038 | `class="WordOfChrist"` (only value) |

Entities are numeric only (`&#182;` ×2,970, `&#8217;` ×1,997, `&#8211;` ×797, plus a
long tail of one-offs). **No** `blockquote`, `div`, `table`, `ruby`, `br` or `<!P>`
appears in any chapter record — which independently re-confirms that
`PSChapterAssembler`'s three deliberately-ported unreachable branches (the `lg`
blockquote move, `hackChapterToAccommodateBrokenLG`, the post-loop blockquote close)
are still unreachable.

So the pipeline is:

```
tokens ──PSChapterExpander──▶ HTML          (KEPT: byte-locked by fixtures, now a test oracle)
tokens ──PSChapterDocumentBuilder──▶ ChapterDocument ──▶ LazyVStack   (the render path)
```

Three reasons this is the right altitude:

1. **Serializing to HTML only to re-parse it is a round trip through a format we
   own.** The app generates that HTML itself, from a token stream that already *is*
   a structured document. SwiftSoup would be a ~30k-LOC HTML5 parser earning its
   keep on six known tags.
2. **It reintroduces a third-party dependency into a repo whose last two projects
   removed ~47k lines of them.** There is no CocoaPods and no SPM today and
   `externals/` is empty; the token→document route keeps it that way.
3. **The two emitters share one gating table and are held together by a test, not by
   hope.** Both consume the same `PSChapterExpander.Options`, so a divergence is a
   parity-test failure across all 2,378 chapters rather than a silently different
   render. This is the same shape as the deliberate three-implementation redundancy
   the file header for `PSChapterExpander` describes.

**What this does NOT change.** The HTML path stays exactly as it is and stays
fixture-pinned — `PSContentStoreTests`' chapter-body fixtures at both option
endpoints, the highlighted-body fixture, and `chapter-loop-counters.tsv` all keep
passing untouched. They are what makes the native path checkable at all, so
**nothing in Wave 9 may edit a fixture or relax one of those assertions.**

The *lexicon* vocabulary is genuinely wider than the chapter one (`br`, `sup`, `sub`,
`q`, `bib`, `latin`, `greek`, `description`, `pronunciation`, plus 14,298 `a name=`
anchors and 14,989 lexicon→lexicon `href`s) and footnotes narrower (`i`, `font`
only). The study-popup port is therefore its own step with its own vocabulary, not a
reuse of the chapter renderer.

**WebKit removal is full, not partial.** All three surfaces go: the reader, the study
popup (`StudyPopupWebView`) and the dictionary entry (`DictionaryEntryWebView`), so
`import WebKit` leaves the target entirely along with both JS resources and the
`createHTMLString` / `createInfoHTMLString` / `createStrongsInfoHTMLString` shells.
Stopping at the reader would leave the final static audit inheriting WebKit and two
`UIViewRepresentable`s. `PSInfoPopupContent`'s lemma/transliteration parser is
**kept** — it is content, not presentation.

### Wave 9 acceptance criterion: edge-to-edge reading

**The reader must scroll content under the chrome, not stop at it.** As of Wave 7
the chapter is *letterboxed*: the scroll view ends at the toolbar and at the
floating tab bar, so the reader shows black bands top and bottom. Wave 9 is where
this gets fixed, and it is a criterion rather than a nicety — it is the most
visible thing about the reading surface.

The target is a full-height scroll view whose **content** carries the safe-area
insets: text flows edge-to-edge and scrolls beneath translucent bars, while no
line is ever obscured at rest. Concretely, `contentMargins` (or
`safeAreaPadding`) on the `LazyVStack`'s scroll view, plus
`ignoresSafeArea` on the scroll view itself. In a native scroll view this is
one call; native scrolling handles the rest.

Both halves of the tradeoff have already been got wrong once each, so neither is
an acceptable end state:

- Wave 6 let the WebView extend under the tab bar with no content inset, and
  lines painted permanently behind it.
- Wave 7 kept the WebView inside the safe area, which fixed the overlap and
  produced the current letterboxing.

**Why this was not fixed in the WebView.** For a WebView the insets have to come
from the HTML — `viewport-fit=cover` plus `env(safe-area-inset-*)` in
`PSModuleController.createHTMLString`, replacing `PSContentReader.chapterPage`'s
six hardcoded `<p>&nbsp;</p>` pads (themselves a faithful port of
`-getChapter:`'s own six). Every verse offset that `versePositionArray`,
`scrollToVerse`, `scrollHappened` and the two-point scroll threshold measure sits
downstream of where content begins, and the chapter-body fixtures plus
`chapter-loop-counters.tsv` pin the surrounding output. That is a change to the
render path and its scroll math, in a WebView this wave deletes — so it is paid
for once, here, in the reader that survives.

A cheap intermediate exists if the bands need to look deliberate before Wave 9
lands: make the toolbar and tab bar backgrounds opaque, so the boundary reads as
a chrome edge rather than as clipped content. Cosmetic only, and it carries none
of the scroll-math risk.

## Verification

- Run all existing content, persistence, parser, and search tests after every wave.
- Add tests for state routing, deep links, background indexing, legacy data decoding, bookmark identity, and iCloud merge behavior.
- Cover launch, all workspaces, reading navigation, Bible/commentary switching, search, dictionary, bookmark CRUD/reordering, history, voice states, Focus mode, and relaunch restoration with XCUITest.
- Verify light/dark mode, Dynamic Type, VoiceOver, RTL, iPhone/iPad, rotation, constrained toolbar overflow, interrupted launch, and empty/error states.
- The native reader requires workflow and feature parity, not pixel-identical WebKit output.
- **Check the reader's top and bottom edges explicitly, in both orientations.** The
  chapter must flow edge-to-edge and scroll under the chrome, with no black band at
  either end and no line obscured at rest. This has been wrong in both directions
  across Waves 6 and 7 (overlap, then letterboxing) and is a Wave 9 acceptance
  criterion — see the section under Wave 9.
  **Wave 9 inverted how you check this.** The old advice was "a hierarchy dump does
  NOT catch it, read the screenshot", because `reading.web-content` sat on a
  container and reported full-window whether the WebView inside it was letterboxed
  or not. The identifier is now `reading.chapter-content` and it sits on the
  `ScrollView` **itself**, so its frame is the measurement: letterboxing shows up as
  a frame that stops short of the window. Confirmed in the final pass — iPhone 17
  Pro `{{0,0},{402,874}}` against an `402x874` window, iPad Pro 11-inch
  `{{0,0},{834,1210}}` portrait and `{{0,0},{1210,834}}` landscape. Note **both**
  panes carry the identifier (the inactive one at `opacity(0)`), so use
  `.firstMatch`. Screenshots are still the right tool for *typography* — that is how
  the Wave 9 verse-number weight defect was found.
- Finish with all three configurations and a static audit showing no project-owned UIKit imports, symbols, Objective-C sources, or UIKit-only dependencies.
