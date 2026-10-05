//
//  PSBookOSISResolver.swift
//  PocketSword
//
//  Book-name -> OSIS-abbreviation lookup and the app's whole versification
//  layer, over the baked Resources/Versification-KJV.json.
//
//  The app's refs carry book NAMES ("Genesis 1") while the content store is
//  keyed on OSIS (`book_osis='Gen'`). This is deliberately NOT a free-text
//  parser: it resolves "<book> <chapter>" for the 66 books' known spellings and
//  nothing else. Free-text parsing is `PSRefParser` (on top of this table);
//  `PSVoiceRefParser` keeps its own fuzzier grammar for voice input.
//
//  The lookup surface (`init?`, `resolve(ref:)`, `book(named:)`, `book(osis:)`)
//  is on the reader's hot path and pinned by PSContentStoreTests.
//

import Foundation

/// One book of the versification, as the baked dump holds it.
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

/// NSObject-derived only for the `@objc` members in the extension at the bottom
/// of this file; `PSVersificationBook` stays a plain Swift struct.
@objc(PSBookOSISResolver)
final class PSBookOSISResolver: NSObject {

    /// The 66 books in versification order.
    let books: [PSVersificationBook]

    /// Lowercased spelling -> book index. Every spelling the dump carries plus the
    /// `createRefString` normalisations.
    private let index: [String: Int]

    /// osisName -> book, for the reverse direction (`headings` is keyed by the
    /// module's key text, which uses the long name).
    private let byOsis: [String: PSVersificationBook]

    /// The shared instance over the bundled dump.
    ///
    /// A missing or malformed dump is **fatal** — it is the app's whole
    /// versification layer. Optional only so tests can build broken copies with
    /// `reportFailures: false`.
    static let shared: PSBookOSISResolver? = {
        guard let url = Bundle.main.url(forResource: "Versification-KJV", withExtension: "json") else {
            PSContentStore.fatal("Versification-KJV.json is not in the app bundle")
            return nil
        }
        return PSBookOSISResolver(url: url)
    }()

    /// Internal rather than private so tests can point it at a broken copy.
    init?(url: URL, reportFailures: Bool = true) {
        guard let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let raw = root["books"] as? [[String: Any]] else {
            PSContentStore.fatal("Versification-KJV.json is unreadable at \(url.path)", report: reportFailures)
            return nil
        }

        var parsed: [PSVersificationBook] = []
        parsed.reserveCapacity(raw.count)
        for entry in raw {
            guard let osis = entry["osisName"] as? String,
                  let name = entry["name"] as? String,
                  let verseMax = entry["verseMax"] as? [Int], !verseMax.isEmpty else {
                PSContentStore.fatal("Versification-KJV.json has a malformed book entry", report: reportFailures)
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
            PSContentStore.fatal("Versification-KJV.json holds \(parsed.count) books, expected 66", report: reportFailures)
            return nil
        }
        books = parsed

        var idx: [String: Int] = [:]
        var osisMap: [String: PSVersificationBook] = [:]
        for (i, book) in parsed.enumerated() {
            osisMap[book.osisName] = book
            // Every spelling the dump carries. `name` is the app-munged form the
            // app's own refs use; `longName`/`localisedName` are the roman-numeral
            // forms ("I Corinthians") the `headings` table and note refs are keyed on.
            for spelling in [book.osisName, book.name, book.longName, book.localisedName,
                             book.shortName, book.preferredAbbreviation, book.abbreviation] {
                let key = spelling.lowercased()
                guard !key.isEmpty else { continue }
                // First writer wins: the books are in canonical order, so an
                // ambiguous short form resolves to the earlier book.
                if idx[key] == nil { idx[key] = i }
            }
            // The `createRefString` normalisations ("III "->"3 ", "II "->"2 ",
            // "I "->"1 ", " of John "->" "). A normalised ref ("1 Corinthians") is
            // covered by `name`; an unnormalised one ("I Corinthians") by `longName`.
            // Both are in the table, so callers need not normalise first.
            let munged = PSRefHelper.createRefString(book.longName).lowercased()
            if idx[munged] == nil { idx[munged] = i }
        }
        index = idx
        byOsis = osisMap
        // Last: every stored property must be assigned before super.init().
        super.init()
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

    /// Split a "<book> <chapter>" ref.
    ///
    /// The chapter is the trailing integer; everything before it is the book name,
    /// which may contain spaces ("1 Corinthians 13", "Song of Solomon 2"). A ref
    /// with a verse ("Genesis 1:1") resolves to its chapter.
    ///
    /// Returns nil rather than guessing: an unresolvable book must never become a
    /// silently wrong chapter.
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

    // MARK: - Versification
    //
    // `PSVersificationBook` reproduces the engine's book-name munges byte-exactly
    // (`name` == munge(localisedName), `shortName` == despace-then-first-3(name)),
    // so no adapter type or re-munging is needed.

    /// A book by versification index (0 = Genesis, 65 = Revelation), or nil when
    /// out of range. A flat 66-entry array, so there is no testament split.
    func book(at index: Int) -> PSVersificationBook? {
        guard index >= 0 && index < books.count else { return nil }
        return books[index]
    }

    /// The 1-based versification index of a book, or nil if it is not this table's.
    /// Compares by `osisName` because that is the one field guaranteed unique
    /// (`shortName` has two intentional collisions).
    func index(of book: PSVersificationBook) -> Int? {
        return books.firstIndex { $0.osisName == book.osisName }
    }

    /// Verses in a chapter, 1-based, or nil when the chapter is out of range.
    ///
    /// Note the store's own `entry_count` is this **+1** (slot 0 is the verse-0
    /// intro), verified for all 1,189 chapters.
    func verseMax(book: PSVersificationBook, chapter: Int) -> Int? {
        guard chapter >= 1 && chapter <= book.verseMax.count else { return nil }
        return book.verseMax[chapter - 1]
    }

    /// Verses in a chapter of a book named `name`, or nil if either is unknown.
    func verseMax(bookNamed name: String, chapter: Int) -> Int? {
        guard let book = book(named: name) else { return nil }
        return verseMax(book: book, chapter: chapter)
    }

    /// The chapter after `(book, chapter)`, rolling into the next book, or nil at
    /// Revelation 22.
    ///
    /// **Returning nil at the end is deliberate.** Returning the clamped ref
    /// instead would turn a no-op into a full re-render.
    func nextChapter(book: PSVersificationBook, chapter: Int) -> (book: PSVersificationBook, chapter: Int)? {
        guard chapter >= 1 && chapter <= book.chapterCount else { return nil }
        if chapter < book.chapterCount {
            return (book, chapter + 1)
        }
        guard let i = index(of: book), let next = self.book(at: i + 1) else { return nil }
        return (next, 1)
    }

    /// The chapter before `(book, chapter)`, rolling into the previous book's last
    /// chapter, or nil at Genesis 1. Same rationale as `nextChapter(book:chapter:)`.
    func previousChapter(book: PSVersificationBook, chapter: Int) -> (book: PSVersificationBook, chapter: Int)? {
        guard chapter >= 1 && chapter <= book.chapterCount else { return nil }
        if chapter > 1 {
            return (book, chapter - 1)
        }
        guard let i = index(of: book), let prev = self.book(at: i - 1) else { return nil }
        return (prev, prev.chapterCount)
    }

    /// The ref string chapter navigation expects back, in the **un-munged
    /// `longName`** form ("Revelation of John 22", "I Corinthians 13").
    ///
    /// Deliberate: every caller munges it through `createRefString`, and
    /// `createRefString(longName + " N") == name + " N"` for all 66 books. 18 of the
    /// 66 have `name != longName`.
    func displayRef(book: PSVersificationBook, chapter: Int) -> String {
        return "\(book.longName) \(chapter)"
    }

    /// `displayRef` for a next/prev result tuple.
    func displayRef(_ location: (book: PSVersificationBook, chapter: Int)) -> String {
        return displayRef(book: location.book, chapter: location.chapter)
    }
}

// MARK: - Name -> OSIS lookup
//
// `osisName(forBookName:)` is the named entry point PSRefSemanticsTests
// exercises.
extension PSBookOSISResolver {

    /// + [PSBookOSISResolver sharedResolver] — nil if the bundled table is missing
    /// or malformed, exactly as `shared` is.
    @objc(sharedResolver)
    static func sharedResolver() -> PSBookOSISResolver? { return shared }

    /// The OSIS abbreviation for any known spelling of a book, or nil.
    @objc(osisNameForBookName:)
    func osisName(forBookName name: String?) -> String? {
        guard let name = name else { return nil }
        return book(named: name)?.osisName
    }
}
