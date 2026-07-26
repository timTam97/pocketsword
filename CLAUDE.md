# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PocketSword is a GPL'd iOS Bible-study app built on the CrossWire SWORD C++ API (https://www.crosswire.org/sword/). This repo is a fork of `bitbucket.org/niccarter/pocketsword` updated for new iPhones and iOS 26.

The app is a **mixed Swift / Objective-C++ target**. The app layer under `Classes/` was migrated to Swift (see `SWIFT_MIGRATION_PLAN.md`); the only remaining Objective-C(++) is the **permanent SWORD bridge** (`Classes/Sword*.{h,mm}`, `PSSearchEngine.{h,mm}`, `VerseEnumerator.{h,mm}`) plus one clean DTO (`SwordModuleTextEntry.m`). **Swift never touches C++** — it talks to SWORD only through the Foundation-only Obj-C facades. There is no CocoaPods/SPM; all third-party code is vendored under `externals/`. The UI is programmatic UIKit — there are **no XIBs** and only a `LaunchScreen.storyboard`.

## Build / run

- Open `PocketSword.xcodeproj` in Xcode and build the shared `PocketSword` scheme (there is a second scheme `PocketSword1`). There is no `.xcworkspace` and no package manager step.
- CLI build: `xcodebuild -project PocketSword.xcodeproj -scheme PocketSword -configuration Debug -sdk iphonesimulator build` (swap to `-sdk iphoneos` and `-configuration Release`/`Distribution` as needed). You may need `CODE_SIGNING_ALLOWED=NO` for simulator builds without a dev team.
- **Tests exist.** The `PocketSwordTests` XCTest bundle (app-hosted, `@testable import PocketSword`) has 28 tests: 18 in `Classes/PersistedFormatTests.swift` plus 10 in `Classes/PSVoiceRefParserTests.swift`. Run with `xcodebuild -project PocketSword.xcodeproj -scheme PocketSword -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`. The persisted-format tests **lock the byte-exact persisted formats** (history / bookmark / search-history serialization and the per-module pref-key format) and encode existing read/write quirks deliberately — a change that flips one red means you altered a persisted format and will corrupt user data. Do not "fix" a test to make it pass; fix the code.
- Configurations: `Debug`, `Release`, `Distribution`. Each has a **different** `PRODUCT_BUNDLE_IDENTIFIER` (`org.timsams.PocketSword` / `org.timsam.PocketSword` / `org.Crosswire.PocketSword`) — do not assume they match.
- Deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, universal (`TARGETED_DEVICE_FAMILY = "1,2"`).

## SWORD / third-party build wiring (important)

The SWORD engine is compiled **from sources in-tree** (`externals/sword/src/…` with headers in `externals/sword/include`), not linked as a prebuilt framework. Compile-time knobs live in `misc/PocketSword_Prefix.pch` (`GCC_PREFIX_HEADER`), force-included into every Obj-C(++) translation unit (Swift ignores the prefix header):

- `CURLAVAILABLE` is intentionally **not** defined — the in-app module-download feature and `InstallMgr`'s CURL transports have been removed; their call sites compile to null-returning stubs. Do not re-enable CURL or reintroduce download UI without a deliberate design discussion.
- `EXCLUDEXZ`, `unix`, `__unix__` are set; `_ICU_`/`USELUCENE` are commented out.
- ZipArchive (`externals/ZipArchive`, with `minizip`) needs `HAVE_INTTYPES_H`, `HAVE_PKCRYPT`, `HAVE_STDINT_H`, `HAVE_WZAES`, `HAVE_ZLIB` — all set in the prefix.
- `HEADER_SEARCH_PATHS` still lists `externals/clucene/**` for historical reasons even though the folder is absent; leave it unless you are actively cleaning up.
- The build links `-licucore` (`OTHER_LDFLAGS`); C++ standard is `c++0x`; Obj-C ARC is on for the app target.
- `DLog(...)` is a `NSLog` wrapper that only fires in `DEBUG`; `ALog(...)` always fires (both defined in the pch, Obj-C only). Swift has mirror shims `dlog(...)` / `alog(...)` in `AppConstants.swift`. Prefer `DLog`/`dlog` for anything chatty.

## Swift ⇄ Obj-C++ interop mechanics (read before touching a header)

The migration's single load-bearing rule: **a Swift bridging header is parsed in Objective-C mode, not Obj-C++, so it can never see a `sword::` type.** The whole interop scheme exists to keep C++ out of anything Swift imports.

- **Clean facade + `+Cpp.h` split.** Each `Sword*.h` public header is Foundation-only (`@class` forwards, `NSString`/`id` signatures). All C++ — the `sword::SWModule *` ivars, `#include <lowercase.h>`, `using sword::`, dynamic-cast macros, C++-typed methods — lives in a sibling internal header `Sword*+Cpp.h` (e.g. `SwordModule+Cpp.h`) that is imported **only by `.mm` files**. When adding a method that takes/returns a C++ type, it goes in `+Cpp.h`, never the public header. Do not re-add `#include <sword…>` or `using sword::` to a public `Sword*.h`.
- **Bridging header** `misc/PocketSword-Bridging-Header.h` lists exactly the clean Obj-C facades Swift is allowed to see (the `Sword*.h` chain, `PSSearchEngine.h`, `SwordModuleTextEntry.h`, `MBProgressHUD.h`, `SSZipArchive.h`, `globals.h`, plus system umbrellas `MessageUI`/`WebKit` that the generated header needs at class-level). It is heavily commented with *why* each import is present — read those comments before editing; a wrong add re-taints the whole Swift import graph.
- **Generated header** `PocketSword-Swift.h` (`SWIFT_OBJC_INTERFACE_HEADER_NAME`) exposes `@objc` Swift classes back to the `.mm` files. Obj-C++ TUs under `c++0x` do **not** honour the generated header's `@import Foundation;`-style module imports, which is why the bridging header pre-imports system umbrellas.
- Swift classes that Obj-C must instantiate/reference are annotated `@objc(ClassName)` to keep the runtime name stable across the boundary.
- `SwordModuleTextEntry` (a clean `NSString`-only DTO) is the value type that actually crosses the boundary. `SWIFT_VERSION = 5.0`, `SWIFT_STRICT_CONCURRENCY = minimal`.
- **`globals.h` ↔ `AppConstants.swift` are dual-maintained.** `globals.h` is the Obj-C source of truth for the `Defaults*`/notification-name/`ShownTab`/`PSSearch*` constants; `Classes/AppConstants.swift` mirrors every wire string **byte-for-byte** (persisted default keys, `Notification.Name` raw values, the `"<pref>_<mod>"` per-module-key format, the `DEFAULT_*_PATH` expressions). The persisted key often differs from the macro name (`DefaultsLastRef` → `"lastRef"`) and there is one notification mismatch (`moduleMaintainerModeChanged` → `"ModuleMaintainerModeChanged"`, no prefix). When you change a literal in one, change it in the other, or Obj-C/Swift observers silently stop interoperating and persisted data breaks.

## High-level architecture

### Launch sequence (all Swift)

1. `PocketSwordAppDelegate` (`@main`, `Classes/PocketSwordAppDelegate.swift`; there is **no `main.m`**): registers for `NSUbiquitousKeyValueStore` change notifications (iCloud key-value sync of bible history) and hands scene configuration to `PocketSwordSceneDelegate`.
2. `PocketSwordSceneDelegate` (`UIWindowSceneDelegate`, `PSLaunchDelegate`): installs `PSLaunchViewController` as the root VC, kicks off `startInitializingPocketSword` on a background thread, and holds any launch URL (`sword://…`) until init finishes.
3. When init completes, `finishedInitializingPocketSword:` builds a `PSTabBarControllerDelegate`, swaps the window's root VC to its `tabBarController`, and replays the pending URL through `PocketSwordAppDelegate`'s open-URL handler.

`PSTabBarControllerDelegate` is the central coordinator for the running app: it owns the tab bar, the Bible/Commentary/Dictionary view controllers, the reference selector, the info popup (Strong's / morph / footnotes / xrefs / dict entries), and the search/history multi-list. Cross-VC coordination is done via `NSNotificationCenter` — the notification names are the `Notification…` defines in `Classes/globals.h`, mirrored as `Notification.Name` extensions in `AppConstants.swift`.

### SWORD bridge (`Classes/Sword*.{h,mm}`, `PSSearchEngine.{h,mm}`, `VerseEnumerator.{h,mm}`) — permanent Obj-C++

Objective-C++ wrappers over the C++ SWORD API. **These stay `.mm` forever** — direct Swift⇄C++ interop is not viable for SWORD's operator-overloaded value-semantic API.

- `SwordManager` (singleton via `+defaultManager`) wraps `sword::SWMgr` — enumerates installed modules, manages cipher keys, global options, and the module install path (`DEFAULT_MODULE_PATH` under `Documents/`). Its surface was pruned in the Phase-1 module-choice removal: `modulesForFeature:`, `+managerWithPath:`, `-addPath:`, `-initWithSWMgr:`, `+moduleTypes` and the `moduleListByType` / `moduleTypes` / `temporaryManager` properties are gone. `+moduleCategoryAllowed:` survives as an internal PrivateAPI helper — `-refreshModules` uses it to keep glossary/essay dictionaries out of the list.
- `SwordModule` (+ subclasses `SwordBook`, `SwordDictionary`) wrap `sword::SWModule` and produce rendered HTML via the markup-filter chain.
- `SwordKey` / `SwordVerseKey` / `SwordListKey` / `VerseEnumerator` wrap SWORD's key types for references and search.
- `PSSearchEngine.mm` owns the SQLite/FTS5 search index build and query (C++-clean public header; the `sword::`/`sqlite3` code stays in the `.mm`).

### App-level module layer (`Classes/PSModule*`, `Classes/PS*ViewController` — Swift)

- `PSModuleController` (singleton via `+defaultModuleController`) holds the **primary Bible / commentary / dictionary** the user is currently reading, builds the HTML shells (`+createHTMLString:…`, `+createInfoHTMLString:…`), unpacks bundled starter modules (`installModulesFromZip:…`), and exposes ref-string helpers.
- `PSModuleViewController` is the shared base for `PSBibleViewController` and `PSCommentaryViewController`. Rendering happens in a `PSWebView` (a `WKWebView` subclass); tapped verses / Strong's lookups come back through the `PSWebViewDelegate` protocol (`@objc`), which the tab-bar delegate routes to `PSInfoPopupViewController`.
- `PSLaunchViewController` performs first-run bootstrap (seeding `Documents/` from the zips under `Resources/`, running one-off migrations like `DefaultsLuceneSwept` / `DefaultsSimplifiedCleanupDone` / `DefaultsModuleChoiceRetired`).

### Tabs enum (stable ordinals)

`ShownTab` in `globals.h` is `BibleTab, CommentaryTab, DictionaryTab, DevotionalTab, DownloadsTab, PreferencesTab`. **`DevotionalTab` and `DownloadsTab` are dead placeholders** — the devotional and in-app download features have been removed — but the enum values are kept so that ordinals persisted in `NSUserDefaults` do not shift. Do not renumber or delete them.

### Display preferences (where they live, and why)

Display prefs are split by scope, and the split is **load-bearing**:

- **Per-module** prefs — the *content* toggles (Strong's, morph tags, headings, footnotes, cross-references, red-letter, verse-per-line) — live in the **per-tab `▾` menu** on the Bible and Commentary tabs (`PSModuleViewController.rebuildSettingsMenu()`). Each row writes `"<pref>_<ModuleName>"` keyed on the module's own `name`, gated on `-[SwordModule hasFeature:]`. Note `hasFeature:` also matches `GlobalOptionFilter` entries (bare and `OSIS`/`GBF`/`ThML`/`UTF8`-prefixed), not just `Feature=` lines — which is why KJV gets Footnotes/Headings/RedLetter rows. MHCC declares neither, so its menu has **no** rows at all and the button hides itself (`setSettingsMenu(nil)`) rather than presenting an empty menu.
- **Global** prefs — **font name + size** plus the device options — live in `PSPreferencesController` (2 sections: `DISPLAY = 0`, `DEVICE = 1`; `LANG_SECTION = 44` is deliberately out of range and unreachable). There is exactly **one** font for the whole app.

**Font is global, deliberately.** `createHTMLString` reads only the unsuffixed `fontNamePreference` / `fontSizePreference`; the per-module `"<fontpref>_<mod>"` override was removed when the picker moved out of the per-tab menus. The `DefaultsGlobalFontOnly` migration deletes the orphaned per-module font/size/defaults keys so they can't sit in the plist looking authoritative. `moduleName` is still passed to `createHTMLString`, but now only for the RTL check.

**Do not "simplify" the per-module content toggles into global Preferences.** `-[SwordModule getChapter:]` calls `-setPreferences`, which reads the *per-module* keys off `self.name` and pushes them into SWORD as global options — overwriting whatever the unsuffixed global keys set. A toggle written to the global domain would be silently clobbered on every render. (Font is exempt: it never goes through `-setPreferences`, which is why it *can* be global.)

> Historical note: the deleted `PSModulePreferencesController` derived its key from `self.tabBarController?.navigationItem.title`, which nothing had set since commit `5654f92` (Apr 2026) removed its only writer. It therefore read and wrote `"<pref>_"` and had been completely inert. The `DefaultsModuleChoiceRetired` migration deletes those orphaned keys rather than honouring them.

### Persistence

- User state: `NSUserDefaults` with `Defaults…` string keys in `globals.h` / `AppConstants.swift`. Per-module prefs use the key pattern `"<PrefName>_<ModuleName>"` — the Obj-C `GetBoolPrefForMod / SetBoolPrefForMod / …` macros and the Swift `UserDefaults.ps*(…forModule:)` extension must produce identical keys.
- Cross-device sync: reading history (`PSHistoryName = @"bibleHistory"`) is mirrored through `NSUbiquitousKeyValueStore`; `PSHistoryController` reconciles on the `NSUbiquitousKeyValueStoreDidChangeExternallyNotification` from the app delegate.
- Bookmarks live on disk under `DEFAULT_BOOKMARKS_PATH` (`Documents/`).
- **The serialized shapes of history / bookmark / search-history objects are locked by `PersistedFormatTests.swift`.** Changing an array index, a hardcoded literal, or the pref-key format is a data-migration event — keep the tests green.

### Bundled content

The app ships **exactly five modules and no UI to add, remove, or pick one**: one Bible (KJV), one commentary (MHCC), and three fixed-role lexicons — `StrongsRealGreek` (`Feature=GreekDef`), `StrongsRealHebrew` (`HebrewDef`), `Robinson` (`GreekParse`). The roles are **not** interchangeable; they are hardcoded in the `BundledModules` enum in `AppConstants.swift`, which is the single source of truth for the set.

They ship as zips in `Resources/` (`KJV.zip`, `MHCC.zip`, `Robinson.zip`, `strongsrealgreek.zip`, `strongsrealhebrew.zip`, `locales.d.zip`) and are unpacked on first launch into **`Documents/`** (`AppPaths.modulePath`) — *not* `Documents/Built-in/`. `AppPaths.builtinModulePath` exists only to delete the legacy directory left behind by old builds; nothing installs there.

Seeding is an unconditional idempotent loop: any bundled module that isn't installed gets re-seeded. The old `DefaultsKJVRemoved` / `DefaultsMHCCRemoved` / etc. opt-out flags and the `DefaultsStrongsGreekModule` / `DefaultsStrongsHebrewModule` / `DefaultsMorphGreekModule` lexicon-role keys are **retired** — still declared in `globals.h` / `AppConstants.swift` so the names are not reused, but never read or written. The one-shot `DefaultsModuleChoiceRetired` migration clears any that are already set (a stale `*Removed` flag would otherwise suppress a bundled module forever now that there is no removal UI, and a lexicon key can legitimately hold the localized string `"None"`).

### URL handling

The app registers the `sword://` URL scheme (`CFBundleURLTypes` in `misc/Info.plist`). Incoming URLs are routed through `PocketSwordAppDelegate`'s open-URL handler; if a URL arrives during launch before the tab bar exists, the scene delegate caches it in `_pendingLaunchURL` and replays it from `finishedInitializingPocketSword:`.

## Localization

Localization is **`.strings`-based** (programmatic UIKit — there are no XIBs), but the app ships **English only**. UI strings go through `NSLocalizedString(...)` and resolve against the single `en.lproj/Localizable.strings`, with `Settings.bundle/en.lproj/Root.strings` for the Settings pane. `en.lproj/Localizable.strings` is the source of truth for keys; add new keys there. The former non-English locale projects (`ar cs de es fr it ja ko nl pt ru sv th uk zh-Hans zh-Hant`) have been removed, and `knownRegions` / the `Localizable.strings` variant group in the pbxproj list only `en` — do not re-add other locales without a deliberate decision.

> The repo still contains `gen_xib_strings.py` / `localize_xibs.py`. These are **dead XIB-era tooling** — they operate on `.xib` files, of which there are none. Do not run them or treat them as the localization flow.
