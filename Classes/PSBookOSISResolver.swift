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
//  and nothing else. Free-text parsing with verses and ranges is `PSRefParser`
//  (Phase 4), which sits on top of this table rather than duplicating it;
//  `PSVoiceRefParser` keeps its own deliberately fuzzier grammar for voice input.
//
//  Phase 4 additionally made this the app's whole versification layer, replacing
//  `SwordBook` + `sword::VerseKey`'s chapter arithmetic: see the "Versification"
//  section below (`book(at:)`, `verseMax(book:chapter:)`, `nextChapter`,
//  `previousChapter`, `displayRef`). Those are purely additive — the Phase-3
//  lookup surface (`init?`, `resolve(ref:)`, `book(named:)`, `book(osis:)`, the
//  spelling index) is on the reader's hot path and is pinned by
//  PSContentStoreTests / PSDifferentialTests, so it is deliberately untouched.
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

/// NSObject-derived only so `PSSearchEngine.mm` can reach the two @objc members in
/// the extension at the bottom of this file. Nothing else about the class is
/// Obj-C-visible, and `PSVersificationBook` stays a plain Swift struct.
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
    /// Phase 5: a missing or malformed dump is **fatal** — it is the app's whole
    /// versification layer and there is no engine behind it. Optional only so the
    /// tests can build broken copies with `reportFailures: false`.
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
        // Last, per Swift's phase-1/phase-2 rule: every stored property above is
        // assigned before the superclass initialiser runs. (NSObject base is new in
        // Phase 4 — see the @objc extension at the bottom of this file.)
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

    // MARK: - Versification (Phase 4 — the SwordBook / sword::VerseKey replacement)
    //
    // Everything below is additive. It replaces three things that used to route
    // through the engine purely for reference semantics:
    //   - `SwordBook` (-name/-shortName/-osisName/-chapters/-verses:), which is now
    //     `PSVersificationBook` itself: the baked table reproduces every one of
    //     `SwordBook`'s munges byte-exactly (verified 66/66 for `name` ==
    //     munge(localisedName) and `shortName` == despace-then-first-3(name)), so
    //     there is no adapter type and no re-munging.
    //   - `-[SwordModule setToNextChapter]` / `-setToPreviousChapter` /
    //     `-getVerseMax`, which were `sword::VerseKey::setChapter` + `normalize`.
    //   - `-[SwordManager translateBookName:]`, which is identity on every device
    //     (there is no `en` locale conf; `SWLocale(0)` has no `[Text]` section, so
    //     `translate` returns its input — see the retirement in
    //     PSTabBarControllerDelegate / PSModuleController).

    /// A book by versification index (0 = Genesis, 65 = Revelation), or nil when
    /// out of range. This is the flat 66-entry array — SWORD's `BMAX` testament
    /// split does not apply, which is why the rollover below is so much simpler
    /// than `VerseKey::normalize` looks.
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
    /// SWORD's `VersificationMgr::Book::getVerseMax` returns **-1** for an
    /// out-of-range chapter rather than erroring; nil is the Swift equivalent and
    /// forces callers to decide, instead of propagating a sentinel into a loop
    /// bound. Note the store's own `entry_count` is this **+1** (slot 0 is the
    /// verse-0 intro), verified for all 1,189 chapters.
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
    /// **Returning nil at the end is deliberate and load-bearing.** SWORD does not
    /// error here: `VerseKey::normalize` (versekey.cpp:1466-1493) *clamps* to the
    /// upper bound and merely sets KEYERR_OUTOFBOUNDS, so
    /// `-[SwordModule setToNextChapter]` at Rev 22 returned "Revelation of John 22"
    /// — the same ref it was given. The callers' string-equality gate is what
    /// turned that into a no-op. A structural replacement must return nil rather
    /// than the clamped ref, or a no-op becomes a full re-render.
    func nextChapter(book: PSVersificationBook, chapter: Int) -> (book: PSVersificationBook, chapter: Int)? {
        guard chapter >= 1 && chapter <= book.chapterCount else { return nil }
        if chapter < book.chapterCount {
            return (book, chapter + 1)
        }
        guard let i = index(of: book), let next = self.book(at: i + 1) else { return nil }
        return (next, 1)
    }

    /// The chapter before `(book, chapter)`, rolling into the previous book's last
    /// chapter, or nil at Genesis 1. Same clamp-vs-nil rationale as
    /// `nextChapter(book:chapter:)`.
    func previousChapter(book: PSVersificationBook, chapter: Int) -> (book: PSVersificationBook, chapter: Int)? {
        guard chapter >= 1 && chapter <= book.chapterCount else { return nil }
        if chapter > 1 {
            return (book, chapter - 1)
        }
        guard let i = index(of: book), let prev = self.book(at: i - 1) else { return nil }
        return (prev, prev.chapterCount)
    }

    /// The ref string the app's chapter-navigation call sites expect back, in the
    /// **un-munged `longName`** form ("Revelation of John 22", "I Corinthians 13").
    ///
    /// That is not an oversight. `VerseKey::freshtext` (versekey.cpp:378) builds its
    /// key text from `getBookName()`, which is `translate(getLongName())` = identity
    /// here, so `-setToNextChapter` genuinely returned the long form and every
    /// caller munges it downstream through `createRefString`. Returning `name`
    /// instead would be an off-by-a-munge visible only on Revelation and the five
    /// numbered books — 18 of the 66 have `name != longName`. Verified
    /// `createRefString(longName + " N") == name + " N"` 66/66, so the existing
    /// call sites keep working unchanged.
    func displayRef(book: PSVersificationBook, chapter: Int) -> String {
        return "\(book.longName) \(chapter)"
    }

    /// `displayRef` for a next/prev result tuple.
    func displayRef(_ location: (book: PSVersificationBook, chapter: Int)) -> String {
        return displayRef(book: location.book, chapter: location.chapter)
    }
}

// MARK: - Former Obj-C seam
//
// `PSSearchEngine.mm`'s book-scope filter needed name -> OSIS, which had been its own
// private `-osisBookNameForLocalisedBookName:` over a live `sword::VerseKey`. These
// two members were the entire Obj-C surface of the resolver, and are why
// `PSBookOSISResolver` derives from NSObject at all (which is why `init?` calls
// `super.init()` — the stored properties are all assigned before that, as Swift
// requires).
//
// **Phase 5 step 8 ported the engine to Swift**, so nothing in Obj-C calls either of
// these now: the engine reaches `shared` and `book(named:)` directly. They are kept
// because `PSRefSemanticsTests` exercises `osisName(forBookName:)` as the named entry
// point for that lookup, and because they document what the deleted shim did.
extension PSBookOSISResolver {

    /// + [PSBookOSISResolver sharedResolver] — nil if the bundled table is missing
    /// or malformed, exactly as `shared` is.
    @objc(sharedResolver)
    static func sharedResolver() -> PSBookOSISResolver? { return shared }

    /// The OSIS abbreviation for any known spelling of a book, or nil.
    ///
    /// Replaces `-[PSSearchEngine osisBookNameForLocalisedBookName:]`. The engine
    /// version built a `sword::VerseKey`, set its text to the name, and read
    /// `getOSISBookName()`; this reads the same value out of the baked table. The
    /// "localised" in the old name was aspirational — `translateBookName:` is
    /// identity on every device, so the input was always an English spelling.
    @objc(osisNameForBookName:)
    func osisName(forBookName name: String?) -> String? {
        guard let name = name else { return nil }
        return book(named: name)?.osisName
    }
}
