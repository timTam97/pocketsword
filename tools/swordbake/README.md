# swordbake — offline SWORD content converter (Phase 2)

Throwaway macOS CLI that links the vendored SWORD engine and bakes the five
bundled modules into a SQLite content store plus a KJV versification dump.
Deleted in Phase 5 with `externals/sword`.

## Build & run

```sh
make            # build build/swordbake
make run        # unpack the shipped zips to a scratch dir, convert into ../../Resources
make verify     # convert twice, assert byte-identical output
make clean
```

`sword_sources.txt` is the list of 148 SWORD translation units, extracted from
the app's own Sources build phase in `project.pbxproj`, so the tool compiles
exactly the engine the app compiles. The two `.c` files (`ftplib.c`,
`ftpparse.c`) must be compiled as C, not C++.

## Output

- `Resources/PSContent.sqlite` — chapter blobs, headings, notes, lexicon
  entries, and the FTS build source. **schemaVersion 2 / tokenGrammar v2** as of
  Phase 3; `Classes/PSContentStore.swift` is the reader and refuses to open
  anything else, so the two must be changed together.
- `Resources/Versification-KJV.json` — 66 books, 1189 chapters, 31102 verses.

Both are deterministic: the same inputs produce byte-identical files.

## Self-checks (fail the build)

1. **Token round-trip.** Expanding every stored entry's tokens back through the
   same printf templates must reproduce the original rendered HTML byte-for-byte.
   This is what makes tokenisation as safe as storing baked HTML.
2. **No `passagestudy.jsp` remnants.** Any un-tokenised anchor would otherwise
   ship as a dead link.
3. **Post-compression validation.** Every chunk is inflated back out of SQLite and
   compared row-by-row against what went in, and the logical row totals are
   asserted against the Phase 2 measurements (31,102 / 27,715 `verses_plain`,
   6,959 notes, 1,526 / 5,624 / 8,674 dict keys, 1,189 + 1,189 chapters), plus a
   SQL check that no `verses_plain` row points outside its chunk. A compression bug
   has to fail the bake, not the reader.

## Things the engine does that the store has to respect

- `renderText` runs the `UTF8HTML` encoding filter (entity-escapes every
  non-ASCII byte to `&#960;`); `stripText` does not. So the HTML columns are
  entity-escaped and the plain-text columns are raw UTF-8.
- `getChapter`'s loop counter is not the verse number, so the store keeps the
  loop's *input sequence* (empties preserved) rather than its output.
- Rendering happens with Headings **On**: 1,250 of KJV's `<title>` tags live in
  intro-only slots and are only emitted into the body when the option is on.
  The 138 canonical Psalm titles never reach the body and are dumped from
  `EntryAttributes["Heading"]` instead.
- Lemmas is forced **Off** (KJV declares `GlobalOptionFilter=OSISLemma`; leaving
  it on emits ~145k garbage anchors).

## `stripText()` is captured with four options OFF (Phase 3 fix)

The bake renders chapter tokens with Strong's / morph / footnotes / cross-references
**On** — the anchors are the point. But `stripText()` interleaves that same markup
into the *plain* text, so capturing the FTS source under the same config put junk in
the search index:

- morph markers in the parenthesised form (`"God created (8804) the heaven"`) in
  **21,175 of 30,862** KJV rows. `PSSearchCleanDisplayText`'s regex is
  angle-bracket-only, so these passed straight through.
- whole footnote bodies, HTML tags included — Gen 1:4 gained
  `"[<i>the light from…</i>: Heb. <i>between the light and between the darkness</i>]"`.

So the FTS capture now turns all four Off and restores them **unconditionally**
afterwards, including on the empty-text path — leaving any of them Off would silently
strip the anchors from every later chapter's tokens.

Neither bug was visible to any fixture. Both were found by `PSSearchIndexParityTests`
diffing a store-built FTS index against an engine-built one, row by row.

## Findings worth carrying into Phase 3

- **A fifth `passagestudy` emission site.** `osishtmlhref.cpp:327` emits a
  `showRef`/`scripRef` anchor for every `<reference>` tag. It is *not*
  option-gated, uses raw `&` separators rather than `&amp;`, and emits only the
  opening tag. KJV verse bodies contain none, but the canonical Psalm titles do.
- **`StrongsRealHebrew` has two duplicate keys on disk** (`02200`, `06401`); for
  `06401` the second is a 21-byte `</dictionary>` stub. First occurrence wins.
- **`verses_plain` is 31,102 rows for KJV**, not the 32,359 the plan estimated —
  the smaller figure matches today's index build exactly (verified against a
  replica of `-buildWithProgress:`).
- **`SWLD::strongsPad` drops a leading `G`/`H` without re-prepending it**
  (`swld.cpp:134`), so `"H430"` pads to `"0430"` and `rawstr4.cpp:234-241` then
  snaps to a *neighbouring* entry with no error set. Phase 3 must reimplement
  this returning nil on a miss.
- `externals/sword/include/zlib.h` is zlib **1.1.4** and shadows the SDK header,
  so `compressBound` is not declared through it. The app has the same skew but
  only calls `compress2`/`uncompress`, whose signatures never changed.

## Cross-check (the Phase 2 exit criterion)

```sh
python3 tools/swordbake/crosscheck.py
```

Expands each stored chapter's tokens, replays `-[SwordModule chapterBodyHTML:…]`'s
accumulator loop over the result, and diffs against the fixtures
`SwordOracleCaptureTests` captured from the live engine on the simulator.

The two sides share no code — one is C++ writing SQLite, the other Swift calling
SWORD — so a pass means the store holds the right entries, in the right order,
with the right bytes. That is what the converter's internal round-trip check
*cannot* tell you: it is self-referential and would still pass if the wrong
entries had been captured, or captured out of order.

Verified to be a real gate: swapping two same-length records inside a chapter
makes it fail with the byte offset and exit non-zero.

## Artifacts and the app bundle

Both artifacts **are** in the app's Copy Resources phase as of Phase 3, and the app
reads them through `Classes/PSContentStore.swift`. They are bundled by path, so
re-running `make run` replaces them in place with no pbxproj change.

## Size

Measured with `dbstat` (per-table on-disk pages, not the sum of column lengths),
after the Phase 3 schema-v2 chunk compression:

| section | on disk |
|---|---|
| `plain_texts_chunks` (the FTS build source) | 5.44 MB |
| `chapters` + `bodies` (zlib per chapter/body) | 6.37 MB |
| `verses_plain` + `idx_vp` (the FTS skeleton) | 2.91 MB |
| `dict_chunks` + `dict_keys` + its index | 2.09 MB |
| `notes_chunks` + `notes_index` + its index | 0.50 MB |
| `headings`, `content_meta`, autoindexes, misc | 0.25 MB |
| **total file** | **17.6 MB** (12.9 MB gzipped) |

Down from 43 MB (14.2 MB gzipped) at the end of Phase 2. Honest framing: the App
Store ships a compressed IPA, so the *download* delta is ~1.3 MB; the real win is
~25 MB on disk.

Chunk sizes are per access pattern, not uniform: `plain_texts` 256 rows (walked in
bulk by the index build), `dict_entries` 64 (one key per lexicon tap, so keep the
per-lookup inflate cheap), `notes` 256. `chapters`/`bodies` are deliberately **not**
re-compressed — Phase 2 measured zstd at 3% better / 1% worse on blobs already
zlib'd per chapter, which is not worth a new dependency.

> **Retracted: "drop `plain_texts` and derive it on device".**
> Phase 2 recommended this and Phase 3 decided against it. The derivation would be a
> second, untested implementation of `stripText()` plus the `Word`-attribute walk, and
> a bug in it does not crash — search results just quietly go missing. Chunking gets
> the same ~5x on that table while the column stays byte-for-byte what the live engine
> emitted, which is what the whole oracle strategy depends on. Phase 3 then found two
> real defects in exactly that column (see above), which is the argument made concrete.
> See `SWORD_REMOVAL_PLAN.md` §5.6.
