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

// Record separator inside a chapter blob.
static const char kEntrySep = '\0';

static const int kSchemaVersion = 1;

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

        // Whichever construct comes first.
        size_t next = std::min(a == std::string::npos ? in.size() : a,
                               t == std::string::npos ? in.size() : t);
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
            default: break;
        }
        if (!kind) { out += in[i++]; continue; }
        size_t end;
        if (kind == 5) {
            // A title token's payload may contain other tokens (anchors inside a
            // heading), so scan for ITS close specifically rather than the first
            // close byte of any kind. Titles never nest — tokeniseEntry refuses
            // to build a nested one — so no depth counter is needed.
            end = findFrom(in, TOK_TITLE_CLOSE, i + 1);
        } else {
            end = findFrom(in, closeTok, i + 1);
        }
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
        }
        i = end + 1;
    }
    return out;
}

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

     // Note bodies, ALREADY RENDERED via renderText(buf) — the same call the
     // app makes at SwordModule.mm:567, which sets processEntryAttributes=false
     // and is a different code path from rendering at a key position.
     "CREATE TABLE notes("
     "  module TEXT NOT NULL,"
     "  osis_ref TEXT NOT NULL,"
     "  marker TEXT NOT NULL,"
     "  type TEXT,"
     "  body TEXT,"
     "  ref_list TEXT);"

     // Lexicon entries keyed on the canonical on-disk key.
     "CREATE TABLE dict_entries("
     "  module TEXT NOT NULL,"
     "  key TEXT NOT NULL,"
     "  html TEXT NOT NULL,"
     "  PRIMARY KEY(module, key));"

     // FTS build source, dumped from real stripText()/EntryAttributes (with
     // PSSearchCleanDisplayText already applied, exactly as
     // -buildWithProgress: does) so the on-device index build stays a copy loop
     // with zero derivation logic. No FTS index is shipped: keeping the
     // on-device build sidesteps macOS<->iOS FTS5 on-disk compatibility
     // entirely.
     //
     // The text is held one level of indirection away in plain_texts. RawCom
     // (MHCC) points a whole verse range at one shared comment body, so the
     // per-verse text repeats — inlining it costs 28 MB against 2 MB deduped.
     // Phase 3's build loop becomes a JOIN rather than a scan; still no
     // derivation.
     "CREATE TABLE plain_texts("
     "  module TEXT NOT NULL,"
     "  id INT NOT NULL,"
     "  text_plain TEXT NOT NULL,"
     "  lemmas TEXT,"
     "  word_map TEXT,"
     "  PRIMARY KEY(module, id));"

     "CREATE TABLE verses_plain("
     "  module TEXT NOT NULL,"
     "  ordinal INT NOT NULL,"
     "  osis_ref TEXT NOT NULL,"
     "  book_osis TEXT NOT NULL,"
     "  testament INT NOT NULL,"
     "  text_id INT NOT NULL);"

     "CREATE INDEX idx_notes ON notes(module, osis_ref);"
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
    sqlite3_stmt *insNote = [db prepare:
        "INSERT INTO notes(module,osis_ref,marker,type,body,ref_list) VALUES(?,?,?,?,?,?);"];
    sqlite3_stmt *insPlain = [db prepare:
        "INSERT INTO verses_plain(module,ordinal,osis_ref,book_osis,testament,text_id)"
        " VALUES(?,?,?,?,?,?);"];
    sqlite3_stmt *insPlainText = [db prepare:
        "INSERT INTO plain_texts(module,id,text_plain,lemmas,word_map) VALUES(?,?,?,?,?);"];
    // Dedup key is the full (text, lemmas, word_map) triple, so two verses only
    // share a row when all three agree.
    std::map<std::string, int> plainIds;
    int nextPlainId = 0;

    const std::string modNameStr = [modName UTF8String];

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

                        bindText(insNote, 1, modNameStr);
                        bindText(insNote, 2, osisRef);
                        bindText(insNote, 3, marker);
                        bindText(insNote, 4, type);
                        bindText(insNote, 5, rbt);
                        bindText(insNote, 6, refList);
                        step1(insNote, db->db);
                        noteRows++;
                    }
                }

                // FTS source row. stripText() does NOT run the UTF8HTML
                // encoding filter, so this column is raw UTF-8 (unlike the
                // entity-escaped HTML columns).
                if (v >= 1) {
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
                            bindText(insPlainText, 1, modNameStr);
                            sqlite3_bind_int(insPlainText, 2, textId);
                            bindText(insPlainText, 3, plain);
                            bindText(insPlainText, 4, lemmas);
                            bindText(insPlainText, 5, wordMap);
                            step1(insPlainText, db->db);
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

    sqlite3_finalize(insChapter);
    sqlite3_finalize(insBody);
    sqlite3_finalize(insHeading);
    sqlite3_finalize(insNote);
    sqlite3_finalize(insPlain);
    sqlite3_finalize(insPlainText);

    note(@"  %@: %lld chapters, %lld plain rows (%d distinct texts), %lld notes, %lld headings, %d distinct bodies",
         modName, chapters, plainRows, nextPlainId, noteRows, headingRows, nextBodyId);
    note(@"  %@: raw %.2f MB -> zlib %.2f MB", modName,
         rawTotal / 1048576.0, blobTotal / 1048576.0);
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

// Mirrors PSLemmasForCurrentVerse (PSSearchEngine.mm:300-334) exactly, so the
// on-device index build becomes a copy loop.
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
    sqlite3_stmt *ins = [db prepare:"INSERT INTO dict_entries(module,key,html) VALUES(?,?,?);"];
    sqlite3_stmt *exists = [db prepare:"SELECT 1 FROM dict_entries WHERE module=? AND key=?;"];
    const std::string modNameStr = [modName UTF8String];

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

            bindText(ins, 1, modNameStr);
            bindText(ins, 2, key);
            bindText(ins, 3, html);
            step1(ins, db->db);
            n++;
        }
        (*mod)++;
    }
    sqlite3_finalize(ins);
    sqlite3_finalize(exists);
    note(@"  %@: %lld entries (%lld numeric keys, %lld non-numeric, %lld duplicate keys skipped)",
         modName, n, numericKeys, otherKeys, dupes);

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
    [self setMeta:@"tokenGrammar" to:@"v1"];

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
