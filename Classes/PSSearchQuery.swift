//
//  PSSearchQuery.swift
//  PocketSword
//
//  Translates user-typed search input into an FTS5 MATCH expression. Handles:
//    * quoted "phrases"
//    * All (AND) / Any (OR) / Exact (whole-input phrase) match types
//    * Fuzzy toggle (suffix '*' on each non-phrase token)
//    * Strong's toggle (H0xxx / Hxxx equivalence under a lemmas: column filter)
//    * Diacritic folding so accented input matches unaccented storage
//
//  Migrated from PSSearchQuery.{h,mm} (Swift migration PR 1.2). This file is a
//  pure-Foundation value leaf — the former .mm contained NO sword:: usage. The
//  diacritic-folding sequence (NFD -> drop combining-mark ranges -> NFC ->
//  lowercase) is reproduced BYTE-FOR-BYTE because it must stay compatible with
//  PSSearchEngine's stored `text_norm` FTS5 column (PSFoldForIndex); any drift
//  silently corrupts search matching (Risk R1). Exposed to the still-Obj-C++
//  callers (PSModuleSearchController.mm, SwordModule.mm) via @objc; the class
//  method surface matches the former Obj-C class byte-for-byte.
//

import Foundation

@objc(PSSearchQuery)
final class PSSearchQuery: NSObject {

    // MARK: - Folding (must match PSSearchEngine's PSFoldForIndex)

    /// Fold diacritics for storage/query normalisation. Exposed so the engine's
    /// stored `text_norm` column and the parser use the same rules.
    @objc(foldForIndex:)
    class func foldForIndex(_ s: String) -> String {
        if s.isEmpty { return "" }
        // NFD, then strip:
        //  * Hebrew points + cantillation (U+0591–U+05C7) — FTS5's
        //    remove_diacritics=2 doesn't touch these.
        //  * Generic Unicode combining marks (U+0300–U+036F, U+1AB0–U+1AFF,
        //    U+1DC0–U+1DFF, U+20D0–U+20FF, U+FE20–U+FE2F) — catches Greek
        //    polytonic accents and anything else that slipped past unicode61.
        let decomposed = Array(s.decomposedStringWithCanonicalMapping.utf16)
        var out: [UInt16] = []
        out.reserveCapacity(decomposed.count)
        var i = 0
        let n = decomposed.count
        while i < n {
            let c = decomposed[i]
            let drop =
                (c >= 0x0300 && c <= 0x036F) ||
                (c >= 0x0591 && c <= 0x05C7) ||
                (c >= 0x1AB0 && c <= 0x1AFF) ||
                (c >= 0x1DC0 && c <= 0x1DFF) ||
                (c >= 0x20D0 && c <= 0x20FF) ||
                (c >= 0xFE20 && c <= 0xFE2F)
            if !drop {
                if UTF16.isLeadSurrogate(c) && i + 1 < n {
                    out.append(c)
                    out.append(decomposed[i + 1])
                    i += 2
                    continue
                }
                out.append(c)
            }
            i += 1
        }
        let assembled = String(utf16CodeUnits: out, count: out.count)
        return assembled.precomposedStringWithCanonicalMapping.lowercased()
    }

    // MARK: - Tokenisation

    private struct PSToken {
        let text: String  // the phrase/word content, never contains quote chars
        let isPhrase: Bool // true if user wrapped it in "…"
    }

    // Tiny scanner: splits whitespace-separated tokens, keeping "quoted phrases"
    // as single atoms. Unterminated quotes are treated as running to end of input.
    private static func tokenise(_ raw: String) -> [PSToken] {
        var tokens: [PSToken] = []
        let chars = Array(raw.utf16)
        var i = 0
        let n = chars.count
        while i < n {
            let c = chars[i]
            if c == 0x20 || c == 0x09 || c == 0x0A { // space, tab, newline
                i += 1
                continue
            }

            if c == 0x22 { // '"'
                i += 1
                let start = i
                while i < n && chars[i] != 0x22 { i += 1 }
                let phrase = String(utf16CodeUnits: Array(chars[start..<i]), count: i - start)
                if i < n { i += 1 } // skip closing quote
                if !phrase.isEmpty {
                    tokens.append(PSToken(text: phrase, isPhrase: true))
                }
            } else {
                let start = i
                while i < n {
                    let ch = chars[i]
                    if ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x22 { break }
                    i += 1
                }
                let word = String(utf16CodeUnits: Array(chars[start..<i]), count: i - start)
                if !word.isEmpty {
                    tokens.append(PSToken(text: word, isPhrase: false))
                }
            }
        }
        return tokens
    }

    // MARK: - Escaping

    // Escape a token for use inside an FTS5 phrase: double any embedded quotes
    // and wrap in "…". Phrase syntax accepts any characters literally, which
    // side-steps the need to strip operator keywords like AND/OR/NEAR.
    private static func quote(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func isStrongsNumber(_ s: String) -> (isStrongs: Bool, prefix: Character) {
        let units = Array(s.utf16)
        if units.count < 2 { return (false, "\0") }
        let p = units[0]
        if p != UInt16(UnicodeScalar("H").value) && p != UInt16(UnicodeScalar("G").value)
            && p != UInt16(UnicodeScalar("h").value) && p != UInt16(UnicodeScalar("g").value) {
            return (false, "\0")
        }
        for idx in 1..<units.count {
            let c = units[idx]
            if c < UInt16(UnicodeScalar("0").value) || c > UInt16(UnicodeScalar("9").value) {
                return (false, "\0")
            }
        }
        let prefix: Character = (p == UInt16(UnicodeScalar("h").value) || p == UInt16(UnicodeScalar("H").value)) ? "H" : "G"
        return (true, prefix)
    }

    // For an H-prefixed Strong's number, return the OTHER form (H0430 ↔ H430).
    // Returns nil if the input is G-prefixed or already ambiguous.
    private static func alternateHebrewForm(_ s: String) -> String? {
        if s.count < 2 { return nil }
        let first = s[s.startIndex]
        if first != "H" && first != "h" { return nil }
        let digits = String(s[s.index(s.startIndex, offsetBy: 1)...])
        if digits.hasPrefix("0") {
            return "H" + String(digits.dropFirst())
        }
        return "H0" + digits
    }

    // MARK: - Expression builder

    /// Build an FTS5 MATCH expression for the given user input. Returns nil for
    /// trivial input (empty / pure whitespace / just quotes).
    @objc(fts5ExpressionFromUserInput:matchType:fuzzy:strongs:)
    class func fts5Expression(fromUserInput raw: String,
                              matchType: PSSearchType,
                              fuzzy: Bool,
                              strongs: Bool) -> String? {
        if raw.isEmpty { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Strong's mode: short-circuit — every whitespace-separated token is
        // treated as a Strong's number and mapped to the lemmas: column with
        // H0/H equivalence. Non-conforming tokens pass through as plain terms.
        if strongs {
            let parts = trimmed.components(separatedBy: .whitespaces)
            var ors: [String] = []
            for tok in parts {
                if tok.isEmpty { continue }
                let (isStrongs, prefix) = isStrongsNumber(tok)
                if isStrongs {
                    let upper = String(prefix) + String(tok.dropFirst())
                    if let alt = alternateHebrewForm(upper) {
                        ors.append("(\(quote(upper)) OR \(quote(alt)))")
                    } else {
                        ors.append(quote(upper))
                    }
                } else {
                    ors.append(quote(tok))
                }
            }
            if ors.isEmpty { return nil }
            // Join with OR so a multi-number Strong's query (rare but possible)
            // matches any of them. Constrain to the lemmas column.
            let joined = ors.joined(separator: " OR ")
            return "lemmas:(\(joined))"
        }

        // Exact mode: treat the whole raw input as a single phrase (strip any
        // surrounding quotes the user typed so we don't double-wrap).
        if matchType == .ExactSearch {
            var body = trimmed
            if body.hasPrefix("\"") && body.hasSuffix("\"") && body.count >= 2 {
                body = String(body.dropFirst().dropLast())
            }
            if body.isEmpty { return nil }
            let folded = foldForIndex(body)
            return "text_norm:\(quote(folded))"
        }

        // All / Any modes: tokenise, fold each non-phrase, apply fuzzy if set.
        let tokens = tokenise(trimmed)
        if tokens.isEmpty { return nil }

        var atoms: [String] = []
        for tk in tokens {
            let folded = foldForIndex(tk.text)
            if folded.isEmpty { continue }
            if tk.isPhrase {
                // Quoted phrases always match as a phrase, regardless of fuzzy.
                atoms.append("text_norm:\(quote(folded))")
            } else if fuzzy {
                // Prefix match: word*. Fold to a form FTS5 accepts as a bareword
                // by stripping non-alphanumerics; fall back to a quoted phrase if
                // nothing survives.
                let bare = barewordForPrefix(folded)
                if !bare.isEmpty {
                    atoms.append("text_norm:\(bare)*")
                } else {
                    atoms.append("text_norm:\(quote(folded))")
                }
            } else {
                atoms.append("text_norm:\(quote(folded))")
            }
        }
        if atoms.isEmpty { return nil }

        let joiner = (matchType == .OrSearch) ? " OR " : " AND "
        return atoms.joined(separator: joiner)
    }

    /// Extract the canonicalised Strong's numbers from raw user input. Each valid
    /// H/G token is upper-cased and included; H-numbers also include their alternate
    /// form (H0430 ↔ H430). Non-Strong's tokens are ignored. Returns an empty array
    /// if the input contains no Strong's numbers. The returned set matches the
    /// tokens `fts5ExpressionFromUserInput:…strongs:YES` injects into the query,
    /// so they can be used to filter the stored word_map.
    @objc(strongsTokensFromUserInput:)
    class func strongsTokens(fromUserInput raw: String) -> [String] {
        if raw.isEmpty { return [] }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        let parts = trimmed.components(separatedBy: .whitespaces)
        var out: [String] = []
        var seen = Set<String>()
        for tok in parts {
            if tok.isEmpty { continue }
            let (isStrongs, prefix) = isStrongsNumber(tok)
            if !isStrongs { continue }
            let upper = String(prefix) + String(tok.dropFirst())
            if !seen.contains(upper) { seen.insert(upper); out.append(upper) }
            if let alt = alternateHebrewForm(upper), !seen.contains(alt) {
                seen.insert(alt); out.append(alt)
            }
        }
        return out
    }

    // Produce a bareword suitable for FTS5 prefix syntax (`word*`). Strips
    // any character that isn't a unicode letter or digit; if the result is
    // empty we fall back to a quoted phrase.
    private static func barewordForPrefix(_ s: String) -> String {
        // Reproduce the former Obj-C loop byte-for-byte: it iterates UTF-16 code
        // units and tests each against -[NSCharacterSet characterIsMember:]
        // (which takes a single unichar), so surrogate halves of a non-BMP char
        // are individually rejected. CharacterSet.contains(_:UnicodeScalar) would
        // differ for non-BMP scalars, so test per UTF-16 unit here too.
        let ok = NSCharacterSet.alphanumerics as NSCharacterSet
        var out: [UInt16] = []
        for c in s.utf16 {
            if ok.characterIsMember(c) {
                out.append(c)
            }
        }
        return String(utf16CodeUnits: out, count: out.count)
    }
}
