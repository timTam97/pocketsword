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
