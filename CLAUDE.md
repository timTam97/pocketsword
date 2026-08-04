# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PocketSword is a GPL'd iOS Bible-study app. It **was** built on the CrossWire SWORD C++ API (https://www.crosswire.org/sword/); it now ships that project's *content*, baked offline into a bundled SQLite store, with no C++ at runtime. This repo is a fork of `bitbucket.org/niccarter/pocketsword` updated for new iPhones and iOS 26.

**The target is pure Swift.** `Classes/` is 58 `.swift` files plus exactly one header, `globals.h` (enums + macros, consumed via both bridging headers); the only other Objective-C in the target is the vendored `externals/MBProgressHUD`. There is no C++, no Objective-C++, no `.mm` anywhere.

Getting there was two projects, both complete on `opus/sword-migration`:
- `SWIFT_MIGRATION_PLAN.md` moved the app layer under `Classes/` from Obj-C to Swift, leaving a deliberately-permanent Obj-C++ SWORD bridge.
- `SWORD_REMOVAL_PLAN.md` then deleted that bridge and the engine under it. Phase 3 moved content *reading* to a pure-Swift reader over the baked store; Phase 4 did the same for versification and reference parsing; **Phase 5 deleted `externals/sword`, the `Sword*.{h,mm,+Cpp.h}` bridge, `tools/swordbake`, `externals/ZipArchive`, the module zips and the whole C++ build wiring**, and ported `PSSearchEngine` to Swift. ~47k LOC removed. Read its per-phase status blocks before assuming anything in this file's history section still applies.

There is no CocoaPods/SPM; all third-party code is vendored under `externals/` (which is now just `MBProgressHUD`). The UI is programmatic UIKit — there are **no XIBs** and only a `LaunchScreen.storyboard`.

## Build / run

- Open `PocketSword.xcodeproj` in Xcode and build the shared `PocketSword` scheme (there is a second scheme `PocketSword1`). There is no `.xcworkspace` and no package manager step.
- CLI build: `xcodebuild -project PocketSword.xcodeproj -scheme PocketSword -configuration Debug -sdk iphonesimulator build` (swap to `-sdk iphoneos` and `-configuration Release`/`Distribution` as needed). You may need `CODE_SIGNING_ALLOWED=NO` for simulator builds without a dev team. **`/usr/bin/xcodebuild` resolves stable Xcode and fails this iOS-26 project with "Found no destinations"** — use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild`, or prefer the Xcode MCP build/test tools.
- A clean build should show **`CompileC` 1** (`externals/MBProgressHUD/MBProgressHUD.m`, the only Obj-C translation unit) and **`SwiftCompile` 59**. A `CompileC` above 1 means non-Swift sources came back into the target; that is a regression, not a detail.
- **Tests exist.** The `PocketSwordTests` XCTest bundle (app-hosted, `@testable import PocketSword`) has **78 tests** — 76 that run by default plus 2 env-gated: 18 in `Classes/PersistedFormatTests.swift`, 10 in `Classes/PSVoiceRefParserTests.swift`, 32 in `Classes/PSContentStoreTests.swift`, 4 in `Classes/PSSearchIndexParityTests.swift`, 14 in `Classes/PSRefSemanticsTests.swift`. Run with the Xcode MCP test tools, or `xcodebuild … test` with the `DEVELOPER_DIR` caveat above. The persisted-format tests **lock the byte-exact persisted formats** (history / bookmark / search-history serialization and the per-module pref-key format) and encode existing read/write quirks deliberately — a change that flips one red means you altered a persisted format and will corrupt user data. Do not "fix" a test to make it pass; fix the code.
- **Check the skip count, not just the pass count.** The expected result is *76 passed / 2 skipped / 0 failed*. The 2 skips are the `PSREF_EXHAUSTIVE` pair. Historically, every engine-driven test polled `isModuleInstalled(name)` with a 90 s timeout and then `XCTSkip`ed, so a mis-ordered commit **skipped rather than failed** — that trap is what dictated Phase 5's step order (see `PHASE5_ORDERING.md`). Those tests are gone, but the habit is still the right one.
- **The whole suite runs against committed fixtures that were captured from the live SWORD engine, and the engine is gone.** There is no way to regenerate any of them, so a red fixture test is a real behaviour change — never "fix" one by recapturing. The `PSORACLE_CAPTURE` env var and the capture code it gated are deleted. Under `Tests/Fixtures/`:
  - chapter bodies at **both** option endpoints, a bookmark-highlighted body, lexicon entries, footnote attribute shapes — read by `PSContentStoreTests`
  - `versification-KJV-oracle.txt` — 66 books × 5 members, 1,189 verse maxima, **all 2,376 transitions**; this single fixture is the whole versification gate now that `SwordBook` is gone
  - `search-index-KJV.digest` — all **31,102** rows of the *engine-built* FTS index in rowid order, as `reference|book_osis|testament|` plus a hash of each of the four text columns. Truncated to SHA-256's leading 64 bits (full hex was 8.7 MB vs 2.7 MB): a change detector, not a commitment scheme.
  - `chapter-loop-counters.tsv` — `entryCount` for all 1,189 chapters × both modules (2,378 rows), so the loop-counter guard survived the loss of `-chapterBodyHTML:`
  - `strongsPad-prefixed-key-bug.txt` — a **historical record** of an engine bug, not a live oracle; see its header
- **`PSSearchIndexParityTests` is the acceptance criterion for both the store-built index and the Swift `PSSearchEngine` port.** It runs a real `build(progress:)` (tens of seconds — kept in the default suite deliberately, because the failure it guards is silent: search results just quietly go missing) and compares all 31,102 rows against the digest. The other two tests there pin `PSSearchQuery.cleanDisplayText` and `foldForIndex` against **known vectors that are the Obj-C originals' outputs**, captured while those originals existed.
- **`PSRefSemanticsTests`** covers reference semantics (Phase 4), tiered and gated on `PSREF_EXHAUSTIVE=1`. Its fast tier includes the **four-part unreachability proof** that licensed the `x`/`scriptRef` deletion, re-derived from the store on every run rather than trusted as prose.
- Getting an env var into a *test* run needs a temporary `<EnvironmentVariables>` block in the shared scheme's `TestAction` **plus** `shouldUseLaunchSchemeArgsEnv = "NO"` (the block is ignored otherwise) — back the scheme up and restore it, it is checked in. `RunAllTests` / `RunSomeTests` have no parameter for this.
- Configurations: `Debug`, `Release`, `Distribution`. Each has a **different** `PRODUCT_BUNDLE_IDENTIFIER` (`org.timsams.PocketSword` / `org.timsam.PocketSword` / `org.Crosswire.PocketSword`) — do not assume they match.
- Deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, universal (`TARGETED_DEVICE_FAMILY = "1,2"`).

### Driving the app on the simulator (Xcode MCP device interaction)

Most of this app's behaviour is only observable by actually reading a chapter, so runtime verification matters. Notes from doing it, because several of these cost real time to discover:

- **Session shape.** `DeviceInteractionStartWorkspaceSession` → `DeviceInteractionInstallAndRun` → `DeviceInteractionSynthesize` (repeat) → `DeviceInteractionEndSession`. Use the *Workspace* variant: the plain `DeviceInteractionStartSession` cannot install, and pairing it with a separate `RunProject` gives a session that reports `applicationState: NotRun` forever even though the app is visibly running. Always close the session — it is resource-heavy.
- **Every Xcode MCP call needs `tabIdentifier`** (`windowtab1` for this project's single window). Omitting it returns an error listing the open windows rather than doing anything.
- Starting a session returns `skillToTrigger: device-interaction` and instructs you to spawn a subagent for all interaction. That is the MCP's own convention, **not** a hard requirement — driving `DeviceInteractionSynthesize` inline works fine, which is what you want when the session's instructions say to avoid subagents. The `device-interaction` skill's real value is the command syntax below; if it isn't loadable, `xcrun agent skills export <dir>` writes it to disk.
- **`interactionCommand` syntax** lives in the `device-interaction` skill, which may not be loadable in the session. The vocabulary is not guessable — `describe`, `help`, `type`, `k` are all invalid and just error. The ones that matter:
  - `t <x> <y> [dur]` tap · `d <x> <y>` double tap · `t <x1> <y1> f <x2> <y2> [dur]` swipe
  - `sender keyboard kbd <text>` types text; it **must be the last command in the chain** and everything after `kbd ` is verbatim. `\u{000A}` is Return (this is how you submit a search).
  - `b h` home, `w <dur>` wait, `orientation <name>`, `drag`, `mt` multi-touch.
  - Omit `interactionCommand` entirely to just capture state.
- **Read the hierarchy file, not the screenshot, for coordinates.** Every call returns a `hierarchyPath`; each element carries a `hitPoint`. Guessing pixel positions off the screenshot mostly taps empty space. `grep` the hierarchy for a `label:` to find the target.
- The response's `logsPath` plus `GetConsoleOutput` (with a `pattern` filter) is the fastest way to check for exceptions after an interaction. Expect harmless noise: a `UIAccessibilityLoaderWebShared` duplicate-class warning, `cannot add handler to 0 from 0`, and WebKit freezer-status errors are all normal here and not app bugs.
- **The reading pane is a `WKWebView`**, so verse text, Strong's links and footnote markers do **not** appear in the UI hierarchy — only the WebView does. Verify that content by reading the screenshot image.
- The app restores its last tab and scroll position, so a fresh launch may not start where you expect. Capture before assuming.
- For a one-off env var on an **app** run, use `InstallAndRun`'s `environmentVariables` / `commandLineArguments` (`$(inherited)` preserves the scheme's own) rather than editing the scheme — they apply to that run only. **`RunAllTests` / `RunSomeTests` have no such parameter**, so getting an env var into a *test* run (the only one left is `PSREF_EXHAUSTIVE`) means temporarily adding an `<EnvironmentVariables>` block to the scheme's `TestAction` **plus** `shouldUseLaunchSchemeArgsEnv = "NO"` — back the file up first and restore it immediately after, since the scheme is shared and checked in.
- `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` from the CLI may fail with "Unable to find a destination" even when that simulator is booted and the MCP can target it, because the CLI resolves a different `SDKROOT`. Prefer the MCP test tools over the CLI here; for builds, `DEVELOPER_DIR=/Applications/Xcode-beta.app/…` plus that Xcode's own `xcodebuild` works.
- **`simctl` and the MCP session fight over the debug session.** `xcrun simctl terminate` / `launch` / `openurl` all work and are the only way to do some things (`openurl` for the `sword://` shapes; a `launch` after editing the prefs plist to re-run a one-shot migration). But a `simctl terminate` out from under the MCP makes the next `Synthesize` report `applicationState: Crashed` even though nothing crashed — check for an actual `.ips` crash report and `launchctl list | grep -i pocketsword` before believing it, then `InstallAndRun` to re-attach. Also note **a reinstall assigns a new container UUID**, so re-resolve with `xcrun simctl get_app_container <device> <bundle-id> data` rather than reusing the path.
- **The pane needs a beat to load.** Both the info popup and the dictionary entry screen are `WKWebView`s; screenshotting immediately after the tap shows an empty pane that looks exactly like a rendering bug. Insert a `w 2.0` before capturing. A previous session recorded a "Dictionary blank pane" defect on this basis that the final Phase-5 pass could not reproduce on either dictionary path.

## Build wiring

There is no C++ and no third-party build wiring left. `misc/PocketSword_Prefix.pch` (`GCC_PREFIX_HEADER`) survives for exactly one translation unit — `externals/MBProgressHUD/MBProgressHUD.m` — and holds only the Foundation/UIKit imports and:

- `DLog(...)`, a `NSLog` wrapper that only fires in `DEBUG`, and `ALog(...)`, which always fires. Both are Obj-C-only; Swift ignores the prefix header entirely and uses the mirror shims `dlog(...)` / `alog(...)` in `AppConstants.swift`. Prefer `DLog`/`dlog` for anything chatty.

**zlib comes from the SDK's own Clang module** — `PSContentStore` does `import zlib` and calls `uncompress()`. That needs no build setting and no vendored code; do not confuse it with the deleted minizip.

> Historical, and do not restore any of it: the engine used to be compiled from sources in-tree (`externals/sword/src/…`, 292 `.cpp` + 2 `.c` in the Sources phase) with its knobs in the pch — `unix`, `__unix__`, `EXCLUDEXZ`, and commented-out `_ICU_` / `_APPLE_IOS_` / `USELUCENE` / `CURLAVAILABLE` — plus five `HAVE_*` defines for ZipArchive/minizip. The project carried `CLANG_CXX_LANGUAGE_STANDARD = c++0x`, `OTHER_LDFLAGS = -licucore`, and `HEADER_SEARCH_PATHS` naming `externals/sword/include` and a long-absent `externals/clucene/**`. Phase 5 step 11 removed all of it. **`CURLAVAILABLE` was never defined** — the in-app module-download feature and `InstallMgr`'s CURL transports were removed long before, and their call sites compiled to null-returning stubs. Do not reintroduce download UI without a deliberate design discussion; with a fixed baked module set there is nothing for it to download.
>
> Note the two pbxproj **scopes**, because they are easy to conflate: `HEADER_SEARCH_PATHS` was on the **app target** (`1D6058940`/`1D6058950`/`E982FA660`) while the C++/Swift-interop settings were on the **project** (`C01FCF4F`/`C01FCF50`/`E982FA650`). Still on the project and still needed: `GCC_PREFIX_HEADER`, both `SWIFT_OBJC_BRIDGING_HEADER` settings, `GCC_C_LANGUAGE_STANDARD`, `CLANG_ENABLE_OBJC_ARC`, `SWIFT_VERSION = 5.0`.

### The content store is baked, and the converter that baked it is gone

`Resources/PSContent.sqlite` + `Resources/Versification-KJV.json` **are** the app's render path and its versification. They were produced by `tools/swordbake` — a standalone macOS CLI that linked the vendored engine — which Phase 5 step 10 deleted along with `externals/sword`. **There is no longer any way to regenerate them in this repo.** Both are bundled by path, so a replacement artifact needs no pbxproj change; producing one would mean resurrecting the engine and the converter from git history (`fa09511^`), where `tools/swordbake/README.md` records the measurements and the engine quirks the schema had to be designed around (two encodings, the `getChapter` loop counter, the headings axis, the fifth `passagestudy.jsp` emission site, and why the FTS text is captured with four options **off**).

The store is at **schemaVersion 2 / tokenGrammar v2** and `Classes/PSContentStore.swift` refuses to open anything else. Since the writer no longer exists, that check now guards against a *reader* change rather than a writer skew — it is still load-bearing, because a mismatch would address the wrong chunk slot and return **plausible but wrong** text.

**The FTS source is shipped, not derived on device.** Phase 2 recommended dropping `plain_texts` and re-deriving it; Phase 3 retracted that (`SWORD_REMOVAL_PLAN.md` §5.6) because the derivation would be a second untested implementation of `stripText()` and a bug in it does not crash — search results quietly go missing.

## Swift ⇄ Obj-C interop (there is barely any left)

Both bridging headers now import **`globals.h` and nothing else from the project** (the app's also takes `MBProgressHUD.h`). If you are looking for the elaborate interop scheme this section used to describe, it is deleted; `misc/PocketSword-Bridging-Header.h`'s own header comment explains what it was for and why it no longer applies. **Do not reconstruct it.**

- **`globals.h` ↔ `AppConstants.swift` are dual-maintained, and this is still live.** `globals.h` is the source of truth for the `Defaults*` / notification-name / `ShownTab` / `PSSearch*` constants and the `ModuleType` / `ATTRTYPE_*` / `SW_OUTPUT_*_KEY` / `SWMOD_*` values that Phase 5 step 2 moved into it out of the then-doomed `SwordModule.h` / `SwordManager.h`. `Classes/AppConstants.swift` mirrors every wire string **byte-for-byte** (persisted default keys, `Notification.Name` raw values, the `"<pref>_<mod>"` per-module-key format, the `DEFAULT_*_PATH` expressions). The persisted key often differs from the macro name (`DefaultsLastRef` → `"lastRef"`) and there is one notification mismatch (`moduleMaintainerModeChanged` → `"ModuleMaintainerModeChanged"`, no prefix). Change a literal in one, change it in the other, or persisted data breaks.
- **`SWIFT_OBJC_INTERFACE_HEADER_NAME` is unset, so `PocketSword-Swift.h` is not generated.** Many Swift file headers still explain that an Obj-C++ caller reached them "via the generated `PocketSword-Swift.h`" — that is history, accurate for when it was written. No Obj-C consumer remains.
- **`@objc` annotations are now largely vestigial.** `@objc(PSContentStore)`, `@objc(PSSearchResult)`, `@objc(PSContentVerseRow)`, the resolver's `@objc` seam, and so on exist because an Obj-C++ caller used to need them. They are kept where removing them would be pure churn, and the ones that matter say so in a comment. **Do not read an `@objc` as evidence that an Obj-C caller exists.** The ones that are genuinely load-bearing are the `@objc` protocol conformances and selector-based targets within Swift (`#selector`, `addTarget`, `UIMenu` actions, delegate protocols like `PSWebViewDelegate` / `PSModuleSearchControllerDelegate`), which go through the Obj-C runtime regardless of language.
- `SWIFT_VERSION = 5.0`, `SWIFT_STRICT_CONCURRENCY = minimal`.

## High-level architecture

### Launch sequence (all Swift)

1. `PocketSwordAppDelegate` (`@main`, `Classes/PocketSwordAppDelegate.swift`; there is **no `main.m`**): registers for `NSUbiquitousKeyValueStore` change notifications (iCloud key-value sync of bible history) and hands scene configuration to `PocketSwordSceneDelegate`.
2. `PocketSwordSceneDelegate` (`UIWindowSceneDelegate`, `PSLaunchDelegate`): installs `PSLaunchViewController` as the root VC, kicks off `startInitializingPocketSword` on a background thread, and holds any launch URL (`sword://…`) until init finishes.
3. When init completes, `finishedInitializingPocketSword:` builds a `PSTabBarControllerDelegate`, swaps the window's root VC to its `tabBarController`, and replays the pending URL through `PocketSwordAppDelegate`'s open-URL handler.

`PSTabBarControllerDelegate` is the central coordinator for the running app: it owns the tab bar, the Bible/Commentary/Dictionary view controllers, the reference selector, the info popup (Strong's / morph / footnotes / xrefs / dict entries), and the search/history multi-list. Cross-VC coordination is done via `NSNotificationCenter` — the notification names are the `Notification…` defines in `Classes/globals.h`, mirrored as `Notification.Name` extensions in `AppConstants.swift`.

### The Swift content reader (`Classes/PSContent*`, `PSChapter*`, `PSBookOSISResolver` — the render path)

**The app reads content from the baked SQLite store. There is no other path and no
fallback.** Phase 3 introduced this behind `PSFeatureFlags.swiftContentReader`; Phase 5
step 1 retired the flag and split the reader's ten former nil-returns into **fatal**
(store missing/unopenable, schema or grammar mismatch, absent chunk sizes, bad
versification — the app cannot function, and a crash report beats a blank pane) and
**loud-and-nil** (malformed token stream, unresolvable book, bad chunk slot,
unresolvable MHCC body id, chapter record-count mismatch, index row off its chunk — one
bad chapter must not brick the app). `PSContentReader.swift`'s header says which is
which; keep it accurate if you add a failure.

- `PSContentStore` — read-only SQLite (`SQLITE_OPEN_READONLY`) + chunk framing.
  Rows out, no HTML. Guarded by a serial queue. Inflates with **`import zlib`** /
  `uncompress()`, *not* `Compression.framework` (the blobs are zlib-with-header and
  each chunk carries its exact `raw_size`). Validates `schemaVersion == 2` /
  `tokenGrammar == "v2"` and reads the chunk sizes out of `content_meta` rather than
  hardcoding them — a converter/reader skew would address the wrong slot and return
  *plausible but wrong* text.
- `PSChapterExpander` — tokens → the exact HTML the markup filters emitted. A
  disabled toggle **skips** its token; that is byte-exact, not approximate. Note
  `Options.forHeading`: a title token is headings-gated in a chapter record but
  unconditional inside a stored heading (see the file header for why).
- `PSChapterAssembler` — a faithful port of `-[SwordModule chapterBodyHTML:]`'s
  accumulator loop, quirks included, plus `-highlightVerse:withClass:` over
  `NSMutableString` (the algorithm is index-based insertion at UTF-16 offsets;
  redoing it over `String.Index` would be a different algorithm).
- `PSBookOSISResolver` — book **name** → OSIS abbreviation, because runtime refs
  carry names ("Genesis 1") while `chapters` is keyed `book_osis='Gen'`. As of
  Phase 4 it is also the app's whole **versification layer** — `book(at:)`,
  `verseMax(book:chapter:)`, `nextChapter`/`previousChapter`, `displayRef` — and
  `PSVersificationBook` is the direct replacement for the deleted `SwordBook`.
  Two things there are deliberate and load-bearing: next/prev return **nil** at
  Genesis 1 / Revelation 22 where `VerseKey::normalize` *clamped* (returning the
  clamped ref would turn a no-op into a full re-render), and `displayRef` returns
  the un-munged **`longName`** form because that is what `VerseKey::freshtext`
  produced and every call site munges it downstream.
- `PSRefParser` — the free-text reference parser (Phase 4):
  `<book> [<chapter>[:<verse>[-<verse>]]]`, single book. Deliberately narrower
  than `parseVerseList` — no lists, no cross-book/cross-chapter ranges, no roman
  numerals, no `ff`, no `inscriptio` — and the header documents each omission with
  the `versekey.cpp` line that implements it. Its one production caller is the
  inbound `sword://` URL path, the only reference the app does not generate itself.
  Note it is **wider** than `PSBookOSISResolver.resolve(ref:)` (it adds a
  trailing-`.` and a despaced-abbreviation fallback), so anything that *persists* a
  parsed ref must check the resolver can still resolve it — see the app delegate.
- `PSRefLinkRouter` — the `showRef` routing predicate, extracted out of
  `PSTabBarControllerDelegate` as a pure function so link routing is assertable
  without the simulator. It reproduces `+[SwordModule
  moduleTypeForModuleTypeString:]`'s `ret = bible` default, which a naive
  type-string comparison gets wrong for an unrecognised type.
- `PSContentReader` — the coordinator the view controllers talk to. Owns module
  selection, the **per-module** option prefs, the bookmark-highlight lookup, the
  bottom pad, the JS block, the `createHTMLString` shell and language/direction.

**Two things not to "simplify":**

- `dict_keys.key` is **`COLLATE NOCASE`**, now as **defence in depth** rather than
  load-bearing. The Dictionary tab used to display and re-look-up
  `[keyText capitalizedString]`, mangling 1,375 of Robinson's 1,526 keys
  (`V-PAI-3S` → `V-Pai-3S`) and working only because SWORD uppercases both sides for
  a module without `CaseSensitiveKeys`. Phase 4 **fixed** that — both producers now
  return the module's true casing, and a `DefaultsDictKeyCaseFixed` one-shot deletes
  the `<Caches>/cache-<name>-<version>` key caches so they rebuild (the version comes
  from `content_meta`, so the migration needs no SWORD call). Keep the collation
  anyway: a cache that somehow survives the migration still finds its entry instead of
  showing a blank definition, and `PSContentStoreTests` asserts **both** casings
  resolve for all 15,824 keys so a binary `WHERE key=?` still fails the suite.
  Relatedly, `PSDictionaryViewController` has exactly one `key(at:)` that branches on
  `searching`; do not go back to reading the key off the cell's label, and do not
  index the full key list unconditionally — that opens the wrong entry for every
  search result.
- The chapter-navigation JS lives in **one** place, now
  `Classes/PSChapterNavigationJS.swift`. It is 4 KB of pure JS. It was
  `+[SwordModule chapterNavigationJSWithEntryCount:extraJS:]`, and Phase 5 step 3
  *added* the Swift version alongside it with a test asserting the two produced
  identical bytes for several `entryCount` values, precisely so the move could not be a
  silent retype; the Obj-C copy and the assertion died together with the bridge in
  step 7. Keep it one copy. Note all four `%ld` substitutions take the **same**
  `entryCount`.
  - **It emits TWO blocks, and where each lands in the document is load-bearing.**
    `script(entryCount:)` goes in `<head>` (definitions + a `window.onload` that
    re-measures and re-applies); `bootScript(extraJS:)` goes at the very **end of
    `<body>`**, appended by `PSContentReader.chapterPage` after the six pads, and is
    what performs the initial scroll. A script there runs after parse but **before
    the first paint**, so a chapter opened at John 3:20 paints already scrolled.
  - `extraJS` used to go inside `window.onload` instead, and `scrollToVerse` /
    `scrollToPosition` each wrapped their work in a 250 ms `setTimeout`. That
    combination *was* the jerky jump the user reported: `onload` fires post-paint, so
    the top of the chapter was painted and only then did the page jump. Do not move
    `extraJS` back into `onload` and do not reintroduce the timeouts.
  - The `onload` re-apply (`psReapplyInitialScroll`) exists because a late-loading
    webfont or image can shift the measured verse offsets. It is guarded on
    `psUserScrolled`, set by **capturing** `touchstart` / `wheel` listeners. Guard on
    *input*, not on comparing `window.pageYOffset` to the offset applied at boot: an
    offset comparison cannot tell a user scroll from a reflow, so it would disable
    the re-apply in exactly the case it exists to fix.

### Chapter paging restores NO position, in both directions

`-prevChapter` and `-nextChapter` (`PSModuleViewController`) both pass
`RestoreNoPosition`, landing at the **start** of the chapter they move to.

`prevChapter` used to pass `RestoreVersePosition`, which was a bug. That restore type
reads the *shared* `Defaults{Bible,Commentary}VersePosition` — the verse you were on in
the chapter you are **leaving** — so paging back from John 3:20 restored "verse 20"
into John 2 and dumped you near the bottom of a chapter you had just arrived at.
`nextChapter` had always zeroed `verseToShow` and passed `RestoreNoPosition`, so the
two directions were also asymmetric. Chapter paging is not a position-restoring
operation; the verse-position defaults exist for the *ref-selection* and
*search/history* paths, which name a verse explicitly.

Note the same button is reachable via `topReloadTriggered` (pull-down) and the
`bibleSwipeRight` / `commentarySwipeRight` notifications — all route through
`prevChapter`, so all three got the fix.

### Search (`Classes/PSSearchEngine.swift`, `PSSearchQuery.swift`, `PSSearchIndexBuilder.swift`)

`PSSearchEngine` owns the SQLite/FTS5 index build and query. It was `PSSearchEngine.{h,mm}` — the last Obj-C++ file in the tree — and Phase 5 step 8 ported it, which is what made the target pure Swift. Five things there are load-bearing, and each fails **silently** if a "simplification" gets it wrong:

1. **`SQLITE_TRANSIENT` on every `sqlite3_bind_text`.** Bridging a Swift `String` to `const char *` yields a buffer valid only for the call, so the default `SQLITE_STATIC` leaves a dangling pointer by the time `sqlite3_step` runs. The symptom is not a crash — every query matches nothing. Same hazard for the SQL handed to `prepare_v2`/`exec`, which is why both go through `withCString`.
2. **`SQLITE_OPEN_FULLMUTEX` + `sqlite3_busy_timeout(2000)` and deliberately NO serial queue.** `PSContentStore` funnels everything through a serial queue; the engine must not. A ~30-second build runs on one global queue while queries run on another, and FULLMUTEX serialises per *call* rather than per transaction — a serial queue would serialise the whole build against every keystroke.
3. **The FTS5 schema, its seven columns and their order are unchanged**, as is **`ORDER BY rowid`** — deliberately not `ORDER BY ordinal`. Verified equivalent (ordinal is strictly increasing and unique across all 31,102 rows), and switching would need an extra column, a schema bump and a forced rebuild for every user, to buy nothing.
4. **`PSSearchQuery.cleanDisplayText` is applied BEFORE the emptiness test** in the build loop, so it decides which rows exist at all — not merely how they read.
5. **`dropIndex` must not remove the enclosing directory** — KJV and MHCC share `<Caches>/search`, so dropping one module's index would delete the other's (see the paragraph below). Note also that `engine(forModuleName:)` is spelled as a factory because it returns a *shared* instance; the Obj-C `+engineForModuleName:` imported into Swift as `init(forModuleName:)`, which read like it made a new one and did not. There is **no `invalidate(forModuleName:)`**: the Obj-C original's only caller was the KJV re-seed path's `deleteSearchIndex`, deleted with the seeding in step 9, and nothing is lost — `dropIndex` closes the handle before unlinking, and a cached engine whose file is gone reopens on demand (`indexIsFresh` is false while it is missing), so the cache never hands back a handle to a deleted index.

**The index lives at `<Caches>/search/<module>.db`** (`AppPaths.searchIndexPath(for:)`), keyed by name so modules share one directory. It used to be `<AbsoluteDataPath>/search/fts.db`, a path that came out of SWORD's own conf munging and could not survive the zips; derived data belongs in Caches anyway. `PSSearchEngine.schemaVersion` went **4 → 5** to force the one-time rebuild, and there is **no migration** — the bump makes any old index stale wherever it sits, and the existing "build a search index?" prompt handles it. Consequently `dropIndex` **must not** remove the enclosing directory (it used to, safely, when the directory held one module's index): KJV and MHCC now share it.

**`cleanDisplayText` and `foldForIndex` live on `PSSearchQuery`, one copy each.** They were the C-linkage `PSSearchCleanDisplayText` and `PSFoldForIndex` in the `.mm`, and `foldForIndex` in particular was **duplicated byte-for-byte** between the two languages with only a test holding them in sync. Step 8 deleted the Obj-C copies. `cleanDisplayText` strips the inline `<H0430>` / `<TH8799>` markers `stripText()` interleaved when the Strong's option was on; `foldForIndex` is the diacritic fold that produces the `text_norm` column. Both are pinned to known vectors — **the Obj-C originals' outputs** — in `PSSearchIndexParityTests`. Changing either silently stops queries matching rows already built on users' devices.

The `PSSearchEngineErrorDomain` + negative-sentinel-code contract was **not preserved**, because no caller ever read it: `PSSearchIndexBuilder` catches generically and reports cancellation from its own `cancelRequested` flag. It is a plain Swift error enum now. `PSSearchHighlightOpen`/`Close` went the same way — they were FTS5 `snippet()` delimiters, unreferenced since the engine started returning full `text_plain` and letting the UI highlight.

> ### Historical: the SWORD bridge (deleted in Phase 5)
>
> `Classes/Sword{Manager,Module,Dictionary,Key,VerseKey,ListKey}.{h,mm}` + their `+Cpp.h` siblings, `VerseEnumerator.{h,mm}`, `SwordModuleTextEntry.{h,m}` and `utils.h` were Obj-C++ wrappers over the C++ SWORD API — ~4.7k LOC. They are **gone**, along with `externals/sword` beneath them. What replaced what:
>
> - `SwordModule`'s markup-filter rendering and its `-chapterBodyHTML:` accumulator loop → `PSContentStore` + `PSChapterExpander` + `PSChapterAssembler`. The loop's `entryCount` out-param — **not** a verse count; it advances even for entries the loop skips, and drives the `vv{i}` anchors, `pocketsword:versemenu:` links and bookmark-highlight lookup — is reproduced exactly, and pinned by `chapter-loop-counters.tsv`.
> - `SwordBook`, `VerseKey`, `ListKey` semantics → `PSBookOSISResolver` (Phase 4) + `PSRefParser`. The `x`/`scriptRef` branches of `attributeValue(forEntryData:)` were **deleted** on a four-part unreachability proof still re-derived from the store on every test run: zero `action=showRef` across 122,380 record expansions plus all 1,322 headings; 6,959/6,959 notes `type='study'` with empty refLists; the only baked `sword://` links are 14,989 lexicon→lexicon ones, all routing to the *dictionary* arm.
> - `SwordManager` (module enumeration, global options, the `Documents/` install path) → the `BundledModules` enum plus `content_meta`. `hasFeature:` — which matched `Feature=` *and* bare / `GBF`- / `ThML`- / `UTF8`- / `OSIS`-prefixed `GlobalOptionFilter=` entries — was **baked as answers**, not inputs, into `module.<name>.features`.
> - `-setPreferences` → nothing. It pushed per-module prefs into SWORD as global options; the toggles write `UserDefaults` directly. Of its nine callers, three were wired and all three sat in the deliberately-unreachable `LANG_SECTION = 44`; six were dead code.
> - `-[PSModuleController reload]` / `removeModule` / the `primary*` `SwordModule` properties → deleted; the three primaries are **`String?` names** (`primaryBibleName` etc.), because every surviving consumer only read `.name`.
> - `+translateBookName:` / `+translateToSystemLocale:` → deleted. Verified identity for all 66 books on every device (there is no `en` locale conf, and `SWLocale(0)` has no `[Text]` section).
>
> If you need to see any of this, it is at `fa09511^`. Do not resurrect it into the target.

### App-level module layer (`Classes/PSModule*`, `Classes/PS*ViewController` — Swift)

- `PSModuleController` (singleton via `+defaultModuleController`) holds the **primary Bible / commentary / dictionary the user is currently reading, as `String?` names** (`primaryBibleName` / `primaryCommentaryName` / `primaryDictionaryName`), and builds the HTML shells (`+createHTMLString:…`, `+createInfoHTMLString:…`) and ref-string helpers. It no longer unpacks anything, has no `swordManager`, and has no `reload()` / `removeModule` / `setPreferences` — see the historical block above for why each went.
- `PSModuleViewController` is the shared base for `PSBibleViewController` and `PSCommentaryViewController`. Rendering happens in a `PSWebView` (a `WKWebView` subclass); tapped verses / Strong's lookups come back through the `PSWebViewDelegate` protocol (`@objc`, load-bearing — runtime dispatch), which the tab-bar delegate routes to `PSInfoPopupViewController`.
- `PSLaunchViewController` performs first-run bootstrap. **There is no seeding any more** — no zips, nothing written to `Documents/`. What it still does: `resetPreferences`, the insomnia pref, the `MMM` temp cleanup, and five one-shot migrations — `DefaultsModuleChoiceRetired`, `DefaultsGlobalFontOnly`, `DefaultsLastRefValidated`, `DefaultsDictKeyCaseFixed`, and `DefaultsSwordRetired`.
- **`DefaultsSwordRetired` is the upgrade path**, and it is the only thing standing between an upgrading user and ~18.7 MB of orphaned files. It deletes `Documents/{mods.d,modules,locales.d,unused}` and `<Caches>/InstallMgr`. Measured on a planted pre-Phase-5 container: `Documents/` 13 MB → 4 KB, idempotent on relaunch. **`PSBookmarks.plist` is at `Documents/` root** (`PSBookmarks.swift:46`), outside all four — verified safe, and it is the one piece of irreplaceable user data down there, so do not widen the sweep to `Documents/` itself. Deleting `Documents/modules` is also what removes the legacy search index. The `<Caches>/cache-*` lexicon key caches are **not** swept here — `DefaultsDictKeyCaseFixed` already does it.

### Tabs enum (stable ordinals)

`ShownTab` in `globals.h` is `BibleTab, CommentaryTab, DictionaryTab, DevotionalTab, DownloadsTab, PreferencesTab`. **`DevotionalTab` and `DownloadsTab` are dead placeholders** — the devotional and in-app download features have been removed — but the enum values are kept so that ordinals persisted in `NSUserDefaults` do not shift. Do not renumber or delete them.

### Display preferences (where they live, and why)

Display prefs are split by scope, and the split is **load-bearing**:

- **Per-module** prefs — the *content* toggles (Strong's, morph tags, headings, footnotes, cross-references, red-letter, verse-per-line) — live in the **per-tab `▾` menu** on the Bible and Commentary tabs (`PSModuleViewController.rebuildSettingsMenu()`). Each row writes `"<pref>_<ModuleName>"` keyed on the module's own `name`, gated on the **baked** feature set (`content_meta`'s `module.<name>.features`, via `PSContentStore.moduleHasFeature`). That set holds the *answers* `-[SwordModule hasFeature:]` gave, which also matched `GlobalOptionFilter` entries (bare and `OSIS`/`GBF`/`ThML`/`UTF8`-prefixed), not just `Feature=` lines — which is why KJV gets Footnotes/Headings/RedLetter rows despite declaring only `Feature=StrongsNumbers`.
  - **KJV shows exactly SIX rows**, verified against the live engine before deletion and on-device: Strong's Numbers, Morphological Tags, Headings, Footnotes, Red Letter, Verse Per Line. **Cross-references is *not* among them** and never was — KJV has no `OSISScripref` filter and no `Feature=Scripref`. Do not "fix" this into a behaviour change. (Its seventh baked feature is `Lemma`, which has no row.)
  - **MHCC declares neither, so its menu has no rows at all and the button hides itself** (`setSettingsMenu(nil)`) rather than presenting an empty menu. Confirmed on-device: the Commentary tab's nav bar has no Display Settings button.
- **Global** prefs — **font name + size** plus the device options — live in `PSPreferencesController` (2 sections: `DISPLAY = 0`, `DEVICE = 1`; `LANG_SECTION = 44` is deliberately out of range and unreachable). There is exactly **one** font for the whole app.

**Font is global, deliberately.** `createHTMLString` reads only the unsuffixed `fontNamePreference` / `fontSizePreference`; the per-module `"<fontpref>_<mod>"` override was removed when the picker moved out of the per-tab menus. The `DefaultsGlobalFontOnly` migration deletes the orphaned per-module font/size/defaults keys so they can't sit in the plist looking authoritative. `moduleName` is still passed to `createHTMLString`, but now only for the RTL check.

**The per-module content toggles stay per-module.** The original reason was mechanical: `-[SwordModule getChapter:]` called `-setPreferences`, which read the per-module keys off `self.name` and pushed them into SWORD as global options, so a toggle written to the global domain was silently clobbered on every render. `setPreferences` and SWORD are both gone, so that specific trap is too — but the *scope* is still right. The toggles are genuinely per-module (KJV has six, MHCC has none), and flattening them into global Preferences would mean one module's menu writing keys another module's render reads. Font is the deliberate exception, and always was.

> Historical note: the deleted `PSModulePreferencesController` derived its key from `self.tabBarController?.navigationItem.title`, which nothing had set since commit `5654f92` (Apr 2026) removed its only writer. It therefore read and wrote `"<pref>_"` and had been completely inert. The `DefaultsModuleChoiceRetired` migration deletes those orphaned keys rather than honouring them.

### Persistence

- User state: `NSUserDefaults` with `Defaults…` string keys in `globals.h` / `AppConstants.swift`. Per-module prefs use the key pattern `"<PrefName>_<ModuleName>"` — the Obj-C `GetBoolPrefForMod / SetBoolPrefForMod / …` macros and the Swift `UserDefaults.ps*(…forModule:)` extension must produce identical keys.
- Cross-device sync: reading history (`PSHistoryName = @"bibleHistory"`) is mirrored through `NSUbiquitousKeyValueStore`; `PSHistoryController` reconciles on the `NSUbiquitousKeyValueStoreDidChangeExternallyNotification` from the app delegate.
- Bookmarks live on disk at `DEFAULT_BOOKMARKS_PATH` — `Documents/PSBookmarks.plist`, at the **root** of `Documents/`. That placement is load-bearing for the `DefaultsSwordRetired` sweep, which deletes four *subdirectories* and would take the bookmarks with it if they moved.
- **Derived data lives in Caches**, not `Documents/`: the FTS search index at `<Caches>/search/<module>.db` and the lexicon key caches at `<Caches>/cache-<name>-<version>`. Both are rebuildable, which is what makes Caches the correct (and OS-purgeable) home.
- **The serialized shapes of history / bookmark / search-history objects are locked by `PersistedFormatTests.swift`.** Changing an array index, a hardcoded literal, or the pref-key format is a data-migration event — keep the tests green. Phase 5 changed **no** persisted format; those 18 tests were untouched throughout.

### Bundled content

The app ships **exactly five modules and no UI to add, remove, or pick one**: one Bible (KJV), one commentary (MHCC), and three fixed-role lexicons — `StrongsRealGreek` (`Feature=GreekDef`), `StrongsRealHebrew` (`HebrewDef`), `Robinson` (`GreekParse`). The roles are **not** interchangeable; they are hardcoded in the `BundledModules` enum in `AppConstants.swift`, which is the single source of truth for the set.

All five ship **inside `Resources/PSContent.sqlite`** (17.6 MB, 12.9 MB gzipped), with versification in `Resources/Versification-KJV.json`. Both are read-only bundled resources; **nothing is unpacked, and `Documents/` stays at 0 B on a fresh install.**

> Historical: they used to ship as six zips (`KJV.zip`, `MHCC.zip`, `Robinson.zip`, `strongsrealgreek.zip`, `strongsrealhebrew.zip`, `locales.d.zip` — 10.7 MB shipped, ~18.7 MB unpacked) which an idempotent loop seeded into `Documents/` on launch. Phase 5 step 9 deleted the zips and the seeding; step 10 deleted the `SSZipArchive`/minizip that unpacked them. `KJV.zip` also carried a dead 6.7 MB Lucene index — 64% of its uncompressed size — which finally went with it.

Several `NSUserDefaults` keys from that era are **retired**: the `DefaultsKJVRemoved` / `DefaultsMHCCRemoved` opt-out flags and the `DefaultsStrongsGreekModule` / `DefaultsStrongsHebrewModule` / `DefaultsMorphGreekModule` lexicon-role keys. They are still *declared* in `globals.h` / `AppConstants.swift` so the names cannot be reused, but are never read or written, and `DefaultsModuleChoiceRetired` clears any that are already set — a stale `*Removed` flag would otherwise suppress a bundled module forever now that there is no removal UI, and a lexicon key can legitimately hold the localized string `"None"`.

### URL handling

The app registers the `sword://` URL scheme (`CFBundleURLTypes` in `misc/Info.plist`). Incoming URLs are routed through `PocketSwordAppDelegate`'s open-URL handler; if a URL arrives during launch before the tab bar exists, the scene delegate caches it in `_pendingLaunchURL` and replays it from `finishedInitializingPocketSword:`.

This is **the only reference the app does not generate itself**, which is why `PSRefParser` exists at all and why it is deliberately wider than `PSBookOSISResolver.resolve(ref:)`. Four shapes, all verified on-device (`xcrun simctl openurl` is the way to drive them):

| URL | resolves to |
|---|---|
| `sword://Bible/John%203:16` | John 3:16 |
| `sword://KJV/Romans%208:28` | Romans 8:28 (module name as host) |
| `sword://Bible/Jude` | Jude 1:1 (chapter-less → 1:1) |
| `sword://Bible/Genesis%201:1.` | Genesis 1:1 (trailing period tolerated) |

A ref the parser cannot resolve is **ignored**, not guessed at: no navigation, no history entry, and one `alog` line (`"sword:// URL carries an unresolvable reference, ignoring: …"`). Anything that *persists* a parsed ref must additionally check the resolver can still resolve it, because the parser is the wider of the two — see the app delegate.

## Localization

Localization is **`.strings`-based** (programmatic UIKit — there are no XIBs), but the app ships **English only**. UI strings go through `NSLocalizedString(...)` and resolve against the single `en.lproj/Localizable.strings`, with `Settings.bundle/en.lproj/Root.strings` for the Settings pane. `en.lproj/Localizable.strings` is the source of truth for keys; add new keys there. The former non-English locale projects (`ar cs de es fr it ja ko nl pt ru sv th uk zh-Hans zh-Hant`) have been removed, and `knownRegions` / the `Localizable.strings` variant group in the pbxproj list only `en` — do not re-add other locales without a deliberate decision.

> The `gen_xib_strings.py` / `localize_xibs.py` scripts at the repo root were **dead XIB-era tooling** — they operated on `.xib` files, of which there are none — and Phase 5 step 13 deleted them. Do not resurrect them as "the localization flow"; there isn't one beyond editing `en.lproj/Localizable.strings`.
