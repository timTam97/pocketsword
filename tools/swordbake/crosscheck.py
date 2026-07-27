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

TOKEN_RE = re.compile(
    "[\x01\x03\x05\x07\x0b\x0e]"
)


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
}


def expand(s):
    """Inverse of main.mm's tokeniseEntry()."""
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
            out.append("<p><b>" + expand(payload) + "</b></p>")
        elif c == TOK_SCRIPREF_OPEN:
            out.append(scripref_anchor(payload))
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


def load_chapter(conn, module, book_osis, chapter):
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
    return [expand(r) if r else "" for r in records]


def load_headings(conn, module, book_full, chapter, nrecords):
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
            out.setdefault(verse, []).append((bool(canonical), expand(html)))
    return out


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

    checks = []
    for line in open(summary_path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        ref = line.split("\t")[0]
        entries = int(line.split("\t")[1].split("=")[1])
        checks.append(("KJV", ref, entries, False))
    mhcc_summary = os.path.join(args.fixtures, "MHCC-chapter-summary.tsv")
    if os.path.exists(mhcc_summary):
        for line in open(mhcc_summary, encoding="utf-8"):
            line = line.rstrip("\n")
            if not line:
                continue
            ref = line.split("\t")[0]
            entries = int(line.split("\t")[1].split("=")[1])
            checks.append(("MHCC", ref, entries, True))

    failures = 0
    for module, ref, expected_entries, is_com in checks:
        book_abbrev, chapter = ref.rsplit(" ", 1)
        chapter = int(chapter)
        book_full = BOOK_OSIS.get(book_abbrev, book_abbrev)
        # chapters are keyed by OSIS book name
        osis = {v: k for k, v in BOOK_OSIS.items()}.get(book_full, book_abbrev)

        records = load_chapter(conn, module, osis, chapter)
        if records is None:
            print("FAIL %s %s: not in store" % (module, ref))
            failures += 1
            continue

        headings = load_headings(conn, module, book_full, chapter, len(records))
        body, count = replay_chapter(records, headings, is_com)

        fixture = os.path.join(
            args.fixtures, "%s-%s.html" % (module, ref.replace(" ", "_")))
        if not os.path.exists(fixture):
            print("SKIP %s %s: no fixture" % (module, ref))
            continue
        golden = open(fixture, encoding="utf-8").read()

        # The fixture is the full accumulator, which also contains the
        # empty-chapter fallback when nothing rendered. Nothing we check is empty.
        ok_body = (body == golden)
        ok_count = (count == expected_entries)

        if ok_body and ok_count:
            print("ok   %s %-8s entries=%-4d bytes=%d" % (module, ref, count, len(body)))
        else:
            failures += 1
            if not ok_count:
                print("FAIL %s %s: entry count %d != fixture %d"
                      % (module, ref, count, expected_entries))
            if not ok_body:
                k = 0
                while k < min(len(body), len(golden)) and body[k] == golden[k]:
                    k += 1
                lo = max(0, k - 70)
                print("FAIL %s %s: body differs at char %d (store %d chars, fixture %d)"
                      % (module, ref, k, len(body), len(golden)))
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
            row = conn.execute(
                "SELECT html FROM dict_entries WHERE module=? AND key=?",
                (module, key)).fetchone()
            # The app passes the bare number and relies on SWLD::strongsPad to
            # zero-fill; the store holds the canonical on-disk key. Retry padded.
            if row is None and key.isdigit():
                row = conn.execute(
                    "SELECT html FROM dict_entries WHERE module=? AND key=?",
                    (module, key.zfill(5))).fetchone()
            if row is None:
                print("FAIL %s key=%s: not in store" % (module, key))
                failures += 1
                continue
            if row[0] != entry:
                failures += 1
                print("FAIL %s key=%s: entry differs (store %d chars, fixture %d)"
                      % (module, key, len(row[0]), len(entry)))
            else:
                print("ok   %s key=%-10s bytes=%d" % (module, key, len(entry)))

    print()
    if failures:
        print("CROSS-CHECK FAILED: %d mismatch(es)" % failures)
        return 1
    print("CROSS-CHECK PASSED: store matches the live-SWORD fixtures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
