//
//  PSInfoPopupContent.swift
//  PocketSword
//
//  The parsed content of a study popup — the HTML plus the Greek/Hebrew lemma and
//  transliteration pulled out of a rendered lexicon entry.
//
//  Wave 8 split this out of `PSInfoPopupViewController.{h,mm}` -> `.swift`, whose
//  presentation half (467 lines of UIVisualEffectView / UIStackView /
//  NSLayoutConstraint) is replaced by `StudyPopupSheet` in SwiftUIStudyViews.swift.
//  This half is unchanged and deliberately so: the lexeme parsing below is the
//  product of working through what the bundled strongsrealgreek /
//  strongsrealhebrew modules actually render — nested beta-code brackets, the ~114
//  Hebrew entries whose inline <sup> vowel survives a tag strip as a spurious
//  ASCII letter, numeric character references that must be decoded before the
//  script can be recognised at all. It is content, not chrome.
//
//  The class stays an `NSObject` subclass. Nothing requires that any more, but it
//  costs nothing and `PSSearchHistoryItem` / `PSVerseTextEntry` alongside it are
//  the same shape.
//

import UIKit
import WebKit

final class PSInfoPopupContent: NSObject {
    let html: String
    let contextTitle: String?
    let reference: String?
    let searchTerm: String?
    /// The actual Greek/Hebrew lemma (e.g. "ὁ"), parsed from the rendered
    /// lexicon entry. nil when the module isn't a standard Strong's lexicon.
    let lemma: String?
    /// The transliteration (e.g. "ho"), parsed from the first `{…}` token.
    let transliteration: String?

    var isStrongsEntry: Bool {
        reference != nil
    }

    var isHebrew: Bool {
        reference?.hasPrefix("H") ?? false
    }

    init(html: String) {
        self.html = html
        self.contextTitle = nil
        self.reference = nil
        self.searchTerm = nil
        self.lemma = nil
        self.transliteration = nil
    }

    init(strongsHTML html: String, rawEntry: String?, reference rawReference: String, allowsSearch: Bool) {
        let normalizedReference = Self.normalizedStrongsReference(rawReference)
        let isHebrew = normalizedReference.hasPrefix("H")
        let lexeme = Self.parseStrongsLexeme(fromRenderedEntry: rawEntry)

        self.html = html
        self.contextTitle = NSLocalizedString(
            isHebrew ? "PreferencesHebrewStrongsLexiconTitle" : "PreferencesGreekStrongsLexiconTitle",
            comment: ""
        )
        self.reference = normalizedReference
        self.searchTerm = allowsSearch ? normalizedReference : nil
        self.lemma = lexeme.lemma
        self.transliteration = lexeme.transliteration
    }

    private static func normalizedStrongsReference(_ reference: String) -> String {
        let uppercased = reference
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let prefix = uppercased.first, prefix == "G" || prefix == "H" else {
            return uppercased
        }

        let digits = uppercased.dropFirst()
        let withoutLeadingZeroes = digits.drop(while: { $0 == "0" })
        return String(prefix) + (withoutLeadingZeroes.isEmpty ? "0" : String(withoutLeadingZeroes))
    }

    /// Pull the leading lemma and transliteration out of a rendered Strong's
    /// entry. The bundled strongsrealgreek/strongsrealhebrew modules render as
    /// `ὁ [O(] {ho} \ho\ including the feminine ἡ …` — the lemma is the text
    /// before the first `[`, the transliteration is the first `{…}` token.
    /// Defensive: returns (nil, nil) for anything that doesn't look like a
    /// standard lexeme so callers fall back to showing the reference.
    static func parseStrongsLexeme(fromRenderedEntry rawEntry: String?) -> (lemma: String?, transliteration: String?) {
        guard let rawEntry = rawEntry else { return (nil, nil) }

        // The rendered entry looks like (HTML tags + numeric entities intact):
        //   <a name="4018">4018</a> &#960;&#949;&#961;… [PERIBO/LAION] {perib&#243;laion} \…\ neuter of…
        // Strip tags, decode entities to real Unicode, collapse whitespace,
        // then drop the leading key number the hidden anchor leaves behind.
        let decoded = decodingHTMLEntities(
            rawEntry.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        )
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let body = decoded
            .replacingOccurrences(of: "^\\d+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let openBracket = body.firstIndex(of: "[") else { return (nil, nil) }
        let candidate = String(body[body.startIndex..<openBracket])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // ~114 strongsrealhebrew entries (H726/H728/H971/H1208/H1269…) render an
        // inline <sup> vowel that survives the tag strip as a spurious trailing
        // ASCII letter, e.g. "אֲרוֹן o". The lemma is script only, so keep just
        // the leading run up to the first ASCII letter.
        let lemma = String(candidate.prefix(while: { !($0.isASCII && $0.isLetter) }))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Reject anything that isn't a short run of actual script — the real
        // lemma is a handful of non-ASCII letters, not a sentence.
        let hasNonASCIILetter = lemma.unicodeScalars.contains { $0.value > 0x7F && CharacterSet.letters.contains($0) }
        guard !lemma.isEmpty, lemma.count <= 40, hasNonASCIILetter else {
            return (nil, nil)
        }

        // Transliteration. Greek renders `θεός [QEO/S] {theós} \…\` — the
        // transliteration is the `{…}` immediately after the bracket group.
        // Hebrew renders `חשך [chôshek] \…\ … {misery} …` — the transliteration
        // is *inside* the brackets, and any `{…}` later on is a gloss in the
        // definition, not a transliteration. So: prefer a `{…}` right after the
        // closing `]`; otherwise fall back to the bracket content when it reads
        // like a transliteration (has a lowercase letter, i.e. not Greek beta-code).
        var transliteration: String? = nil
        if let closeBracket = matchingCloseBracket(in: body, openBracket: openBracket) {
            let afterBracket = body[body.index(after: closeBracket)...]
                .drop(while: { $0 == " " })
            if afterBracket.first == "{", let brace = afterBracket.firstIndex(of: "}") {
                let inner = String(afterBracket[afterBracket.index(after: afterBracket.startIndex)..<brace])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !inner.isEmpty { transliteration = inner }
            } else {
                let bracketContent = String(body[body.index(after: openBracket)..<closeBracket])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // A transliteration reads as lowercase Latin — possibly with
                // diacritics (Hebrew renders `[chôshek]`, `['â‛]`). Greek
                // beta-code is uppercase ASCII (`QEO/S`), so requiring a
                // lowercase letter distinguishes the two without an ASCII
                // restriction that would drop diacritic-only Hebrew translits.
                if bracketContent.contains(where: { $0.isLowercase }) {
                    transliteration = bracketContent
                }
            }
        }

        return (lemma, transliteration)
    }

    /// The `]` that closes the `[` at `openBracket`, honouring nesting. Greek
    /// beta-code occasionally nests brackets (`[…[1GE]…]`, e.g. G1490), so a
    /// naive `firstIndex(of: "]")` lands on the inner close and truncates the
    /// group before the trailing `{…}` transliteration. Returns nil if the
    /// bracket is never closed.
    private static func matchingCloseBracket(in body: String, openBracket: String.Index) -> String.Index? {
        var depth = 0
        var index = openBracket
        while index < body.endIndex {
            let character = body[index]
            if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = body.index(after: index)
        }
        return nil
    }

    /// Decode the HTML entities the SWORD markup filter emits (named basics +
    /// decimal/hex numeric character references) into real Unicode. The lexicon
    /// renders Greek/Hebrew as `&#960;`-style entities, so we must decode before
    /// we can recognise the script.
    private static func decodingHTMLEntities(_ input: String) -> String {
        var result = input
        let named: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<",
            "&gt;": ">", "&quot;": "\"", "&apos;": "'"
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        guard result.contains("&#"),
              let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") else {
            return result
        }

        let ns = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return result }

        var output = ""
        var cursor = 0
        for match in matches {
            output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let isHex = ns.substring(with: match.range(at: 1)) == "x"
            let digits = ns.substring(with: match.range(at: 2))
            if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                output.unicodeScalars.append(scalar)
            }
            cursor = match.range.location + match.range.length
        }
        output += ns.substring(from: cursor)
        return output
    }
}
