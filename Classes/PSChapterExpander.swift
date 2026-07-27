//
//  PSChapterExpander.swift
//  PocketSword
//
//  Expands the content store's token sentinels back into the exact HTML the SWORD
//  markup-filter chain emitted. Phase 3 of SWORD_REMOVAL_PLAN.md.
//
//  This is a transliteration of `tools/swordbake/crosscheck.py`'s `expand()`,
//  which is itself an independent reimplementation of `main.mm`'s
//  `expandEntry()`. Three implementations of one grammar sounds like duplication,
//  and it is on purpose: the converter's own round-trip check is self-referential
//  (it would pass even if the wrong entries had been captured), so the value comes
//  from the sides not sharing code. If this file drifts from the grammar,
//  PSContentReaderTests fails against the committed live-SWORD fixtures.
//
//  === Option gating ===
//
//  A disabled toggle SKIPS its token; it does not post-process the HTML. That is
//  byte-exact rather than approximate, confirmed in the engine source:
//  with Strong's off, osisstrongs.cpp:242-256 strips the `lemma` attribute before
//  osishtmlhref.cpp's processLemma (:209) runs, so the anchor is never emitted and
//  the surrounding text is untouched. Same shape for morph and footnotes.
//
//  Red-letter is the exception and the one that matters: with the option off,
//  osisredletterwords.cpp strips who="Jesus" from the <q> tag, so
//  osishtmlhref.cpp:581/615 never emit the span — but the quote marks and THE
//  ENCLOSED TEXT still render. Measured, all 2,038 spans in the corpus contain
//  nested Strong's/morph tokens, so the payload must be recursively expanded, not
//  dropped. A CSS-only "hide the span" shortcut cannot reproduce this: SWORD omits
//  the element, so the DOM differs and byte parity is impossible.
//
//  === Titles are gated differently in a body and in a heading ===
//
//  TOK_TITLE is headings-gated inside a CHAPTER RECORD but unconditional inside a
//  stored HEADING:
//
//   * In a record, every title token is a non-canonical (Interverse) title,
//     because osisheadings.cpp:132 keeps canonical preverse titles out of the body
//     entirely while processEntryAttributes is on. So `option || canonical`
//     reduces to `option`.
//   * In a heading, the app renders the stored buffer through `renderText(buf)`,
//     which turns processEntryAttributes OFF — so
//     `(!preverse || !processEntryAttributes) && (option || canonical)` emits the
//     wrapper for a canonical heading whatever the option says.
//
//  Hence `Options.forHeading`. One flat token->option table gets eight of the ten
//  all-off fixtures wrong.
//

import Foundation

enum PSChapterExpander {

    // MARK: - Token grammar (must match tools/swordbake/main.mm)

    private static let strongsOpen: Character   = "\u{0001}"
    private static let strongsClose: Character  = "\u{0002}"
    private static let morphOpen: Character     = "\u{0003}"
    private static let morphClose: Character    = "\u{0004}"
    private static let noteOpen: Character      = "\u{0005}"
    private static let noteClose: Character     = "\u{0006}"
    private static let xrefOpen: Character      = "\u{0007}"
    private static let xrefClose: Character     = "\u{0008}"
    private static let titleOpen: Character     = "\u{000B}"
    private static let titleClose: Character    = "\u{000C}"
    private static let scripRefOpen: Character  = "\u{000E}"
    private static let scripRefClose: Character = "\u{000F}"
    private static let redLetterOpen: Character  = "\u{0011}"
    private static let redLetterClose: Character = "\u{0012}"

    /// The exact strings osishtmlhref.cpp's MyUserData ctor installs (:118-119).
    /// The trailing space is part of the construct — with the option off SWORD
    /// emits neither string, so the space goes too.
    private static let wocOpenHTML = "<span class=\"WordOfChrist\"> "
    private static let wocCloseHTML = "</span> "

    // MARK: - Options

    /// The render axes that gate a token. These are the seven user-facing toggles'
    /// subset that actually affects the token stream; the other four options
    /// `setPreferences` pushes (glosses, variants, greekAccents, hebrewPoints,
    /// hebrewCantillation) act on source text the converter already baked, so they
    /// have no token to gate — see PSContentReader for why that is safe for the
    /// five shipped modules.
    struct Options {
        var strongs = true
        var morphs = true
        var footnotes = true
        var redLetter = true
        var headings = true

        static let allOn = Options()
        static let allOff = Options(strongs: false, morphs: false, footnotes: false,
                                    redLetter: false, headings: false)

        /// The variant to expand a stored heading's html under: as the body, except
        /// the title wrapper is always emitted (see the file header).
        var forHeading: Options {
            var copy = self
            copy.headings = true
            return copy
        }
    }

    // MARK: - Anchor templates (osishtmlhref.cpp)

    private static func strongsAnchor(type: String, value: String, shown: String) -> String {
        "<a href=\"passagestudy.jsp?action=showStrongs&amp;type=\(type)&amp;value=\(value)\""
            + " class=\"strongs\">&lt;\(shown)&gt;</a>"
    }

    private static func morphAnchor(type: String, value: String, shown: String) -> String {
        "<a href=\"passagestudy.jsp?action=showMorph&amp;type=\(type)&amp;value=\(value)\""
            + " class=\"morph\">(\(shown))</a>"
    }

    private static func noteAnchor(_ ch: Character, value: String, module: String, passage: String) -> String {
        "<a href=\"passagestudy.jsp?action=showNote&amp;type=\(ch)&amp;value=\(value)"
            + "&amp;module=\(module)&amp;passage=\(passage)\" class=\"\(ch)\">*\(ch)</a>"
    }

    /// osishtmlhref.cpp:327. Note the RAW `&` separators (not `&amp;`) and that
    /// only the opening tag is emitted — the matching `</a>` comes from the tag's
    /// own end-tag branch at :341, which is part of the surrounding text.
    private static func scripRefAnchor(_ value: String) -> String {
        "<a href=\"passagestudy.jsp?action=showRef&type=scripRef&value=\(value)&module=\">"
    }

    // MARK: - Expansion

    /// Expand one tokenised entry.
    ///
    /// Returns nil on a malformed token stream (an unterminated token, a payload
    /// with the wrong field count, an unknown Strong's flag). That is a corrupt
    /// store, and the caller falls back to SWORD rather than rendering a partial
    /// verse.
    static func expand(_ input: String, options: Options = .allOn) -> String? {
        var out = ""
        out.reserveCapacity(input.count * 3)
        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            guard let closer = closingToken(for: c) else {
                out.append(c)
                i += 1
                continue
            }
            guard let end = nextIndex(of: closer, in: chars, from: i + 1) else {
                PSContentStore.fail("unterminated token U+\(String(format: "%04X", c.unicodeScalars.first!.value))")
                return nil
            }
            let payload = String(chars[(i + 1)..<end])

            if let axis = gatingAxis(for: c), !axis(options) {
                // Option off. Red-letter keeps its payload (recursively expanded);
                // the anchors have no text of their own that survives.
                if c == redLetterOpen {
                    guard let inner = expand(payload, options: options) else { return nil }
                    out += inner
                }
                i = end + 1
                continue
            }

            switch c {
            case strongsOpen:
                guard let anchor = expandStrongs(payload) else { return nil }
                out += anchor
            case morphOpen:
                guard let anchor = expandMorph(payload) else { return nil }
                out += anchor
            case noteOpen, xrefOpen:
                let fields = payload.components(separatedBy: "|")
                guard fields.count == 3 else {
                    PSContentStore.fail("bad note payload: \(payload.debugDescription)")
                    return nil
                }
                out += noteAnchor(c == xrefOpen ? "x" : "n",
                                  value: fields[0], module: fields[1], passage: fields[2])
            case titleOpen:
                guard let inner = expand(payload, options: options) else { return nil }
                out += "<p><b>" + inner + "</b></p>"
            case scripRefOpen:
                guard !payload.contains("|") else {
                    PSContentStore.fail("bad scripRef payload: \(payload.debugDescription)")
                    return nil
                }
                out += scripRefAnchor(payload)
            case redLetterOpen:
                guard let inner = expand(payload, options: options) else { return nil }
                out += wocOpenHTML + inner + wocCloseHTML
            default:
                PSContentStore.fail("unhandled token")
                return nil
            }
            i = end + 1
        }
        return out
    }

    // MARK: - Token dispatch

    private static func closingToken(for open: Character) -> Character? {
        switch open {
        case strongsOpen:   return strongsClose
        case morphOpen:     return morphClose
        case noteOpen:      return noteClose
        case xrefOpen:      return xrefClose
        case titleOpen:     return titleClose
        case scripRefOpen:  return scripRefClose
        case redLetterOpen: return redLetterClose
        default:            return nil
        }
    }

    /// Which option gates a token, as a predicate. nil means "always emitted".
    private static func gatingAxis(for open: Character) -> ((Options) -> Bool)? {
        switch open {
        case strongsOpen:   return { $0.strongs }
        case morphOpen:     return { $0.morphs }
        case noteOpen, xrefOpen: return { $0.footnotes }
        case titleOpen:     return { $0.headings }
        case redLetterOpen: return { $0.redLetter }
        // scripRef is not option-gated: osishtmlhref.cpp:327 emits it for every
        // <reference> tag unconditionally.
        case scripRefOpen:  return nil
        default:            return nil
        }
    }

    /// A token's payload may contain other tokens (anchors inside a heading,
    /// Strong's inside a WoC span), so scan for THIS token's own close rather than
    /// the first close byte of any kind. Neither the title nor the red-letter token
    /// nests inside itself — the converter refuses to build a nested one — so no
    /// depth counter is needed.
    private static func nextIndex(of target: Character, in chars: [Character], from start: Int) -> Int? {
        var i = start
        while i < chars.count {
            if chars[i] == target { return i }
            i += 1
        }
        return nil
    }

    // MARK: - Payload forms

    /// `\x01 G|H|- value \x02`, or the explicit `*type|value|shown` fallback.
    /// Measured over all 373,619 KJV occurrences, `shown == value` always and
    /// `type` is exactly "Greek" or "Hebrew" — the compact form covers them all,
    /// and the explicit form exists so nothing can ever be lost.
    private static func expandStrongs(_ payload: String) -> String? {
        if payload.hasPrefix("*") {
            let fields = String(payload.dropFirst()).components(separatedBy: "|")
            guard fields.count == 3 else {
                PSContentStore.fail("bad strongs payload: \(payload.debugDescription)")
                return nil
            }
            return strongsAnchor(type: fields[0], value: fields[1], shown: fields[2])
        }
        guard let flag = payload.first else {
            PSContentStore.fail("empty strongs payload")
            return nil
        }
        let value = String(payload.dropFirst())
        let type: String
        switch flag {
        case "G": type = "Greek"
        case "H": type = "Hebrew"
        case "-": type = ""
        default:
            PSContentStore.fail("bad strongs flag '\(flag)'")
            return nil
        }
        return strongsAnchor(type: type, value: value, shown: value)
    }

    /// `\x03 type|value \x04`, or the explicit `*type|value|shown` fallback.
    ///
    /// Two derivations are reconstructed here rather than stored:
    ///  * an empty `type` field means `type == "strongMorph%3A" + value`
    ///    (71,016 of 216,395 cases);
    ///  * `shown` is `value` with a leading "TH"/"TG" dropped when a digit follows
    ///    (osishtmlhref.cpp:92-93).
    private static func expandMorph(_ payload: String) -> String? {
        if payload.hasPrefix("*") {
            let fields = String(payload.dropFirst()).components(separatedBy: "|")
            guard fields.count == 3 else {
                PSContentStore.fail("bad morph payload: \(payload.debugDescription)")
                return nil
            }
            return morphAnchor(type: fields[0], value: fields[1], shown: fields[2])
        }
        let fields = payload.components(separatedBy: "|")
        guard fields.count == 2 else {
            PSContentStore.fail("bad morph payload: \(payload.debugDescription)")
            return nil
        }
        let value = fields[1]
        let type = fields[0].isEmpty ? "strongMorph%3A" + value : fields[0]
        var shown = value
        let v = Array(value)
        if v.count >= 3, v[0] == "T", v[1] == "H" || v[1] == "G", v[2].isNumber, v[2].isASCII {
            shown = String(v[2...])
        }
        return morphAnchor(type: type, value: value, shown: shown)
    }
}
