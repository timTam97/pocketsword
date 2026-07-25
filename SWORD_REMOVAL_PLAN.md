# PocketSword SWORD-Removal Plan (Direction + Phasing)

> Status: direction agreed, ready to break into per-phase plans. Goal: **eliminate the CrossWire SWORD C++ engine and its Obj-C++ bridge**, leaving a pure-Swift app serving a fixed set of bundled modules. This is a *simplification* project — the win is measured in deleted code, not added features.
>
> This doc is intentionally lighter than `SWIFT_MIGRATION_PLAN.md`. It fixes the target architecture, the phase ordering, and the load-bearing risks. Each phase is meant to be picked up in its own session, planned in detail there, and implemented independently.
>
> **Adopted assumptions (override any):** the app ships **exactly one module per type** long-term (no module choice); there is **no user module-install path** (confirmed — no `UIFileSharingEnabled`, no `CFBundleDocumentTypes`, CURL/download UI already removed); the reading pane stays a **`WKWebView`**; SWORD is kept only as an **offline build-time tool**, never shipped; work happens on a dedicated branch off `main`, integrated separately; `PersistedFormatTests.swift` stays green throughout.

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

1. **Bundled content store (SQLite).** Produced offline (Phase 2). Tables roughly:
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

### Phase 1 — Remove module choice (still on SWORD)

Pure deletion; lowest risk; **most valuable first step** because it shrinks the contract everything later must satisfy. Still fully backed by SWORD — no engine work yet.

- Collapse `SwordManager` usage to "the one bundled module per type." Removes/guts `modules(forType:)`, `modules(forFeature:)`, `listModules`, `moduleNames`, install/remove, `augmentModules`, the first-run multi-zip bootstrap in `PSLaunchViewController`.
- Delete `PSModuleSelectorController`, `PSPreferencesModuleSelectorTableViewController`, and the module-picker entry points in `PSTabBarControllerDelegate` / preferences.
- Decide the canonical set (assumed: KJV + one commentary + Strong's Greek/Hebrew + Robinson morph). Everything else stops shipping.
- Keep `DefaultsKJVRemoved`-style keys only if still meaningful; otherwise retire them carefully (persisted-format territory — check the tests).

### Phase 2 — Offline converter (SWORD as a build tool)

A throwaway tool (macOS CLI or a dev-only build mode) that links SWORD once and emits the SQLite content store from §2.1.

- Drive each module's own `VerseKey` (TOP→BOTTOM, `++`), call `renderText` for HTML and `stripText` for the FTS source, pull `getEntryAttributes()` for headings / footnotes / xrefs / per-word Strong's.
- Emit deterministic, byte-stable output so it's diffable.
- Also dump the **KJV versification table** (book list, chapter counts, verse counts, OSIS names) as a bundled JSON/plist for Phase 4.
- This is where *all* remaining SWORD API use concentrates before it's discarded.

### Phase 3 — Swift content reader (replace the facades)

Introduce the thin Swift reader (§2.2) behind the existing method names. Cut over `PSModuleController` / `PSModuleViewController` / dictionary VCs to it. SWORD is still in the tree as a fallback/oracle during this phase — do **not** delete it yet.

- Verify by diffing reader output against live SWORD `getChapter` / `entry(forKey:)` / `attributeValue(forEntryData:)`, verse-by-verse and key-by-key.
- Search: point `PSSearchEngine`'s index build at the SQLite plain-text source instead of `stripText()`; FTS5 query side is unchanged. The lone query-time `osisBookNameForLocalisedBookName:` call moves to the Phase-4 parser.

### Phase 4 — KJV reference parser + versification (replace VerseKey)

Pure Swift; the one genuinely new algorithm. Bounded because it's KJV-only.

- Load the Phase-2 versification table.
- Free-text ref parse (`"Jn 3:16"`, ranges, abbreviations) → canonical OSIS; round-trip back to display strings; chapter/verse bounds; next/prev navigation.
- Replaces `SwordBook` (ref selector, chapter/verse selectors, voice-ref gazetteer) and the internal `VerseKey`/`ListKey` semantics.
- Lock behavior with tests in the `PersistedFormatTests` spirit (this is correctness-sensitive and user-visible).

### Phase 5 — Excise SWORD + C++ build wiring

Once Phases 3–4 are proven, delete the engine and the interop machinery.

- Remove `externals/sword`, `Sword*.{h,mm,+Cpp.h}`, the SWORD parts of `PSSearchEngine.mm`, `VerseEnumerator.{h,mm}`.
- Remove C++ from the build: prune `misc/PocketSword_Prefix.pch` C++ knobs, `-licucore`, `c++0x`, the bridging header's SWORD imports, `SWIFT_OBJC_INTERFACE_HEADER_NAME` usage if no Obj-C remains.
- Likely remove `externals/ZipArchive` + `minizip` (confirm nothing else unzips at runtime).
- Rebuild the bundled `KJV.zip` etc. as the SQLite store (drops the dead Lucene index).
- Target should now be **pure Swift** — update `CLAUDE.md` (the whole "SWORD bridge / interop mechanics" sections become historical).

### Orthogonal (unsequenced) — bookmarks / iCloud sync removal

Not on the SWORD critical path. `PSHistoryController` only reads `name`/`type` off the primary module; bookmarks/sync barely touch the engine. Remove whenever convenient — just don't let them block the C++ removal. Each is its own persisted-format event (mind the tests).

---

## 4. Risk register

- **Rendering fidelity (highest).** The pre-baked HTML must match the CSS-class/anchor vocabulary the existing shell + JS bridge expect, and the `sword://` / `passagestudy.jsp` link scheme decoded in `PSModuleController.data(forLink:)`. *Mitigation:* diff converter output against live SWORD before deleting the engine; the oracle exists until Phase 5.
- **Reference parser correctness.** User-visible, easy to get subtly wrong (abbreviations, ranges, cross-book). *Mitigation:* dump the truth table from SWORD; exhaustive tests.
- **Persisted-format drift.** Removing module choice / bookmarks / sync each touches `NSUserDefaults` keys and on-disk shapes locked by `PersistedFormatTests`. *Mitigation:* treat each as a migration; don't "fix" a red test — fix the code or write a real migration.
- **Hidden SWORD semantics.** e.g. auto-normalization of odd refs, intro handling (`setIntros`), verse-0 chapter headings. *Mitigation:* the converter must exercise the same edge inputs the app does (chapter intros, preverse headings) and the diff must cover them.
- **Scope creep back toward generality.** Any pressure to re-add module install invalidates the whole approach. *Mitigation:* the fixed-content assumption is stated up front; revisit the plan wholesale if it changes.

---

## 5. Assumptions adopted (defaults applied — override any)

1. One module per type, no user install, ever. (If false → this plan doesn't apply.)
2. Pre-render to HTML fragments + toggle via CSS, rather than storing structured data and rendering in Swift at runtime. (Simpler, matches the existing WebView; chosen for simplicity over flexibility.)
3. SQLite as the content store (reuses the existing sqlite3 dependency already used by search).
4. SWORD kept as an offline tool through Phase 4, deleted in Phase 5 — not removed early.
5. Bookmarks/iCloud removal is decoupled and unscheduled here.
