//
//  PSRefParser.swift
//  PocketSword
//
//  The pure-Swift reference parser, Phase 4 of SWORD_REMOVAL_PLAN.md. Replaces
//  the reference-semantics half of `sword::VerseKey::setText` /
//  `VerseKey::parseVerseList` for the one input the app does not itself generate.
//
//  ## Why this is a separate file from PSBookOSISResolver
//
//  It reads the same table — it takes a `PSBookOSISResolver` and never touches the
//  JSON — but `PSBookOSISResolver` is on the content reader's hot path
//  (`PSContentReader` calls `resolve(ref:)` on every page turn) and three test
//  files pin its shape. The parser is a consumer, not part of that surface.
//
//  ## Grammar
//
//      <book> [ <chapter> [ ":" <verse> [ "-" <verse> ] ] ]
//
//  `<book>` is any of the seven spellings per book that the resolver's index
//  carries ("Genesis", "Gen", "1 Corinthians", "I Corinthians", "1Cor", "Jn", …),
//  case-insensitively, with an optional trailing "." after an abbreviation. Verse
//  and chapter default to 1 when absent. A range must be ascending and inside the
//  chapter.
//
//  ## Deliberately out of scope
//
//  This is bounded by what the UI actually produces, not by what SWORD could
//  parse. Anything wider would be the "scope creep back toward generality" the
//  plan's risk register warns about, and would be untested production code —
//  nothing in the app can emit any of it:
//
//    - **Lists.** No comma or semicolon forms ("Gen 1:1,3", "Gen 1:1; 2:4") and no
//      cross-book or cross-chapter ranges ("Gen 1:1 - Exod 2:2", "Gen 1:31-2:3").
//      `parseVerseList` handles all of these; the app never emits one. The inbound
//      `sword://` path truncates a list itself before this parser ever sees it
//      (PocketSwordAppDelegate: "28-30" -> "28", "26,28;30" -> "26").
//    - **Roman-numeral chapters** ("Gen ii"), which versekey.cpp:948 accepts.
//    - **`ff` / trailing-letter suffixes** ("Gen 1:1ff", "Gen 1:12a"),
//      versekey.cpp:885 and :925.
//    - **`inscriptio` / `subscriptio`** (versekey.cpp:962-971), an INTF-only form
//      for storing titles as book/chapter intros. No bundled module uses it.
//    - **Localised book names.** There is no `en` locale conf and `SWLocale(0)`
//      has no `[Text]` section, so `translateBookName:` is identity on every
//      device; there has never been anything to translate. See the retirement in
//      PSTabBarControllerDelegate / PSModuleController.
//    - **Fuzzy / spoken input.** `PSVoiceRefParser` owns that, keeps its own
//      grammar, and deliberately discards ranges (pinned by
//      PSVoiceRefParserTests.testRangesKeepFirstVerse). Do not merge them.
//
//  `PSRefSemanticsTests`' exhaustive tier *prints* the abbreviation forms this
//  parser rejects but SWORD accepts, so that delta stays visible rather than
//  assumed.
//
//  ## The parse context is always explicit
//
//  `parse(_:relativeTo:)` takes the book to resolve a bare chapter/verse against;
//  it never reads `getCurrentBibleRef()` itself. `SwordModule.mm:600` seeded
//  `parseVerseList` from exactly that ambient global state, and the only thing
//  that needed it is the `scriptRef` branch Phase 4 deletes.
//

import Foundation

/// A parsed single-book reference. `verse`/`endVerse` are always populated —
/// an absent verse spec means verse 1, matching `VerseKey`'s own default.
struct BibleReference: Equatable {
    let book: PSVersificationBook
    let chapter: Int
    let verse: Int
    /// The last verse of an inclusive range; equal to `verse` when there is no range.
    let endVerse: Int

    /// True when the source string carried a chapter number at all. False for a
    /// bare book name ("John"), where `chapter` is the default 1.
    ///
    /// The `sword://` URL path needs this: a chapter-less URL used to persist the
    /// chapter-less string itself as `lastRef`, which `VerseKey` absorbed but the
    /// Swift reader cannot resolve. Note it cannot be inferred by looking for a
    /// digit — "1 John" has one and still has no chapter.
    let hadExplicitChapter: Bool

    /// True when the source string carried a ":" verse spec, so `verse` is
    /// something the caller asked for rather than the default. The `sword://` URL
    /// path keeps its own separately-derived verse position.
    let hadExplicitVerse: Bool

    var isRange: Bool { endVerse > verse }

    /// "Genesis 1" — the **munged `name`** form, which is what the app persists in
    /// `Defaults.lastRef` and keys history / bookmarks / headings on.
    var chapterRef: String { "\(book.name) \(chapter)" }

    /// "Genesis 1:1" / "Genesis 1:1-3".
    var displayRef: String {
        isRange ? "\(chapterRef):\(verse)-\(endVerse)" : "\(chapterRef):\(verse)"
    }

    static func == (lhs: BibleReference, rhs: BibleReference) -> Bool {
        lhs.book.osisName == rhs.book.osisName
            && lhs.chapter == rhs.chapter
            && lhs.verse == rhs.verse
            && lhs.endVerse == rhs.endVerse
            && lhs.hadExplicitChapter == rhs.hadExplicitChapter
            && lhs.hadExplicitVerse == rhs.hadExplicitVerse
    }
}

typealias PSParsedReference = BibleReference

struct PSRefParser {

    private let resolver: PSBookOSISResolver

    /// Fails only when the bundled versification table itself is unavailable —
    /// the same condition that makes the content reader decline.
    init?(resolver: PSBookOSISResolver? = PSBookOSISResolver.shared) {
        guard let resolver = resolver else { return nil }
        self.resolver = resolver
    }

    /// Parse a single-book reference.
    ///
    /// - Parameter relativeTo: the book a bare "3:16" or "3" resolves against.
    ///   Pass nil to require a book name in the string. Never read from ambient
    ///   state inside here — see the file header.
    /// - Returns: nil for anything the grammar above does not cover, for an
    ///   unknown book, or for a chapter/verse outside the versification. Never a
    ///   clamped or guessed result: a wrong ref renders plausible-but-wrong text,
    ///   which is worse than declining.
    func parse(_ input: String, relativeTo contextBook: PSVersificationBook? = nil) -> PSParsedReference? {
        // Normalise the separators the app's own producers use. NBSP appears in
        // pasted refs; the en/em dashes in typed and voice-transcribed ones.
        let normalised = input
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalised.isEmpty else { return nil }

        // Split off the numeric tail: everything from the last run of
        // "<space><digit>" onward. The book name may itself both start with a
        // digit ("1 Corinthians") and contain spaces ("Song of Solomon"), so
        // neither "split on the first space" nor "split on the first digit"
        // works — hence scanning from the right.
        let (bookPart, numericPart) = splitBookFromNumbers(normalised)

        let book: PSVersificationBook
        if bookPart.isEmpty {
            // No book name: a bare "3:16" against the caller's context.
            guard let contextBook = contextBook else { return nil }
            book = contextBook
        } else {
            // A trailing "." after an abbreviation ("Gen.", "1 Cor.") is not in
            // the resolver's index; strip it and retry rather than adding 66 more
            // spellings to a table three test files pin.
            guard let resolved = resolveBook(bookPart) else { return nil }
            book = resolved
        }

        // "Genesis" alone -> chapter 1 verse 1, matching parseVerseList's
        // "if chapter is left off, use the default key" behaviour.
        guard !numericPart.isEmpty else {
            return PSParsedReference(book: book, chapter: 1, verse: 1, endVerse: 1,
                                     hadExplicitChapter: false, hadExplicitVerse: false)
        }

        return parseNumbers(numericPart, in: book)
    }

    // MARK: - Book name

    /// Resolve a book name through the table, then through two narrow fallbacks.
    ///
    /// Both fallbacks live here rather than in `PSBookOSISResolver`'s index because
    /// that index is pinned by `PSContentStoreTests` and is on the reader's hot
    /// path — the parser is allowed to be more permissive than the reader.
    private func resolveBook(_ part: String) -> PSVersificationBook? {
        if let book = resolver.book(named: part) { return book }

        // 1. A single trailing period after an abbreviation ("Gen.", "1 Cor.").
        if part.hasSuffix(".") {
            let trimmed = String(part.dropLast()).trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, let book = resolveBook(trimmed) { return book }
        }

        // 2. Spaced abbreviations of the numbered books: "1 Cor", "2 Kgs",
        //    "1 Thess". The table carries only the unspaced `abbreviation` form
        //    ("1Cor"), but SWORD accepts both — `canon_abbrevs.h` has spaced
        //    entries ("1 CORINTHIANS", "1 C") and `getBookFromAbbrev` does a
        //    *prefix* match over them, so "1 COR" resolves there. Despacing is
        //    verified collision-free: across all 66 books x 7 spellings, no
        //    despaced form resolves to a different book than its spaced form.
        let despaced = part.replacingOccurrences(of: " ", with: "")
        if despaced != part, !despaced.isEmpty, let book = resolver.book(named: despaced) {
            return book
        }
        return nil
    }

    /// Split "1 Corinthians 13:4" into ("1 Corinthians", "13:4").
    ///
    /// Scans right-to-left for the last space that is followed by a digit, and
    /// treats everything after it as the numeric part — but only if the remaining
    /// left side is non-empty, so "1 Corinthians" does not lose its "1". A string
    /// that is entirely numeric ("3:16") yields an empty book part.
    private func splitBookFromNumbers(_ input: String) -> (String, String) {
        let chars = Array(input)
        if let first = chars.first, first.isNumber, !input.contains(" ") {
            // "3:16" / "3" — no book name at all.
            return ("", input)
        }
        var i = chars.count - 1
        var candidate: Int? = nil
        while i > 0 {
            if chars[i] == " ", i + 1 < chars.count, chars[i + 1].isNumber {
                let left = String(chars[0..<i]).trimmingCharacters(in: .whitespaces)
                // Reject a split that would leave only a number on the left
                // ("1 Corinthians" split at its own space): a lone leading digit
                // group is part of the book name, not a chapter.
                if !left.isEmpty && !left.allSatisfy({ $0.isNumber }) {
                    candidate = i
                    break
                }
            }
            i -= 1
        }
        guard let split = candidate else { return (input, "") }
        return (String(chars[0..<split]).trimmingCharacters(in: .whitespaces),
                String(chars[(split + 1)...]).trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Numbers

    /// "13", "13:4", "13:4-6" — and nothing else. Rejects rather than truncates:
    /// a caller that wants "the first verse of a list" must do that itself, the
    /// way the `sword://` path already does.
    private func parseNumbers(_ part: String, in book: PSVersificationBook) -> PSParsedReference? {
        let pieces = part.components(separatedBy: ":")
        guard pieces.count <= 2 else { return nil }

        guard let chapter = strictInt(pieces[0]),
              chapter >= 1, chapter <= book.chapterCount,
              let maxVerse = resolver.verseMax(book: book, chapter: chapter) else {
            return nil
        }

        guard pieces.count == 2 else {
            return PSParsedReference(book: book, chapter: chapter, verse: 1, endVerse: 1,
                                     hadExplicitChapter: true, hadExplicitVerse: false)
        }

        let versePart = pieces[1].trimmingCharacters(in: .whitespaces)
        let verseBounds = versePart.components(separatedBy: "-")
        guard verseBounds.count <= 2,
              let verse = strictInt(verseBounds[0]), verse >= 1, verse <= maxVerse else {
            return nil
        }

        var endVerse = verse
        if verseBounds.count == 2 {
            // In-chapter ascending range only. A descending or cross-chapter one
            // ("1:3-1", "1:31-2:3") is a shape the app cannot produce.
            guard let end = strictInt(verseBounds[1]), end >= verse, end <= maxVerse else {
                return nil
            }
            endVerse = end
        }

        return PSParsedReference(book: book, chapter: chapter, verse: verse,
                                 endVerse: endVerse, hadExplicitChapter: true,
                                 hadExplicitVerse: true)
    }

    /// Digits only. `Int(_:)` already rejects "12a" and "1ff", but it accepts a
    /// leading "+"/"-" and Unicode digits, so the character check is explicit —
    /// "-3" must not parse as a chapter, and NSString's lenient `integerValue`
    /// (which the notification path uses) must not leak in here.
    private func strictInt(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(trimmed)
    }
}
