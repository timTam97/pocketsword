# PocketSword SWORD-Removal Plan (Direction + Phasing)

> Status: direction agreed, ready to break into per-phase plans. Goal: **eliminate the CrossWire SWORD C++ engine and its Obj-C++ bridge**, leaving a pure-Swift app serving a fixed set of bundled modules. This is a *simplification* project — the win is measured in deleted code, not added features.
>
> This doc is intentionally lighter than `SWIFT_MIGRATION_PLAN.md`. It fixes the target architecture, the phase ordering, and the load-bearing risks. Each phase is meant to be picked up in its own session, planned in detail there, and implemented independently.
>
> **Adopted assumptions (override any):** the app ships a **fixed module set** long-term (no module choice) — 1 Bible + 1 commentary + 3 fixed-role lexicons, per Phase 1; there is **no user module-install path** (confirmed — no `UIFileSharingEnabled`, no `CFBundleDocumentTypes`, CURL/download UI already removed); the reading pane stays a **`WKWebView`**; SWORD is kept only as an **offline build-time tool**, never shipped; work happens on a dedicated branch off `main`, integrated separately; `PersistedFormatTests.swift` stays green throughout.

---

## 1. Executive summary & core decision

PocketSword talks to SWORD only through Foundation-only Obj-C++ facades (`Sword*.{h,mm}`, `PSSearchEngine.mm`, `VerseEnumerator.mm`) — ~4.7k LOC of bridge over a 2.6 MB / ~42k-LOC vendored C++ engine in `externals/sword`. The Swift app never touches C++ directly; the app-facing contract is ~55 public members across 6 SWORD-backed classes.

### The single load-bearing decision

**Convert content once, offline — never render at runtime.** The hard two-thirds of SWORD is (a) the OSIS/ThML/GBF → HTML markup-filter chain and (b) the binary format drivers (zText/RawCom/zLD/RawLD4 + ZIP + cipher). We reimplement **neither**. Instead we run SWORD **once, on a dev machine**, to render every module into a bundled SQLite database of HTML fragments + extracted dictionary/footnote/xref data. The shipping app becomes "fetch HTML fragment → show in WebView," with zero C++.

This is only viable because the module set is fixed. If arbitrary user-installed modules were ever a requirement, this plan is wrong and you'd be back to reimplementing the SWORD driver + filter matrix at runtime (a multi-month effort). **Removing module choice is therefore a hard prerequisite, not a nice-to-have** — it is Phase 1 for exactly this reason.

### Strategy in one line

Delete-then-convert: strip module choice while still on SWORD (shrinks the contract), build an offline converter that bakes the 5 modules into a SQLite content store, replace the Obj-C++ facades with a thin Swift reader over that store, write a KJV-only reference parser to replace VerseKey semantics, then rip out `externals/sword`, the bridge, and the C++ build wiring. Verify every phase by diffing against live SWORD output — the engine itself is the oracle while it's still in the tree.

### What gets deleted at the end (the payoff)

`externals/sword` (~42k LOC), the entire `Sword*.{h,mm,+Cpp.h}` bridge (~4.7k LOC), almost all of `PSSearchEngine.mm`'s SWORD coupling, likely `externals/ZipArchive` + `minizip` (no runtime unzip once content ships as a DB), the C++ knobs in `misc/PocketSword_Prefix.pch`, `-licucore`, `c++0x`, the bridging-header / `+Cpp.h` / generated-header interop dance. **The mixed target becomes pure Swift.** Bonus: `KJV.zip` currently carries a dead ~6.7 MB Lucene index that vanishes with the rebuild.

---

## 2. Target architecture

Three runtime pieces replace the engine:

1. **Bundled content store (SQLite).** Produced offline (Phase 2). **Superseded by what Phase 2 actually built** — the per-verse `verses(module, osis_ref, ordinal, html)` shape below proved unaffordable (66.6 MB for KJV) and the real schema is tokenised and chapter-grain. See the Phase 2 status block and `tools/swordbake/README.md`. Kept here for the vocabulary it fixes:
   - `verses(module, osis_ref, ordinal, html)` — per-verse **rendered HTML fragment**, with Strong's / morph / heading / red-letter markup **always present** as classed anchors/spans (`a.verse`, `a.strongs`, `a.morph`, `a.x`, `a.n`, `span.WordOfChrist`, `blockquote.lg`, ruby). Ordinal = canonical order (drives search ranking too).
   - `verses_plain(module, osis_ref, text_plain, text_norm, lemmas, word_map)` — the FTS5 source; mirrors today's search columns so the search layer barely changes.
   - `dict_entries(module, key, html)` — pre-rendered Strong's / lexicon definitions.
   - `notes(module, osis_ref, type, marker, body, ref_list)` — footnote / cross-reference bodies + target ref lists, matching the `attributeValue(forEntryData:)` output shape.
2. **Thin Swift reader** behind the *same method names the app already calls* (so the app layer barely changes):
   - `getChapter(_:withExtraJS:)` → fetch the chapter's verse fragments, reapply the **app-side glue** (verse numbering, VPL formatting, bookmark-highlight injection, `pocketsword:versemenu:` anchors). Note: most of `SwordModule.mm:1164` `getChapter` is already app glue, not SWORD — that logic ports mostly as-is.
   - `entry(forKey:)` → a `SELECT` on `dict_entries`.
   - `attributeValue(forEntryData:)` → a `SELECT` on `notes`, returning the same `NSString` / `[{OutputRefKey,OutputTextKey}]` shapes.
3. **Runtime option toggles become CSS/JS, not re-rendering.** Because every markup class is pre-baked, Strong's / morph / headings / red-letter on-off become `display` toggles in the WebView's stylesheet. (Greek accents / Hebrew points / cantillation are moot: the only *reading* text is English KJV; Greek/Hebrew appears solely inside pre-rendered dictionary entries.)

Reference/versification (no SWORD): embed **one** KJV book/chapter/verse table (dumped from SWORD once) as a bundled resource, plus a Swift free-text reference parser (`"Jn 3:16"` → canonical OSIS) with range handling and round-tripping. This replaces all `VerseKey`/`ListKey`/`SwordBook` semantics — none of which have direct Swift call sites today, so only the *semantics* need to survive, not the classes.

---

## 3. Phase plan (dependency-ordered)

Each phase should ship independently and keep the app launchable + `PersistedFormatTests` green.

### Phase 1 — Remove module choice (still on SWORD) — ✅ DONE

> **Status: complete.** Landed as 7 build-green commits on `opus/sword-migration`. 28 tests green at every commit; fresh-install and upgrade scenarios hand-verified on the iPhone 17 simulator.
>
> **What shipped:**
> - The module set is fixed at **1 + 1 + 3**, not "one per type": KJV, MHCC, and three *non-interchangeable* lexicons — `StrongsRealGreek` (`GreekDef`), `StrongsRealHebrew` (`HebrewDef`), `Robinson` (`GreekParse`). Single source of truth: the `BundledModules` enum in `AppConstants.swift`.
> - Deleted `PSModuleSelectorController`, `PSPreferencesModuleSelectorTableViewController`, `PSModulePreferencesController`, `PSModuleType`, `PSLanguageCode` + `Resources/LanguageCodes.json`, `-[SwordModule langString]` / `-fullAboutText`, and the coordinator's `toggleModulesList` cluster — ~1,900 LOC + 158 KB.
> - `SwordManager` pruned: `modulesForFeature:`, `+managerWithPath:`, `-addPath:`, `-initWithSWMgr:`, `+moduleTypes`, `moduleListByType` / `moduleTypes` / `temporaryManager`. Kept `modulesForType:` / `listModules` / `moduleNames` / `moduleWithName:` / `isModuleInstalled:` (bootstrap + primary-module fallbacks).
>
> **Findings that correct this doc and the Phase-1 plan:**
> 1. `Documents/Built-in/` was already dead — all five zips seed into `Documents/`; `builtinModulePath` only deletes the legacy dir. `CLAUDE.md` claimed otherwise in two places (now fixed).
> 2. `+moduleCategoryAllowed:` is **not** unreachable (the Phase-1 plan said it was): `-refreshModules` calls it to keep glossary/essay dictionaries out of the list. Kept as an internal helper.
> 3. **The per-module preferences screen had been completely inert since Apr 2026.** It derived its pref key from `self.tabBarController?.navigationItem.title`, whose only writer (`PSModuleInfoViewController`) was deleted by `5654f92`, so it read/wrote `"<pref>_"` — keys the renderer never consults. Relocating those toggles into the per-tab `▾` menus (keyed on the module's own `name`) is therefore a **fix**, and a user-visible behaviour change: previously-dead switches now take effect.
> 4. The retired keys were **not** migrated forward, deliberately: `Defaults*Removed` flags would permanently suppress a bundled module with no UI left to clear them, and the lexicon keys can hold the localized string `"None"`. A one-shot `DefaultsModuleChoiceRetired` migration clears all of them plus the orphaned `"<pref>_"` garbage. Nothing in `PersistedFormatTests` pins these, so the upgrade path was hand-verified (swipe-delete MHCC + Robinson on the old build → both restored on the new one).
>
> **Deferred to Phase 5 as planned:** repacking `KJV.zip` to drop its dead 6.7 MB Lucene index.

### Phase 2 — Offline converter (SWORD as a build tool) — ✅ DONE

> **Status: complete.** Landed as 3 build-green commits on `opus/sword-migration`. 38 tests green (28 pre-existing + 10 new); reading, Strong's popup, search UI and commentary hand-verified on the iPhone 17 Pro simulator.
>
> **What shipped:**
> - `tools/swordbake/` — a standalone Makefile + Obj-C++ `main.mm`, **not** an Xcode target (the project has no shell-script build phases and a project-level `GCC_PREFIX_HEADER` that imports UIKit). `sword_sources.txt` holds the 148 SWORD translation units, extracted from the app's own Sources build phase, so the tool compiles exactly the engine the app compiles.
> - `Resources/PSContent.sqlite` + `Resources/Versification-KJV.json`, both byte-identical across runs (`make verify`). **Checked in but deliberately not bundled** — Phase 2 ships no rendering change, so adding 43 MB to the app now buys nothing. Phase 3 adds them to the Copy Resources phase when it cuts the reader over.
> - `Classes/SwordOracleCaptureTests.swift` + 19 fixtures under `Tests/Fixtures/`, captured from the live engine and asserted byte-for-byte on every subsequent run. Capture is opt-in via `PSORACLE_CAPTURE`.
> - `tools/swordbake/crosscheck.py` — the exit criterion (below).
>
> **Storage decision that overrides §2.1:** per-verse baked HTML is not affordable. KJV has 374k Strong's + 216k morph anchors at ~110 bytes each, so rendered per-verse KJV is 66.6 MB. Storage is instead **tokenised and chapter-grain** (12.3 MB raw / 3.2 MB zlib for KJV), and each chapter stores the **input sequence** of `getChapter`'s loop — empties preserved — rather than its output, because that loop's counter is not the verse number yet drives the `vv{i}` anchors, the `versemenu` links and the bookmark-highlight lookup. A verbatim Phase-3 port therefore reproduces the counter by construction.
>
> **Two converter self-checks fail the build:** expanding every stored entry's tokens back through the same templates must reproduce the original rendered HTML byte-for-byte (69,471 entries), and no `passagestudy.jsp` substring may survive tokenisation.
>
> **The exit criterion passed.** `crosscheck.py` expands each stored chapter, replays the accumulator loop, and diffs against the live-SWORD fixtures — two sides sharing no code (C++ writing SQLite vs Swift calling SWORD). All 11 chapter bodies reproduce byte-for-byte (including Ps 119's 177 entries, the canonical-heading path and MHCC's shared-body path) and all 14 sampled lexicon entries match. Confirmed to be a real gate by swapping two same-length records inside a chapter: it fails with the byte offset and exits non-zero.
>
> **Findings that correct this doc and the Phase-2 plan:**
> 1. **There is a fifth `passagestudy.jsp` emission site.** `osishtmlhref.cpp:327` emits a `showRef`/`scripRef` anchor for every `<reference>` tag. It is **not** option-gated, uses raw `&` separators rather than `&amp;`, and emits only the opening tag (the `</a>` comes from the end-tag branch). KJV verse bodies contain none.
>    **CORRECTED IN PHASE 4 (F1):** this finding went on to claim the canonical Psalm titles *do* carry such an anchor. **They do not.** Re-derived three independent ways — zero `action=showRef` across 122,380 record expansions plus all 1,322 stored headings, none in any of the 33 committed live-SWORD fixtures, and the only baked `sword://` links anywhere are 14,989 lexicon→lexicon ones. The emission site exists in the engine; no shipped content reaches it. That is what licensed deleting the `scriptRef` branch in Phase 4 step 8.
> 2. **`verses_plain` is 31,102 rows for KJV, not 32,359.** The smaller figure matches today's index build exactly, verified against a replica of `-buildWithProgress:`. The stored text also has `PSSearchCleanDisplayText` applied, as the app does before inserting. (Phase 2 stored these columns so the index build would be a pure copy loop; Phase 3 now derives them instead — see the size-reduction plan. The 31,102 figure still matters as the row count the derived path must reproduce.)
> 3. **`StrongsRealHebrew` has two duplicate keys on disk** (`02200`, `06401`); for `06401` the second occurrence is a 21-byte `</dictionary>` stub. `INSERT OR REPLACE` would have silently kept the stub, so first-occurrence wins and every collision is logged. 8,674 stored + 2 skipped = the 8,676 in the `.idx`.
> 4. **Gen 1's loop counter is 32, for 31 verses** — it starts at 0 on the verse-0 intro slot and increments at the bottom of every iteration including the one that steps out of the chapter, so it lands on `verses + 1`.
> 5. **The plan's suggested footnote passages carry no footnotes** (Gen 4:8, Gen 1:1, Ps 3:1). The fixture was silently empty until cross-checked against the store. Also confirmed: all 6,959 KJV notes are `type="study"` with an empty `refList`, so the `x` branch of `attributeValueForEntryData:` is unreachable for the shipped content.
> 6. `ftplib.c` / `ftpparse.c` must be compiled as **C**, not C++; and `externals/sword/include/zlib.h` is zlib **1.1.4**, which shadows the SDK header and lacks `compressBound`.
>
> **Confirmed as documented:** 148/148 engine sources compile clean for macOS; 1,189 KJV chapters; Gen.1 inflates to 32 records; 138 canonical Psalm titles and 1,250 non-canonical titles that need `Headings=On`; MHCC's 28,970 slots dedup to 4,435 distinct bodies; KJV emits zero `crossReference` notes; SWORD is 1.9.0.3837.
>
> **Carried into Phase 3:** `SWLD::strongsPad` (`swld.cpp:134`) drops a leading `G`/`H` without re-prepending it, so `"H430"` pads to `"0430"` and `rawstr4.cpp:234-241` snaps to a *neighbouring* entry with **no error set** — `entry(forKey: "H430")` returns entry 8674. Captured as a fixture so the Phase-3 fix (return nil on a miss) is not mistaken for a regression. The app is unaffected today because it passes the bare number.
>
> **Size.** The store is 43 MB on disk (14.2 MB gzipped, which is closer to what App Store download actually costs). Measured per-table with `dbstat`, not by summing column lengths:
>
> | section | on disk |
> |---|---|
> | `plain_texts` + `verses_plain` + `idx_vp` (the FTS build source) | 30.2 MB |
> | `dict_entries` (uncompressed HTML) | 5.0 MB |
> | `chapters` + `bodies` (already zlib per chapter/body) | 6.4 MB |
> | `notes`, `headings`, misc | 1.4 MB |
>
> Two-thirds is the search-index source, stored **uncompressed** — a consequence of the "no derivation logic on device" choice, which also meant no compression was applied there. Today's shipped zips total 10.7 MB, so as it stands this is a real download-size regression. **Phase 3 fixes it structurally — see the size-reduction plan there.**

### Phase 3 — Swift content reader (replace the facades) — ✅ DONE

The reader is in and the read paths are cut over to it. SWORD is still in the tree
as the in-process oracle; Phase 5 deletes it.

**What shipped**

| file | role |
|---|---|
| `Classes/PSContentStore.swift` | SQLite + chunk framing. Rows out, no HTML. |
| `Classes/PSBookOSISResolver.swift` | book name → OSIS, over `Versification-KJV.json` |
| `Classes/PSChapterExpander.swift` | tokens → the exact HTML the filters emitted, option-gated |
| `Classes/PSChapterAssembler.swift` | `-[SwordModule chapterBodyHTML:]`'s accumulator loop |
| `Classes/PSContentReader.swift` | the coordinator the view controllers talk to; failure policy |

Gated by `PSFeatureFlags.swiftContentReader`, **now default-on** (its own commit, so
it is revertible by itself). Removed in Phase 5.

**The acceptance criterion, met.** `PSDifferentialTests` renders both ways in one
process. Exhaustive tier (`PSDIFF_EXHAUSTIVE=1`), run before the flip:

- KJV 1,189 chapters × 2 option endpoints = **2,378** renders byte-identical, loop
  counter matching on every one
- MHCC 1,189 × 2 = **2,378** renders byte-identical
- **31,102** search-source rows identical

Fast tier, every `test` run: all **15,824** lexicon entries keyed as the UI keys
them, all **6,959** notes, a fixed strided chapter sample at both endpoints, plus
`PSSearchIndexParityTests` comparing an entire store-built FTS index against an
engine-built one row by row.

**Size: 43 MB → 17.6 MB**, against the ~11 MB this section previously projected (that projection assumed dropping `plain_texts` entirely — see the retraction below). Honest framing: gzipped
(which is what the App Store ships) it is 14.2 → 12.9 MB, so the *download* delta
is ~1.3 MB. The real win is ~25 MB on disk.

**Assumption 6 is retracted.** The FTS source is **shipped, chunk-compressed** —
not derived on device. Deriving `text_plain`/`lemmas`/`word_map` would be a second,
untested implementation of `stripText()` plus the `Word`-attribute walk, and a bug
in it does not crash: search results quietly go missing. Chunking gets the same ~5×
on that table (26.8 → 5.4 MB) while the column stays exactly what the live engine
emitted, which is the property the whole oracle strategy rests on. §5.6 is corrected
in place.

**Store schema v2 / token grammar v2**

- chunk-compressed `plain_texts_chunks` (256 rows), `dict_chunks` (64),
  `notes_chunks` (256); `chapters`/`bodies` left alone (Phase 2 measured zstd at 3%
  better / 1% worse on blobs already zlib'd per chapter)
- keys stay **uncompressed** in `dict_keys` / `notes_index`: the Dictionary tab
  drives its whole table off the key list, so `allKeys()`/`entryCount()` must not
  inflate anything
- `dict_keys.key COLLATE NOCASE` — load-bearing, see the findings below
- new recursive red-letter token `\x11…\x12`
- every chunk carries `row_count` + `raw_size`, checked on both sides rather than
  trusted; the bake re-inflates every chunk and compares, and asserts the logical
  row totals

#### Findings from Phase 3 (things the plan had wrong or did not know)

1. **`ORDER BY rowid` was NOT replaced with `ORDER BY ordinal`** (the plan said to).
   Verified a no-op: `verses_plain.ordinal` is strictly increasing and unique across
   all 31,102 rows and the cursor walks it in that order, so rowid order *is* ordinal
   order. Switching would need a new FTS column, a `PSSearchSchemaVersion` bump and a
   forced rebuild for every user, to buy nothing. A comment records the verification.

2. **The dictionary-casing bug (P1).** `SwordDictionary.mm:67` stores
   `[keyText capitalizedString]`, and `PSDictionaryViewController.swift:252` feeds
   *that mangled string* back into the lookup — altering 1,375 of Robinson's 1,526
   keys (`V-PAI-3S` → `V-Pai-3S`). It works today only because `Robinson.conf` omits
   `CaseSensitiveKeys`, so `RawStr::findOffset` uppercases both sides
   (`rawstr.cpp:188`). `COLLATE NOCASE` reproduces that exactly — safe because all
   15,824 keys are pure ASCII with zero case-fold collisions and rowid order == binary
   order == case-insensitive order. Verified to be a real gate: forcing the lookup
   case-sensitive fails with "1375 of 1526 UI-cased keys do not resolve".
   The wrong *display* casing was deliberately preserved here; **Phase 4 step 9 fixed
   it** (both producers now return true casing) and invalidated the on-disk key caches
   via the `DefaultsDictKeyCaseFixed` one-shot, as this note required. The
   `COLLATE NOCASE` stays as defence in depth.

3. **Two real bugs in the baked FTS text, found by the differential test, not by any
   fixture.** The converter captured `stripText()` under the config it uses for the
   chapter tokens (Strong's/morph/footnotes On), but `stripText()` interleaves that
   markup into the plain text: 21,175 of 30,862 KJV rows carried `(8804)`-style morph
   markers (the parenthesised form `PSSearchCleanDisplayText`'s angle-bracket regex
   does not strip), and footnote bodies leaked in wholesale — Gen 1:4 held
   `[<i>the light from…</i>: Heb. …]`, HTML tags included. The converter now takes
   `stripText()` with all four options Off and restores them unconditionally.

4. **`-buildWithProgress:` pins no global options at all**, so today's index *content*
   varies with the user's per-module toggles. The store fixes that by construction —
   the indexed text is the verse and nothing else, identically on every device — which
   is why the parity test pins the engine side rather than treating the ambient case as
   the contract.

5. **Titles are gated differently in a body and in a heading.** In a chapter record
   every title token is non-canonical (`osisheadings.cpp:132` keeps canonical preverse
   titles out of the body while `processEntryAttributes` is on), so
   `option || canonical` reduces to `option`; inside a stored heading the app renders
   via `renderText(buf)`, which turns `processEntryAttributes` off, so the canonical
   title's wrapper is emitted whatever the option says. One flat token→option table
   gets eight of the ten all-off fixtures wrong.

6. **`setPreferences` pushes eleven options, not six** — and only five have a token to
   gate. `variants` is pinned to Primary Reading; `glosses`/`greekAccents`/
   `hebrewPoints`/`hebrewCantillation` act on source text and their filters are not
   even in KJV/MHCC's chains. That is the one place the reader is narrower than the
   engine, and it is recorded in `PSContentReader`.

7. **The footnote `passage` arrives URL-encoded** (`passage=Genesis+4%3A1`);
   `data(forLink:)` splits the query without decoding it, unlike its own `sword://`
   branch. `VerseKey::setText` tolerates that, a SQL lookup does not.

8. **`sqlite3_bind_text` from Swift needs SQLITE_TRANSIENT.** The bridged
   `const char *` is valid only for the call, so the default SQLITE_STATIC leaves a
   dangling pointer — and the symptom is not a crash, every query silently matches
   nothing.

9. **The Dictionary tab's key-cache prompt made the tab unusable** with the reader on
   (answering "No" left it showing "No dictionary loaded" while the reader had the keys
   in hand). The prompt exists only because `-allKeys` walks the module from TOP; it is
   skipped when the reader is active. Found by driving the simulator.

10. **`kExpected` was 32000 against an actual 31,102**, so the index-build progress bar
    never got past ~97%. Fixed.

11. **One expected reader/SWORD difference, asserted rather than tolerated.**
    `StrongsRealHebrew` has two on-disk entries each for `02200` and `06401`, and
    `06401`'s second is a 21-byte `</dictionary>` stub. The converter keeps the first,
    so the reader returns the real definition while SWORD returns the stub — the reader
    is *better*. Consequence found by the test: `-allKeys` yields **15,826** keys, not
    15,824, because both duplicated keys appear twice.

**Still on SWORD after Phase 3** (Phase 4 work — all now ✅ done, see the Phase 4
block below): `attributeValue(forEntryData:)`'s `scriptRef` and `x` branches
(believed to need range resolution via `parseVerseList`; Phase 4 found both
unreachable and deleted them instead), versification / `SwordBook` / ref parsing,
`osisBookNameForLocalisedBookName:`, and the Robinson display-casing fix. The module zips must also keep seeding into
`Documents/` for now, because `PSSearchEngine` derives its db path from
`AbsoluteDataPath` and `hasFeature:` reads the module `.conf`.

### Phase 4 — KJV reference parser + versification (replace VerseKey) — ✅ DONE

Pure Swift over the already-bundled `Resources/Versification-KJV.json`. Landed as 11
commits, one sub-area each; every commit builds and leaves the default suite green.
**Tests: 73 → 96 default** (7 env-gated), the new ones in `PSRefSemanticsTests`.

What landed: `PSBookOSISResolver` extended into the whole versification layer
(`book(at:)`, `verseMax`, `nextChapter`/`previousChapter`, `displayRef`); new
`PSRefParser` (bounded grammar, one production caller) and `PSRefLinkRouter`
(routing predicate as a pure function); the four selector VCs, the voice gazetteer,
the search book-scope filter and chapter next/prev all moved off SWORD; the locale
round-trip retired; `x`/`scriptRef` deleted; the Robinson display-casing bug fixed;
`SwordBook` + `+booksForVersificationSystem:` deleted.

#### Findings that shaped the work (all measured, not assumed)

**F1. `scriptRef` is unreachable for the shipped content, exactly like `x` — and
this *corrects* Phase-2 finding 1 below.** That finding claimed canonical Psalm
titles carry the un-option-gated `osishtmlhref.cpp:327` `showRef` anchor. **They do
not.** Re-derived from the store on every test run: zero `action=showRef` across
122,380 record expansions (all 1,189 chapters × both modules × both option
endpoints) **plus all 1,322 stored headings** — the axis a blob-shaped scan misses,
because `headings.html` is a text column, not a blob. None of the 33 committed
live-SWORD fixtures contains one either. The only baked `sword://` links anywhere
are 14,989 lexicon→lexicon (`StrongsRealHebrew` 8,244 + `StrongsRealGreek` 6,745),
and all 14,989 route to the **dictionary** arm of the web delegates, asserted
through the `PSRefLinkRouter` seam. `x` is dead twice over: no `x` anchor is ever
emitted, *and* all 6,959 notes are `type='study'` with an empty `refList`.

**F2. `entry_count == verseMax[chapter-1] + 1` for all 1,189 chapters**, zero
exceptions — so a chapter record's slot index **is** the verse number (slot 0 is the
verse-0 intro). That is what let `testCaptureScriptRefAttributes` be *retargeted* at
`PSRefParser` + `PSChapterExpander` with the fixture byte-unchanged, rather than
deleted.

**F3. `+translateBookName:` / `+translateToSystemLocale:` are identity for every
input on every device.** There is no `en` locale conf (all 118 in `locales.d.zip`
checked); the only English locale is `SWLocale(0)` (`swlocale.cpp:63-69`), built
with `SWConfig(0)`, which has no `[Text]` section, so `translate` returns its input.
Asserted 66/66. The "translate back to English" comment at `SwordManager.mm`
described an intention the code never implemented.

**F4. `content_meta` already carries the module versions that name the key-cache
files** (`Robinson 2.0`, `StrongsRealGreek 1.5-150704`, `StrongsRealHebrew
1.090107`), byte-identical to the `Version=` conf entries — so the cache migration
needs no `SwordDictionary` and no SWORD call, and survives Phase 5.

**F5. `Versification-KJV.json` reproduces `SwordBook`'s munges byte-exactly.**
`name == munge(localisedName)` 66/66; `shortName == despace+first3(name)` 66/66 with
both collisions intact; ΣΣ verseMax = 31,102. No re-munging needed.

#### Two traps, both confirmed in the engine source and handled

- **SWORD *clamps* at the canon boundaries, it does not error.** `normalize`
  (`versekey.cpp:1466-1493`) pins to the bound and only sets `KEYERR_OUTOFBOUNDS`,
  so `-setToNextChapter` at Rev 22 returned *the ref it was given*, and the callers'
  string-equality gate is what turned that into a no-op. The table returns **nil**
  instead; returning the clamped ref would turn a no-op into a full re-render.
- **`setToNextChapter` returns the un-munged `longName` form.** `freshtext`
  (`versekey.cpp:378`) builds key text from `getBookName()` = identity here, so the
  raw return is `"Revelation of John 22"` and callers munge it downstream. 18 of 66
  books have `name != longName`.

#### Bugs found and fixed along the way (none were in the plan)

1. **`-[SwordModule chapterBodyHTML:]` leaked the verse key's `intros` flag on** —
   it set it and never restored it, unlike `-getChapter:`. Invisible in the app
   (only `-getChapter:` calls it, and that restores), but the differential and
   oracle tests call it directly on the same singleton module, and with intros on
   `normalize` treats chapter 0 as valid so `"Genesis 50" + 1` is `"Exodus 0"`. All
   65 book-boundary transitions shift. Now saved/restored, and the navigation tests
   pin the flag rather than relying on the fix.
2. **The inbound `sword://` path persisted unvalidated refs** to `Defaults.lastRef`
   (`sword://KJV/Nonsense+9:9` → `"Nonsense 9"`), and persisted a chapter-less
   `"John"` for `sword:///John`. Both now go through `PSRefParser`.
3. **`PSRefParser` is wider than `PSBookOSISResolver.resolve(ref:)`**, so accepting
   a ref was not enough: `sword://KJV/Gen.+1` parsed and persisted the unresolvable
   `"Gen. 1"` (462 such spelling×shape combinations). The delegate now falls back to
   the parser's canonical `name`-form ref whenever the URL's own spelling is not
   reader-resolvable.
4. **The `"Jud"` abbreviation genuinely disagrees** — Judges for us (first-writer-wins
   over canonical order, which is what the ref-selector strip does), Jude for SWORD
   (prefix match over `canon_abbrevs.h:429-430`). Kept, and asserted as an exact
   expected set. `"Phi"` does *not* diverge.

#### Known issues left open

- **The pushed dictionary-entry view renders a blank body** (correct title, no
  text). Verified pre-existing by stashing back to the step-8 build: identical blank
  body there with the old mangled title, so it predates Phase 4 entirely. It is in
  `PSDictionaryEntryViewController`'s `loadView`/web-view lifecycle, not the key
  lookup. Worth its own commit.
- **`PSModuleSearchController` restores `searchRange` from defaults but leaves
  `bookName` nil**, and only `-scopeControlChanged:` populates it — so a *persisted*
  scope=Book silently searches the whole Bible until the user taps the segment again.
  Pre-existing and unrelated to versification.

#### Deliberately out of scope, still for Phase 5

`hasFeature:` · `AbsoluteDataPath` / the search-index db path · the `Documents/`
module seeding and the five zips · `locales.d.zip` seeding, `+initLocale`,
`+translateBookName:`, `+translateToSystemLocale:` (Phase 4 removed 2 of 4 *callers*)
· `PSSearchEngine`'s SWORD fallback index build ·
`PSFeatureFlags.swiftContentReader` and the reader's ten nil-returns →
hard failures · `+[SwordModule chapterNavigationJSWithEntryCount:extraJS:]` (move,
do not copy) · `SwordKey`/`SwordVerseKey`/`SwordListKey`/`VerseEnumerator` ·
`-setChapter:`/`-setToNextChapter`/`-setToPreviousChapter`/`-getVerseMax`/
`-setIntroductions:`, which now have **no production callers** and survive only as
`PSRefSemanticsTests`' oracle.

#### Verification performed

- **Full clean build** (DerivedData wiped): 174 CompileC + 77 SwiftCompile, no
  errors — the proof that the bridging-header graph is still clean with `SwordBook`
  gone from both headers.
- **Both exhaustive tiers re-run at step 10, 31/31 passed, 0 skipped:**
  `PSRefSemanticsTests` — 62,204 verses vs `VerseKey` (31,102 × both name forms),
  31,102 parser round-trips, 1,189 parser-vs-resolver agreements, 424 abbreviation
  forms agreeing (33 rejected as out-of-scope, 2 collisions);
  `PSDifferentialTests` — KJV 2,378 chapters, MHCC 2,378, 31,102 search-source rows.
- **Simulator (iPhone 17 Pro)** at every cutover: ref-selector strip incl.
  scroll-to-current; chapter/verse selectors (Judges 21 chapters, Judges 7 25
  verses); jump-to-1:1; next/prev at Mal 4→Matt 1 and both greyed-out boundaries;
  search scope=All 16 results vs scope=Book 3 (all 1 John) from the abbreviated
  `"1 Joh"`; Strong's tap in a chapter **and** inside a lexicon entry; the
  localised-`lastRef` migration firing on a seeded container; `sword://` good, bad,
  chapter-less and trailing-period URLs; the Dictionary tab showing true-cased
  `V-PAI-3S` after a planted mangled cache was cleared, and searching then tapping a
  result.

### Phase 5 — Excise SWORD + C++ build wiring

Once Phases 3–4 are proven, delete the engine and the interop machinery.

- Remove `externals/sword`, `Sword*.{h,mm,+Cpp.h}`, the SWORD parts of `PSSearchEngine.mm`, `VerseEnumerator.{h,mm}`.
- Remove C++ from the build: prune `misc/PocketSword_Prefix.pch` C++ knobs, `-licucore`, `c++0x`, the bridging header's SWORD imports, `SWIFT_OBJC_INTERFACE_HEADER_NAME` usage if no Obj-C remains.
- Likely remove `externals/ZipArchive` + `minizip` (confirm nothing else unzips at runtime). **Note:** if Phase 3 adopts chunk-compressed `dict_entries`/`notes`, the app needs *a* decompressor at runtime — but zlib (`-lz`) or the system `Compression` framework covers that; it does not require keeping ZipArchive/minizip, which exist only for the module zips.
- Delete the bundled module zips (`KJV.zip`, `MHCC.zip`, `Robinson.zip`, `strongsrealgreek.zip`, `strongsrealhebrew.zip`) and the `Documents/` seeding path — the SQLite store replaces them. This is where the dead 6.7 MB Lucene index inside `KJV.zip` finally goes. Keep `locales.d.zip` only if anything still reads it after Phase 4 retires `LocaleMgr`.
- Re-check the store size here: Phase 3 landed at **17.6 MB** on disk (12.9 MB gzipped) against the 10.7 MB of zips removed, so the app comes out ~7 MB heavier on disk and roughly flat as a download. If that matters, the remaining lever is the ~5.4 MB `plain_texts_chunks` — but see §5.6 for why deriving it instead was rejected.
- Remove `PSFeatureFlags.swiftContentReader` and its pref key.
- **Convert the reader's fallback conditions to hard failures.** `PSContentReader.swift`'s header lists all ten (missing/unopenable store, schema or grammar mismatch, absent chunk sizes, bad versification, chunk that fails to inflate or whose counters disagree, chapter record count mismatch, unresolvable MHCC body id, malformed token stream, unresolvable book, index row pointing off its chunk). Today each returns nil and falls back to SWORD; with the engine gone there is nothing to fall back to, so each needs to become a loud failure rather than a silent blank.
- Move `+[SwordModule chapterNavigationJSWithEntryCount:extraJS:]` (4 KB of pure JS, no SWORD dependency) into Swift rather than copying it — Phase 3 deliberately kept one copy that both paths call.
- Target should now be **pure Swift** — update `CLAUDE.md` (the whole "SWORD bridge / interop mechanics" sections become historical).

### Orthogonal (unsequenced) — bookmarks / iCloud sync removal

Not on the SWORD critical path. `PSHistoryController` only reads `name`/`type` off the primary module; bookmarks/sync barely touch the engine. Remove whenever convenient — just don't let them block the C++ removal. Each is its own persisted-format event (mind the tests).

---

## 4. Risk register

- **Rendering fidelity (highest).** ✅ **Discharged in Phase 3.** All 1,189 chapters of both shipped modules, at both option endpoints, render byte-identically to the live engine (`PSDifferentialTests`, exhaustive tier), plus all 15,824 lexicon entries, all 6,959 notes and all 31,102 search-source rows. The oracle stays until Phase 5, and the exhaustive tier must be re-run before it is deleted.
- **Fixture-shaped testing (new, and it bit).** Three of Phase 3's real defects were invisible to fixtures and only showed up in differential or on-device testing: the Robinson casing bug (fixtures fed hardcoded true-cased keys the UI never produces), the morph/footnote leakage into the FTS text (no fixture covered that column), and the Dictionary cache prompt (only visible by driving the app). *Mitigation, now standing:* enumerate the inputs the *UI* produces, diff whole corpora rather than samples, and drive the simulator on a wiped container before believing a cutover.
- **Reference parser correctness.** User-visible, easy to get subtly wrong (abbreviations, ranges, cross-book). *Mitigation:* dump the truth table from SWORD; exhaustive tests.
- **Persisted-format drift.** Removing module choice / bookmarks / sync each touches `NSUserDefaults` keys and on-disk shapes locked by `PersistedFormatTests`. *Mitigation:* treat each as a migration; don't "fix" a red test — fix the code or write a real migration.
- **Hidden SWORD semantics.** e.g. auto-normalization of odd refs, intro handling (`setIntros`), verse-0 chapter headings. *Mitigation:* the converter must exercise the same edge inputs the app does (chapter intros, preverse headings) and the diff must cover them.
- **Scope creep back toward generality.** Any pressure to re-add module install invalidates the whole approach. *Mitigation:* the fixed-content assumption is stated up front; revisit the plan wholesale if it changes.

---

## 5. Assumptions adopted (defaults applied — override any)

1. A fixed module set, no user install, ever. (If false → this plan doesn't apply.) **Refined by Phase 1:** the set is 1 Bible + 1 commentary + **3** fixed-role lexicons, not one module per type — the Greek-def / Hebrew-def / Greek-parse lexicons are not interchangeable.
2. Pre-render to HTML fragments + toggle via CSS, rather than storing structured data and rendering in Swift at runtime. (Simpler, matches the existing WebView; chosen for simplicity over flexibility.)
3. SQLite as the content store (reuses the existing sqlite3 dependency already used by search).
4. SWORD kept as an offline tool through Phase 4, deleted in Phase 5 — not removed early.
5. Bookmarks/iCloud removal is decoupled and unscheduled here.
6. ~~**The FTS source is derived on device, not shipped.**~~ **RETRACTED in Phase 3.** The source is **shipped, chunk-compressed**. Deriving `text_plain`/`lemmas`/`word_map` on device would be a second, untested implementation of `stripText()` plus the `Word`-attribute walk, and a derivation bug does not crash — search results quietly go missing. Chunking gets the same ~5x on that table (26.8 -> 5.4 MB) while the column stays byte-for-byte what the live engine emitted, which is the property the whole oracle strategy rests on. Phase 3 also demonstrated the risk was not hypothetical: the differential test found two real defects in that column (morph markers and footnote bodies leaking into the indexed text) that no fixture caught. Final size 43 -> 17.6 MB on disk, 14.2 -> 12.9 MB gzipped.
