# PocketSword iOS 27 SwiftUI Redesign

## Execution Status

**Last updated:** 2026-08-05

**Overall state:** In progress. Waves 1 through 6 are complete; Wave 7 (iOS 27
toolbar and reading chrome) is the next wave.

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
- [x] Wave 3: Supporting SwiftUI screens
- [x] Wave 4: Library workspace
- [x] Wave 5: Search workspace and background indexing
- [x] Wave 6: SwiftUI WebKit reader
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
  result snapshots, and highlighted full-verse results. The old UIKit search
  controller remains compiled but has no live instantiation and is retained only
  until the UIKit coordinator is removed.
- Wave 6 now has an in-progress native SwiftUI WebKit surface in
  `SwiftUIReaderViews.swift`. `ReaderWebPageModel` owns `WebPage`, typed
  `NavigationDeciding`, ordered JavaScript calls, navigation events, and WebView
  scroll callbacks. `PSModuleViewController` temporarily hosts that view while
  retaining the existing UIKit reading chrome and presentation actions.
- The old `PSWebView.swift` wrapper has been deleted and removed from explicit
  Xcode target membership. This is not yet a completion claim: the latest load
  race and safe-area changes still require runtime verification.
- Search index builds persist an interrupted module and submit a
  `BGProcessingTaskRequest`. The launch-registered background manager restarts
  the same transactional `PSSearchEngine` build, cancels cleanly on expiration,
  retries expired work, and clears the pending marker only after success or a
  terminal failure.
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
