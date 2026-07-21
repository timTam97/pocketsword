# PocketSword Swift Migration Plan (Authoritative, Execution-Ready)

> Status: ready to execute. Each wave ships independently green. The SWORD C++ engine and its Obj-C++ bridge are **never** rewritten in Swift — only their headers are sanitized. Work climbs the dependency graph leaves-first; hubs (`PSModuleController`, `PSTabBarControllerDelegate`, `globals.h`) migrate last; `Sword*.{h,mm}` stays Obj-C++ permanently.
>
> Produced by a multi-agent planning workflow: 5 parallel codebase readers → 3 competing strategies → 3-judge panel → synthesis → drafted plan → adversarial completeness critic → this revision. Every structural claim below was verified against the source tree.
>
> **Adopted assumptions (see §6 — override any of these):** Swift **5 language mode** (Swift 6 strict concurrency deferred); the **XCTest target is added** in Wave 0c; cadence is **one PR per leaf / atomic unit, all 3 configs built per wave**; end state is **app-layer Swift over a permanent Obj-C++ SWORD bridge**; all work stays on a **dedicated `swift-migration` branch** off `main` and is **never merged back here** — the owner handles integration into `main` separately.

---

## 1. Executive summary & core architectural decision

PocketSword is a programmatic-UIKit, Objective-C / Objective-C++ iOS app built directly on the in-tree CrossWire SWORD C++ engine (compiled from `externals/sword/src`, headers in `externals/sword/include`, C++ standard `c++0x`, no module map). There is **no Swift today** — zero `.swift` files, zero `SWIFT_*` build settings. The goal is an incremental, always-shippable migration to a **mixed Obj-C / Obj-C++ / Swift** target. Scope: ~109 app files / ~25.7k lines under `Classes/` (15 `.m`, 39 `.mm`, 55 `.h`).

### The single load-bearing decision

**Swift never touches C++.** Direct Swift⇄C++ interop (`cxxInteroperabilityMode`) is rejected as non-viable: SWORD's public surface is operator-overloaded value-semantic C++11 — custom `SWBuf` strings, nested `std::map` `AttributeList`, conversion operators from the `SWMODULE_OPERATORS` macro, key navigation via `(*key)++` / `*sk = sword::TOP`, deep virtual hierarchies — none of which the Clang importer surfaces usefully, and the project predates reliable interop (`c++0x`, no SWORD module map). The existing Obj-C++ shim (`SwordManager`, `SwordModule`, `SwordBook`, `SwordDictionary`, `SwordKey`, `SwordVerseKey`, `SwordListKey`, `VerseEnumerator`) is the **permanent** C++ boundary and stays `.mm` forever.

The mandatory enabling change is **header sanitization**: every `Sword*.h` leaks C++ into its public Objective-C surface today (`#include <swmgr.h>`, `using sword::SWModule;`, `sword::SWMgr *` ivars and method signatures; `SwordBook.h` even has an **unguarded** `#import <versificationmgr.h>` at line 9 plus a `const sword::VersificationMgr::Book *` ivar and `-initWithBook:`). A Swift bridging header is parsed in Objective-C (not Obj-C++) mode and cannot import any of these. The **true gate is transitive header taint, not direct `sword::` usage**: 27 of 39 `.mm` files contain no `sword::` token, yet most import a C++-leaking header (`PSModuleController.h` imports `SwordModule.h`; `PSTabBarControllerDelegate.h` itself includes `<swmgr.h>`/`<swmodule.h>`/`<localemgr.h>`). De-tainting `PSModuleController.h` and `PSTabBarControllerDelegate.h` alone unblocks ~15 mid-tier view controllers.

### Strategy in one line

Sanitize-then-climb: split each `Sword*.h` (and the two tainted hub headers) into a clean Foundation-only public interface plus a per-class internal `SwordX+Cpp.h` holding the relocated C++, wire Swift into the build, port `globals.h` to a Swift constants layer, then migrate leaves-first up the dependency graph — **respecting the interop mechanics in §2A**, which dictate that some files migrate together as atomic units rather than one-per-PR. `SwordModuleTextEntry` (a clean `NSString` DTO) is the value type that crosses the boundary. Localization is `.strings`-based (`NSLocalizedString`, 17 `.lproj`, zero `.xib`) and is **unaffected** — the `gen_xib_strings.py` / `localize_xibs.py` flow in CLAUDE.md is stale.

---

## 2. PREREQUISITE — WAVE 0 (enabling plumbing; no Swift business logic)

Wave 0 has five PRs (0a–0e). Each must build green in **all three** configs (Debug / Release / Distribution) before merge. **All file additions, moves, and deletes go through the Xcode MCP** (`XcodeWrite` / `XcodeMV` / `XcodeRM` / `XcodeMakeDir`) so they register in `project.pbxproj` — a raw filesystem write leaves the file uncompiled and invisible to the target.

### 0a. Enable Swift in the project

Via `mcp__xcode__XcodeUpdate`, add to the **project-level** build configs `C01FCF4F` (Debug), `C01FCF50` (Release), `E982FA65` (Distribution) so the single app target inherits them:

| Setting | Value |
|---|---|
| `SWIFT_VERSION` | `5.0` — **assumption: Swift 5 mode, not 6.** Swift 6 strict concurrency would force `Sendable`/actor-isolation annotations across the bg-thread SWORD init, the `NSNotificationCenter` web of cross-VC posts, and every `@objc` boundary type — a second migration layered on the first. Stay on Swift 5; revisit Swift 6 only after the codebase is fully Swift. |
| `SWIFT_OBJC_BRIDGING_HEADER` | `misc/PocketSword-Bridging-Header.h` |
| `SWIFT_OBJC_INTERFACE_HEADER_NAME` | `PocketSword-Swift.h` (pins the generated reverse header; default already resolves to this since `PRODUCT_NAME=PocketSword`) |
| `CLANG_ENABLE_MODULES` | `YES` |
| `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` | `YES` |
| `SWIFT_OPTIMIZATION_LEVEL` | Debug `-Onone`; Release/Distribution `-O` |
| `SWIFT_COMPILATION_MODE` | Debug `singlefile`; Release/Distribution `wholemodule` |
| `SWIFT_STRICT_CONCURRENCY` | `minimal` (default; do not raise to `targeted`/`complete` during the migration) |

Create `misc/PocketSword-Bridging-Header.h` via `XcodeWrite`. It imports **only** verified C++-clean headers. Initial contents:

```objc
#import "globals.h"            // C++-free; the most valuable import for Swift
#import "PSResizing.h"         // pure UIKit
#import "PSWebView.h"          // WebKit only; PSWebViewDelegate
#import "PSInfoPopupViewController.h"
#import "SearchWebView.h"
#import "SwordModuleTextEntry.h" // clean NSString DTO across the boundary
#import "VerseEnumerator.h"      // clean header (impl stays .mm)
// Sword*.h clean facades are added here ONLY after 0e splits them.
```

Add **one** trivial `.swift` file (e.g. `Classes/SwiftBuildProbe.swift` containing `import Foundation`) via `XcodeWrite` to prove the toolchain links. The auto-generated `PocketSword-Swift.h` (Swift→ObjC direction) lands in DerivedData — never create it by hand, never add it to the project; `.m`/`.mm` files `#import "PocketSword-Swift.h"` to call Swift.

**Coexistence with the `.pch`:** `GCC_PREFIX_HEADER = misc/PocketSword_Prefix.pch` is force-included into every C/ObjC/C++ TU but is **ignored by the Swift compiler**. Swift gets none of it — not Foundation/UIKit auto-import, not `DLog`/`ALog`, not the SWORD/ZipArchive `#define`s. Every Swift file must `import Foundation`/`import UIKit` explicitly. Leave the `.pch`, `c++0x`, `-licucore`, `GCC_PRECOMPILE_PREFIX_HEADER`, and the Sources phase **byte-for-byte unchanged**. **Do not** enable cxx-interop. State in the PR: "Swift addition leaves the SWORD/ICU/c++0x/.pch build path byte-for-byte unchanged."

### 0b. Port `globals.h` to a Swift `AppConstants` layer

`globals.h` is `#define`-only plus bare `typedef enum`s; Swift sees the enums but **none** of the macros. Port as follows (preserving every wire string byte-for-byte — the persisted key string usually differs from the macro name, e.g. `DefaultsLastRef` → `"lastRef"`, `DefaultsBibleVersePosition` → `"bibleVersePosition"`):

- **Enums** — convert the bare `typedef enum`s to `NS_ENUM`/`NS_CLOSED_ENUM` in a sanitized `globals.h` (or a new `PSConstants.h` it `#import`s) so Swift imports them with clean cases. **Preserve ordinals exactly**: `ShownTab` = `BibleTab, CommentaryTab, DictionaryTab, DevotionalTab, DownloadsTab, PreferencesTab` (the two dead placeholders are persisted in `NSUserDefaults` — do not renumber). Also `ShownMultiListTab`, `PSSearchType`, `PSSearchRange`, `RotationPosition`.
- **`Defaults*` keys / font names / tab titles** (~50 plain `@"literal"` defines) — these import into Swift as global `String` constants when left in the bridging-header'd `globals.h`; additionally mirror them in a Swift `enum Defaults` (caseless namespace of `static let`) for ergonomics. Wire strings unchanged.
- **`Notification*` names** (~25) — Swift `extension Notification.Name` with `rawValue` equal to the existing `@"..."` strings so ObjC and Swift observers/posters interoperate during the mixed phase. `SendNotifyModulesChanged(X)` is a statement macro with no Swift analogue → a Swift `func` (or inline `NotificationCenter.default.post(...)`).
- **`GetBoolPrefForMod` / `GetStringPrefForMod` / `GetIntegerPrefForMod` / `SetBoolPrefForMod` / `SetObjectPrefForMod` / `SetIntegerPrefForMod` / `RemovePrefForMod`** — function-like macros that build the composite key `"<Pref>_<Mod>"` via `[NSString stringWithFormat:@"%@_%@", Pref, Mod]`. Port to **one** canonical `UserDefaults` extension reproducing the `%@_%@` format exactly (e.g. `func psBool(_ pref:String, forModule mod:String) -> Bool`). Have ObjC and Swift call the same implementation to prevent format drift.
- **`DEFAULT_*_PATH`** — these are expression macros that re-run `NSSearchPathForDirectoriesInDomains` on **every** expansion. Port as **computed** `static var` properties (never captured `let`s). Preserve the domain split exactly: `DEFAULT_MODULE_PATH` / `DEFAULT_BUILTIN_MODULE_PATH` / `DEFAULT_BOOKMARKS_PATH` under `NSDocumentDirectory`; `DEFAULT_MODULE_PATH_OLD` / `DEFAULT_APPSUPPORT_PATH` / `DEFAULT_INSTALLER_PATH` under `NSCachesDirectory`; `DEFAULT_MMM_PATH` under `NSTemporaryDirectory`. Preserve trailing-slash and `Built-in/` suffix conventions — the Documents-vs-Caches distinction drives the one-time module migration and the iCloud-backup skip attribute.
- **`userDefaults`** → `UserDefaults.standard` (no port). **`defSwordManager`** → leave OUT of the Swift constants and OUT of `PSConstants.h`: it expands to `[SwordManager defaultManager]` and `SwordManager.h` leaks C++. Swift reaches the manager only through the clean facade (after 0e).
- **`DLog`/`ALog`** live in the `.pch`, invisible to Swift → add a Swift `func dlog(...)` guarded by `#if DEBUG`.

ObjC keeps using `globals.h` unchanged during the mixed phase; treat `globals.h` (or `PSConstants.h` it includes) as the single source of truth for raw strings, with the Swift layer mirroring values. This is intentional dual-maintenance until ObjC is gone.

### 0c. Add a minimal XCTest unit-test target (adopted)

**Assumption adopted: the test target is added.** It is the only automated guard against silent user-data corruption, and the marginal cost (one target + a handful of round-trip tests) is small against a 25k-line migration. There is no test target today and the project ships in three configs with different bundle IDs. Add a Unit Test target via Xcode MCP, hosting it on the app target, and write round-trip tests that lock the **load-bearing persisted formats** before any model ports:

- `PSHistoryItem` array-of-arrays `[ref, scroll, mod, NSDate]` (used in both `NSUserDefaults` under `PSHistoryName=@"bibleHistory"` and `NSUbiquitousKeyValueStore`), 100-entry cap (`PSHistoryMaxEntries`).
- `PSBookmark` / `PSBookmarkFolder` positional plist array schema (folder marker at index 3, rgb hex at 4, children at 5) on disk under `DEFAULT_BOOKMARKS_PATH`.
- `PSSearchHistoryItem` `searchHistoryItemArray` ordering.
- The `%@_%@` per-module pref key format.

**Test-target build wiring (settled):** make it a unit-test bundle **hosted by the `PocketSword` app target** (`TEST_HOST` + `BUNDLE_LOADER` set to the app) and use `@testable import PocketSword` — this gives the tests the app's already-built module (Swift + the bridged ObjC/Obj-C++ symbols) without re-declaring `SWIFT_OBJC_BRIDGING_HEADER` on the test target, and sidesteps recompiling the SWORD/C++ sources into the bundle. Give the test target `SWIFT_VERSION=5.0` to match. The three app configs carry different bundle IDs but the **module name is `PocketSword` in all three**, so one test target validates across configs. Confirm it builds & runs (`mcp__xcode__RunAllTests`) in Debug before any model port, and at least once in Release/Distribution per the per-wave loop.

### 0d. Migrate `PSResizing` (first real Swift file, pure UIKit leaf)

`PSResizing` (**verified in-degree 27**, the highest in the app) is stateless UIKit geometry/orientation/window helpers with no app-internal dependency — a dependency-graph leaf despite huge fan-in. Porting it early gives every later Swift file a Swift-native helper and **exercises the importer-rewrite procedure (§2A) at its largest scale on day one.** Of its 27 importers, exactly one is a *header* (`PocketSwordAppDelegate.h`) — handle it per the §2A header rule (it uses `PSResizing` only as a type reference, so a `@class` forward declaration suffices and `PocketSwordAppDelegate` need not migrate yet). The other 26 are `.m`/`.mm` bodies — each gets `#import "PSResizing.h"` swapped for `#import "PocketSword-Swift.h"`. (Mechanics + verification otherwise identical to a Wave-1 leaf; included in Wave 0 because it has zero prerequisites beyond 0a.)

### 0e. Sanitize the C++-leaking headers (the de-taint pass)

For each header below: keep a **clean Foundation-only public `.h`** (everything is already expressible as `NSString`/`NSArray`/`NSInteger`/`BOOL`); move the `#include <...>`, `using sword::...;`, C++ ivars, and C++-typed methods into a **per-class internal `SwordX+Cpp.h`** imported only by `.mm` files. Per-class `+Cpp.h` (not bare `.mm` class extensions) is required because cross-`.mm` callers need the C++ accessors visible (`PSSearchEngine.mm` uses `My_SWDYNAMIC_CAST` + `[mod swModule]`; `PSModuleController.mm` casts `[primaryBible swModule]->getKey()`; subclass `.mm`s reach the inherited `sk` ivar).

| Header | What stays public (clean) | What moves to internal `+Cpp.h` / `.mm` |
|---|---|---|
| `SwordManager.h` | NSObject props (`modules`, `moduleListByType`, `modulesPath`, `managerLock`, `temporaryManager`, `moduleTypes`); Foundation methods (`managerWithPath:`, `defaultManager`, `moduleWithName:`, `listModules`, `moduleNames`, `modulesForFeature:`/`Type:`, `setGlobalOption:value:`, `setCipherKey:forModuleNamed:`, `installModulesFromPath:`, `isModuleInstalled:`, `initLocale`, `moduleCategoryAllowed:`); all `SWMOD_*`/`SW_OPTION_*` `NSString` consts | `#include <swmgr.h>` etc.; `using sword::SWModule;`; `sword::SWMgr *swManager` ivar; `-initWithSWMgr:`, `-getSWModuleWithName:`, `-swManager` |
| `SwordModule.h` | `ModuleType`/`ModuleCategory`/`TextPullType` enums; `SwordModuleAccess` protocol; all `NSString`/`NSArray`/`BOOL`/`NSInteger`/`long` methods (`renderedText`, `strippedText`, `search:withScope:`, `configEntryForKey:`, `hasFeature:`, `getChapter:withExtraJS:`, `setToNextChapter`, …); `ATTRTYPE_*`/`SW_OUTPUT_*` consts | `#include <swtext.h>`/`<versekey.h>`/`<regex.h>`; `using sword::SWModule;`; `My_SWDYNAMIC_CAST` macro (→ shared `SwordModule+Cpp.h`); `sword::SWModule *swModule` ivar; `-initWithSWModule:`, `-swModule` |
| `SwordBook.h` | `name`/`osisName`/`shortName` (`NSString`), `chapters`/`verses:` (`NSInteger`) | fix the **unguarded** `#import <versificationmgr.h>`; `const sword::VersificationMgr::Book *book` ivar; `-initWithBook:` |
| `SwordDictionary.h` | `allKeys`, `entryForKey:`, `fullRefName:`, `keysCached`/`keysLoaded`, `releaseKeys`, `removeCache` | `-initWithSWModule:swordManager:` (the only leak) |
| `SwordKey.h` | `swordKey`/`swordKeyWithRef:`/`initWithRef:`/`clone`/`setPersist:`/`persist`/`error`/`setPosition:`/`decrement`/`increment`/`keyText`/`setKeyText:`; `created` BOOL may stay | `#include <swkey.h>`; `sword::SWKey *sk` ivar; `-swordKeyWithSWKey:`, `-initWithSWKey:`, `-swKey`. (Declare `sk` in `SwordKey+Cpp.h` imported by all three key `.mm`s so subclasses can cast it.) |
| `SwordVerseKey.h` | full Foundation API (`verseKeyWithRef:v11n:`, `verseKeyForOT/NT/WholeBible/WholeBook:`, index/testament/book/chapter/verse getters+setters, `bookName`/`osisBookName`/`osisRef`/`versification`) | `#include <versekey.h>`; `-verseKeyWithSWVerseKey:`, `-initWithSWVerseKey:`, `-swVerseKey` |
| `SwordListKey.h` | `listKeyWithRef:*` factories, `parse`/`parseWithHeaders`, `verseEnumerator`, `numberOfVerses`/`count`/`refForElement:`/`containsKey:` | `#include <swkey.h>`/`<listkey.h>`/`<versekey.h>`; `-listKeyWithSWListKey:`, `-initWithSWListKey:`, `-swListKey` |

Also in 0e, de-taint the two hub headers (this is what unblocks the VC tier):

- **`PSTabBarControllerDelegate.h`** — remove `#include <swmgr.h>`/`<swmodule.h>`/`<markupfiltmgr.h>`/`<filemgr.h>`/`<localemgr.h>`. The only direct C++ use (`sword::LocaleMgr::getSystemLocaleMgr()` in `updateViewWithSelectedBookName:`) is internal to the `.mm` — move it behind a new Foundation-only helper.
- **`PSModuleController.h`** — change `SwordModule*`/`SwordDictionary*`/`SwordManager*` properties so the header no longer `#import`s `SwordModule.h`. Refactor the direct C++ call sites in `PSModuleController.mm` behind new Foundation-only ObjC methods on `SwordModule`/`SwordVerseKey` (LocaleMgr; `getKey()` casts/setText/setChapter; `new sword::InstallMgr`/`SWMgr`). After this, the bridging header may import the clean `SwordManager.h`/`SwordModule.h` facades, and the `.mm` keeps importing the `+Cpp.h` internals.

Also in 0e: `VerseEnumerator` is already `.mm` on disk — **do not chase a `.m`→`.mm` rename**. Just ensure its `swListKey` accessor remains visible via the shared `SwordListKey+Cpp.h` after the split, in the same PR. Reclassify the three "false leaf" selector/type files (`PSChapterSelectorController`, `PSVerseSelectorController`, `PSModuleType`) as mid-tier — their **public headers** `#import SwordBook.h`/`SwordModule.h`, so they become Swift-eligible only after 0e.

---

## 2A. Mixed-language interop mechanics (read before every wave)

This section is the operational core. Migrating a file to Swift is never "rewrite the body" — it is "rewrite the body **and** repair every Obj-C site that referenced the deleted Obj-C header." Skipping this turns every leaf PR red. There are three rules.

### Rule 1 — when a leaf goes Swift, rewrite its importers (the per-PR procedure)

When you replace `Foo.{h,m}` with `Foo.swift` (a `@objc final class Foo : NSObject`) and `XcodeRM` the old `Foo.h`, **every surviving Obj-C file that did `#import "Foo.h"` no longer compiles.** The mechanical step, in the *same PR*:

- **Importer is an implementation file (`.m` / `.mm`):** replace `#import "Foo.h"` with `#import "PocketSword-Swift.h"` (the generated Swift→ObjC header). This is always safe in a `.m`/`.mm` body. If the file already imports `PocketSword-Swift.h`, just delete the `#import "Foo.h"` line.
- **Importer is a header (`.h`):** see Rule 2 — you may **not** import `PocketSword-Swift.h` from a public Obj-C header.

Find the blast radius before you start the PR:
```
grep -rln '#import *"Foo.h"' Classes/*.h Classes/*.m Classes/*.mm
```
The PR is "rewrite `Foo` + touch all N importers" as one mergeable, green unit. Known large cases (verified): **`PSResizing.h` → 27 importers** (handled in Wave 0d), `PSWebView.h` is imported by `PSModuleViewController.h` (a header — Rule 2/3), `PSBookmark.h` by `PSBookmarkAddViewController.h` (a header — Rule 3).

### Rule 2 — never import `PocketSword-Swift.h` from a public Obj-C header

`PocketSword-Swift.h` is generated into DerivedData and is **not available when Xcode parses public/project headers** during the bridging-header and module-build phases; importing it from a `.h` causes "file not found" or include cycles. So when the importer of a now-Swift type is itself a header:

- **If the header only needs the type as a pointer/reference** (property, parameter, ivar of pointer type, delegate var) → replace `#import "Foo.h"` with a **forward declaration**: `@class Foo;` (or `@protocol FooDelegate;`). The actual `PocketSword-Swift.h` import then lives in that header's `.m`/`.mm` body. *Example:* `PocketSwordAppDelegate.h` references `PSResizing` only as a type → `@class PSResizing;` in the header, `#import "PocketSword-Swift.h"` in `PocketSwordAppDelegate.mm`.
- **If the header needs the full type** (it subclasses the Swift class, conforms to a Swift `@objc` protocol, or embeds a value-type ivar) → a forward declaration is insufficient. You must **migrate the importing class in the same PR** (it becomes Swift too, so the dependency moves inside the Swift module and no `-Swift.h` import is needed). This is what forces Rule 3.

### Rule 3 — migrate Obj-C inheritance chains as a single atomic PR

A Swift base class with Obj-C subclasses is a build trap: the still-Obj-C subclass *header* must make the Swift base visible (`@interface PSBookmark : PSBookmarkObject`), but per Rule 2 it cannot import `PocketSword-Swift.h`, and a `@class` forward declaration cannot satisfy `@interface X : <base>`. Therefore **the entire inheritance chain migrates in one PR.**

Verified chain (Wave 1): `PSBookmarkObject` (base, `: NSObject`) ← `PSBookmark : PSBookmarkObject` ← `PSBookmarkFolder : PSBookmarkObject` ← `PSBookmarks : PSBookmarkFolder`, with header `#import` edges `PSBookmark.h→PSBookmarkObject.h`, `PSBookmarkFolder.h→PSBookmarkObject.h`, `PSBookmarks.h→PSBookmarkFolder.h`, and the consumer `PSBookmarkAddViewController.h→PSBookmark.h`. The plan therefore migrates **`PSBookmarkObject` + `PSBookmark` + `PSBookmarkFolder` + `PSBookmarks` together in one PR**, not bottom-up file-by-file. `PSBookmarkAddViewController` (Wave 2) imports `PSBookmark.h` from its header but only as a property type → it can stay Obj-C using `@class PSBookmark;` once the chain is Swift, deferring its own migration.

**General test before sequencing any file:** run the importer grep; if any importer is a header that *subclasses, conforms-to, or value-embeds* the type, fold that importer into the same PR; otherwise a `@class` forward-decl (Rule 2) keeps it deferrable.

---

## 3. Dependency-ordered WAVE PLAN

**Per-wave verification loop (Simulator is the real gate; Wave-0 unit target guards persisted formats):**
1. `mcp__xcode__BuildProject` Debug / iphonesimulator on `tabIdentifier windowtab1`.
2. On failure → `mcp__xcode__GetBuildLog` + `mcp__xcode__XcodeListNavigatorIssues` to read swiftc/clang errors → fix → rebuild. Watch specifically for the Rule-1/2/3 failure signature: "cannot find type X in scope" / "unknown type name 'X'" in an Obj-C importer you forgot to repair.
3. Rebuild **all three** configs at least once per wave (wholemodule Release/Distribution surfaces errors that singlefile Debug hides).
4. Run the Wave-0 unit tests (`RunAllTests`) for any wave touching a persisted model.
5. Simulator smoke test of the touched feature: launch → SWORD init on bg thread → tab bar appears → exercise the migrated screen/model.

**Per-wave rollback:** each PR is one mergeable unit; revert the PR. Because `NSNotificationCenter` coupling is loose (string-keyed) and Swift/ObjC observers share identical name rawValues, a reverted Swift VC leaves the ObjC graph functional with no type dependency to unwind.

**Branch & PR workflow (adopted):** all migration work lands on a dedicated `swift-migration` branch cut from `main` and **stays there** — this branch is **never merged back into `main`** by this effort; the owner handles integration into `main` separately, later. Each PR-unit below (`0a`…`0e`, then `1.1`, `1.2`, each Wave 2–4 file/cluster) is its own commit on `swift-migration`, green in all three configs before moving on. The branch itself is the always-green deliverable; `main` is left untouched throughout. **Cadence (adopted): one commit per leaf or per atomic unit** (an atomic unit = an inheritance/conformance chain per §2A Rule 3) — do **not** batch unrelated leaves, so a red build localizes to one file's importer fan-out.

### Wave 1 — Bookmarks proving slice + value leaves
- **Goal:** prove the end-to-end mixed-language model+UI pattern on the most self-contained island, then port the pure value types.
- **PR 1.1 — bookmark inheritance chain (ATOMIC, per §2A Rule 3):** `PSBookmarkObject` + `PSBookmark` + `PSBookmarkFolder` + `PSBookmarks` migrated together in one PR. (`PSBookmarkTableViewCell` can ride along or be its own follow-up — it's a `UITableViewCell`, not part of the chain.) Repair importers: `PSBookmarkAddViewController.h` → `@class PSBookmark;` (Rule 2); all `.mm` importers → `#import "PocketSword-Swift.h"`. Before merging, extract `PSModuleController`'s `createRefString:` / `getCurrentBibleRef` ref helpers the store needs into the Swift constants/helper layer (eliminate the thin SWORD seams rather than wrap them).
- **PR 1.2 — value leaves (each its own PR, run the importer grep first):** `PSSearchResult`, `PSSearchHistoryItem`, `PSHistoryItem`, `PSSearchQuery`, `SearchWebView` (WKWebView extension; keep `SearchWebView.js` resource).
- **Mechanical steps:** rewrite each as a Swift `final class : NSObject` (or value type) exposing `@objc` members where ObjC callers exist; preserve positional array (de)serialization **byte-for-byte** (`array`/`searchHistoryItemArray`/`parseArray:`); keep `PSSearchQuery` diacritic-folding byte-compatible with `PSSearchEngine`'s index. Replace via `XcodeWrite`; remove old `.m`/`.mm`/`.h` via `XcodeRM`; repair importers per §2A.
- **Verification:** add/remove a bookmark and a folder, restart app (plist round-trip), confirm history list + iCloud array, run a search (query builder unchanged). Run Wave-0 unit tests.

### Wave 2 — clean-header leaf view controllers
- **Goal:** migrate VCs whose headers are clean (or clean after 0e) and whose only consumer is a hub.
- **Files (each: importer-grep → choose Rule-2 forward-decl vs same-PR fold):** `PSInfoPopupViewController` (zero C++, only consumer is the coordinator), `PSDictionaryOverlayViewController`, `PSBookmarkFolderColourSelectorViewController`, `PSBookmarkFolderAddViewController`, `PSBookmarkAddViewController` (now trivial — its only chain dependency became Swift in Wave 1), `PSChapterSelectorController` + `PSVerseSelectorController` (eligible post-`SwordBook` facade), `PSModuleType` (post-`SwordModule` facade), `PSAboutScreenController` (drop the stale device-name table; `MFMailCompose`).
- **`PSLanguageCode.m` (8,116 lines):** do **not** hand-port. It is one static ~8,040-row `[code, name]` lookup built in `+initLookupTable`, queried only as a fallback after `NSLocale`. Externalize the table to a bundled `codes.plist`/`codes.json` resource loaded lazily, and keep ~40 lines of lookup + `-Cyrl`/`-Latn` script-suffix logic in a Swift type. Migrate alongside `PSModuleType` (its consumer).
- **Verification:** open Strong's/footnote/xref popups, the ref selector (book→chapter→verse), the module-by-language list, the About screen. Confirm `Notification*` posts cross the ObjC/Swift boundary.

### Wave 3 — search / dictionary / prefs mid-tier
- **Goal:** migrate the controllers that call the now-faceted bridge via Foundation-only methods.
- **Files:** `PSSearchEngine` query-side logic (the FTS5/sqlite3 path is C-API + Foundation and Swift-portable; the index-**build** path stays Obj-C++ in `.mm`), `PSSearchIndexBuilder`, `PSModuleSearchController` (carry the prior search-crash fix forward — snapshot state + generation counter; migrate carefully), `PSModuleSelectorController`, `PSModulePreferencesController`, `PSPreferencesModuleSelectorTableViewController`, `PSPreferencesFontTableViewController`, `PSBasePreferencesController`, `PSPreferencesController`, `PSDictionaryEntryViewController`, `PSDictionaryViewController`, `PSBookmarksNavigatorController`, `PSRefSelectorController`, `PSHistoryController` (port KVS to `NSUbiquitousKeyValueStore.default`; preserve `[ref,scroll,mod,date]` schema, 100-entry cap, recursive merge/dedup).
- **Verification:** build an index with progress, run live FTS5 search with scope bar + highlights, open a dictionary entry, change per-module + font prefs, exercise history iCloud reconciliation.

### Wave 4 — hubs LAST
- **Goal:** convert the central coordination after everything beneath is Swift-or-faceted.
- **Files (order):** `PSModuleController` (its `.h` is clean post-0e; the `↔PSTabBarControllerDelegate` coupling lives in the `.mm`, so treat it as soft, not a blocking prerequisite — break it with a protocol or notification only if the compiler demands), the render-path cluster `PSWebView` → `PSModuleViewController` → `PSBibleViewController` / `PSCommentaryViewController` (migrate this cluster as one chain per §2A Rule 3 — `PSModuleViewController.h` imports `PSWebView.h` and is the base of the two VCs; keep `PSWebViewDelegate` `@objc`), `PSLaunchViewController`, `PocketSwordSceneDelegate`, `PocketSwordAppDelegate` + `main.m` (→ `@main`), and finally `PSTabBarControllerDelegate` (13 `NSNotificationCenter` observers, multiple delegate protocols, WKNavigation routing).
- **Verification:** full cold-launch smoke (bg SWORD init → root swap → tab bar), `sword://` URL replay, verse tap → Strong's/morph/footnote/xref/dict routing, primary-module switches, fullscreen, all three configs.

### Never migrated (permanent Obj-C++)
`SwordManager`, `SwordModule`, `SwordBook`, `SwordDictionary`, `SwordKey`, `SwordVerseKey`, `SwordListKey`, `VerseEnumerator`, `utils.h`, and the `.mm` index-build path of `PSSearchEngine`. Only their **headers** changed (Wave 0). `SwordModuleTextEntry` stays ObjC as the shared DTO. The `.pch`, `c++0x`, `-licucore`, and the C/C++ Sources phase are untouched throughout.

### Localization
Unaffected. `NSLocalizedString` maps 1:1 to Swift `NSLocalizedString` / `String(localized:)` reading the same `Localizable.strings`. No `.xib` exists; the CLAUDE.md XIB scripts are dead — flag for docs cleanup, do not act unless asked.

---

## 4. Risk register

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **Persisted-format corruption** — Swift rewrites of `PSBookmark`/`PSHistoryItem`/`PSSearchHistoryItem` change positional plist/KVS array layouts or the `%@_%@` pref-key format, silently destroying user data and iCloud sync. | High | Wave-0 XCTest target locks every round-trip before any model ports; preserve element ordering byte-for-byte; keep wire key strings (not macro names) verbatim. |
| R2 | **No test target today** — only Simulator smoke testing guards a migration of this size. | High | **Add the XCTest target in Wave 0c** (also a decision). Build all 3 configs per wave; scripted Simulator smoke per wave. |
| R3 | **C++ leak regression** — a future header edit re-adds `#include <sword…>`/`sword::`/`using` to a sanitized public `.h` or the bridging header, breaking the Swift build cryptically. | High | Keep all C++ in per-class `+Cpp.h` imported only by `.mm`; never import `Sword*.h` C++ headers or the `.pch` into the bridging header; add a pre-merge grep guard (`grep -rn 'sword::\|#include <[a-z].*\.h>' <public headers + bridging header>`). |
| R4 | **Hub-header taint underestimated** — `PSTabBarControllerDelegate.h` and `PSModuleController.h` leak C++ themselves; missing this blocks the entire VC tier. | High | De-taint both in Wave 0e (move LocaleMgr/`getKey()` use into the `.mm`; retype properties). |
| R5 | **Broken importers when a leaf goes Swift** (§2A Rule 1) — deleting `Foo.h` breaks every `#import "Foo.h"`; symptom "cannot find type Foo". Blast radius can be large (`PSResizing.h`: 27 importers). | High | Per-PR procedure: importer-grep first; `.m`/`.mm` → import `PocketSword-Swift.h`; ship importer fixes in the same PR; build all configs. |
| R6 | **`-Swift.h` imported from a public Obj-C header** (§2A Rule 2) — causes file-not-found / include cycles. | High | Never import `PocketSword-Swift.h` from a `.h`; use `@class`/`@protocol` forward decls in headers, put the real import in the `.m`/`.mm`. |
| R7 | **Inheritance/conformance chain split across languages** (§2A Rule 3) — a Swift base with Obj-C subclass headers cannot compile (`@interface Sub : SwiftBase` needs the full type, forbidden in a header). | High | Migrate inheritance chains atomically in one PR. Verified case: the 4-class bookmark chain (Wave 1 PR 1.1) and the `PSWebView`→`PSModuleViewController`→Bible/Commentary cluster (Wave 4). |
| R8 | **`.pch` / bridging-header interplay** — engineers assume Swift inherits `.pch` imports/macros (`DLog`, SWORD defines) and get "cannot find in scope". | Med | Documented: Swift ignores `GCC_PREFIX_HEADER`; every Swift file imports Foundation/UIKit and uses the Swift `dlog`/`AppConstants` shims. |
| R9 | **NSNotification coordination during partial migration** — Swift and ObjC observers must agree on raw string values or events silently stop flowing. | Med | Define `Notification.Name` rawValues identical to the existing `@"..."` literals; keep one source of truth (`globals.h`/`PSConstants.h`). |
| R10 | **Files added on filesystem, not project model** — `.swift` written with a raw `Write` never compiles (not in `project.pbxproj`); symptom is "cannot find type" with no compile of the file. | Med | All file ops via Xcode MCP (`XcodeWrite`/`XcodeMV`/`XcodeRM`/`XcodeMakeDir`). |
| R11 | **Mixed-language `@objc` exposure gaps** — Swift types ObjC must call need `@objc`/`NSObject` subclassing; Swift-only types (enums with associated values, structs) are invisible to ObjC. | Med | Keep boundary types `@objc final class : NSObject`; keep delegate protocols (`PSWebViewDelegate`, `PSSearchIndexBuilderDelegate`, `PSDictionaryViewControllerDelegate`, etc.) `@objc` until both sides are Swift. |
| R12 | **Whole-module vs single-file divergence** — Release/Distribution (`wholemodule`) surface errors Debug (`singlefile`) hides. | Med | Build all 3 configs every wave; bundle-ID differences don't affect the module name (`PocketSword`), so the generated header name is stable. |
| R13 | **Search-crash regression** — `PSModuleSearchController` had a `nonatomic-strong` race fixed locally (snapshot + generation counter). | Med | Carry the existing fix into the Swift port verbatim; smoke-test typing-while-searching. |
| R14 | **`PSModuleController`↔coordinator import cycle** treated as a hard blocker when it is `.mm`-local. | Low | Cycle lives in the `.mm`, not the (post-0e) header; break with protocol/notification only if the compiler forces it — do not gate Wave 4 on it. |
| R15 | **`PSLanguageCode` 8k-line hand-port** wastes effort and risks transcription errors. | Low | Externalize to a bundled resource + ~40-line Swift lookup; it's fallback-only data. |

---

## 5. Per-file appendix (file → wave → Swift readiness)

| File | Wave | Swift readiness / interop note |
|---|---|---|
| `PocketSword.xcodeproj/project.pbxproj` | 0a | build-config edits via MCP |
| `misc/PocketSword-Bridging-Header.h` (new) | 0a | hand-written, clean-headers only |
| `misc/PocketSword_Prefix.pch` | — | keep-objcpp; Swift ignores it |
| `Classes/globals.h` | 0b | hub → Swift `AppConstants` + sanitized `PSConstants.h` |
| (new XCTest target) | 0c | locks persisted formats |
| `Classes/PSResizing.{h,m}` | 0d | leaf → Swift; **27 importers** (1 header → `@class`, 26 bodies → `-Swift.h`) |
| `Classes/SwordManager.{h,mm}` | 0e (header) | keep-objcpp; header split |
| `Classes/SwordModule.{h,mm}` | 0e (header) | keep-objcpp; header split + `+Cpp.h` |
| `Classes/SwordBook.{h,mm}` | 0e (header) | keep-objcpp; fix unguarded include |
| `Classes/SwordDictionary.{h,mm}` | 0e (header) | keep-objcpp |
| `Classes/SwordKey.{h,mm}` | 0e (header) | keep-objcpp; `sk` → internal header |
| `Classes/SwordVerseKey.{h,mm}` | 0e (header) | keep-objcpp |
| `Classes/SwordListKey.{h,mm}` | 0e (header) | keep-objcpp |
| `Classes/VerseEnumerator.{h,mm}` | 0e | keep-objcpp (already `.mm`) |
| `Classes/SwordModuleTextEntry.{h,m}` | 0e | clean DTO; stays ObjC |
| `Classes/utils.h` | — | keep-objcpp |
| `Classes/PSTabBarControllerDelegate.h` | 0e (de-taint) / mm Wave 4 | hub |
| `Classes/PSModuleController.h` | 0e (de-taint) / mm Wave 4 | hub |
| `Classes/PSBookmarkObject.{h,m}` | 1 (PR 1.1 atomic) | chain base → Swift |
| `Classes/PSBookmark.{h,m}` | 1 (PR 1.1 atomic) | chain → Swift (preserve array order) |
| `Classes/PSBookmarkFolder.{h,m}` | 1 (PR 1.1 atomic) | chain → Swift |
| `Classes/PSBookmarks.{h,mm}` | 1 (PR 1.1 atomic) | chain top → Swift after ref-helper extract |
| `Classes/PSBookmarkTableViewCell.{h,m}` | 1 | leaf → Swift |
| `Classes/PSSearchResult.{h,m}` | 1 | leaf → Swift |
| `Classes/PSSearchHistoryItem.{h,m}` | 1 | leaf → Swift (preserve array order) |
| `Classes/PSHistoryItem.{h,mm}` | 1 | leaf → Swift (preserve array order) |
| `Classes/PSSearchQuery.{h,mm}` | 1 | leaf → Swift (folding byte-stable) |
| `Classes/SearchWebView.{h,m}` | 1 | leaf → WKWebView extension |
| `Classes/PSInfoPopupViewController.{h,mm}` | 2 | leaf → Swift |
| `Classes/PSDictionaryOverlayViewController.{h,m}` | 2 | mid → Swift |
| `Classes/PSBookmarkFolderColourSelectorViewController.{h,m}` | 2 | leaf → Swift |
| `Classes/PSBookmarkFolderAddViewController.{h,m}` | 2 | mid → Swift |
| `Classes/PSBookmarkAddViewController.{h,mm}` | 2 | mid → Swift (`@class PSBookmark;` after Wave 1) |
| `Classes/PSChapterSelectorController.{h,mm}` | 2 | mid (post-`SwordBook` facade) |
| `Classes/PSVerseSelectorController.{h,mm}` | 2 | mid (post-`SwordBook` facade) |
| `Classes/PSModuleType.{h,mm}` | 2 | mid (post-`SwordModule` facade) |
| `Classes/PSLanguageCode.{h,m}` | 2 | leaf → Swift + externalized data resource |
| `Classes/PSAboutScreenController.{h,mm}` | 2 | leaf → Swift |
| `Classes/PSSearchEngine.{h,mm}` | 3 | query-side Swift; build path keep-objcpp |
| `Classes/PSSearchIndexBuilder.{h,mm}` | 3 | mid → Swift |
| `Classes/PSModuleSearchController.{h,mm}` | 3 | mid → Swift (carry crash fix) |
| `Classes/PSModuleSelectorController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSModulePreferencesController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSPreferencesModuleSelectorTableViewController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSPreferencesFontTableViewController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSBasePreferencesController.{h,m}` | 3 | mid → Swift |
| `Classes/PSPreferencesController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSDictionaryEntryViewController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSDictionaryViewController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSBookmarksNavigatorController.{h,mm}` | 3 | mid → Swift |
| `Classes/PSHistoryController.{h,mm}` | 3 | mid → Swift (KVS port, preserve schema) |
| `Classes/PSRefSelectorController.{h,mm}` | 3 | mid (post-`SwordBook` facade) |
| `Classes/PSModuleController.{mm}` | 4 | hub → Swift last among app-model |
| `Classes/PSWebView.{h,mm}` | 4 | hub render-path (atomic with VC base) |
| `Classes/PSModuleViewController.{h,mm}` | 4 | hub render-path base (imports `PSWebView.h`) |
| `Classes/PSBibleViewController.{h,mm}` | 4 | hub render-path |
| `Classes/PSCommentaryViewController.{h,mm}` | 4 | hub render-path |
| `Classes/PSLaunchViewController.{h,mm}` | 4 | hub |
| `Classes/PocketSwordSceneDelegate.{h,mm}` | 4 | hub |
| `Classes/PocketSwordAppDelegate.{h,mm}` | 4 | hub (`@class PSResizing;` from Wave 0d) |
| `Classes/main.m` | 4 | leaf → `@main` |
| `Classes/PSTabBarControllerDelegate.mm` | 4 | central coordinator — last |
| `*.lproj/Localizable.strings` (17) | — | unaffected |
| `PocketSword/LaunchScreen.storyboard` | — | unaffected |

---

## 6. Assumptions adopted (defaults applied — override any of these)

These cannot be inferred from the code, so the plan adopts the most defensible default for each and bakes it in at the cited location. Each is a one-line override if you disagree.

| # | Decision | **Adopted default** | Where it's baked in | Override impact |
|---|---|---|---|---|
| 1 | Swift language mode | **Swift 5** (`SWIFT_VERSION=5.0`, `SWIFT_STRICT_CONCURRENCY=minimal`). Swift 6 strict concurrency is a second migration layered on the bg-thread SWORD init + notification web; defer until the app is fully Swift. | §2 0a settings table | Choosing Swift 6 adds `Sendable`/actor annotations to every boundary type and the SWORD init path — large scope increase. |
| 2 | Add XCTest target | **Yes** — app-hosted unit-test bundle, `@testable import PocketSword`, locks persisted formats before any model port. | §2 0c | Declining raises R1 (data corruption) and R2 (no automated gate) to unmitigated; Simulator-only becomes the sole guard. |
| 3 | Cadence | **One PR per leaf / per atomic unit** (chains stay atomic per §2A Rule 3); all 3 configs built per wave. | §3 verification "Branch & PR workflow" | Batching leaves trades localizable red builds for fewer PRs. |
| 4 | End state | **App-layer Swift over a permanent Obj-C++ SWORD bridge** (sanitize headers only). A full Swift/C++-interop rewrite of the SWORD bridge is rejected as non-viable (§1). | §1 + "Never migrated" list | Reversing this means evaluating `cxxInteroperabilityMode` against SWORD's C++11 surface — a separate, high-risk research effort. |
| 5 | Branch / PR flow | **Dedicated `swift-migration` branch off `main`; one commit per PR-unit; never merged back here** — the owner integrates into `main` separately, later. `main` is left untouched. | §3 "Branch & PR workflow" | Different team conventions (trunk-based, per-wave branches) only change the mechanics, not the wave content. |

**These no longer gate Wave 0.** Wave 0a (enable Swift + bridging header) can begin immediately under the adopted defaults; flag any override before the affected step runs.
