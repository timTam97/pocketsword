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
#import "PSHistoryItem.h"
// PSSearchHistoryItem is Swift as of migration step 1.2 — its type is visible to
// the test bundle via `@testable import PocketSword`, so it is NOT imported here.
// The bookmark chain (PSBookmarkObject / PSBookmark / PSBookmarkFolder /
// PSBookmarks) is Swift as of migration step 1.1 — its types are visible to the
// test bundle via `@testable import PocketSword`, so they are NOT imported here.
