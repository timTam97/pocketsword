# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PocketSword is a GPL'd iOS Bible-study app built on the CrossWire SWORD C++ API (https://www.crosswire.org/sword/). This repo is a fork of `bitbucket.org/niccarter/pocketsword` updated for new iPhones and iOS 26. The app is Objective-C / Objective-C++ (`.m` / `.mm`); there is no Swift and no CocoaPods/SPM — all third-party code is vendored under `externals/`.

## Build / run

- Open `PocketSword.xcodeproj` in Xcode and build the `PocketSword` scheme. There is no `.xcworkspace` and no package manager step.
- CLI build: `xcodebuild -project PocketSword.xcodeproj -scheme PocketSword -configuration Debug -sdk iphonesimulator build` (swap to `-sdk iphoneos` and `-configuration Release`/`Distribution` as needed). You may need to pass `CODE_SIGNING_ALLOWED=NO` for simulator builds without a dev team.
- Configurations: `Debug`, `Release`, `Distribution`. Each has a **different** `PRODUCT_BUNDLE_IDENTIFIER` (`org.timsams.PocketSword` / `org.timsam.PocketSword` / `org.Crosswire.PocketSword`) — do not assume they match.
- Deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, universal (`TARGETED_DEVICE_FAMILY = "1,2"`). No shared Xcode scheme is checked in.
- There is no test target. Do not invent `xcodebuild test` commands; verify in Simulator.

## SWORD / third-party build wiring (important)

The SWORD engine is compiled **from sources in-tree** (`externals/sword/src/…` with headers in `externals/sword/include`), not linked as a prebuilt framework. Compile-time knobs live in `misc/PocketSword_Prefix.pch` (`GCC_PREFIX_HEADER`), which is force-included into every translation unit:

- `CURLAVAILABLE` is intentionally **not** defined — the in-app module-download feature and `InstallMgr`'s CURL transports have been removed; their call sites compile to null-returning stubs. Do not re-enable CURL or reintroduce download UI without a deliberate design discussion.
- `EXCLUDEXZ`, `unix`, `__unix__` are set; `_ICU_`/`USELUCENE` are commented out.
- ZipArchive (`externals/ZipArchive`, with `minizip`) needs `HAVE_INTTYPES_H`, `HAVE_PKCRYPT`, `HAVE_STDINT_H`, `HAVE_WZAES`, `HAVE_ZLIB` — all set in the prefix.
- `HEADER_SEARCH_PATHS` still lists `externals/clucene/**` for historical reasons even though the folder is absent; leave it unless you are actively cleaning up.
- The build links `-licucore` (`OTHER_LDFLAGS`); C++ standard is `c++0x`; Obj-C ARC is on for the app target.
- `DLog(...)` is a `NSLog` wrapper that only fires in `DEBUG`; `ALog(...)` always fires. Prefer `DLog` for anything chatty.

## High-level architecture

### Launch sequence

1. `main.m` → `PocketSwordAppDelegate` (`UIApplicationDelegate`): registers for `NSUbiquitousKeyValueStore` change notifications (iCloud key-value sync of bible history) and hands scene configuration to `PocketSwordSceneDelegate`.
2. `PocketSwordSceneDelegate` (`UIWindowSceneDelegate`, `PSLaunchDelegate`): installs `PSLaunchViewController` as the root VC, kicks off `startInitializingPocketSword` on a background thread, and holds any launch URL (`sword://…`) until init finishes.
3. When init completes, `finishedInitializingPocketSword:` builds a `PSTabBarControllerDelegate`, swaps the window's root VC to its `tabBarController`, and replays the pending URL through `-[PocketSwordAppDelegate application:handleOpenURL:options:]`.

`PSTabBarControllerDelegate` is the central coordinator for the running app: it owns the tab bar, the Bible/Commentary/Dictionary view controllers, the reference selector, the info popup (Strong's / morph / footnotes / xrefs / dict entries), the module selector, and the search/history multi-list. Cross-VC coordination is done via `NSNotificationCenter` — see the long block of `Notification…` defines in `Classes/globals.h`.

### SWORD bridge (`Classes/Sword*.{h,mm}`)

Objective-C++ wrappers over the C++ SWORD API:

- `SwordManager` (singleton via `defSwordManager`) wraps `sword::SWMgr` — enumerates installed modules, manages cipher keys, global options, and the module install path (`DEFAULT_MODULE_PATH` under `Documents/`, plus `Documents/Built-in/` for shipped starters).
- `SwordModule` (+ subclasses `SwordBook`, `SwordDictionary`) wrap `sword::SWModule` and produce rendered HTML via the markup-filter chain.
- `SwordKey` / `SwordVerseKey` / `SwordListKey` / `VerseEnumerator` wrap SWORD's key types for references and search.

### App-level module layer (`Classes/PSModule*`, `Classes/PS*ViewController`)

- `PSModuleController` (singleton via `+defaultModuleController`) holds the **primary Bible / commentary / dictionary** the user is currently reading, builds the HTML shells (`+createHTMLString:…`, `+createInfoHTMLString:…`), unpacks bundled starter modules (`installModulesFromZip:…`), and exposes ref-string helpers.
- `PSModuleViewController` is the shared base for `PSBibleViewController` and `PSCommentaryViewController`. Rendering happens in a `PSWebView` (a `WKWebView` subclass); tapped verses / Strong's lookups come back through `PSWebViewDelegate` callbacks, which the tab-bar delegate then routes to `PSInfoPopupViewController`.
- `PSLaunchViewController` performs first-run bootstrap (seeding `Documents/Built-in/` from the zips under `Resources/`, running one-off migrations like `DefaultsLuceneSwept` / `DefaultsSimplifiedCleanupDone`).

### Tabs enum (stable ordinals)

`ShownTab` in `globals.h` is `BibleTab, CommentaryTab, DictionaryTab, DevotionalTab, DownloadsTab, PreferencesTab`. **`DevotionalTab` and `DownloadsTab` are dead placeholders** — the devotional and in-app download features have been removed — but the enum values are kept so that ordinals persisted in `NSUserDefaults` do not shift. Do not renumber or delete them.

### Persistence

- User state: `NSUserDefaults` with `Defaults…` string keys defined in `globals.h`. Per-module prefs use the `GetBoolPrefForMod / SetBoolPrefForMod / …` macros (key pattern `"<PrefName>_<ModuleName>"`).
- Cross-device sync: reading history (`PSHistoryName = @"bibleHistory"`) is mirrored through `NSUbiquitousKeyValueStore`; `PSHistoryController +synchronizeHistoryItemsFromCloud:` reconciles on the `NSUbiquitousKeyValueStoreDidChangeExternallyNotification` from the app delegate.
- Bookmarks live on disk under `DEFAULT_BOOKMARKS_PATH` (`Documents/`).

### Bundled content

Starter modules ship as zips in `Resources/` (`KJV.zip`, `MHCC.zip`, `Robinson.zip`, `strongsrealgreek.zip`, `strongsrealhebrew.zip`, `locales.d.zip`) and are unpacked on first launch into `Documents/Built-in/`. When switching builds, the `DefaultsKJVRemoved` / `DefaultsMHCCRemoved` / etc. keys record that the user has removed a bundled module so it is not re-seeded on next launch.

### URL handling

The app registers the `sword://` URL scheme (`CFBundleURLTypes` in `misc/Info.plist`). Incoming URLs are routed through `-[PocketSwordAppDelegate application:handleOpenURL:options:]`; if a URL arrives during launch before the tab bar exists, the scene delegate caches it in `_pendingLaunchURL` and replays it from `finishedInitializingPocketSword:`.

## Localization

**Never edit non-English XIB files directly.** The English XIB is the source of truth; localized XIBs are regenerated from `.strings` files. Two helper scripts own this flow:

- `./gen_xib_strings.py [-p] <path>` — extract strings from the English XIB into per-locale `.strings` files.
- `./localize_xibs.py <path>` — regenerate localized XIBs from translated `.strings` files.

Both scripts carry the same warning at the top and should be run from the repo root. Locale projects live in `ar.lproj`, `cs.lproj`, `de.lproj`, `en.lproj`, `es.lproj`, `fr.lproj`, `it.lproj`, `ja.lproj`, `ko.lproj`, `nl.lproj`, `pt.lproj`, `ru.lproj`, `sv.lproj`, `th.lproj`, `uk.lproj`, `zh-Hans.lproj`, `zh-Hant.lproj`.
