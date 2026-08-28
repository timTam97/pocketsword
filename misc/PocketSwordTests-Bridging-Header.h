//
//  PocketSwordTests-Bridging-Header.h
//  PocketSwordTests
//
//  Bridging header for the unit-test bundle (Swift migration step 0c).
//
//  The test bundle is app-hosted (TEST_HOST + BUNDLE_LOADER -> PocketSword.app)
//  and uses `@testable import PocketSword`, which exposes the app module's Swift
//  symbols (AppConstants, the Notification.Name extension, the UserDefaults
//  per-module-key extension, etc.).
//
//  The Obj-C model classes whose persisted formats these tests LOCK are NOT in
//  the app's own bridging header, so `@testable import` alone does not surface
//  them to the test's Swift code. We import their (C++-clean, Foundation-only)
//  public headers here so the test bundle can reference them. The class
//  IMPLEMENTATIONS live in the already-built host app binary; this header
//  provides only the declarations.
//
//  All headers below were verified C++-clean (no `sword::`, no `using sword`,
//  no `#include <lowercase.h>`), so this bridging header stays Swift-importable.
//

#import "globals.h"               // PSSearchType / PSSearchRange NS_ENUMs + keys

// The four Sword*.h facade imports are GONE (SWORD_REMOVAL_PLAN.md Phase 5).
//
// They existed for the engine-driven tests — SwordOracleCaptureTests and
// PSDifferentialTests captured and compared live-engine output, and
// PSRefSemanticsTests drove VerseKey directly. Step 12 deleted those tests and
// retargeted their claims onto the committed fixtures (versification-KJV-oracle.txt,
// search-index-KJV.digest, chapter-loop-counters.tsv and the chapter-body HTML), and
// step 7 deleted the headers themselves.
//
// The PSSearchEngine.h import is GONE too (step 8). It existed for the one thing the
// tests could not reach through `@testable import`: the engine's two C-linkage free
// functions, `PSFoldForIndex` and `PSSearchCleanDisplayText`. Step 8 ported the
// engine to Swift — `PSFoldForIndex` deleted outright (its Swift twin
// `PSSearchQuery.foldForIndex` was already byte-identical), `PSSearchCleanDisplayText`
// moved to `PSSearchQuery.cleanDisplayText` — and both are now internal Swift members
// the test bundle sees through `@testable import`.
//
// **globals.h is therefore the ONLY thing either bridging header imports from this
// project**, and it is the only non-Swift file in the app target at all. The
// sentence here used to end "...other than it and the vendored MBProgressHUD",
// which was true when written and stopped being true in Wave 8: that library was
// deleted with its only consumer, `externals/` is empty, and a clean build reports
// `CompileC` 0 — there is no longer any Obj-C implementation to speak of.
// PSHistoryItem is Swift as of migration step 1.2 — its type is visible to the
// test bundle via `@testable import PocketSword`, so it is NOT imported here.
// PSSearchHistoryItem is Swift as of migration step 1.2 — its type is visible to
// the test bundle via `@testable import PocketSword`, so it is NOT imported here.
// The bookmark chain (PSBookmarkObject / PSBookmark / PSBookmarkFolder /
// PSBookmarks) is Swift as of migration step 1.1 — its types are visible to the
// test bundle via `@testable import PocketSword`, so they are NOT imported here.
