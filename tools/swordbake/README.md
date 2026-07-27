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
  entries, and the FTS build source.
- `Resources/Versification-KJV.json` — 66 books, 1189 chapters, 31102 verses.

Both are deterministic: the same inputs produce byte-identical files.

## Self-checks (fail the build)

1. **Token round-trip.** Expanding every stored entry's tokens back through the
   same printf templates must reproduce the original rendered HTML byte-for-byte.
   This is what makes tokenisation as safe as storing baked HTML.
2. **No `passagestudy.jsp` remnants.** Any un-tokenised anchor would otherwise
   ship as a dead link.

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

`Resources/PSContent.sqlite` and `Resources/Versification-KJV.json` are checked
in but **deliberately not added to the app's Copy Resources phase**. Phase 2
ships no rendering change, so bundling them now would add 43 MB to the app for
no benefit. Phase 3 adds them to the bundle when it cuts the reader over.

## Size, and the schema change Phase 3 will make

Measured with `dbstat` (per-table on-disk pages, not the sum of column lengths):

| section | on disk |
|---|---|
| `plain_texts` + `verses_plain` + `idx_vp` (the FTS build source) | 30.2 MB |
| `dict_entries` (uncompressed HTML) | 5.0 MB |
| `chapters` + `bodies` (already zlib per chapter/body) | 6.4 MB |
| `notes`, `headings`, misc | 1.4 MB |
| **total file** | **43 MB** (14.2 MB gzipped) |

> **Decided: `plain_texts` goes away in Phase 3.** It exists only so the
> on-device index build could be a pure copy loop, and it costs two-thirds of the
> artifact. All three of its columns are mechanically derivable from the chapter
> tokens, so Phase 3 drops the table and derives them at index-build time
> (43 → 15.7 MB), then chunk-compresses `dict_entries`/`notes` (→ ~11 MB, level
> with the 10.7 MB of zips being replaced). The owner has accepted the on-device
> index-build cost. Full plan, including the measurements that ruled out per-row
> compression and re-compressing `chapters` with zstd, is in
> `SWORD_REMOVAL_PLAN.md` under Phase 3.
>
> **If you are regenerating the store for Phase 3:** before dropping the columns,
> dump `text_plain` / `lemmas` / `word_map` for a verse corpus as fixtures. The
> Swift derivation must reproduce them byte-for-byte, and a derivation bug does
> not crash — search results just quietly go missing.
