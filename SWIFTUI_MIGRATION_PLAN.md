# PocketSword iOS 27 SwiftUI Redesign

## Execution Status

**Last updated:** 2026-08-04

**Overall state:** In progress. Waves 1 and 2 are complete and Wave 3 supporting
screen replacement is underway.

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

- Simulator discovery is blocked from sandboxed shell commands by
  `CoreSimulatorService connection became invalid`. Xcode MCP can access the
  installed iOS 27 simulators and is the verification path for this migration.
- The Wave 1 Xcode scheme is green on the iPhone 17 Pro iOS 27 simulator:
  76 standard unit tests passed, the 2 `PSREF_EXHAUSTIVE` opt-in tests skipped,
  and 3 deterministic XCUITests passed.

### Wave checklist

- [x] Repository and persistence-contract audit
- [x] Confirm Xcode 27, iOS 27 SDK, and baseline device build
- [x] Wave 1: Baseline settings, XCUITest target, and deterministic baselines
- [x] Wave 2: Typed domain values, observable models, coordinators, and stores
- [ ] Wave 3: Supporting SwiftUI screens
- [ ] Wave 4: Library workspace
- [ ] Wave 5: Search workspace and background indexing
- [ ] Wave 6: SwiftUI WebKit reader
- [ ] Wave 7: iOS 27 toolbar and reading chrome
- [ ] Wave 8: SwiftUI app lifecycle and four-workspace cutover
- [ ] Wave 9: Native SwiftUI reader and WebKit removal
- [ ] Final all-configuration builds, tests, UI verification, and static audit

### Current repository facts

- The app logic is already Swift except for vendored `MBProgressHUD`.
- Baked content, reference parsing, FTS5 search, bookmark serialization, history
  serialization/iCloud merge, and voice-reference parsing already exist in
  Swift and must remain the behavior-preserving foundation.
- UIKit still owns the application lifecycle, navigation, and screen layer.
- The Xcode project uses explicit file and target membership.
- `PocketSword` is the shared scheme containing `PocketSwordTests`.
- Project, app, unit-test, and UI-test deployment settings are aligned at 27.0.
- `PocketSwordUITests` is part of the shared `PocketSword` scheme and covers the
  legacy reading/library destinations, Settings/About through More, and the
  History/Search modal using stable accessibility identifiers.
- `AppSession` now owns observable reading, settings, library, and search models.
  Typed stores preserve the legacy defaults keys for reading position, modules,
  font, display, rotation, fullscreen, idle-timer, history, and search
  preferences.
- `LegacyStateBridge` temporarily mirrors the existing UIKit notification flow
  into `AppSession` and routes settings side effects back through the legacy
  redisplay and idle-timer paths.
- Bookmark nodes carry runtime UUIDs that are deliberately excluded from the
  positional plist schema. History and search result snapshots use natural
  persisted reference/module/date identities.
- `LaunchCoordinator` owns preference reset and all one-shot launch migrations;
  the legacy launch controller is now only the temporary UIKit spinner and
  delegate adapter.
- `HistoryStore` owns the iCloud observer, notification interpretation, legacy
  recursive merge/dedup/cap behavior, and local/cloud write-back.
- Wave 3 has replaced the Preferences, font picker, and About destination
  content with SwiftUI views hosted by the existing UIKit tab coordinator.
  MessageUI is no longer used by the live About path; feedback uses `mailto:`.

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
  tests skipped, and all 3 XCUITests passed (104 total results). Wave 3 remains
  in progress: launch, reference picker, and voice-reference SwiftUI views are
  still outstanding.

## Summary

- Target iOS 27 exclusively and incrementally replace UIKit with a SwiftUI-owned app.
- Final navigation: **Read**, **Search**, **Library**, and **Settings**.
- Use quiet, system-native styling with SF Symbols and semantic colors; retain selectable study fonts.
- Preserve all bookmark, history/iCloud, search-history, defaults, baked-content, and `sword://` formats.
- Ship a SwiftUI WebKit reader first, then replace it with native SwiftUI rendering through SwiftSoup.

## iOS 27 Baseline

- Set every project, app, and test Debug/Release/Distribution deployment setting to `27.0`; the effective app target is currently 27, but project defaults and tests remain 26.
- Install Xcode 27, the iOS 27 SDK, and an iOS 27 simulator runtime. The current Xcode 26.6/iOS 26.5 installation cannot verify this target.
- Keep Swift 5 and minimal concurrency checking during this migration; handle Swift 6 separately.
- Treat `@State` as an SDK 27 macro: initialize state either at declaration or exactly once through an explicit initializer, never both, and do not compose wrappers on `@State`.
- Use trailing-closure `overlay`/`background` forms and avoid hard-coded `TupleView` types under SDK 27's unified `@ContentBuilder`.

## Architecture

- Add stable `@MainActor @Observable` models: `AppSession`, `ReadingModel`, `SearchModel`, `LibraryModel`, and `SettingsModel`.
- Add typed values: `Workspace`, `ReadingMode`, `BibleReference`, `StudyLink`, `ChapterRequest`, `ChapterDocument`, `ChapterBlock`, and `InlineRun`.
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
9. **Native reader:** Add SwiftSoup via SPM, parse the existing assembled HTML into `ChapterDocument`, and render stable verse rows using `LazyVStack`, `AttributedString`, native scrolling, typed links, context menus, notes, headings, red letter, and bookmark colors. Remove WebKit and JavaScript resources after feature-parity acceptance.

## Verification

- Run all existing content, persistence, parser, and search tests after every wave.
- Add tests for state routing, deep links, background indexing, legacy data decoding, bookmark identity, and iCloud merge behavior.
- Cover launch, all workspaces, reading navigation, Bible/commentary switching, search, dictionary, bookmark CRUD/reordering, history, voice states, Focus mode, and relaunch restoration with XCUITest.
- Verify light/dark mode, Dynamic Type, VoiceOver, RTL, iPhone/iPad, rotation, constrained toolbar overflow, interrupted launch, and empty/error states.
- The native reader requires workflow and feature parity, not pixel-identical WebKit output.
- Finish with all three configurations and a static audit showing no project-owned UIKit imports, symbols, Objective-C sources, or UIKit-only dependencies.
