//
//  PSBookOSISResolver.swift
//  PocketSword
//
//  Narrow book-name -> OSIS-abbreviation lookup over the baked
//  Resources/Versification-KJV.json. Phase 3 of SWORD_REMOVAL_PLAN.md.
//
//  This exists because of a mismatch the SWORD engine currently absorbs: the app
//  passes book **names**, and the content store is keyed on OSIS abbreviations.
//  `PSModuleController.getCurrentBibleRef()` seeds and returns "Genesis 1"
//  (PSModuleController.swift:264-272), the ref selector and history both round-trip
//  full names, and `chapters` is keyed `book_osis='Gen'`. Today `VerseKey::setText`
//  parses whatever it is given; the reader has to do that one narrow part itself.
//
//  This is deliberately NOT a free-text reference parser. It resolves a
//  "<book> <chapter>" string where <book> is one of the 66 books' known spellings,
//  and nothing else. Arbitrary user input, ranges, verse specs and localisation are
//  Phase 4 (`PSVoiceRefParser` already does the fuzzy variant for voice input).
//

import Foundation

/// One book of the versification, as `tools/swordbake`'s dump holds it.
struct PSVersificationBook {
    let osisName: String
    /// The app-munged display name ("1 Corinthians") — what refs actually carry.
    let name: String
    let longName: String
    let localisedName: String
    let shortName: String
    let preferredAbbreviation: String
    let abbreviation: String
    let testament: Int
    /// verseMax[chapter - 1]
    let verseMax: [Int]

    var chapterCount: Int { verseMax.count }
}

final class PSBookOSISResolver {

    /// The 66 books in versification order.
    let books: [PSVersificationBook]

    /// Lowercased spelling -> book index. Every spelling the dump carries plus the
    /// `createRefString` normalisations.
    private let index: [String: Int]

    /// osisName -> book, for the reverse direction (`headings` is keyed by the
    /// module's key text, which uses the long name).
    private let byOsis: [String: PSVersificationBook]

    /// The shared instance over the bundled dump, or nil if it is missing or
    /// malformed — callers fall back to SWORD.
    static let shared: PSBookOSISResolver? = {
        guard let url = Bundle.main.url(forResource: "Versification-KJV", withExtension: "json") else {
            PSContentStore.fail("Versification-KJV.json is not in the app bundle")
            return nil
        }
        return PSBookOSISResolver(url: url)
    }()

    /// Internal rather than private so tests can point it at a broken copy.
    init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let raw = root["books"] as? [[String: Any]] else {
            PSContentStore.fail("Versification-KJV.json is unreadable at \(url.path)")
            return nil
        }

        var parsed: [PSVersificationBook] = []
        parsed.reserveCapacity(raw.count)
        for entry in raw {
            guard let osis = entry["osisName"] as? String,
                  let name = entry["name"] as? String,
                  let verseMax = entry["verseMax"] as? [Int], !verseMax.isEmpty else {
                PSContentStore.fail("Versification-KJV.json has a malformed book entry")
                return nil
            }
            parsed.append(PSVersificationBook(
                osisName: osis,
                name: name,
                longName: entry["longName"] as? String ?? name,
                localisedName: entry["localisedName"] as? String ?? name,
                shortName: entry["shortName"] as? String ?? "",
                preferredAbbreviation: entry["preferredAbbreviation"] as? String ?? "",
                abbreviation: entry["abbreviation"] as? String ?? "",
                testament: entry["testament"] as? Int ?? 1,
                verseMax: verseMax))
        }
        guard parsed.count == 66 else {
            PSContentStore.fail("Versification-KJV.json holds \(parsed.count) books, expected 66")
            return nil
        }
        books = parsed

        var idx: [String: Int] = [:]
        var osisMap: [String: PSVersificationBook] = [:]
        for (i, book) in parsed.enumerated() {
            osisMap[book.osisName] = book
            // Every spelling the dump carries. `name` is the app-munged form the
            // app's own refs use; `longName`/`localisedName` are the roman-numeral
            // forms SWORD emits in key text ("I Corinthians"), which is what the
            // `headings` table and the note refs are keyed on.
            for spelling in [book.osisName, book.name, book.longName, book.localisedName,
                             book.shortName, book.preferredAbbreviation, book.abbreviation] {
                let key = spelling.lowercased()
                guard !key.isEmpty else { continue }
                // First writer wins: the books are in canonical order, so an
                // ambiguous short form resolves to the earlier book, which is what
                // SWORD's own abbreviation table does.
                if idx[key] == nil { idx[key] = i }
            }
            // The `createRefString` normalisations (PSModuleController.swift:576-584):
            // "III "->"3 ", "II "->"2 ", "I "->"1 ", " of John "->" ". A ref that
            // has been through it arrives as "1 Corinthians" / "2 John", which
            // `name` already covers — but a ref that has NOT been normalised
            // arrives as "I Corinthians", which is `longName`. Both directions are
            // therefore in the table, and neither depends on the caller having
            // normalised first.
            let munged = PSRefHelper.createRefString(book.longName).lowercased()
            if idx[munged] == nil { idx[munged] = i }
        }
        index = idx
        byOsis = osisMap
    }

    // MARK: - Lookup

    /// A book by any of its known spellings, case-insensitively.
    func book(named name: String) -> PSVersificationBook? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = index[trimmed.lowercased()] { return books[i] }
        // A ref may arrive un-normalised ("III John"); normalise and retry rather
        // than requiring every caller to remember to.
        let normalised = PSRefHelper.createRefString(trimmed).lowercased()
        if let i = index[normalised] { return books[i] }
        return nil
    }

    func book(osis: String) -> PSVersificationBook? { byOsis[osis] }

    /// Split a "<book> <chapter>" ref — the shape `-getChapter:` is given.
    ///
    /// The chapter is the trailing integer; everything before it is the book name,
    /// which may contain spaces ("1 Corinthians 13", "Song of Solomon 2"). A ref
    /// with a verse ("Genesis 1:1") resolves to its chapter, because that is what
    /// `VerseKey::setText` + `setVerse(0)` does today.
    ///
    /// Returns nil rather than guessing: an unresolvable book is a reader failure
    /// that falls back to SWORD, never a silently wrong chapter.
    func resolve(ref: String) -> (book: PSVersificationBook, chapter: Int)? {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastSpace = trimmed.lastIndex(of: " ") else { return nil }
        let bookPart = String(trimmed[trimmed.startIndex..<lastSpace])
        var chapterPart = String(trimmed[trimmed.index(after: lastSpace)...])
        // "Genesis 1:1" -> chapter 1. The verse is dropped, matching
        // -chapterBodyHTML:'s own setVerse(0).
        if let colon = chapterPart.firstIndex(of: ":") {
            chapterPart = String(chapterPart[chapterPart.startIndex..<colon])
        }
        guard let chapter = Int(chapterPart), chapter >= 1,
              let book = book(named: bookPart), chapter <= book.chapterCount else {
            return nil
        }
        return (book, chapter)
    }
}
