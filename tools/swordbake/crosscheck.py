#!/usr/bin/env python3
"""Cross-check the baked content store against the golden SWORD fixtures.

This is the Phase 2 exit criterion. The converter already proves internally that
its tokenisation round-trips (expand(tokenise(x)) == x per entry). That check is
self-referential: it would still pass if the converter captured the *wrong*
entries, or assembled them in the wrong order.

This script closes that gap by going the other way. It expands each stored
chapter's tokens back to HTML, replays -[SwordModule getChapter:]'s accumulator
loop over the result, and diffs the output against the fixture that
SwordOracleCaptureTests captured from the live engine on the simulator. The two
sides share no code: one is C++ writing SQLite, the other is Swift calling SWORD.

A pass therefore means the store contains the right entries, in the right order,
with the right bytes -- which is exactly what Phase 3's Swift reader will rely on.

Usage:
    python3 tools/swordbake/crosscheck.py [--db PATH] [--fixtures DIR]
"""

import argparse
import os
import re
import sqlite3
import sys
import zlib

# Token grammar -- must match tools/swordbake/main.mm. Kept as an independent
# reimplementation on purpose: if the two drift, this script fails, which is the
# point of an oracle.
TOK_STRONGS_OPEN, TOK_STRONGS_CLOSE = "\x01", "\x02"
TOK_MORPH_OPEN, TOK_MORPH_CLOSE = "\x03", "\x04"
TOK_NOTE_OPEN, TOK_NOTE_CLOSE = "\x05", "\x06"
TOK_XREF_OPEN, TOK_XREF_CLOSE = "\x07", "\x08"
TOK_TITLE_OPEN, TOK_TITLE_CLOSE = "\x0b", "\x0c"
TOK_SCRIPREF_OPEN, TOK_SCRIPREF_CLOSE = "\x0e", "\x0f"
TOK_REDLETTER_OPEN, TOK_REDLETTER_CLOSE = "\x11", "\x12"

WOC_OPEN_HTML = '<span class="WordOfChrist"> '
WOC_CLOSE_HTML = "</span> "

# Chunk framing (schema v2).
CHUNK_ROW_SEP = "\x1e"
CHUNK_FIELD_SEP = "\x1f"

SCHEMA_VERSION = "2"
TOKEN_GRAMMAR = "v2"


def strongs_anchor(type_, value, shown):
    return ('<a href="passagestudy.jsp?action=showStrongs&amp;type=%s&amp;value=%s"'
            ' class="strongs">&lt;%s&gt;</a>' % (type_, value, shown))


def morph_anchor(type_, value, shown):
    return ('<a href="passagestudy.jsp?action=showMorph&amp;type=%s&amp;value=%s"'
            ' class="morph">(%s)</a>' % (type_, value, shown))


def note_anchor(ch, value, module, passage):
    return ('<a href="passagestudy.jsp?action=showNote&amp;type=%s&amp;value=%s'
            '&amp;module=%s&amp;passage=%s" class="%s">*%s</a>'
            % (ch, value, module, passage, ch, ch))


def scripref_anchor(value):
    return ('<a href="passagestudy.jsp?action=showRef&type=scripRef&value=%s'
            '&module=">' % value)


CLOSERS = {
    TOK_STRONGS_OPEN: TOK_STRONGS_CLOSE,
    TOK_MORPH_OPEN: TOK_MORPH_CLOSE,
    TOK_NOTE_OPEN: TOK_NOTE_CLOSE,
    TOK_XREF_OPEN: TOK_XREF_CLOSE,
    TOK_TITLE_OPEN: TOK_TITLE_CLOSE,
    TOK_SCRIPREF_OPEN: TOK_SCRIPREF_CLOSE,
    TOK_REDLETTER_OPEN: TOK_REDLETTER_CLOSE,
}

# Which option gates each token. `None` means "always emitted". These are the
# axes the reader has to gate on, and the reason the all-off fixture set is
# checkable at all: with an option off SWORD does not emit the construct, so
# expanding with that token skipped is the whole difference.
#
# TOK_TITLE is headings-gated, but only in a CHAPTER RECORD. Every title token
# in a record is a non-canonical (Interverse) title, because osisheadings.cpp:132
# keeps canonical preverse titles out of the body entirely while
# processEntryAttributes is on — so `option || canonical` reduces to `option`
# there. Inside a stored HEADING it is the opposite: the app renders that buffer
# through renderText(buf), which turns processEntryAttributes off, so
# `(!preverse || !processEntryAttributes) && (option || canonical)` emits the
# title for a canonical heading whatever the option says. Hence
# `heading_options()` below rather than one flat table.
TOKEN_OPTION = {
    TOK_STRONGS_OPEN: "strongs",
    TOK_MORPH_OPEN: "morphs",
    TOK_NOTE_OPEN: "footnotes",
    TOK_XREF_OPEN: "footnotes",
    TOK_TITLE_OPEN: "headings",
    TOK_SCRIPREF_OPEN: None,
    TOK_REDLETTER_OPEN: "redletter",
}

ALL_ON = {"strongs": True, "morphs": True, "footnotes": True, "redletter": True,
          "headings": True}
ALL_OFF = {"strongs": False, "morphs": False, "footnotes": False, "redletter": False,
           "headings": False}


def heading_options(options):
    """The option set to expand a stored heading's html under: same as the body's
    except the title wrapper is always emitted (see TOKEN_OPTION)."""
    out = dict(options)
    out["headings"] = True
    return out


def expand(s, options=None):
    """Inverse of main.mm's tokeniseEntry().

    `options` maps an axis name to a bool. A token whose axis is off is SKIPPED:
    for Strong's, morph and notes the anchor simply is not emitted (with the
    option off the filter strips the source attribute before the HTML filter
    sees it, so the surrounding text is untouched). Red-letter is different — the
    span goes away but its PAYLOAD is still emitted, recursively expanded, or the
    verse loses its text.
    """
    if options is None:
        options = ALL_ON
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        closer = CLOSERS.get(c)
        if closer is None:
            out.append(c)
            i += 1
            continue
        end = s.find(closer, i + 1)
        if end < 0:
            raise ValueError("unterminated token %r at %d" % (c, i))
        payload = s[i + 1:end]

        axis = TOKEN_OPTION[c]
        if axis is not None and not options.get(axis, True):
            # Option off. Red-letter keeps its payload; the anchors do not have
            # one that survives (their link text is the marker itself).
            if c == TOK_REDLETTER_OPEN:
                out.append(expand(payload, options))
            i = end + 1
            continue

        if c == TOK_STRONGS_OPEN:
            if payload.startswith("*"):
                f = payload[1:].split("|")
                out.append(strongs_anchor(f[0], f[1], f[2]))
            else:
                flag, value = payload[0], payload[1:]
                type_ = {"G": "Greek", "H": "Hebrew", "-": ""}[flag]
                out.append(strongs_anchor(type_, value, value))
        elif c == TOK_MORPH_OPEN:
            if payload.startswith("*"):
                f = payload[1:].split("|")
                out.append(morph_anchor(f[0], f[1], f[2]))
            else:
                type_field, value = payload.split("|", 1)
                type_ = type_field if type_field else "strongMorph%3A" + value
                shown = value
                if len(value) >= 3 and value[0] == "T" and value[1] in "HG" and value[2].isdigit():
                    shown = value[2:]
                out.append(morph_anchor(type_, value, shown))
        elif c == TOK_NOTE_OPEN:
            f = payload.split("|")
            out.append(note_anchor("n", f[0], f[1], f[2]))
        elif c == TOK_XREF_OPEN:
            f = payload.split("|")
            out.append(note_anchor("x", f[0], f[1], f[2]))
        elif c == TOK_TITLE_OPEN:
            out.append("<p><b>" + expand(payload, options) + "</b></p>")
        elif c == TOK_SCRIPREF_OPEN:
            out.append(scripref_anchor(payload))
        elif c == TOK_REDLETTER_OPEN:
            out.append(WOC_OPEN_HTML + expand(payload, options) + WOC_CLOSE_HTML)
        i = end + 1
    return "".join(out)


# ---------------------------------------------------------------------------
# Replay of -[SwordModule chapterBodyHTML:...]
#
# A deliberate transliteration of the Obj-C loop (SwordModule.mm), because that
# loop -- not the raw entry list -- is what produces the fixture. Any divergence
# here is a real finding about the store.
# ---------------------------------------------------------------------------

WS = " \t\n\r\f\v          " \
     "       　"


def replay_chapter(records, headings, is_commentary, vpl=False, headings_on=True):
    """Reproduce the `verses` accumulator. `records` is the ordered entry list
    (verse 0 upward, empties preserved); `headings` maps entry index -> list of
    (canonical, html) for that key position."""
    verses = []
    last_entry = ""
    i = 0
    for idx, raw in enumerate(records):
        this_entry = raw
        # *x / *n -> x / n
        this_entry = this_entry.replace("*x", "x").replace("*n", "n")
        # strip leading whitespace run (the Obj-C does this via
        # rangeOfCharacterFromSet on the inverted whitespace set)
        stripped = this_entry.lstrip(WS)
        if stripped != this_entry and stripped:
            this_entry = stripped

        if this_entry != last_entry and this_entry != "":
            # Preverse headings: emitted when the option is on OR the heading is
            # canonical. Rendered and *x/*n-cleaned, then wrapped.
            for canonical, html in headings.get(idx, []):
                if headings_on or canonical:
                    h = html.replace("*x", "x").replace("*n", "n")
                    verses.append("<p><b>%s</b></p>" % h)

            if is_commentary:
                if i == 0:
                    verses.append(this_entry)
                else:
                    verses.append(
                        '<p><a href="#verse%d" id="vv%d" class="verse">%d</a><br />%s</p>\n'
                        % (i, i, i, this_entry))
            else:
                entry = this_entry
                entry = entry.replace("<br /> <!P><br /><br />", "<br /> <br />")
                entry = entry.replace("<br /><!P><br /><br />", "<br /> <br />")
                entry = entry.replace("<br /> <!P><br /><!P><br />", "<br /> <br />")
                entry = entry.replace("</blockquote><br />", "</blockquote>")

                if i == 0:
                    if entry == "<br />":
                        entry = ""
                elif vpl:
                    entry = ('<a href="pocketsword:versemenu:%d" id="vv%d" class="verse">%d</a>'
                             '<span id="vvv%d">%s</span><br />\n' % (i, i, i, i, entry))
                else:
                    inserted = False
                    if entry.startswith('<blockquote class="lg">'):
                        entry = ('<blockquote class="lg"><a href="pocketsword:versemenu:%d" '
                                 'id="vv%d" class="verse">%d</a>%s\n' % (i, i, i, entry[23:]))
                        inserted = True
                    if not inserted:
                        entry = ('<a href="pocketsword:versemenu:%d" id="vv%d" '
                                 'class="verse">%d</a>%s\n' % (i, i, i, entry))
                verses.append(entry)

        last_entry = this_entry
        i += 1

    body = "".join(verses)
    if '<blockquote class="lg">' in body and "</blockquote>" not in body:
        body += "</blockquote>"
    return body, i


# ---------------------------------------------------------------------------

BOOK_OSIS = {
    "Gen": "Genesis", "Ps": "Psalms", "Matt": "Matthew", "John": "John",
    "Rev": "Revelation",
}


def load_chapter(conn, module, book_osis, chapter, options=None):
    row = conn.execute(
        "SELECT entry_count, blob_kind, blob FROM chapters "
        "WHERE module=? AND book_osis=? AND chapter=?",
        (module, book_osis, chapter)).fetchone()
    if row is None:
        return None
    entry_count, kind, blob = row
    raw = zlib.decompress(blob).decode("utf-8")
    records = raw.split("\x00")
    if kind == "bodyref":
        bodies = {}
        for bid, bblob in conn.execute(
                "SELECT id, blob FROM bodies WHERE module=?", (module,)):
            bodies[str(bid)] = zlib.decompress(bblob).decode("utf-8")
        records = [bodies[r] if r else "" for r in records]
    return [expand(r, options) if r else "" for r in records]


def load_headings(conn, module, book_full, chapter, nrecords, options=None):
    """Map entry index -> [(canonical, html)]. The store keys headings by the
    module's own key text (e.g. "Psalms 3:1"), and entry index == verse number
    because the converter walks verse 0..verseMax in order."""
    out = {}
    for osis_ref, canonical, html in conn.execute(
            "SELECT osis_ref, canonical, html FROM headings "
            "WHERE module=? AND bucket='Preverse' ORDER BY seq",
            (module,)):
        m = re.match(r"^(.*) (\d+):(\d+)$", osis_ref)
        if not m:
            continue
        if m.group(1) != book_full or int(m.group(2)) != chapter:
            continue
        verse = int(m.group(3))
        if verse < nrecords:
            out.setdefault(verse, []).append(
                (bool(canonical), expand(html, heading_options(options))))
    return out


# ---------------------------------------------------------------------------
# Chunk reads (schema v2)
# ---------------------------------------------------------------------------

def read_chunk(conn, table, module, chunk_id):
    """Inflate one chunk and split it into rows of fields. Validates the framing
    counters rather than trusting them, which is the reader-side half of the
    converter's own post-compression check."""
    row = conn.execute(
        "SELECT row_count, raw_size, blob FROM %s WHERE module=? AND chunk_id=?" % table,
        (module, chunk_id)).fetchone()
    if row is None:
        return None
    row_count, raw_size, blob = row
    raw = zlib.decompress(blob)
    if len(raw) != raw_size:
        raise ValueError("%s chunk %d: raw_size %d but inflated %d"
                         % (table, chunk_id, raw_size, len(raw)))
    rows = raw.decode("utf-8").split(CHUNK_ROW_SEP)
    if len(rows) != row_count:
        raise ValueError("%s chunk %d: row_count %d but blob holds %d"
                         % (table, chunk_id, row_count, len(rows)))
    return [r.split(CHUNK_FIELD_SEP) for r in rows]


def dict_entry(conn, module, key):
    """The lookup the app's Dictionary tab performs. NOCASE on the key column,
    then the strongsPad retry for an all-digit key, then nil."""
    row = conn.execute(
        "SELECT chunk_id, slot FROM dict_keys WHERE module=? AND key=?",
        (module, key)).fetchone()
    if row is None and key.isdigit():
        row = conn.execute(
            "SELECT chunk_id, slot FROM dict_keys WHERE module=? AND key=?",
            (module, key.zfill(5))).fetchone()
    if row is None:
        return None
    rows = read_chunk(conn, "dict_chunks", module, row[0])
    if rows is None or row[1] >= len(rows):
        raise ValueError("%s key %s: index points at a missing chunk slot" % (module, key))
    return rows[row[1]][0]


def main():
    ap = argparse.ArgumentParser()
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(os.path.dirname(here))
    ap.add_argument("--db", default=os.path.join(repo, "Resources", "PSContent.sqlite"))
    ap.add_argument("--fixtures", default=os.path.join(repo, "Tests", "Fixtures"))
    args = ap.parse_args()

    if not os.path.exists(args.db):
        print("crosscheck: no store at %s (run `make run` first)" % args.db, file=sys.stderr)
        return 2

    conn = sqlite3.connect(args.db)
    conn.text_factory = bytes

    def q(sql, params=()):
        return conn.execute(sql, params)

    # sqlite3 with text_factory=bytes returns bytes; decode explicitly where we
    # need text so a stray non-UTF-8 byte is a loud failure, not silent mojibake.
    conn.text_factory = str

    summary_path = os.path.join(args.fixtures, "KJV-chapter-summary.tsv")
    if not os.path.exists(summary_path):
        print("crosscheck: no fixtures at %s (capture them first)" % args.fixtures,
              file=sys.stderr)
        return 2

    # Schema/grammar gate. Reading a v1 store with v2 expectations would produce
    # confusing per-chapter diffs rather than one clear failure.
    meta = dict(conn.execute("SELECT key, value FROM content_meta"))
    if meta.get("schemaVersion") != SCHEMA_VERSION or meta.get("tokenGrammar") != TOKEN_GRAMMAR:
        print("crosscheck: store is schemaVersion=%s tokenGrammar=%s, expected %s/%s"
              " (re-run `make -C tools/swordbake run`)"
              % (meta.get("schemaVersion"), meta.get("tokenGrammar"),
                 SCHEMA_VERSION, TOKEN_GRAMMAR), file=sys.stderr)
        return 2

    # Both option endpoints. The all-off pass is the one that proves the token
    # gating is right; without it a reader could ignore the options entirely and
    # still be byte-perfect on every fixture.
    #
    # `headings_on` tracks the config the fixture was captured under, because the
    # accumulator's own preverse injection is gated on the NSUserDefaults pref
    # rather than the SWORD option (SwordModule.mm:1071).
    configs = [("", ALL_ON, True), ("-alloff", ALL_OFF, False)]

    checks = []
    for suffix, options, headings_on in configs:
        for module, is_com in (("KJV", False), ("MHCC", True)):
            path = os.path.join(args.fixtures, "%s-chapter-summary%s.tsv" % (module, suffix))
            if not os.path.exists(path):
                continue
            for line in open(path, encoding="utf-8"):
                line = line.rstrip("\n")
                if not line:
                    continue
                ref = line.split("\t")[0]
                entries = int(line.split("\t")[1].split("=")[1])
                checks.append((module, ref, entries, is_com, suffix, options, headings_on))

    failures = 0
    for module, ref, expected_entries, is_com, suffix, options, headings_on in checks:
        book_abbrev, chapter = ref.rsplit(" ", 1)
        chapter = int(chapter)
        book_full = BOOK_OSIS.get(book_abbrev, book_abbrev)
        # chapters are keyed by OSIS book name
        osis = {v: k for k, v in BOOK_OSIS.items()}.get(book_full, book_abbrev)

        records = load_chapter(conn, module, osis, chapter, options)
        if records is None:
            print("FAIL %s %s%s: not in store" % (module, ref, suffix))
            failures += 1
            continue

        headings = load_headings(conn, module, book_full, chapter, len(records), options)
        body, count = replay_chapter(records, headings, is_com, headings_on=headings_on)

        fixture = os.path.join(
            args.fixtures, "%s-%s%s.html" % (module, ref.replace(" ", "_"), suffix))
        if not os.path.exists(fixture):
            print("SKIP %s %s%s: no fixture" % (module, ref, suffix))
            continue
        golden = open(fixture, encoding="utf-8").read()

        # The fixture is the full accumulator, which also contains the
        # empty-chapter fallback when nothing rendered. Nothing we check is empty.
        ok_body = (body == golden)
        ok_count = (count == expected_entries)

        label = "%s%s" % (ref, suffix)
        if ok_body and ok_count:
            print("ok   %-5s %-16s entries=%-4d bytes=%d" % (module, label, count, len(body)))
        else:
            failures += 1
            if not ok_count:
                print("FAIL %s %s: entry count %d != fixture %d"
                      % (module, label, count, expected_entries))
            if not ok_body:
                k = 0
                while k < min(len(body), len(golden)) and body[k] == golden[k]:
                    k += 1
                lo = max(0, k - 70)
                print("FAIL %s %s: body differs at char %d (store %d chars, fixture %d)"
                      % (module, label, k, len(body), len(golden)))
                print("  fixture: …%s…" % golden[lo:k + 70].replace("\n", "\\n"))
                print("  store:   …%s…" % body[lo:k + 70].replace("\n", "\\n"))

    # Lexicon spot-check against the captured entries.
    for module in ("StrongsRealGreek", "StrongsRealHebrew", "Robinson"):
        path = os.path.join(args.fixtures, "%s-entries.txt" % module)
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8").read()
        blocks = re.split(r"^### key=", text, flags=re.M)[1:]
        for block in blocks:
            key, _, entry = block.partition("\n")
            key = key.strip()
            entry = entry.rstrip("\n")
            html = dict_entry(conn, module, key)
            if html is None:
                print("FAIL %s key=%s: not in store" % (module, key))
                failures += 1
                continue
            if html != entry:
                failures += 1
                print("FAIL %s key=%s: entry differs (store %d chars, fixture %d)"
                      % (module, key, len(html), len(entry)))
            else:
                print("ok   %s key=%-10s bytes=%d" % (module, key, len(entry)))

    # The dictionary-casing gate. The fixtures above feed keys in true casing,
    # which is not what the UI produces: SwordDictionary.mm:67 stores
    # [keyText capitalizedString] and PSDictionaryViewController.swift:252 feeds
    # THAT string back into the lookup. For Robinson that alters 1,375 of 1,526
    # keys (`V-PAI-3S` -> `V-Pai-3S`), so a case-sensitive index would miss ~90%
    # of the module while every fixture above still passed. Enumerate every key
    # the tab can display and assert each one resolves.
    total_ui_keys = altered = 0
    for module in ("StrongsRealGreek", "StrongsRealHebrew", "Robinson"):
        keys = [k for (k,) in conn.execute(
            "SELECT key FROM dict_keys WHERE module=? ORDER BY chunk_id, slot", (module,))]
        missing = []
        for k in keys:
            ui_key = k.title()          # NSString -capitalizedString
            if ui_key != k:
                altered += 1
            total_ui_keys += 1
            if dict_entry(conn, module, ui_key) is None:
                missing.append((k, ui_key))
        if missing:
            failures += 1
            print("FAIL %s: %d of %d UI-cased keys do not resolve, e.g. %s"
                  % (module, len(missing), len(keys), missing[:5]))
        else:
            print("ok   %s: all %d UI-cased keys resolve" % (module, len(keys)))
    print("     (%d keys checked as the UI keys them; %d differ from the stored casing)"
          % (total_ui_keys, altered))

    print()
    if failures:
        print("CROSS-CHECK FAILED: %d mismatch(es)" % failures)
        return 1
    print("CROSS-CHECK PASSED: store matches the live-SWORD fixtures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
