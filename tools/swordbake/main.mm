/*  swordbake — offline SWORD content converter (PocketSword Phase 2)
 *
 *  Links the vendored CrossWire SWORD engine once, on a dev machine, and bakes
 *  the five bundled modules into a SQLite content store plus a KJV
 *  versification dump. Nothing in the shipping app reads these artifacts yet —
 *  Phase 3 cuts the app over. This tool is deleted in Phase 5 together with
 *  externals/sword.
 *
 *  Design notes that matter (see the Phase 2 plan for the measurements):
 *
 *  1. Storage is TOKENISED and CHAPTER-GRAIN, not per-verse baked HTML. Fully
 *     rendered per-verse KJV is 66.6 MB raw / 11.9 MB compressed because of
 *     374k Strong's + 216k morph anchors at ~110 bytes each. Replacing those
 *     anchors with sentinel tokens and grouping by chapter gives ~10.8 MB raw
 *     / ~2.9 MB compressed.
 *
 *  2. We store the *input sequence* of -[SwordModule getChapter:]'s loop, not
 *     its output. That loop's counter `i` is NOT the verse number — it advances
 *     even for entries it skips as duplicate/empty — yet it drives the
 *     `pocketsword:versemenu:i` links, the `id="vv{i}"` anchors and the
 *     bookmark-highlight lookup. By persisting the ordered list of entry bodies
 *     exactly as each key position produced them (verse 0 upward, empties
 *     preserved), the Phase 3 Swift reader can run a verbatim port of the loop
 *     and `i` matches by construction.
 *
 *  3. We render with Headings ON. KJV has 1,250 non-canonical <title> tags that
 *     live in intro-only entry slots (book/chapter titles); osisheadings.cpp
 *     only emits interverse titles into the body when the option is on. The 138
 *     canonical Psalm titles go to EntryAttributes["Heading"]["Preverse"] and
 *     never reach the body while processEntryAttributes is set, so we dump the
 *     attribute buckets separately with their canonical flag.
 *
 *  4. Options are set DIRECTLY, never via NSUserDefaults. Lemmas, Textual
 *     Variants and Glosses have no UI in the app, so a pref-driven config
 *     cannot express the state we need. Lemmas in particular must be forced Off
 *     — KJV declares GlobalOptionFilter=OSISLemma, and with it On
 *     osishtmlhref.cpp:66 emits ~145k garbage anchors for `lemma.TR:` parts.
 *
 *  Two self-checks fail the build (see -verifyRoundTrip / the passagestudy
 *  scan): expanding the tokens back through the same printf templates must
 *  reproduce the original rendered HTML byte-for-byte per entry, and no
 *  `passagestudy.jsp` substring may survive tokenisation anywhere.
 */

#import <Foundation/Foundation.h>

#include <sqlite3.h>

// NOTE: externals/sword/include ships its own zlib.h and it is zlib 1.1.4,
// which predates compressBound() (added in 1.2.0). That directory has to be on
// our include path for the engine headers, so a bare `#include <zlib.h>` here
// resolves to the stale 1.1.4 copy even though we link the system libz. Rather
// than fight the include order, declare exactly the three entry points we use.
// (The app carries the same header/library skew but only calls compress2 and
// uncompress, whose signatures never changed, so it never noticed.)
#include <zlib.h>
extern "C" uLong compressBound(uLong sourceLen);

#include <swmgr.h>
#include <swmodule.h>
#include <swbuf.h>
#include <versekey.h>
#include <listkey.h>
#include <markupfiltmgr.h>
#include <localemgr.h>
#include <swlocale.h>
#include <versificationmgr.h>
#include <url.h>
#include <swconfig.h>
#include <swversion.h>

#include <string>
#include <vector>
#include <map>

// ---------------------------------------------------------------------------
// Tokens. Chosen from the C0 control range: SWORD never emits these bytes in
// rendered output (verified by the round-trip check, which would corrupt if a
// literal sentinel appeared in source text).
// ---------------------------------------------------------------------------
#define TOK_STRONGS_OPEN  "\x01"
#define TOK_STRONGS_CLOSE "\x02"
#define TOK_MORPH_OPEN    "\x03"
#define TOK_MORPH_CLOSE   "\x04"
#define TOK_NOTE_OPEN     "\x05"
#define TOK_NOTE_CLOSE    "\x06"
#define TOK_XREF_OPEN     "\x07"
#define TOK_XREF_CLOSE    "\x08"
#define TOK_TITLE_OPEN    "\x0B"
#define TOK_TITLE_CLOSE   "\x0C"
#define TOK_SCRIPREF_OPEN  "\x0E"
#define TOK_SCRIPREF_CLOSE "\x0F"
// Red-letter (Words of Christ). Unlike the other tokens this one exists so the
// reader can *drop* a construct: osisredletterwords.cpp strips the
// who="Jesus" attribute when the option is off, so osishtmlhref.cpp:581/615
// never emit the span — the quote marks and the enclosed text stay. A reader
// that deleted the span *and its contents* would lose verse text, and a CSS
// shortcut cannot reproduce the DOM. Payload is recursively tokenised, like
// TOK_TITLE: measured, all 2,038 spans carry nested Strong's/morph tokens.
#define TOK_REDLETTER_OPEN  "\x11"
#define TOK_REDLETTER_CLOSE "\x12"

// The exact strings osishtmlhref.cpp's MyUserData ctor installs (:118-119).
// Both carry a trailing space, and it is part of the construct: with the option
// off SWORD emits neither, so the reader has to remove the space too.
#define WOC_OPEN_HTML  "<span class=\"WordOfChrist\"> "
#define WOC_CLOSE_HTML "</span> "

// Record separator inside a chapter blob.
static const char kEntrySep = '\0';

// Framing inside a compressed chunk blob (schema v2). Rows are separated by
// \x1E, fields within a row by \x1F. Verified across every column that goes into
// a chunk (plain_texts, dict_entries, notes): zero occurrences of either byte in
// the whole corpus, and the converter re-asserts it per row rather than trusting
// the measurement.
static const char kChunkRowSep = '\x1E';
static const char kChunkFieldSep = '\x1F';

// Rows per chunk, per table. Chosen for the access pattern, not uniformity:
// plain_texts and notes are read in bulk (the index build walks all 31,102 KJV
// rows), dict_entries is read one key at a time on a lexicon tap, so its chunks
// are small to keep the per-lookup inflate cheap.
static const int kChunkRowsPlain = 256;
static const int kChunkRowsDict = 64;
static const int kChunkRowsNotes = 256;

static const int kSchemaVersion = 2;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

static void die(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void die(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    fprintf(stderr, "swordbake: FATAL: %s\n", [msg UTF8String]);
    exit(1);
}

static void note(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void note(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    fprintf(stdout, "swordbake: %s\n", [msg UTF8String]);
    fflush(stdout);
}

static std::string zlibDeflate(const std::string &in) {
    if (in.empty()) return std::string();
    uLongf cap = compressBound((uLong)in.size());
    std::string out;
    out.resize(cap);
    // Fixed level 9 keeps the artifact byte-stable across runs and machines.
    int rc = compress2((Bytef *)&out[0], &cap, (const Bytef *)in.data(), (uLong)in.size(), 9);
    if (rc != Z_OK) die(@"zlib compress2 failed: %d", rc);
    out.resize(cap);
    return out;
}

static std::string zlibInflate(const std::string &in, size_t expected) {
    if (in.empty()) return std::string();
    std::string out;
    out.resize(expected ? expected : in.size() * 8 + 64);
    uLongf cap = (uLongf)out.size();
    int rc = uncompress((Bytef *)&out[0], &cap, (const Bytef *)in.data(), (uLong)in.size());
    if (rc != Z_OK) die(@"zlib uncompress failed: %d", rc);
    out.resize(cap);
    return out;
}

// ---------------------------------------------------------------------------
// SQLite wrapper
// ---------------------------------------------------------------------------

@interface DB : NSObject {
@public
    sqlite3 *db;
}
- (instancetype)initAtPath:(NSString *)path;
- (void)exec:(const char *)sql;
- (sqlite3_stmt *)prepare:(const char *)sql;
- (void)close;
@end

@implementation DB

- (instancetype)initAtPath:(NSString *)path {
    if ((self = [super init])) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        if (sqlite3_open([path fileSystemRepresentation], &db) != SQLITE_OK) {
            die(@"cannot open %@: %s", path, sqlite3_errmsg(db));
        }
        // Determinism: page size and encoding pinned, no WAL sidecar files.
        [self exec:"PRAGMA page_size=4096;"];
        [self exec:"PRAGMA encoding='UTF-8';"];
        [self exec:"PRAGMA journal_mode=DELETE;"];
        [self exec:"PRAGMA synchronous=OFF;"];
    }
    return self;
}

- (void)exec:(const char *)sql {
    char *err = NULL;
    if (sqlite3_exec(db, sql, NULL, NULL, &err) != SQLITE_OK) {
        NSString *msg = err ? [NSString stringWithUTF8String:err] : @"?";
        if (err) sqlite3_free(err);
        die(@"SQL error: %@ (in: %s)", msg, sql);
    }
}

- (sqlite3_stmt *)prepare:(const char *)sql {
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) {
        die(@"prepare failed: %s (in: %s)", sqlite3_errmsg(db), sql);
    }
    return st;
}

- (void)close {
    if (db) { sqlite3_close(db); db = NULL; }
}

@end

static void bindText(sqlite3_stmt *st, int idx, const std::string &s) {
    sqlite3_bind_text(st, idx, s.data(), (int)s.size(), SQLITE_TRANSIENT);
}
static void bindNSText(sqlite3_stmt *st, int idx, NSString *s) {
    if (!s) { sqlite3_bind_null(st, idx); return; }
    const char *c = [s UTF8String];
    sqlite3_bind_text(st, idx, c, -1, SQLITE_TRANSIENT);
}
static void step1(sqlite3_stmt *st, sqlite3 *db) {
    if (sqlite3_step(st) != SQLITE_DONE) die(@"step failed: %s", sqlite3_errmsg(db));
    sqlite3_reset(st);
    sqlite3_clear_bindings(st);
}

// ---------------------------------------------------------------------------
// Tokeniser
//
// Rewrites the option-gated inline anchors that osishtmlhref.cpp emits into
// compact sentinels, and records enough state to rebuild the exact original
// bytes. The expander below is the inverse; -verifyRoundTrip asserts
// expand(tokenise(x)) == x for every entry we store.
// ---------------------------------------------------------------------------

// Scan for `needle` starting at `pos` in `hay`.
static size_t findFrom(const std::string &hay, const char *needle, size_t pos) {
    return hay.find(needle, pos);
}

struct TokeniseResult {
    std::string text;
    bool ok;
};

// The exact templates from osishtmlhref.cpp. Kept as literals here (rather than
// reaching into the filter) so the round-trip check is an independent
// reimplementation — if either side drifts, the check fails loudly.
//
//  :66  <a href="passagestudy.jsp?action=showStrongs&amp;type=%s&amp;value=%s" class="strongs">&lt;%s&gt;</a>
//  :96  <a href="passagestudy.jsp?action=showMorph&amp;type=%s&amp;value=%s" class="morph">(%s)</a>
//  :246 <a href="passagestudy.jsp?action=showNote&amp;type=%c&amp;value=%s&amp;module=%s&amp;passage=%s" class="%c">*%c%s</a>
//       (renderNoteNumbers is false at :155, so the trailing %s is always empty)
//  :439 <p><b>  …  </b></p>   for a body-emitted <title>

// A fifth passagestudy site the plan's table omits: osishtmlhref.cpp:327 emits a
// scripRef anchor for every <reference> tag, and it is NOT option-gated. It also
// differs from the other four in two ways — the separators are raw `&` rather
// than `&amp;`, and only the OPENING tag is emitted here (the matching `</a>`
// comes from the tag's end-tag branch at :341). So this token stands alone and
// does not wrap its link text.
//
// KJV verse bodies contain none of these (measured: 0 across all 32,360
// entries), but the canonical Psalm titles do — which is why it only surfaces
// once headings are captured. Line :655's showImage anchor has no occurrences in
// any of the five bundled modules, so it is deliberately not tokenised; if a
// future module emitted one, the passagestudy self-check would catch it.
static std::string scripRefAnchor(const std::string &value) {
    return "<a href=\"passagestudy.jsp?action=showRef&type=scripRef&value=" + value + "&module=\">";
}

static std::string strongsAnchor(const std::string &type, const std::string &value, const std::string &shown) {
    return "<a href=\"passagestudy.jsp?action=showStrongs&amp;type=" + type +
           "&amp;value=" + value + "\" class=\"strongs\">&lt;" + shown + "&gt;</a>";
}
static std::string morphAnchor(const std::string &type, const std::string &value, const std::string &shown) {
    return "<a href=\"passagestudy.jsp?action=showMorph&amp;type=" + type +
           "&amp;value=" + value + "\" class=\"morph\">(" + shown + ")</a>";
}
static std::string noteAnchor(char ch, const std::string &value, const std::string &module, const std::string &passage) {
    std::string s = "<a href=\"passagestudy.jsp?action=showNote&amp;type=";
    s += ch;
    s += "&amp;value=" + value + "&amp;module=" + module + "&amp;passage=" + passage + "\" class=\"";
    s += ch;
    s += "\">*";
    s += ch;
    s += "</a>";
    return s;
}

// Token payload grammar. Fields are '|'-separated and no field may contain '|'
// (asserted at tokenise time). Only NON-DERIVABLE fields are stored — the
// expander recomputes the rest, and the round-trip self-check proves the
// reconstruction is exact for every entry:
//
//   strongs : \x01 G|H-flag value \x02
//       The template's three slots are `type`, `value`, `shown`. Measured over
//       all 373,619 KJV occurrences, `shown` == `value` always, and `type` is
//       exactly "Greek" or "Hebrew" — so one leading flag byte ('G'/'H') plus
//       the value reproduces all three.
//   morph   : \x03 type '|' value \x04
//       `shown` is `value` with a leading "TH"/"TG" stripped when followed by a
//       digit (osishtmlhref.cpp:92-93), so it is derived. `type` is the whole
//       morph attribute (possibly multi-part, e.g.
//       "robinson%3AT-NSM+robinson%3AN-NSM") and `value` one part, so both are
//       kept. When type == "strongMorph%3A" + value (71,016 of 216,395 cases)
//       the type field is stored empty and rebuilt.
//   note    : \x05 value '|' module '|' passage \x06     (type 'n')
//   xref    : \x07 value '|' module '|' passage \x08     (type 'x')
//   title   : \x0B inner \x0C            (inner is itself tokenised)
//   scripRef: \x0E value \x0F
//   redletter: \x11 inner \x12           (inner is itself tokenised)
//       No payload fields: both delimiters are fixed strings. Measured over the
//       whole corpus: 2,038 opens, 2,038 closes, the only `<span…>` opener
//       present is WordOfChrist, max nesting depth 1, and no WoC payload
//       contains another span — so a flat non-counting token is sufficient and
//       the tokeniser asserts each of those properties rather than assuming it.

static bool splitPipes(const std::string &s, std::vector<std::string> &out, size_t expect) {
    out.clear();
    size_t start = 0;
    while (true) {
        size_t p = s.find('|', start);
        if (p == std::string::npos) { out.push_back(s.substr(start)); break; }
        out.push_back(s.substr(start, p - start));
        start = p + 1;
    }
    return out.size() == expect;
}

static std::string tokeniseEntry(const std::string &in);
static std::string expandEntry(const std::string &in);

static std::string tokeniseEntry(const std::string &in) {
    std::string out;
    out.reserve(in.size());
    size_t i = 0;
    const std::string kAnchorStart = "<a href=\"passagestudy.jsp?action=";

    while (i < in.size()) {
        size_t a = in.find(kAnchorStart, i);
        size_t t = in.find("<p><b>", i);
        size_t w = in.find(WOC_OPEN_HTML, i);

        // Whichever construct comes first.
        size_t next = std::min(std::min(a == std::string::npos ? in.size() : a,
                                        t == std::string::npos ? in.size() : t),
                               w == std::string::npos ? in.size() : w);
        out.append(in, i, next - i);
        if (next >= in.size()) break;

        if (next == a) {
            // The scripRef form (:327) is an opening tag only — it has no </a>
            // of its own — so its extent is the tag, not up to the next </a>.
            if (in.compare(a, strlen("<a href=\"passagestudy.jsp?action=showRef"),
                           "<a href=\"passagestudy.jsp?action=showRef") == 0) {
                size_t close = in.find("\">", a);
                if (close == std::string::npos) die(@"unterminated scripRef anchor");
                close += 2;
                std::string whole = in.substr(a, close - a);
                const std::string pre = "<a href=\"passagestudy.jsp?action=showRef&type=scripRef&value=";
                const std::string post = "&module=\">";
                if (whole.compare(0, pre.size(), pre) != 0 ||
                    whole.size() < pre.size() + post.size() ||
                    whole.compare(whole.size() - post.size(), post.size(), post) != 0) {
                    die(@"unexpected scripRef anchor shape: %s", whole.c_str());
                }
                std::string value = whole.substr(pre.size(), whole.size() - pre.size() - post.size());
                if (value.find('|') != std::string::npos) die(@"pipe in scripRef value");
                if (scripRefAnchor(value) != whole) die(@"scripRef anchor did not round-trip at parse time: %s", whole.c_str());
                out += TOK_SCRIPREF_OPEN + value + TOK_SCRIPREF_CLOSE;
                i = close;
                continue;
            }

            size_t end = in.find("</a>", a);
            if (end == std::string::npos) die(@"unterminated anchor in entry");
            end += 4;
            std::string whole = in.substr(a, end - a);

            // Parse out the fields by locating the fixed separators.
            auto grab = [&](const char *key, std::string &dst) -> bool {
                std::string k = key;
                size_t p = whole.find(k);
                if (p == std::string::npos) return false;
                p += k.size();
                size_t e = whole.find("&amp;", p);
                size_t q = whole.find("\" class=", p);
                size_t stop = std::min(e == std::string::npos ? whole.size() : e,
                                       q == std::string::npos ? whole.size() : q);
                dst = whole.substr(p, stop - p);
                return true;
            };

            if (whole.find("action=showStrongs") != std::string::npos) {
                std::string type, value, shown;
                grab("&amp;type=", type);
                grab("&amp;value=", value);
                size_t s1 = whole.find("&lt;");
                size_t s2 = whole.rfind("&gt;</a>");
                if (s1 == std::string::npos || s2 == std::string::npos) die(@"malformed strongs anchor");
                shown = whole.substr(s1 + 4, s2 - (s1 + 4));
                if (value.find('|') != std::string::npos) die(@"pipe in strongs field");
                if (strongsAnchor(type, value, shown) != whole) die(@"strongs anchor did not round-trip at parse time: %s", whole.c_str());
                // Compact only when the derivation holds; otherwise fall back to
                // the explicit 3-field form so nothing is ever lost.
                char flag = 0;
                if (shown == value) {
                    if (type == "Greek")  flag = 'G';
                    if (type == "Hebrew") flag = 'H';
                    if (type.empty())     flag = '-';
                }
                if (flag) {
                    out += TOK_STRONGS_OPEN;
                    out += flag;
                    out += value + TOK_STRONGS_CLOSE;
                } else {
                    if (type.find('|') != std::string::npos || shown.find('|') != std::string::npos)
                        die(@"pipe in strongs field");
                    out += TOK_STRONGS_OPEN "*" + type + "|" + value + "|" + shown + TOK_STRONGS_CLOSE;
                }
            } else if (whole.find("action=showMorph") != std::string::npos) {
                std::string type, value, shown;
                grab("&amp;type=", type);
                grab("&amp;value=", value);
                size_t s1 = whole.find("\" class=\"morph\">(");
                size_t s2 = whole.rfind(")</a>");
                if (s1 == std::string::npos || s2 == std::string::npos) die(@"malformed morph anchor");
                s1 += strlen("\" class=\"morph\">(");
                shown = whole.substr(s1, s2 - s1);
                if (type.find('|') != std::string::npos || value.find('|') != std::string::npos)
                    die(@"pipe in morph field");
                if (morphAnchor(type, value, shown) != whole) die(@"morph anchor did not round-trip at parse time: %s", whole.c_str());
                // `shown` = value with a leading TH/TG dropped when a digit
                // follows (osishtmlhref.cpp:92-93). Store it only if that fails.
                std::string derivedShown = value;
                if (value.size() >= 3 && value[0] == 'T' && (value[1] == 'H' || value[1] == 'G') &&
                    isdigit((unsigned char)value[2])) {
                    derivedShown = value.substr(2);
                }
                // `type` is the full morph attribute; very often it is just
                // "strongMorph%3A" + value, which we elide to an empty field.
                std::string typeField = (type == "strongMorph%3A" + value) ? std::string() : type;
                if (derivedShown == shown) {
                    out += TOK_MORPH_OPEN + typeField + "|" + value + TOK_MORPH_CLOSE;
                } else {
                    if (shown.find('|') != std::string::npos) die(@"pipe in morph field");
                    out += TOK_MORPH_OPEN "*" + type + "|" + value + "|" + shown + TOK_MORPH_CLOSE;
                }
            } else if (whole.find("action=showNote") != std::string::npos) {
                std::string type, value, module, passage;
                grab("&amp;type=", type);
                grab("&amp;value=", value);
                grab("&amp;module=", module);
                grab("&amp;passage=", passage);
                if (type.size() != 1) die(@"unexpected note type '%s'", type.c_str());
                char ch = type[0];
                if (value.find('|') != std::string::npos || module.find('|') != std::string::npos ||
                    passage.find('|') != std::string::npos) die(@"pipe in note field");
                if (noteAnchor(ch, value, module, passage) != whole) die(@"note anchor did not round-trip at parse time: %s", whole.c_str());
                const char *o = (ch == 'x') ? TOK_XREF_OPEN : TOK_NOTE_OPEN;
                const char *c = (ch == 'x') ? TOK_XREF_CLOSE : TOK_NOTE_CLOSE;
                out += o + value + "|" + module + "|" + passage + c;
            } else {
                die(@"unknown passagestudy action in: %s", whole.c_str());
            }
            i = end;
        } else if (next == w) {
            // Red-letter span. Only tokenise when the matching close is present
            // and the payload holds no further span, so a shape we have not
            // measured degrades to verbatim rather than corrupting. The
            // round-trip check then still passes; only the option-off path would
            // be unable to drop that one span, and the passagestudy/round-trip
            // gates stay meaningful.
            size_t close = in.find(WOC_CLOSE_HTML, w + strlen(WOC_OPEN_HTML));
            std::string inner = (close == std::string::npos)
                ? std::string()
                : in.substr(w + strlen(WOC_OPEN_HTML), close - (w + strlen(WOC_OPEN_HTML)));
            if (close == std::string::npos ||
                inner.find("<span") != std::string::npos ||
                inner.find("</span>") != std::string::npos) {
                out.append(in, w, strlen(WOC_OPEN_HTML));
                i = w + strlen(WOC_OPEN_HTML);
                continue;
            }
            out += TOK_REDLETTER_OPEN + tokeniseEntry(inner) + TOK_REDLETTER_CLOSE;
            i = close + strlen(WOC_CLOSE_HTML);
        } else {
            // Body-emitted <title> -> <p><b>…</b></p>. Only tokenise when the
            // matching close is present; a bare "<p><b>" elsewhere is left alone.
            size_t close = in.find("</b></p>", t);
            if (close == std::string::npos) {
                out.append(in, t, 6);
                i = t + 6;
                continue;
            }
            std::string inner = in.substr(t + 6, close - (t + 6));
            // Nested <p><b> inside a title would break the flat token; bail out
            // to verbatim rather than corrupt.
            if (inner.find("<p><b>") != std::string::npos) {
                out.append(in, t, 6);
                i = t + 6;
                continue;
            }
            // Titles can themselves contain anchors — the canonical Psalm
            // headings carry <reference> tags — so tokenise the content too.
            // Recursion is one level deep by construction (the nested-title case
            // is excluded above).
            out += TOK_TITLE_OPEN + tokeniseEntry(inner) + TOK_TITLE_CLOSE;
            i = close + 8;
        }
    }
    return out;
}

static std::string expandEntry(const std::string &in) {
    std::string out;
    out.reserve(in.size() * 3);
    size_t i = 0;
    while (i < in.size()) {
        unsigned char c = (unsigned char)in[i];
        const char *closeTok = NULL;
        int kind = 0;
        switch (c) {
            case 0x01: closeTok = TOK_STRONGS_CLOSE; kind = 1; break;
            case 0x03: closeTok = TOK_MORPH_CLOSE;   kind = 2; break;
            case 0x05: closeTok = TOK_NOTE_CLOSE;    kind = 3; break;
            case 0x07: closeTok = TOK_XREF_CLOSE;    kind = 4; break;
            case 0x0B: closeTok = TOK_TITLE_CLOSE;   kind = 5; break;
            case 0x0E: closeTok = TOK_SCRIPREF_CLOSE; kind = 6; break;
            case 0x11: closeTok = TOK_REDLETTER_CLOSE; kind = 7; break;
            default: break;
        }
        if (!kind) { out += in[i++]; continue; }
        // Always scan for THIS token's own close, never the first close byte of
        // any kind: the title and red-letter payloads legitimately contain other
        // tokens (anchors inside a heading, Strong's inside a WoC span). Neither
        // of those two nests inside itself — tokeniseEntry refuses to build a
        // nested one — so no depth counter is needed.
        size_t end = findFrom(in, closeTok, i + 1);
        if (end == std::string::npos) die(@"unterminated token 0x%02x", c);
        std::string payload = in.substr(i + 1, end - (i + 1));
        std::vector<std::string> f;
        switch (kind) {
            case 1:
                if (!payload.empty() && payload[0] == '*') {
                    if (!splitPipes(payload.substr(1), f, 3)) die(@"bad strongs payload");
                    out += strongsAnchor(f[0], f[1], f[2]);
                } else {
                    if (payload.size() < 1) die(@"bad strongs payload");
                    const char flag = payload[0];
                    std::string value = payload.substr(1);
                    std::string type = (flag == 'G') ? "Greek" : (flag == 'H') ? "Hebrew" : "";
                    if (flag != 'G' && flag != 'H' && flag != '-') die(@"bad strongs flag '%c'", flag);
                    out += strongsAnchor(type, value, value);
                }
                break;
            case 2:
                if (!payload.empty() && payload[0] == '*') {
                    if (!splitPipes(payload.substr(1), f, 3)) die(@"bad morph payload");
                    out += morphAnchor(f[0], f[1], f[2]);
                } else {
                    if (!splitPipes(payload, f, 2)) die(@"bad morph payload");
                    const std::string &value = f[1];
                    std::string type = f[0].empty() ? ("strongMorph%3A" + value) : f[0];
                    std::string shown = value;
                    if (value.size() >= 3 && value[0] == 'T' && (value[1] == 'H' || value[1] == 'G') &&
                        isdigit((unsigned char)value[2])) {
                        shown = value.substr(2);
                    }
                    out += morphAnchor(type, value, shown);
                }
                break;
            case 3:
                if (!splitPipes(payload, f, 3)) die(@"bad note payload");
                out += noteAnchor('n', f[0], f[1], f[2]);
                break;
            case 4:
                if (!splitPipes(payload, f, 3)) die(@"bad xref payload");
                out += noteAnchor('x', f[0], f[1], f[2]);
                break;
            case 5:
                out += "<p><b>" + expandEntry(payload) + "</b></p>";
                break;
            case 6:
                if (payload.find('|') != std::string::npos) die(@"bad scripRef payload");
                out += scripRefAnchor(payload);
                break;
            case 7:
                out += WOC_OPEN_HTML + expandEntry(payload) + WOC_CLOSE_HTML;
                break;
        }
        i = end + 1;
    }
    return out;
}

// ---------------------------------------------------------------------------
// Chunk writer (schema v2)
//
// Buffers logical rows, and every `rowsPerChunk` rows emits one zlib blob of
// them joined by \x1E with fields joined by \x1F. Also keeps the pre-compression
// rows so -validate can inflate every chunk back and compare — a compression bug
// that drops or reorders a chunk has to fail the bake, not the reader.
//
// Framing is asserted, not assumed: any row containing \x1E or \x1F is fatal.
// ---------------------------------------------------------------------------

class ChunkWriter {
public:
    ChunkWriter(DB *database, const char *tableName, const std::string &module,
                int rowsPerChunk, bool withFirstId)
        : db(database), table(tableName), mod(module), perChunk(rowsPerChunk),
          hasFirstId(withFirstId), nextRow(0), chunkId(0) {
        std::string sql = std::string("INSERT INTO ") + tableName + "(module,chunk_id," +
                          (withFirstId ? "first_id," : "") + "row_count,raw_size,blob) VALUES(?,?,?,?,?" +
                          (withFirstId ? ",?" : "") + ");";
        stmt = [database prepare:sql.c_str()];
    }
    ~ChunkWriter() { if (stmt) sqlite3_finalize(stmt); }

    // Append one row. `fields` are joined by \x1F in the order given.
    // Returns the row's global index (its `slot` is index % perChunk, its chunk
    // is index / perChunk).
    long long add(const std::vector<std::string> &fields) {
        std::string row;
        for (size_t i = 0; i < fields.size(); ++i) {
            if (i) row.push_back(kChunkFieldSep);
            if (fields[i].find(kChunkRowSep) != std::string::npos ||
                fields[i].find(kChunkFieldSep) != std::string::npos) {
                die(@"%s: row %lld field %zu contains a chunk framing byte", table, nextRow, i);
            }
            row += fields[i];
        }
        pending.push_back(row);
        long long index = nextRow++;
        if ((long long)pending.size() == perChunk) flush();
        return index;
    }

    void finish() { flush(); }

    long long rowCount() const { return nextRow; }
    long long chunkCount() const { return chunkId; }

    // Inflate every chunk back out of the DB and compare against the rows that
    // went in. Returns the number of rows verified.
    long long validate(DB *database) {
        std::string sql = std::string("SELECT chunk_id,row_count,raw_size,blob FROM ") + table +
                          " WHERE module=? ORDER BY chunk_id;";
        sqlite3_stmt *sel = [database prepare:sql.c_str()];
        sqlite3_bind_text(sel, 1, mod.data(), (int)mod.size(), SQLITE_TRANSIENT);
        long long seen = 0, chunksSeen = 0;
        while (sqlite3_step(sel) == SQLITE_ROW) {
            long long cid = sqlite3_column_int64(sel, 0);
            int rc = sqlite3_column_int(sel, 1);
            long long raw = sqlite3_column_int64(sel, 2);
            const void *b = sqlite3_column_blob(sel, 3);
            int bn = sqlite3_column_bytes(sel, 3);
            if (cid != chunksSeen) die(@"%s: chunk ids not contiguous (saw %lld, expected %lld)", table, cid, chunksSeen);
            std::string inflated = zlibInflate(std::string((const char *)b, (size_t)bn), (size_t)raw);
            if ((long long)inflated.size() != raw) {
                die(@"%s chunk %lld: raw_size %lld but inflated to %zu", table, cid, raw, inflated.size());
            }
            std::vector<std::string> rows;
            size_t start = 0;
            while (true) {
                size_t p = inflated.find(kChunkRowSep, start);
                if (p == std::string::npos) { rows.push_back(inflated.substr(start)); break; }
                rows.push_back(inflated.substr(start, p - start));
                start = p + 1;
            }
            // An empty chunk would produce one empty row from the split above;
            // no chunk is ever written empty, so row_count is authoritative.
            if ((int)rows.size() != rc) {
                die(@"%s chunk %lld: row_count %d but blob holds %zu rows", table, cid, rc, rows.size());
            }
            for (int i = 0; i < rc; ++i) {
                size_t g = (size_t)(cid * perChunk + i);
                if (g >= allRows.size()) die(@"%s chunk %lld: row %d past the %zu rows written", table, cid, i, allRows.size());
                if (rows[i] != allRows[g]) {
                    die(@"%s chunk %lld slot %d: inflated row differs from the row written\n  in:  %.100s\n  out: %.100s",
                        table, cid, i, allRows[g].c_str(), rows[i].c_str());
                }
                seen++;
            }
            chunksSeen++;
        }
        sqlite3_finalize(sel);
        if (chunksSeen != chunkId) die(@"%s: wrote %lld chunks but read back %lld", table, chunkId, chunksSeen);
        if (seen != nextRow) die(@"%s: wrote %lld rows but read back %lld", table, nextRow, seen);
        return seen;
    }

private:
    void flush() {
        if (pending.empty()) return;
        std::string joined;
        for (size_t i = 0; i < pending.size(); ++i) {
            if (i) joined.push_back(kChunkRowSep);
            joined += pending[i];
        }
        std::string z = zlibDeflate(joined);
        int col = 1;
        sqlite3_bind_text(stmt, col++, mod.data(), (int)mod.size(), SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, col++, chunkId);
        if (hasFirstId) sqlite3_bind_int64(stmt, col++, chunkId * perChunk);
        sqlite3_bind_int(stmt, col++, (int)pending.size());
        sqlite3_bind_int64(stmt, col++, (sqlite3_int64)joined.size());
        sqlite3_bind_blob(stmt, col++, z.data(), (int)z.size(), SQLITE_TRANSIENT);
        step1(stmt, db->db);
        rawTotal += joined.size();
        blobTotal += z.size();
        allRows.insert(allRows.end(), pending.begin(), pending.end());
        pending.clear();
        chunkId++;
    }

public:
    long long rawTotal = 0, blobTotal = 0;

private:
    DB *db;
    const char *table;
    std::string mod;
    long long perChunk;
    bool hasFirstId;
    sqlite3_stmt *stmt;
    std::vector<std::string> pending;
    std::vector<std::string> allRows;
    long long nextRow;
    long long chunkId;
};

// ---------------------------------------------------------------------------
// Converter
// ---------------------------------------------------------------------------

@interface Baker : NSObject {
    sword::SWMgr *mgr;
    DB *db;
    NSString *outDir;
    NSString *abbrConfPath;
    // stats
    long long entriesSeen, entriesStored, roundTripChecked;
}
- (instancetype)initWithModulePath:(NSString *)modPath localePath:(NSString *)locPath outDir:(NSString *)out;
- (void)run;
@end

@implementation Baker

- (instancetype)initWithModulePath:(NSString *)modPath localePath:(NSString *)locPath outDir:(NSString *)out {
    if (!(self = [super init])) return nil;
    self->outDir = [out copy];
    self->abbrConfPath = [locPath stringByAppendingPathComponent:@"abbr.conf"];

    // Load locales exactly as -[SwordManager initLocale] does (SwordManager.mm:178-184).
    sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
    lmgr->loadConfigDir([locPath fileSystemRepresentation]);
    // The app leaves the default locale alone for English (PSLaunchViewController
    // short-circuits when preferredLanguages.first == "en") and there is no
    // en.conf — English is SWLocale::DEFAULT_LOCALE_NAME, so translate() is the
    // identity. Do NOT call setDefaultLocaleName here: it would make the dump
    // depend on the dev machine's language settings.

    // Construct the manager identically to -[SwordManager reInit]
    // (SwordManager.mm:361). The explicit path is load-bearing: it stops
    // SWMgr::findConfig (swmgr.cpp:683-740) from walking $SWORD_PATH,
    // /etc/sword.conf or ~/.sword on a dev machine.
    mgr = new sword::SWMgr([modPath fileSystemRepresentation], true,
                           new sword::MarkupFilterMgr(sword::FMT_HTMLHREF, sword::ENC_HTML),
                           false, false);
    if (!mgr) die(@"cannot create SWMgr at %@", modPath);

    db = [[DB alloc] initAtPath:[out stringByAppendingPathComponent:@"PSContent.sqlite"]];
    return self;
}

// Mirrors -[SwordManager initWithPath:] (SwordManager.mm:331-335): every
// advertised global option is turned Off first, so nothing inherits a default
// we didn't choose. Then we set the render config explicitly.
- (void)configureOptions {
    sword::StringList opts = mgr->getGlobalOptions();
    for (sword::StringList::iterator it = opts.begin(); it != opts.end(); ++it) {
        mgr->setGlobalOption(it->c_str(), "Off");
    }

    mgr->setGlobalOption("Strong's Numbers", "On");
    mgr->setGlobalOption("Morphological Tags", "On");
    mgr->setGlobalOption("Footnotes", "On");
    mgr->setGlobalOption("Cross-references", "On");
    mgr->setGlobalOption("Words of Christ in Red", "On");
    mgr->setGlobalOption("Headings", "On");
    mgr->setGlobalOption("Textual Variants", "Primary Reading");
    // Explicitly Off: KJV declares GlobalOptionFilter=OSISLemma, and Lemmas On
    // makes osishtmlhref.cpp:66 emit ~145k anchors for `lemma.TR:` Greek parts.
    mgr->setGlobalOption("Lemmas", "Off");
    mgr->setGlobalOption("Glosses", "Off");

    note(@"global options configured; advertised: %lu", (unsigned long)opts.size());
    for (sword::StringList::iterator it = opts.begin(); it != opts.end(); ++it) {
        note(@"  %-28s = %s", it->c_str(), mgr->getGlobalOption(it->c_str()));
    }
}

- (void)createSchema {
    [db exec:
     "CREATE TABLE content_meta(key TEXT PRIMARY KEY, value TEXT);"

     // One row per (module, chapter). `blob` is zlib(entry bodies joined by
     // \x00) in exact key order from verse 0 to the chapter boundary, with
     // empty entries preserved as empty records so a reader replaying
     // getChapter's loop keeps the same counter. For modules that share entry
     // bodies across a verse range (RawCom, i.e. MHCC) the records hold body
     // ids referencing bodies(id) instead — see `blob_kind`.
     "CREATE TABLE chapters("
     "  module TEXT NOT NULL,"
     "  book_osis TEXT NOT NULL,"
     "  chapter INT NOT NULL,"
     "  ordinal INT NOT NULL,"
     "  entry_count INT NOT NULL,"
     "  raw_size INT NOT NULL,"
     "  blob_kind TEXT NOT NULL,"   // 'inline' | 'bodyref'
     "  blob BLOB,"
     "  PRIMARY KEY(module, book_osis, chapter));"

     // Distinct entry bodies for blob_kind='bodyref' modules. MHCC's 28,970
     // verse slots point at only ~4.4k distinct comment bodies.
     "CREATE TABLE bodies("
     "  module TEXT NOT NULL,"
     "  id INT NOT NULL,"
     "  blob BLOB NOT NULL,"
     "  PRIMARY KEY(module, id));"

     // Mirrors EntryAttributes["Heading"] so the existing app glue
     // (SwordModule.mm:1083-1093) ports unchanged. `html` is the rendered form
     // (renderText(buf), matching the app's call shape).
     "CREATE TABLE headings("
     "  module TEXT NOT NULL,"
     "  osis_ref TEXT NOT NULL,"
     "  bucket TEXT NOT NULL,"      // 'Preverse' | 'Interverse'
     "  seq INT NOT NULL,"
     "  canonical INT NOT NULL,"
     "  html TEXT NOT NULL);"

     // ---- Note bodies (schema v2: chunk-compressed) -----------------------
     //
     // ALREADY RENDERED via renderText(buf) — the same call the app makes at
     // SwordModule.mm:567, which sets processEntryAttributes=false and is a
     // different code path from rendering at a key position.
     //
     // Same split as the lexicons: the (osis_ref, marker) lookup keys stay
     // uncompressed in notes_index, the bodies go into 256-row chunks. A footnote
     // tap resolves one key and inflates one chunk.
     "CREATE TABLE notes_chunks("
     "  module TEXT NOT NULL,"
     "  chunk_id INT NOT NULL,"
     "  row_count INT NOT NULL,"
     "  raw_size INT NOT NULL,"
     "  blob BLOB NOT NULL,"
     "  PRIMARY KEY(module, chunk_id));"

     "CREATE TABLE notes_index("
     "  module TEXT NOT NULL,"
     "  osis_ref TEXT NOT NULL,"
     "  marker TEXT NOT NULL,"
     "  chunk_id INT NOT NULL,"
     "  slot INT NOT NULL,"
     "  PRIMARY KEY(module, osis_ref, marker));"

     // ---- Lexicon entries (schema v2: chunk-compressed) -------------------
     //
     // The HTML bodies live in 64-row zlib chunks; the KEYS stay uncompressed in
     // dict_keys. That split is load-bearing rather than tidy:
     // PSDictionaryViewController drives its whole table off the key list
     // (`:219`/`:241`/`:361`), so `allKeys()` and `entryCount()` must not require
     // inflating anything, while a single tap only needs the one chunk holding
     // that key's slot.
     //
     // `key COLLATE NOCASE` reproduces SWORD's own matching. Robinson.conf omits
     // CaseSensitiveKeys, so SWMgr builds RawLD(..., caseSensitive=false)
     // (swmgr.cpp:1056) and RawStr::findOffset uppercases both sides before
     // comparing (rawstr.cpp:188). The UI feeds back `[keyText capitalizedString]`
     // (SwordDictionary.mm:67 -> PSDictionaryViewController.swift:252), which
     // alters 1,375 of Robinson's 1,526 keys (`V-PAI-3S` -> `V-Pai-3S`), so a
     // binary `WHERE key=?` would miss ~90% of the module. NOCASE is safe and
     // sufficient here — all 15,824 keys across the three lexicons are pure ASCII
     // with zero case-fold collisions, and rowid order == binary order ==
     // case-insensitive order for every module, so enumeration is unaffected.
     // (SQLite's NOCASE is ASCII-only, which is exactly SWORD's toupper.)
     "CREATE TABLE dict_chunks("
     "  module TEXT NOT NULL,"
     "  chunk_id INT NOT NULL,"
     "  row_count INT NOT NULL,"
     "  raw_size INT NOT NULL,"
     "  blob BLOB NOT NULL,"
     "  PRIMARY KEY(module, chunk_id));"

     "CREATE TABLE dict_keys("
     "  module TEXT NOT NULL,"
     "  key TEXT NOT NULL COLLATE NOCASE,"
     "  chunk_id INT NOT NULL,"
     "  slot INT NOT NULL,"
     "  PRIMARY KEY(module, key COLLATE NOCASE));"

     // ---- FTS build source (schema v2: chunk-compressed) ------------------
     //
     // Dumped from real stripText()/EntryAttributes with PSSearchCleanDisplayText
     // already applied, exactly as -buildWithProgress: does, so the on-device
     // index build carries no derivation logic. No FTS index is shipped: building
     // on device sidesteps macOS<->iOS FTS5 on-disk compatibility entirely.
     //
     // Phase 2 considered dropping this table and re-deriving all three columns
     // from the chapter tokens on device. That is retracted: the derivation would
     // be a second, untested implementation of stripText + the Word attribute
     // walk, and a bug in it does not crash — search results just quietly go
     // missing. Chunking gets 26.8 MB down to ~4 MB while keeping the column
     // exactly what the live engine produced, which is the property the whole
     // oracle strategy rests on.
     //
     // Rows stay dense and contiguous per module, so a reader locates row `id` at
     // chunk `id / 256`, slot `id % 256`, with no index. `first_id` is stored
     // anyway so that invariant is checkable rather than assumed.
     //
     // The text is one level of indirection away from verses_plain because RawCom
     // (MHCC) points a whole verse range at one shared comment body: inlining
     // costs 28 MB against 2 MB deduped.
     "CREATE TABLE plain_texts_chunks("
     "  module TEXT NOT NULL,"
     "  chunk_id INT NOT NULL,"
     "  first_id INT NOT NULL,"
     "  row_count INT NOT NULL,"
     "  raw_size INT NOT NULL,"
     "  blob BLOB NOT NULL,"
     "  PRIMARY KEY(module, chunk_id));"

     "CREATE TABLE verses_plain("
     "  module TEXT NOT NULL,"
     "  ordinal INT NOT NULL,"
     "  osis_ref TEXT NOT NULL,"
     "  book_osis TEXT NOT NULL,"
     "  testament INT NOT NULL,"
     "  text_id INT NOT NULL);"

     "CREATE INDEX idx_headings ON headings(module, osis_ref);"
     "CREATE INDEX idx_vp ON verses_plain(module, ordinal);"
    ];
}

- (void)setMeta:(NSString *)key to:(NSString *)value {
    sqlite3_stmt *st = [db prepare:"INSERT OR REPLACE INTO content_meta(key,value) VALUES(?,?);"];
    bindNSText(st, 1, key);
    bindNSText(st, 2, value);
    step1(st, db->db);
    sqlite3_finalize(st);
}

// -----------------------------------------------------------------------
// Baked module metadata (SWORD_REMOVAL_PLAN.md Phase 5 step 4)
// -----------------------------------------------------------------------

// The exact feature set `-[SwordModule hasFeature:]` answers YES for.
//
// Baking the ANSWER, not the inputs. hasFeature: is not a `Feature=` lookup:
// it also matches a `GlobalOptionFilter=` entry that is the feature name either
// bare or prefixed `GBF` / `ThML` / `UTF8` / `OSIS` (SwordModule.mm:732-752).
// That is why KJV — which declares only `Feature=StrongsNumbers` and
// `Feature=NoParagraphs` — nonetheless answers YES for Morph, Headings,
// Footnotes, Scripref and RedLetterWords, from its six `GlobalOptionFilter=OSIS*`
// lines; and why MHCC, which declares neither kind, answers NO to everything and
// so gets no `▾` menu rows at all and hides the button.
//
// Reproducing that here rather than in the reader is the point: a reader-side
// reimplementation would be a second copy of the rule with no engine to check it
// against, whereas this runs against the live `.conf` parser one last time.
//
// The queried set is exactly what the app asks about — every string passed to
// hasFeature: anywhere in the tree, which is a closed set because there is no UI
// to add a module:
//   PSModuleViewController.rebuildSettingsMenu: Strongs, StrongsNumbers, Morph,
//     Headings, Footnotes, Scripref (note the spelling — not "Scriptref"),
//     RedLetterWords
//   PSModuleSearchController:  Strongs, StrongsNumbers
//   PSTabBarControllerDelegate: GreekDef, HebrewDef
//   PSDictionaryViewController: Images
// GreekParse / HebrewParse / Glossary / DailyDevotion are included because they
// are cheap and the .conf files do use GreekParse (Robinson) — a future reader
// asking about one should get a real answer rather than a silent NO.
- (NSString *)featureListForModule:(sword::SWModule *)mod {
    static NSArray<NSString *> *queried = @[
        @"Strongs", @"StrongsNumbers", @"Morph", @"Headings", @"Footnotes",
        @"Scripref", @"RedLetterWords", @"Lemma", @"GreekDef", @"HebrewDef",
        @"GreekParse", @"HebrewParse", @"Glossary", @"DailyDevotion", @"Images",
    ];
    NSMutableArray<NSString *> *has = [NSMutableArray array];
    for (NSString *feature in queried) {
        const char *f = [feature UTF8String];
        BOOL yes = mod->getConfig().has("Feature", f);
        if (!yes) {
            for (NSString *prefix in @[@"GBF", @"ThML", @"UTF8", @"OSIS", @""]) {
                NSString *candidate = [prefix stringByAppendingString:feature];
                if (mod->getConfig().has("GlobalOptionFilter", [candidate UTF8String])) {
                    yes = YES;
                    break;
                }
            }
        }
        if (yes) [has addObject:feature];
    }
    // '|' delimited. Safe: every name above is alphanumeric, and the reader
    // splits on the same character. Empty string for a module with no features
    // (MHCC), which the reader must treat as "no rows" rather than "unknown".
    return [has componentsJoinedByString:@"|"];
}

// Round-trip gate: expanding the tokens must reproduce the exact input bytes,
// and no passagestudy.jsp substring may survive in the tokenised form.
- (std::string)tokeniseChecked:(const std::string &)rendered where:(const char *)where {
    std::string tok = tokeniseEntry(rendered);
    if (tok.find("passagestudy.jsp") != std::string::npos) {
        die(@"SELF-CHECK FAILED: passagestudy.jsp survived tokenisation at %s", where);
    }
    std::string back = expandEntry(tok);
    if (back != rendered) {
        // Report the first divergence to make a real failure debuggable.
        size_t n = std::min(back.size(), rendered.size());
        size_t k = 0;
        while (k < n && back[k] == rendered[k]) ++k;
        die(@"SELF-CHECK FAILED: round-trip mismatch at %s (offset %zu)\n  orig: %.120s\n  back: %.120s",
            where, k, rendered.c_str() + (k > 40 ? k - 40 : 0), back.c_str() + (k > 40 ? k - 40 : 0));
    }
    roundTripChecked++;
    return tok;
}

// -----------------------------------------------------------------------
// Bible / commentary: chapter-grain entry-body capture.
// -----------------------------------------------------------------------
- (void)bakeVerseModule:(sword::SWModule *)mod name:(NSString *)modName isCommentary:(BOOL)isCom {
    note(@"baking %@ (%s)…", modName, mod->getType());

    sqlite3_stmt *insChapter = [db prepare:
        "INSERT INTO chapters(module,book_osis,chapter,ordinal,entry_count,raw_size,blob_kind,blob)"
        " VALUES(?,?,?,?,?,?,?,?);"];
    sqlite3_stmt *insBody = [db prepare:"INSERT INTO bodies(module,id,blob) VALUES(?,?,?);"];
    sqlite3_stmt *insHeading = [db prepare:
        "INSERT INTO headings(module,osis_ref,bucket,seq,canonical,html) VALUES(?,?,?,?,?,?);"];
    sqlite3_stmt *insNoteIdx = [db prepare:
        "INSERT INTO notes_index(module,osis_ref,marker,chunk_id,slot) VALUES(?,?,?,?,?);"];
    sqlite3_stmt *insPlain = [db prepare:
        "INSERT INTO verses_plain(module,ordinal,osis_ref,book_osis,testament,text_id)"
        " VALUES(?,?,?,?,?,?);"];
    // Dedup key is the full (text, lemmas, word_map) triple, so two verses only
    // share a row when all three agree.
    std::map<std::string, int> plainIds;
    int nextPlainId = 0;

    const std::string modNameStr = [modName UTF8String];

    // Chunked writers for the two bulk tables. plain_texts rows are dense and
    // contiguous per module, so `first_id` is carried and the reader can locate
    // row `id` arithmetically; notes are addressed through notes_index instead,
    // which records each row's (chunk_id, slot) explicitly.
    ChunkWriter plainChunks(db, "plain_texts_chunks", modNameStr, kChunkRowsPlain, true);
    ChunkWriter noteChunks(db, "notes_chunks", modNameStr, kChunkRowsNotes, false);

    // Body dedup for RawCom-style modules that share one body across a range.
    const BOOL dedup = isCom;
    std::map<std::string, int> bodyIds;
    int nextBodyId = 0;

    sword::VerseKey *vk = (sword::VerseKey *)mod->getKey();
    vk->setIntros(true);
    vk->setPersist(true);

    // Walk book by book, chapter by chapter, so each chapter's entry list is
    // exactly what getChapter's loop would traverse: verse 0 (the intro slot)
    // through the last verse.
    const sword::VersificationMgr::System *sys =
        sword::VersificationMgr::getSystemVersificationMgr()
            ->getVersificationSystem(mod->getConfigEntry("Versification")
                                     ? mod->getConfigEntry("Versification") : "KJV");
    if (!sys) die(@"no versification system for %@", modName);

    long long chapters = 0, plainRows = 0, noteRows = 0, headingRows = 0;
    long long rawTotal = 0, blobTotal = 0;

    for (int b = 0; b < sys->getBookCount(); ++b) {
        const sword::VersificationMgr::Book *bk = sys->getBook(b);
        const std::string bookOsis = bk->getOSISName();

        for (int c = 1; c <= bk->getChapterMax(); ++c) {
            // Assemble this chapter's entry records.
            std::vector<std::string> records;
            int vmax = bk->getVerseMax(c);
            long long chapterOrdinal = -1;

            for (int v = 0; v <= vmax; ++v) {
                char refbuf[128];
                snprintf(refbuf, sizeof(refbuf), "%s %d:%d", bk->getOSISName(), c, v);
                vk->setText(refbuf);
                if (vk->popError()) { records.push_back(std::string()); continue; }

                // Rendered body, exactly as getChapter takes it
                // (SwordModule.mm:1072): renderText(0, -1, true) at the key
                // position, which clears + repopulates entryAttributes.
                sword::SWBuf rendered = mod->renderText(0, -1, true);
                entriesSeen++;

                std::string body(rendered.c_str() ? rendered.c_str() : "", rendered.length());
                char where[192];
                snprintf(where, sizeof(where), "%s %s:%d", modNameStr.c_str(), refbuf, v);
                std::string tok = body.empty() ? std::string() : [self tokeniseChecked:body where:where];
                records.push_back(tok);
                if (!tok.empty()) entriesStored++;

                const char *keyText = vk->getText();
                std::string osisRef = keyText ? keyText : refbuf;
                if (v == 0) chapterOrdinal = vk->getIndex();

                // Heading buckets. osisheadings.cpp routes canonical/preverse
                // titles here and (with processEntryAttributes on) keeps them
                // out of the body, so they must be captured separately.
                sword::AttributeTypeList &ats = mod->getEntryAttributes();
                sword::AttributeTypeList::iterator hIt = ats.find("Heading");
                if (hIt != ats.end()) {
                    for (sword::AttributeList::iterator bIt = hIt->second.begin(); bIt != hIt->second.end(); ++bIt) {
                        const std::string bucket = bIt->first.c_str();
                        if (bucket != "Preverse" && bucket != "Interverse") continue;
                        for (sword::AttributeValue::iterator sIt = bIt->second.begin(); sIt != bIt->second.end(); ++sIt) {
                            const std::string seqKey = sIt->first.c_str();
                            if (sIt->second.length() == 0) continue;
                            // canonical flag lives in the sibling numeric bucket
                            int canonical = 0;
                            sword::AttributeList::iterator nIt = hIt->second.find(seqKey.c_str());
                            if (nIt != hIt->second.end()) {
                                sword::AttributeValue::iterator cIt = nIt->second.find("canonical");
                                if (cIt != nIt->second.end() && cIt->second == "true") canonical = 1;
                            }
                            // Render with the same call shape the app uses for
                            // preverse headings (SwordModule.mm:1089).
                            sword::SWBuf rh = mod->renderText(sIt->second.c_str());
                            std::string rhs(rh.c_str() ? rh.c_str() : "", rh.length());
                            char hw[192];
                            snprintf(hw, sizeof(hw), "heading %s %s", modNameStr.c_str(), osisRef.c_str());
                            std::string rht = rhs.empty() ? std::string() : [self tokeniseChecked:rhs where:hw];

                            bindText(insHeading, 1, modNameStr);
                            bindText(insHeading, 2, osisRef);
                            bindText(insHeading, 3, bucket);
                            sqlite3_bind_int(insHeading, 4, atoi(seqKey.c_str()));
                            sqlite3_bind_int(insHeading, 5, canonical);
                            bindText(insHeading, 6, rht);
                            step1(insHeading, db->db);
                            headingRows++;
                        }
                    }
                }

                // Footnote / cross-reference bodies. Captured with
                // renderText(buf) — the same shape as SwordModule.mm:567.
                sword::AttributeTypeList::iterator fIt = ats.find("Footnote");
                if (fIt != ats.end()) {
                    for (sword::AttributeList::iterator mIt = fIt->second.begin(); mIt != fIt->second.end(); ++mIt) {
                        const std::string marker = mIt->first.c_str();
                        std::string type, bodyRaw, refList;
                        sword::AttributeValue::iterator it2;
                        if ((it2 = mIt->second.find("type")) != mIt->second.end()) type = it2->second.c_str();
                        if ((it2 = mIt->second.find("body")) != mIt->second.end()) bodyRaw = it2->second.c_str();
                        if ((it2 = mIt->second.find("refList")) != mIt->second.end()) refList = it2->second.c_str();

                        sword::SWBuf rb = mod->renderText(bodyRaw.c_str());
                        std::string rbs(rb.c_str() ? rb.c_str() : "", rb.length());
                        char nw[192];
                        snprintf(nw, sizeof(nw), "note %s %s #%s", modNameStr.c_str(), osisRef.c_str(), marker.c_str());
                        std::string rbt = rbs.empty() ? std::string() : [self tokeniseChecked:rbs where:nw];

                        std::vector<std::string> fields;
                        fields.push_back(type);
                        fields.push_back(rbt);
                        fields.push_back(refList);
                        long long row = noteChunks.add(fields);

                        bindText(insNoteIdx, 1, modNameStr);
                        bindText(insNoteIdx, 2, osisRef);
                        bindText(insNoteIdx, 3, marker);
                        sqlite3_bind_int64(insNoteIdx, 4, row / kChunkRowsNotes);
                        sqlite3_bind_int(insNoteIdx, 5, (int)(row % kChunkRowsNotes));
                        step1(insNoteIdx, db->db);
                        noteRows++;
                    }
                }

                // FTS source row. stripText() does NOT run the UTF8HTML
                // encoding filter, so this column is raw UTF-8 (unlike the
                // entity-escaped HTML columns).
                //
                // *** stripText() is taken with Strong's AND morph OFF. ***
                // The rest of this bake runs with both On, because the chapter
                // tokens need the anchors — but stripText() with them on
                // interleaves markers into the verse text: `<H0430>` for Strong's
                // and, via osisplain, a parenthesised `(8804)` for morph.
                // PSSearchCleanDisplayText strips the first form and NOT the
                // second (its regex is angle-bracket-only), so baking with morph
                // on put "(8804)" into the indexed text of 21,175 of 30,862 KJV
                // rows — searchable junk, and a divergence from the live index
                // build, which renders under the app's per-module prefs (all-off
                // on a fresh install).
                //
                // Found by PSSearchIndexParityTests diffing the two index builds
                // row-by-row; no fixture covered it. The Word entry attributes
                // that lemmas/word_map come from are NOT affected: osisstrongs.cpp
                // populates them inside `if (isProcessEntryAttributes())` (:100),
                // which runs before and independently of the `if (!option)` lemma
                // strip (:242).
                if (v >= 1) {
                    mgr->setGlobalOption("Strong's Numbers", "Off");
                    mgr->setGlobalOption("Morphological Tags", "Off");
                    // Footnotes too: with the option on, osisplain emits each note
                    // body inline in square brackets, so Gen 1:4's indexed text
                    // gained "[<i>the light from…</i>: Heb. <i>between the light
                    // and between the darkness</i>]" — HTML tags and all — into a
                    // column that is supposed to be plain verse text. Same class of
                    // bug as the morph markers above, same detection route.
                    mgr->setGlobalOption("Footnotes", "Off");
                    mgr->setGlobalOption("Cross-references", "Off");
                    const char *plainC = mod->stripText();
                    // Same order as buildWithProgress: strip the inline markers
                    // first, then test for emptiness, so the row set matches
                    // today's index exactly.
                    std::string plain = [self cleanDisplayText:(plainC ? std::string(plainC) : std::string())];
                    if (!plain.empty()) {
                        std::string lemmas = [self lemmasFor:mod];
                        std::string wordMap = [self wordMapFor:mod];
                        std::string dedupKey = plain + "\x1F" + lemmas + "\x1F" + wordMap;
                        std::map<std::string, int>::iterator pf = plainIds.find(dedupKey);
                        int textId;
                        if (pf == plainIds.end()) {
                            textId = nextPlainId++;
                            plainIds[dedupKey] = textId;
                            std::vector<std::string> fields;
                            fields.push_back(plain);
                            fields.push_back(lemmas);
                            fields.push_back(wordMap);
                            long long row = plainChunks.add(fields);
                            // The whole arithmetic addressing scheme rests on the
                            // ids being dense and issued in order; assert it here
                            // rather than discovering it in the reader.
                            if (row != textId) die(@"plain_texts id %d landed at chunk row %lld", textId, row);
                        } else {
                            textId = pf->second;
                        }
                        bindText(insPlain, 1, modNameStr);
                        sqlite3_bind_int64(insPlain, 2, (sqlite3_int64)vk->getIndex());
                        bindText(insPlain, 3, osisRef);
                        bindText(insPlain, 4, bookOsis);
                        sqlite3_bind_int(insPlain, 5, vk->getTestament());
                        sqlite3_bind_int(insPlain, 6, textId);
                        step1(insPlain, db->db);
                        plainRows++;
                    }
                    // Restore the render config unconditionally — including on the
                    // empty-text path. Leaving any of these Off would silently
                    // strip the corresponding anchors from every subsequent
                    // chapter's tokens.
                    mgr->setGlobalOption("Strong's Numbers", "On");
                    mgr->setGlobalOption("Morphological Tags", "On");
                    mgr->setGlobalOption("Footnotes", "On");
                    mgr->setGlobalOption("Cross-references", "On");
                }
            }

            // Join into one blob. For dedup modules the records become body ids.
            std::string joined;
            std::string kind = dedup ? "bodyref" : "inline";
            for (size_t r = 0; r < records.size(); ++r) {
                if (r) joined.push_back(kEntrySep);
                if (!dedup) {
                    joined += records[r];
                } else if (records[r].empty()) {
                    // empty record stays empty so the loop counter matches
                } else {
                    std::map<std::string, int>::iterator f = bodyIds.find(records[r]);
                    int id;
                    if (f == bodyIds.end()) {
                        id = nextBodyId++;
                        bodyIds[records[r]] = id;
                        std::string bz = zlibDeflate(records[r]);
                        bindText(insBody, 1, modNameStr);
                        sqlite3_bind_int(insBody, 2, id);
                        sqlite3_bind_blob(insBody, 3, bz.data(), (int)bz.size(), SQLITE_TRANSIENT);
                        step1(insBody, db->db);
                    } else {
                        id = f->second;
                    }
                    char idbuf[24];
                    snprintf(idbuf, sizeof(idbuf), "%d", id);
                    joined += idbuf;
                }
            }

            // Skip wholly-empty chapters (nothing to store, and the reader
            // falls back to the "empty chapter" message just as today).
            bool anything = false;
            for (size_t r = 0; r < records.size(); ++r) if (!records[r].empty()) { anything = true; break; }
            if (!anything) continue;

            std::string z = zlibDeflate(joined);
            rawTotal += joined.size();
            blobTotal += z.size();

            bindText(insChapter, 1, modNameStr);
            bindText(insChapter, 2, bookOsis);
            sqlite3_bind_int(insChapter, 3, c);
            sqlite3_bind_int64(insChapter, 4, (sqlite3_int64)chapterOrdinal);
            sqlite3_bind_int(insChapter, 5, (int)records.size());
            sqlite3_bind_int64(insChapter, 6, (sqlite3_int64)joined.size());
            bindText(insChapter, 7, kind);
            sqlite3_bind_blob(insChapter, 8, z.data(), (int)z.size(), SQLITE_TRANSIENT);
            step1(insChapter, db->db);
            chapters++;
        }
    }

    plainChunks.finish();
    noteChunks.finish();

    sqlite3_finalize(insChapter);
    sqlite3_finalize(insBody);
    sqlite3_finalize(insHeading);
    sqlite3_finalize(insNoteIdx);
    sqlite3_finalize(insPlain);

    // Post-compression validation, before the numbers are reported: inflate every
    // chunk this module wrote and compare it against the rows that went in. A
    // compression bug that drops, truncates or reorders a chunk must fail the
    // bake — the reader must never be the thing that discovers it.
    long long plainVerified = plainChunks.validate(db);
    long long noteVerified = noteChunks.validate(db);
    if (plainVerified != nextPlainId) die(@"%@: verified %lld plain rows, expected %d", modName, plainVerified, nextPlainId);
    if (noteVerified != noteRows) die(@"%@: verified %lld note rows, expected %lld", modName, noteVerified, noteRows);

    note(@"  %@: %lld chapters, %lld plain rows (%d distinct texts), %lld notes, %lld headings, %d distinct bodies",
         modName, chapters, plainRows, nextPlainId, noteRows, headingRows, nextBodyId);
    note(@"  %@: chapters raw %.2f MB -> zlib %.2f MB", modName,
         rawTotal / 1048576.0, blobTotal / 1048576.0);
    note(@"  %@: plain_texts %lld rows in %lld chunks, raw %.2f MB -> zlib %.2f MB (re-inflated + compared: %lld rows)",
         modName, plainChunks.rowCount(), plainChunks.chunkCount(),
         plainChunks.rawTotal / 1048576.0, plainChunks.blobTotal / 1048576.0, plainVerified);
    note(@"  %@: notes %lld rows in %lld chunks, raw %.2f MB -> zlib %.2f MB (re-inflated + compared: %lld rows)",
         modName, noteChunks.rowCount(), noteChunks.chunkCount(),
         noteChunks.rawTotal / 1048576.0, noteChunks.blobTotal / 1048576.0, noteVerified);
}

// Mirrors PSSearchCleanDisplayText (PSSearchEngine.mm:266-295) exactly. The app
// applies this to stripText() BEFORE inserting into the FTS table, because with
// the Strong's option on, stripText() interleaves inline `<H0430>` / `<TH8799>`
// markers into the verse text. Storing the raw form instead would both bloat the
// artifact (38.9 MB vs 30.4 MB for KJV) and force Phase 3 to re-derive this,
// which is exactly what dumping the FTS source is meant to avoid.
- (std::string)cleanDisplayText:(const std::string &)plain {
    if (plain.empty()) return std::string();
    static NSRegularExpression *markerRe, *wsRe, *wsBeforePunctRe;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        markerRe = [NSRegularExpression regularExpressionWithPattern:@"<[A-Z][A-Z0-9]*\\d[A-Z0-9-]*>"
                                                             options:0 error:NULL];
        wsRe = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:NULL];
        wsBeforePunctRe = [NSRegularExpression regularExpressionWithPattern:@"\\s+([,.;:!?\\)\\]])"
                                                                    options:0 error:NULL];
    });
    NSString *in = [NSString stringWithUTF8String:plain.c_str()];
    if (!in) in = [[NSString alloc] initWithBytes:plain.data() length:plain.size()
                                         encoding:NSISOLatin1StringEncoding] ?: @"";
    NSMutableString *out = [in mutableCopy];
    [markerRe replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@" "];
    [out replaceOccurrencesOfString:@" [] " withString:@" " options:0 range:NSMakeRange(0, out.length)];
    [wsRe replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@" "];
    [wsBeforePunctRe replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"$1"];
    NSString *trimmed = [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    const char *c = [trimmed UTF8String];
    return c ? std::string(c) : std::string();
}

// Mirrors PSLemmasForCurrentVerse (PSSearchEngine.mm:300-334) exactly. Phase 3
// reimplements this derivation in Swift over the stored chapter tokens (see the
// plain_texts comment in -createSchema), so this stays useful as the reference
// implementation and as the source of the comparison fixtures.
- (std::string)lemmasFor:(sword::SWModule *)mod {
    std::string out;
    sword::AttributeList &words = mod->getEntryAttributes()["Word"];
    for (sword::AttributeList::iterator it = words.begin(); it != words.end(); ++it) {
        int parts = atoi(it->second["PartCount"].c_str());
        if (parts < 1) parts = 1;
        for (int i = 1; i <= parts; ++i) {
            sword::SWBuf key = (parts == 1) ? sword::SWBuf("Lemma") : sword::SWBuf().setFormatted("Lemma.%d", i);
            sword::AttributeValue::iterator li = it->second.find(key);
            if (li == it->second.end()) continue;
            const char *lemmaCStr = li->second.c_str();
            if (!lemmaCStr || !*lemmaCStr) continue;
            const char *colon = strrchr(lemmaCStr, ':');
            const char *token = colon ? (colon + 1) : lemmaCStr;
            if (!*token) continue;
            if (!out.empty()) out += " ";
            std::string t = token;
            out += t;
            if (t.size() >= 2 && t[0] == 'H') {
                if (t[1] == '0') out += " H" + t.substr(2);
                else             out += " H0" + t.substr(1);
            }
        }
    }
    return out;
}

// Mirrors PSWordMapForCurrentVerse (PSSearchEngine.mm:344-395).
- (std::string)wordMapFor:(sword::SWModule *)mod {
    std::string out;
    sword::AttributeList &words = mod->getEntryAttributes()["Word"];
    for (sword::AttributeList::iterator it = words.begin(); it != words.end(); ++it) {
        const char *textCStr = it->second["Text"].c_str();
        if (!textCStr || !*textCStr) continue;
        NSString *surface = [NSString stringWithUTF8String:textCStr];
        if (!surface) continue;
        surface = [surface stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (surface.length == 0) continue;
        surface = [surface stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
        surface = [surface stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

        std::vector<std::string> lemmas;
        int parts = atoi(it->second["PartCount"].c_str());
        if (parts < 1) parts = 1;
        for (int i = 1; i <= parts; ++i) {
            sword::SWBuf key = (parts == 1) ? sword::SWBuf("Lemma") : sword::SWBuf().setFormatted("Lemma.%d", i);
            sword::AttributeValue::iterator li = it->second.find(key);
            if (li == it->second.end()) continue;
            const char *lemmaCStr = li->second.c_str();
            if (!lemmaCStr || !*lemmaCStr) continue;
            const char *colon = strrchr(lemmaCStr, ':');
            const char *token = colon ? (colon + 1) : lemmaCStr;
            if (!*token) continue;
            std::string t = token;
            if (t.empty()) continue;
            lemmas.push_back(t);
            if (t.size() >= 2 && t[0] == 'H') {
                if (t[1] == '0') lemmas.push_back("H" + t.substr(2));
                else             lemmas.push_back("H0" + t.substr(1));
            }
        }
        if (lemmas.empty()) continue;
        if (!out.empty()) out += "\n";
        out += [surface UTF8String];
        out += "\t";
        for (size_t i = 0; i < lemmas.size(); ++i) {
            if (i) out += " ";
            out += lemmas[i];
        }
    }
    return out;
}

// -----------------------------------------------------------------------
// Lexicons
// -----------------------------------------------------------------------
- (void)bakeDictionary:(sword::SWModule *)mod name:(NSString *)modName {
    note(@"baking %@ (lexicon)…", modName);
    // Deliberately NOT "INSERT OR REPLACE": two StrongsRealHebrew keys (02200
    // and 06401) appear twice in the module's own .idx, and for 06401 the second
    // occurrence is a 21-byte "</dictionary>" stub. REPLACE would silently keep
    // that stub and lose the real definition. First occurrence wins, and every
    // collision is reported.
    //
    // The duplicate check runs against dict_keys, whose key column is
    // COLLATE NOCASE — so it now also catches a pair of keys that differ only in
    // case. There are none today (measured: zero case-fold collisions across all
    // 15,824 keys), and if a future module had one, silently dropping the second
    // would be the wrong answer: it would be indistinguishable from the on-disk
    // duplicate case, so this reports it either way.
    sqlite3_stmt *ins = [db prepare:"INSERT INTO dict_keys(module,key,chunk_id,slot) VALUES(?,?,?,?);"];
    sqlite3_stmt *exists = [db prepare:"SELECT 1 FROM dict_keys WHERE module=? AND key=?;"];
    const std::string modNameStr = [modName UTF8String];
    ChunkWriter dictChunks(db, "dict_chunks", modNameStr, kChunkRowsDict, false);

    long long n = 0, numericKeys = 0, otherKeys = 0, dupes = 0;
    mod->setSkipConsecutiveLinks(false);
    *mod = sword::TOP;
    while (!mod->popError()) {
        const char *k = mod->getKeyText();
        std::string key = k ? k : "";
        sword::SWBuf rendered = mod->renderText();
        std::string html(rendered.c_str() ? rendered.c_str() : "", rendered.length());
        if (!key.empty() && !html.empty()) {
            // Key-space assertion (plan §3): Strong's lexicons use fixed-width
            // numeric keys; Robinson's are morph codes like "N-NSF" and are a
            // different key space that must NOT be normalised numerically.
            bool allDigits = true;
            for (size_t i = 0; i < key.size(); ++i) if (!isdigit((unsigned char)key[i])) { allDigits = false; break; }
            bindText(exists, 1, modNameStr);
            bindText(exists, 2, key);
            BOOL already = (sqlite3_step(exists) == SQLITE_ROW);
            sqlite3_reset(exists);
            sqlite3_clear_bindings(exists);
            if (already) {
                dupes++;
                note(@"  NOTE: %@ key '%s' appears more than once on disk; keeping the first (%zu bytes ignored)",
                     modName, key.c_str(), html.size());
                (*mod)++;
                continue;
            }

            if (allDigits) numericKeys++; else otherKeys++;

            // Only the HTML goes into the chunk; the key stays uncompressed in
            // dict_keys so the Dictionary tab can enumerate and count without
            // inflating anything.
            std::vector<std::string> fields;
            fields.push_back(html);
            long long row = dictChunks.add(fields);

            bindText(ins, 1, modNameStr);
            bindText(ins, 2, key);
            sqlite3_bind_int64(ins, 3, row / kChunkRowsDict);
            sqlite3_bind_int(ins, 4, (int)(row % kChunkRowsDict));
            step1(ins, db->db);
            n++;
        }
        (*mod)++;
    }
    dictChunks.finish();
    sqlite3_finalize(ins);
    sqlite3_finalize(exists);

    long long dictVerified = dictChunks.validate(db);
    if (dictVerified != n) die(@"%@: verified %lld dict rows, expected %lld", modName, dictVerified, n);

    note(@"  %@: %lld entries (%lld numeric keys, %lld non-numeric, %lld duplicate keys skipped)",
         modName, n, numericKeys, otherKeys, dupes);
    note(@"  %@: %lld chunks, raw %.2f MB -> zlib %.2f MB (re-inflated + compared: %lld rows)",
         modName, dictChunks.chunkCount(),
         dictChunks.rawTotal / 1048576.0, dictChunks.blobTotal / 1048576.0, dictVerified);

    // The Strong's lexicons must be entirely fixed-width numeric — that is what
    // makes a Swift strongsPad reimplementation (Phase 3) well-defined.
    if ([modName isEqualToString:@"StrongsRealGreek"] || [modName isEqualToString:@"StrongsRealHebrew"]) {
        if (otherKeys != 0) die(@"%@ has %lld non-numeric keys; expected all numeric", modName, otherKeys);
    }
}

// -----------------------------------------------------------------------
// Versification dump
// -----------------------------------------------------------------------
- (void)dumpVersification {
    const sword::VersificationMgr::System *sys =
        sword::VersificationMgr::getSystemVersificationMgr()->getVersificationSystem("KJV");
    if (!sys) die(@"no KJV versification system");

    // English abbreviations come straight from locales.d/abbr.conf, NOT through
    // LocaleMgr: abbr.conf is Encoding=ISO8859-1 while
    // StringMgr::hasUTF8Support() returns true unconditionally
    // (stringmgr.cpp:348-350), so loadConfigDir rejects it
    // (localemgr.cpp:176-186).
    NSMutableDictionary *abbrevs = [NSMutableDictionary dictionary];
    NSString *abbrPath = abbrConfPath;
    if (abbrPath && [[NSFileManager defaultManager] fileExistsAtPath:abbrPath]) {
        NSString *raw = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:abbrPath]
                                              encoding:NSISOLatin1StringEncoding];
        BOOL inText = NO;
        for (NSString *line in [raw componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([t isEqualToString:@"[Text]"]) { inText = YES; continue; }
            if ([t hasPrefix:@"["]) { inText = NO; continue; }
            if (!inText || t.length == 0) continue;
            NSRange eq = [t rangeOfString:@"="];
            if (eq.location == NSNotFound) continue;
            abbrevs[[t substringToIndex:eq.location]] = [t substringFromIndex:eq.location + 1];
        }
        note(@"read %lu English abbreviations from %@", (unsigned long)abbrevs.count, abbrPath);
    } else {
        die(@"cannot find locales.d/abbr.conf (looked at %@)", abbrPath);
    }

    sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
    NSMutableArray *books = [NSMutableArray array];

    for (int b = 0; b < sys->getBookCount(); ++b) {
        const sword::VersificationMgr::Book *bk = sys->getBook(b);
        NSString *longName = [NSString stringWithUTF8String:bk->getLongName()];
        // Localised name, as SwordBook.mm:25 builds it.
        const char *tr = lmgr->translate(bk->getLongName());
        NSString *localised = tr ? [NSString stringWithUTF8String:tr] : longName;
        if (!localised) localised = longName;

        // The app-munged display name (SwordBook.mm:50-55) — III->3, II->2,
        // I->1, " of John"->"" applied in that order.
        NSString *munged = [[[[localised stringByReplacingOccurrencesOfString:@"III " withString:@"3 "]
                              stringByReplacingOccurrencesOfString:@"II " withString:@"2 "]
                             stringByReplacingOccurrencesOfString:@"I " withString:@"1 "]
                            stringByReplacingOccurrencesOfString:@" of John" withString:@""];
        // shortName (SwordBook.mm:58-65): despaced, first 3 chars.
        NSString *despaced = [munged stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *shortName = [despaced substringToIndex:MIN((NSUInteger)3, despaced.length)];

        NSMutableArray *verseMax = [NSMutableArray array];
        for (int c = 1; c <= bk->getChapterMax(); ++c) {
            [verseMax addObject:@(bk->getVerseMax(c))];
        }

        NSMutableDictionary *e = [NSMutableDictionary dictionary];
        e[@"osisName"]      = [NSString stringWithUTF8String:bk->getOSISName()];
        e[@"longName"]      = longName ?: @"";
        e[@"localisedName"] = localised ?: @"";
        e[@"name"]          = munged ?: @"";
        e[@"shortName"]     = shortName ?: @"";
        e[@"preferredAbbreviation"] = [NSString stringWithUTF8String:bk->getPreferredAbbreviation() ?: ""];
        e[@"abbreviation"]  = abbrevs[longName] ?: (abbrevs[localised] ?: @"");
        e[@"testament"]     = @(b < 39 ? 1 : 2);
        e[@"chapterCount"]  = @(bk->getChapterMax());
        e[@"verseMax"]      = verseMax;
        [books addObject:e];
    }

    NSDictionary *root = @{
        @"versification": @"KJV",
        @"schemaVersion": @(kSchemaVersion),
        @"swordVersion": [NSString stringWithUTF8String:sword::SWVersion::currentVersion.getText()],
        @"bookCount": @(sys->getBookCount()),
        @"books": books,
    };

    NSError *err = nil;
    // Sorted keys + pretty printing keeps the file diffable and byte-stable.
    NSData *json = [NSJSONSerialization dataWithJSONObject:root
                                                  options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                    error:&err];
    if (!json) die(@"JSON serialisation failed: %@", err);
    NSString *path = [outDir stringByAppendingPathComponent:@"Versification-KJV.json"];
    if (![json writeToFile:path options:NSDataWritingAtomic error:&err]) {
        die(@"cannot write %@: %@", path, err);
    }
    note(@"wrote %@ (%lu books, %.1f KB)", path, (unsigned long)books.count, json.length / 1024.0);
}

// -----------------------------------------------------------------------
// Whole-store validation
//
// The per-module ChunkWriter::validate already proves every chunk inflates back
// to the rows that went in. This is the other half: that the LOGICAL row counts
// are the ones Phase 2 measured against the live engine. A compression change
// that silently lost a whole module's tail would satisfy the per-chunk check
// (what was written is what reads back) and only this catches it.
//
// The numbers are hardcoded on purpose. They are the measurements the Phase 2
// cross-check validated against real SWORD output, so they are an external
// expectation, not a self-derived one. If a module is legitimately updated these
// have to be re-measured and changed deliberately.
// -----------------------------------------------------------------------
- (void)validateTotals {
    struct Expectation { const char *sql; long long want; const char *what; };
    const Expectation checks[] = {
        {"SELECT count(*) FROM verses_plain WHERE module='KJV'",   31102, "KJV verses_plain rows"},
        {"SELECT count(*) FROM verses_plain WHERE module='MHCC'",  27715, "MHCC verses_plain rows"},
        {"SELECT count(*) FROM notes_index WHERE module='KJV'",     6959, "KJV notes"},
        {"SELECT count(*) FROM notes_index",                        6959, "notes across all modules"},
        {"SELECT count(*) FROM dict_keys WHERE module='Robinson'",  1526, "Robinson keys"},
        {"SELECT count(*) FROM dict_keys WHERE module='StrongsRealGreek'",  5624, "StrongsRealGreek keys"},
        {"SELECT count(*) FROM dict_keys WHERE module='StrongsRealHebrew'", 8674, "StrongsRealHebrew keys"},
        {"SELECT count(*) FROM chapters WHERE module='KJV'",        1189, "KJV chapters"},
        {"SELECT count(*) FROM chapters WHERE module='MHCC'",       1189, "MHCC chapters"},
    };
    for (size_t i = 0; i < sizeof(checks) / sizeof(checks[0]); ++i) {
        sqlite3_stmt *st = [db prepare:checks[i].sql];
        if (sqlite3_step(st) != SQLITE_ROW) die(@"validation query failed: %s", checks[i].sql);
        long long got = sqlite3_column_int64(st, 0);
        sqlite3_finalize(st);
        if (got != checks[i].want) {
            die(@"VALIDATION FAILED: %s = %lld, expected %lld", checks[i].what, got, checks[i].want);
        }
        note(@"  ok  %-34s = %lld", checks[i].what, got);
    }

    // Every plain_texts row a verses_plain row points at must exist, and the
    // arithmetic addressing must hold: text_id `n` lives at chunk n/256, slot
    // n%256. Checking it in SQL is cheap and catches an off-by-one in the writer
    // that the per-chunk comparison cannot see.
    sqlite3_stmt *st = [db prepare:
        "SELECT count(*) FROM verses_plain v LEFT JOIN plain_texts_chunks c"
        "  ON c.module = v.module AND c.chunk_id = v.text_id / 256"
        " WHERE c.chunk_id IS NULL OR v.text_id % 256 >= c.row_count;"];
    if (sqlite3_step(st) != SQLITE_ROW) die(@"addressing validation failed");
    long long orphans = sqlite3_column_int64(st, 0);
    sqlite3_finalize(st);
    if (orphans) die(@"VALIDATION FAILED: %lld verses_plain rows point outside their chunk", orphans);
    note(@"  ok  %-34s = 0", "verses_plain rows off their chunk");
}

// -----------------------------------------------------------------------
// Driver
// -----------------------------------------------------------------------
- (void)run {
    [self configureOptions];
    [self createSchema];

    // One transaction for the whole build: ~40k inserts otherwise dominate
    // wall-clock, and a partial DB is useless anyway.
    [db exec:"BEGIN IMMEDIATE;"];

    // Iterate the modules in a fixed, name-sorted order so the row order (and
    // therefore the file bytes) does not depend on SWMgr's map iteration.
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (sword::ModMap::iterator it = mgr->Modules.begin(); it != mgr->Modules.end(); ++it) {
        [names addObject:[NSString stringWithUTF8String:it->second->getName()]];
    }
    [names sortUsingSelector:@selector(compare:)];
    note(@"found %lu modules: %@", (unsigned long)names.count, [names componentsJoinedByString:@", "]);

    for (NSString *name in names) {
        sword::SWModule *mod = mgr->getModule([name UTF8String]);
        if (!mod) die(@"module %@ vanished", name);
        const char *type = mod->getType();
        NSString *t = type ? [NSString stringWithUTF8String:type] : @"";

        [self setMeta:[NSString stringWithFormat:@"module.%@.version", name]
                   to:mod->getConfigEntry("Version") ? [NSString stringWithUTF8String:mod->getConfigEntry("Version")] : @""];
        [self setMeta:[NSString stringWithFormat:@"module.%@.type", name] to:t];

        // Phase 5 step 4: the last three things the app read off the live module.
        //
        // `lang` mirrors -[SwordModule lang] (swModule->getLanguage()), used for
        // chapterPage's xml:lang substitution. `direction` mirrors the raw
        // `Direction=` conf entry, which -isRTL compares against "RtoL"; the
        // comparison stays in the reader so the *value* is what is baked, not the
        // verdict. All five shipped modules are Lang=en with no Direction=, so this
        // is provably a no-op today — which is exactly why the reader must read the
        // baked value rather than hardcoding "en": the no-op is a property of the
        // content, not of the code.
        const char *lang = mod->getLanguage();
        [self setMeta:[NSString stringWithFormat:@"module.%@.lang", name]
                   to:lang ? [NSString stringWithUTF8String:lang] : @""];
        const char *dir = mod->getConfigEntry("Direction");
        [self setMeta:[NSString stringWithFormat:@"module.%@.direction", name]
                   to:dir ? [NSString stringWithUTF8String:dir] : @""];
        [self setMeta:[NSString stringWithFormat:@"module.%@.features", name]
                   to:[self featureListForModule:mod]];

        if ([t isEqualToString:@"Biblical Texts"]) {
            [self bakeVerseModule:mod name:name isCommentary:NO];
        } else if ([t isEqualToString:@"Commentaries"]) {
            [self bakeVerseModule:mod name:name isCommentary:YES];
        } else if ([t isEqualToString:@"Lexicons / Dictionaries"]) {
            [self bakeDictionary:mod name:name];
        } else {
            die(@"unexpected module type '%@' for %@", t, name);
        }
    }

    [self setMeta:@"schemaVersion" to:[NSString stringWithFormat:@"%d", kSchemaVersion]];
    [self setMeta:@"swordVersion" to:[NSString stringWithUTF8String:sword::SWVersion::currentVersion.getText()]];
    [self setMeta:@"tokenGrammar" to:@"v2"];
    [self setMeta:@"chunkRows.plain_texts" to:[NSString stringWithFormat:@"%d", kChunkRowsPlain]];
    [self setMeta:@"chunkRows.dict" to:[NSString stringWithFormat:@"%d", kChunkRowsDict]];
    [self setMeta:@"chunkRows.notes" to:[NSString stringWithFormat:@"%d", kChunkRowsNotes]];

    [self validateTotals];

    [db exec:"COMMIT;"];
    // VACUUM after the bulk load so the file has no free pages — otherwise the
    // byte image depends on insert-time page churn and determinism is lost.
    [db exec:"VACUUM;"];
    [db close];

    [self dumpVersification];

    note(@"entries seen %lld, non-empty stored %lld, round-trip checks passed %lld",
         entriesSeen, entriesStored, roundTripChecked);
    note(@"SELF-CHECK: token round-trip byte-exact on all %lld checked entries", roundTripChecked);
    note(@"SELF-CHECK: no passagestudy.jsp substring survived tokenisation");
    note(@"done.");
}

@end

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *modPath = nil, *locPath = nil, *outPath = nil;
        for (int i = 1; i < argc; ++i) {
            NSString *a = [NSString stringWithUTF8String:argv[i]];
            if ([a isEqualToString:@"--modules"] && i + 1 < argc) modPath = [NSString stringWithUTF8String:argv[++i]];
            else if ([a isEqualToString:@"--locales"] && i + 1 < argc) locPath = [NSString stringWithUTF8String:argv[++i]];
            else if ([a isEqualToString:@"--out"] && i + 1 < argc) outPath = [NSString stringWithUTF8String:argv[++i]];
            else die(@"unknown argument: %@\nusage: swordbake --modules DIR --locales DIR --out DIR", a);
        }
        if (!modPath || !outPath) die(@"usage: swordbake --modules DIR [--locales DIR] --out DIR");
        if (!locPath) locPath = [modPath stringByAppendingPathComponent:@"locales.d"];

        note(@"SWORD %s", sword::SWVersion::currentVersion.getText());
        note(@"modules: %@", modPath);
        note(@"locales: %@", locPath);
        note(@"out:     %@", outPath);

        Baker *baker = [[Baker alloc] initWithModulePath:modPath localePath:locPath outDir:outPath];
        [baker run];
    }
    return 0;
}
