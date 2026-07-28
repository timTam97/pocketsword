//
//  PSRefSemanticsTests.swift
//  PocketSwordTests
//
//  The acceptance criterion for Phase 4 of SWORD_REMOVAL_PLAN.md: the pure-Swift
//  versification + reference layer must reproduce `SwordBook` and
//  `sword::VerseKey`'s reference semantics exactly, and the `x` / `scriptRef`
//  branches must be provably unreachable for the shipped content.
//
//  This is `PSDifferentialTests` for reference semantics rather than for rendered
//  HTML, and it exists for the same reason: Phase 5 deletes the engine, so this is
//  the last chance to compare against it. Where the two disagree, SWORD wins —
//  except at the two canon boundaries, where the difference is deliberate and is
//  asserted *as* a difference (see `testBoundariesClampInSwordAndReturnNilInSwift`).
//
//  === Two tiers ===
//
//  * FAST — runs on every `test` invocation. 66 books x 5 consumed members,
//    1,189 verseMax comparisons, all 2,376 next/prev transitions byte-for-byte,
//    both boundary cases, 66 name->OSIS comparisons against a live VerseKey, the
//    translateBookName identity round-trip, the parser grammar fixture, and the
//    four-part unreachability proof.
//  * EXHAUSTIVE — set `PSREF_EXHAUSTIVE=1`. All 31,102 `displayRef` values against
//    a live `VerseKey` in both the `name` and `longName` forms, all 31,102 parser
//    round-trips, 1,189 parser-vs-resolver agreement checks, and the
//    `builtin_abbrevs` inclusion direction.
//
//  Both tiers print their coverage: a silently-sampled gate reads as "covered
//  everything" when it did not.
//
//  === The committed fixture ===
//
//  `testCaptureVersificationTable` dumps the live engine's whole answer — 66 books
//  x 5 members, 1,189 verse maxes, all 2,376 transitions — into
//  Tests/Fixtures/versification-KJV-oracle.txt in the `SwordOracleCaptureTests`
//  idiom (assert by default, rewrite only under PSORACLE_CAPTURE). That exists so
//  step 10's deletion of `SwordBook` cannot force a test to be weakened: after the
//  engine is gone, the comparisons above re-anchor on the fixture instead.
//

import XCTest
@testable import PocketSword

final class PSRefSemanticsTests: XCTestCase {

    // MARK: - Tiering / fixture plumbing

    private static var isExhaustive: Bool {
        ProcessInfo.processInfo.environment["PSREF_EXHAUSTIVE"] != nil
    }

    private static var isCapturing: Bool {
        ProcessInfo.processInfo.environment["PSORACLE_CAPTURE"] != nil
    }

    /// Same derivation as SwordOracleCaptureTests: from `#filePath`, so capture
    /// writes into the source tree rather than the simulator sandbox.
    private static func fixtureDir() -> URL {
        if let override = ProcessInfo.processInfo.environment["PSORACLE_FIXTURE_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return repoRoot.appendingPathComponent("Tests/Fixtures", isDirectory: true)
    }

    private func checkFixture(_ name: String, actual: String) throws {
        let dir = Self.fixtureDir()
        let url = dir.appendingPathComponent(name)

        if Self.isCapturing {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try actual.write(to: url, atomically: true, encoding: .utf8)
            print("[refsem] captured \(name) (\(actual.utf8.count) bytes)")
            return
        }

        guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("fixture \(name) not captured yet; run with PSORACLE_CAPTURE=1")
        }
        guard expected != actual else { return }

        let e = Array(expected), a = Array(actual)
        var i = 0
        while i < min(e.count, a.count), e[i] == a[i] { i += 1 }
        let lo = max(0, i - 80)
        XCTFail("""
            fixture \(name) does not match.
              first difference at character \(i) (expected \(e.count) chars, got \(a.count))
              expected: …\(String(e[lo..<min(e.count, i + 80)]))…
              actual:   …\(String(a[lo..<min(a.count, i + 80)]))…
            """)
    }

    // MARK: - Fixtures under test

    private func resolver() throws -> PSBookOSISResolver {
        guard let resolver = PSBookOSISResolver.shared else { throw XCTSkip("no resolver") }
        return resolver
    }

    private func parser() throws -> PSRefParser {
        guard let parser = PSRefParser() else { throw XCTSkip("no parser") }
        return parser
    }

    private func store() throws -> PSContentStore {
        guard let store = PSContentStore.shared else { throw XCTSkip("no store") }
        return store
    }

    /// The live engine's book list. Returns nil rather than skipping so the
    /// post-Phase-5 world (where `+booksForVersificationSystem:` is gone and this
    /// whole comparison re-anchors on the committed fixture) needs one edit here
    /// rather than one per test.
    private func swordBooks() -> [SwordBook]? {
        guard let raw = SwordManager.books(forVersificationSystem: "KJV") as? [SwordBook],
              !raw.isEmpty else { return nil }
        return raw
    }

    private func module(_ name: String, timeout: TimeInterval = 90) throws -> SwordModule {
        guard let manager = SwordManager.default() else { throw XCTSkip("no SwordManager") }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if manager.isModuleInstalled(name) { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
        guard let mod = manager.module(withName: name) else {
            throw XCTSkip("module \(name) not available")
        }
        return mod
    }

    /// A module with the **intros flag pinned off**, which every chapter-navigation
    /// comparison below must use.
    ///
    /// This is the same discipline `PSDifferentialTests` applies to the eleven
    /// global options and the two accumulator prefs — an unpinned bit of engine
    /// state makes the equality assertion noise rather than a gate — but it is worth
    /// spelling out, because the pin is load-bearing and the reason is not obvious.
    ///
    /// `VerseKey::normalize` (versekey.cpp:1466-1493) gates chapter 0's validity on
    /// `intros`: with it **on**, chapter 0 exists as the book-intro slot, so
    /// `setChapter(50)` on Genesis then `+1` normalises to "Exodus **0**", not
    /// "Exodus 1" — every one of the 65 book-boundary transitions shifts.
    ///
    /// `intros` defaults to false (versekey.cpp:61) and production always sees it
    /// false at next/prev time: `-getChapter:` turns it on for the render and
    /// restores it at SwordModule.mm:1362, and with the Phase-3 reader active
    /// `-getChapter:` is not even called. But `-chapterBodyHTML:` sets it on at
    /// SwordModule.mm:1055 and — unlike its caller — **never restores it**. That is
    /// harmless in the app (nothing calls it except `-getChapter:`, which restores)
    /// and invisible in a single-test run, but `PSDifferentialTests` and
    /// `SwordOracleCaptureTests` both call it directly on this same shared singleton
    /// module, so in a full-suite run it leaks in and these comparisons would be
    /// measuring the intros-on versification. Pin, don't hope.
    private func moduleForNavigation(_ name: String) throws -> SwordModule {
        let mod = try module(name)
        mod.setIntroductions(false)
        return mod
    }

    // MARK: - Fast tier: the table itself

    /// 66 books x the 5 members the app actually consumes, **including array
    /// order**. Order matters: `nextChapter`/`previousChapter` roll over by index,
    /// and the ref selector's section index is positional.
    func testTableMatchesSwordBookOnAllFiveConsumedMembers() throws {
        let resolver = try resolver()
        guard let books = swordBooks() else {
            throw XCTSkip("+booksForVersificationSystem: unavailable (expected after Phase 5)")
        }

        XCTAssertEqual(books.count, 66, "the engine's KJV book list is not 66 books")
        XCTAssertEqual(resolver.books.count, 66)

        var compared = 0
        for (i, swordBook) in books.enumerated() {
            guard let ours = resolver.book(at: i) else {
                XCTFail("no table entry at index \(i)")
                continue
            }
            // -name is SwordBook's munge of the localised long name; the table's
            // `name` is the same munge applied at bake time. F5 in the plan.
            XCTAssertEqual(ours.name, swordBook.name(),
                           "index \(i): name differs")
            XCTAssertEqual(ours.shortName, swordBook.shortName(),
                           "index \(i) (\(ours.name)): shortName differs")
            XCTAssertEqual(ours.osisName, swordBook.osisName(),
                           "index \(i) (\(ours.name)): osisName differs")
            XCTAssertEqual(ours.chapterCount, swordBook.chapters(),
                           "index \(i) (\(ours.name)): chapterCount differs")
            // -verses: is member 5; covered per chapter by the next test, and
            // spot-checked here at chapter 1 so this test fails on all five.
            XCTAssertEqual(resolver.verseMax(book: ours, chapter: 1), swordBook.verses(1),
                           "index \(i) (\(ours.name)): verses(1) differs")
            compared += 1
        }
        print("[refsem/fast] books compared on 5 members: \(compared)")
        XCTAssertEqual(compared, 66)
    }

    /// All 1,189 chapters' verse maxima, and the two out-of-range directions.
    func testAllVerseMaximaMatchSwordBook() throws {
        let resolver = try resolver()
        guard let books = swordBooks() else {
            throw XCTSkip("+booksForVersificationSystem: unavailable (expected after Phase 5)")
        }

        var compared = 0, total = 0
        for (i, swordBook) in books.enumerated() {
            guard let ours = resolver.book(at: i) else { continue }
            for chapter in 1...ours.chapterCount {
                total += 1
                let mine = resolver.verseMax(book: ours, chapter: chapter)
                XCTAssertEqual(mine, swordBook.verses(chapter),
                               "\(ours.name) \(chapter): verseMax differs")
                guard mine == swordBook.verses(chapter) else { return }
                compared += 1
            }
            // Out of range in both directions. SWORD returns -1
            // (versificationmgr.cpp Book::getVerseMax); we return nil.
            XCTAssertEqual(swordBook.verses(0), -1, "\(ours.name): SWORD no longer returns -1 for chapter 0")
            XCTAssertNil(resolver.verseMax(book: ours, chapter: 0))
            XCTAssertEqual(swordBook.verses(ours.chapterCount + 1), -1)
            XCTAssertNil(resolver.verseMax(book: ours, chapter: ours.chapterCount + 1))
        }
        print("[refsem/fast] verse maxima compared: \(compared) of \(total)")
        XCTAssertEqual(compared, 1189, "the KJV versification is 1,189 chapters")
        // Sum check, independent of the loop: 31,102 verses.
        let sum = resolver.books.reduce(0) { $0 + $1.verseMax.reduce(0, +) }
        XCTAssertEqual(sum, 31102, "total verse count changed")
    }

    // MARK: - Fast tier: chapter navigation (the 2,376 transitions)

    /// Every forward transition, byte-for-byte against `-setToNextChapter`.
    ///
    /// The engine is driven exactly as `PSModuleController.setToNextChapter()`
    /// drives it — `setChapter:` then `setToNextChapter` — because that pairing is
    /// what the app's behaviour actually is, and `setToNextChapter` alone depends on
    /// whatever key the module was left holding.
    func testAllForwardTransitionsMatchSwordModule() throws {
        let resolver = try resolver()
        let mod = try moduleForNavigation("KJV")

        var compared = 0
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                // Skip the very last chapter: that is the boundary case, asserted
                // separately because the two sides deliberately differ there.
                if book.osisName == "Rev" && chapter == book.chapterCount { continue }

                let from = resolver.displayRef(book: book, chapter: chapter)
                mod.setChapter(from)
                guard let swordNext = mod.setToNextChapter() else {
                    XCTFail("\(from): -setToNextChapter returned nil")
                    return
                }
                guard let mine = resolver.nextChapter(book: book, chapter: chapter) else {
                    XCTFail("\(from): nextChapter returned nil but SWORD gave \(swordNext)")
                    return
                }
                let ours = resolver.displayRef(mine)
                guard ours == swordNext else {
                    XCTFail("\(from) -> next: SWORD '\(swordNext)' but table '\(ours)'")
                    return
                }
                compared += 1
            }
        }
        print("[refsem/fast] forward transitions compared: \(compared) (expected 1188)")
        XCTAssertEqual(compared, 1188, "1,189 chapters minus the last")
    }

    /// Every backward transition.
    func testAllBackwardTransitionsMatchSwordModule() throws {
        let resolver = try resolver()
        let mod = try moduleForNavigation("KJV")

        var compared = 0
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                if book.osisName == "Gen" && chapter == 1 { continue }

                let from = resolver.displayRef(book: book, chapter: chapter)
                mod.setChapter(from)
                guard let swordPrev = mod.setToPreviousChapter() else {
                    XCTFail("\(from): -setToPreviousChapter returned nil")
                    return
                }
                guard let mine = resolver.previousChapter(book: book, chapter: chapter) else {
                    XCTFail("\(from): previousChapter returned nil but SWORD gave \(swordPrev)")
                    return
                }
                let ours = resolver.displayRef(mine)
                guard ours == swordPrev else {
                    XCTFail("\(from) -> prev: SWORD '\(swordPrev)' but table '\(ours)'")
                    return
                }
                compared += 1
            }
        }
        print("[refsem/fast] backward transitions compared: \(compared) (expected 1188)")
        XCTAssertEqual(compared, 1188)
    }

    /// The two boundaries, where the two sides deliberately differ — asserted as a
    /// difference rather than tolerated.
    ///
    /// `VerseKey::normalize` (versekey.cpp:1466-1493) pins to the bound and sets
    /// KEYERR_OUTOFBOUNDS, so `-setToNextChapter` at Rev 22 returns **the same ref
    /// it was given**, and the app's string-equality gate is what turns that into a
    /// no-op. The table returns nil instead. If SWORD ever started erroring here
    /// this test fails, which is the point: it documents *why* the nil is correct.
    func testBoundariesClampInSwordAndReturnNilInSwift() throws {
        let resolver = try resolver()
        let mod = try moduleForNavigation("KJV")

        guard let genesis = resolver.book(named: "Genesis"),
              let revelation = resolver.book(named: "Revelation") else {
            XCTFail("Genesis / Revelation missing from the table")
            return
        }

        // Forward, at the end of the canon.
        let lastRef = resolver.displayRef(book: revelation, chapter: revelation.chapterCount)
        XCTAssertEqual(lastRef, "Revelation of John 22", "displayRef must use the longName form")
        mod.setChapter(lastRef)
        XCTAssertEqual(mod.setToNextChapter(), lastRef,
                       "SWORD is expected to CLAMP at the end of the canon, not error")
        XCTAssertNil(resolver.nextChapter(book: revelation, chapter: revelation.chapterCount),
                     "the table must return nil, not the clamped ref")

        // Backward, at the start.
        let firstRef = resolver.displayRef(book: genesis, chapter: 1)
        XCTAssertEqual(firstRef, "Genesis 1")
        mod.setChapter(firstRef)
        XCTAssertEqual(mod.setToPreviousChapter(), firstRef,
                       "SWORD is expected to CLAMP at the start of the canon, not error")
        XCTAssertNil(resolver.previousChapter(book: genesis, chapter: 1),
                     "the table must return nil, not the clamped ref")

        // And the reason the clamp was survivable: the app's gate is string
        // equality against the ref it asked from, which the clamped value satisfies.
        XCTAssertEqual(PSModuleController.createRefString(lastRef), "Revelation 22")
        XCTAssertEqual(PSModuleController.createRefString(firstRef), "Genesis 1")
    }

    /// `displayRef` returns the **longName** form, and every call site's downstream
    /// munge turns that into the `name` form. 66/66, which is what makes returning
    /// longName safe (plan trap 1).
    func testDisplayRefLongNameMungesToTheNameForm() throws {
        let resolver = try resolver()
        var differing = 0
        for book in resolver.books {
            let long = resolver.displayRef(book: book, chapter: 1)
            XCTAssertEqual(PSModuleController.createRefString(long), "\(book.name) 1",
                           "\(book.osisName): createRefString(longName) != name")
            if book.name != book.longName { differing += 1 }
        }
        print("[refsem/fast] books where name != longName: \(differing) (expected 18)")
        XCTAssertEqual(differing, 18,
                       "Revelation + the numbered books are what make the longName choice observable")
    }

    // MARK: - Fast tier: name -> OSIS

    /// The Swift resolver's `@objc osisNameForBookName:` against the engine, for all
    /// 66 books in the spelling the search UI actually passes.
    ///
    /// The oracle is a live `SwordVerseKey`, **not**
    /// `+[PSSearchEngine osisBookNameForLocalisedBookName:]`, for two reasons: that
    /// method is private to `PSSearchEngine.mm` (so Swift cannot see it), and step 4
    /// deletes it — a comparison anchored on it would have to be re-anchored one
    /// commit later. This is the same oracle one layer down: the shim's whole body
    /// is `vk.setText(name); return vk.getOSISBookName()`, which is exactly what
    /// `SwordVerseKey(ref:v11n:).osisBookName()` does.
    func testOsisNameMatchesTheEngine() throws {
        let resolver = try resolver()
        var compared = 0
        for book in resolver.books {
            // The search UI passes the *display* name, which is `name` — the same
            // string the notification dict and lastRef carry.
            let engine = SwordVerseKey(ref: book.name, v11n: "KJV")?.osisBookName()
            let mine = resolver.osisName(forBookName: book.name)
            XCTAssertEqual(mine, book.osisName, "\(book.name): resolver disagrees with its own table")
            XCTAssertEqual(mine, engine, "\(book.name): resolver '\(mine ?? "nil")' vs engine '\(engine ?? "nil")'")
            guard mine == engine else { return }
            compared += 1
        }
        print("[refsem/fast] name->OSIS compared against the engine: \(compared)")
        XCTAssertEqual(compared, 66)

        // The two nil directions.
        XCTAssertNil(resolver.osisName(forBookName: "Nonsense"))
        XCTAssertNil(resolver.osisName(forBookName: ""))
        XCTAssertNil(resolver.osisName(forBookName: nil))
    }

    /// F3: `+translateBookName:` is **identity for every input, on every device** —
    /// there is no `en` locale conf, and `SWLocale(0)` (swlocale.cpp:63-69) has no
    /// `[Text]` section, so `translate` returns its input. This is what licenses
    /// step 6's retirement of the round-trip, and it is asserted rather than
    /// assumed because it looks like a semantic change and is not.
    func testTranslateBookNameIsIdentityForAll66() throws {
        let resolver = try resolver()
        var identity = 0
        for book in resolver.books {
            for spelling in [book.name, book.longName, book.localisedName] {
                XCTAssertEqual(SwordManager.translateBookName(spelling), spelling,
                               "translateBookName is not identity for '\(spelling)'")
                XCTAssertEqual(SwordManager.translate(toSystemLocale: spelling), spelling,
                               "translateToSystemLocale is not identity for '\(spelling)'")
            }
            // The composite the app actually performs (PSModuleController init,
            // PSTabBarControllerDelegate.updateViewWithSelectedBookName).
            let round = PSModuleController.createRefString(
                (SwordManager.translateBookName(book.name) ?? "") + " 1")
            XCTAssertEqual(round, "\(book.name) 1", "\(book.osisName): the round-trip is not identity")
            guard round == "\(book.name) 1" else { return }
            identity += 1
        }
        print("[refsem/fast] translateBookName round-trip identity: \(identity)/66")
        XCTAssertEqual(identity, 66)
    }

    // MARK: - Fast tier: the parser grammar

    /// The grammar cases the plan names, plus the `name`-vs-`longName` pins for the
    /// 18 books where the two differ, plus the whole documented out-of-scope list.
    func testParserGrammar() throws {
        let parser = try parser()

        let accepted: [(input: String, expected: String)] = [
            ("Gen 1:1",              "Genesis 1:1"),
            ("John 3:16",            "John 3:16"),
            ("Ps 23:1-3",            "Psalms 23:1-3"),   // the one in-chapter range
            ("Rom 8:28",             "Romans 8:28"),
            ("Psalms 23:1",          "Psalms 23:1"),     // the display format
            ("1 Cor 13:4",           "1 Corinthians 13:4"),
            ("1Cor 13:4",            "1 Corinthians 13:4"),
            ("I Corinthians 13:4",   "1 Corinthians 13:4"),
            ("III John 1",           "3 John 1:1"),
            ("3 John 1",             "3 John 1:1"),
            ("Rev 22:21",            "Revelation 22:21"),
            ("Revelation of John 22", "Revelation 22:1"),
            ("Song of Solomon 2:1",  "Song of Solomon 2:1"),
            ("Genesis",              "Genesis 1:1"),
            ("Genesis 1",            "Genesis 1:1"),
            ("Gen. 1:1",             "Genesis 1:1"),
            ("  Genesis 1  ",        "Genesis 1:1"),
            ("Psalms 119:176",       "Psalms 119:176"),  // the longest chapter's last verse
        ]
        for (input, expected) in accepted {
            guard let parsed = parser.parse(input) else {
                XCTFail("parser rejected '\(input)', expected \(expected)")
                continue
            }
            XCTAssertEqual(parsed.displayRef, expected, "parsing '\(input)'")
        }

        // Out of scope / invalid. Each line is a shape the app cannot produce; the
        // parser must decline rather than guess.
        let rejected = [
            "Nonsense 9:9",       // unknown book
            "Genesis 51",         // chapter past the end
            "Genesis 0", "Gen 1:0",
            "Gen 1:32",           // verse past the end of Genesis 1 (31)
            "Gen 1:3-1",          // descending range
            "Gen 1:1,3",          // comma list
            "Gen 1:1; 2:4",       // semicolon list
            "Gen 1:1-Exod 2:2",   // cross-book range
            "Gen ii",             // roman-numeral chapter (versekey.cpp:948)
            "Gen 1:1ff",          // ff suffix (:885)
            "Gen 1:12a",          // trailing-letter suffix (:925)
            "Gen inscriptio",     // INTF-only form (:962)
            "Gen -1", "Gen 1:1:1",
            "Psalms 151:1", "Rev 23", "3 John 2",
            "", "   ",
        ]
        for input in rejected {
            XCTAssertNil(parser.parse(input), "parser accepted '\(input)' but should not")
        }

        // The context-relative form, and that it is never taken from ambient state.
        let resolver = try resolver()
        guard let john = resolver.book(named: "John") else { return }
        XCTAssertEqual(parser.parse("3:16", relativeTo: john)?.displayRef, "John 3:16")
        XCTAssertEqual(parser.parse("3", relativeTo: john)?.displayRef, "John 3:1")
        XCTAssertNil(parser.parse("3:16"), "a bare verse spec must need an explicit context")

        // hadExplicitChapter, which the sword:// path branches on.
        XCTAssertEqual(parser.parse("John")?.hadExplicitChapter, false)
        XCTAssertEqual(parser.parse("1 John")?.hadExplicitChapter, false,
                       "'1 John' contains a digit but has no chapter")
        XCTAssertEqual(parser.parse("1 John 2")?.hadExplicitChapter, true)
    }

    /// Every book resolves from every spelling the table carries.
    func testParserResolvesAllBooksFromEverySpelling() throws {
        let parser = try parser()
        let resolver = try resolver()
        var resolved = 0
        // The two intentional shortName collisions: the strip dedups to 64 titles,
        // and "Jud" scrolls to Judges / "Phi" to Philippians. First-writer-wins in
        // the resolver's index reproduces that, so these two spellings do NOT
        // resolve to Jude / Philemon and must not be asserted to.
        let intentionalCollisions: [String: String] = ["Jud": "Judges", "Phi": "Philippians"]

        for book in resolver.books {
            let spellings = [book.name, book.longName, book.localisedName, book.osisName,
                             book.shortName, book.preferredAbbreviation, book.abbreviation]
            for spelling in spellings where !spelling.isEmpty {
                guard let parsed = parser.parse("\(spelling) 1:1") else {
                    XCTFail("parser rejected spelling '\(spelling)' of \(book.osisName)")
                    continue
                }
                if let owner = intentionalCollisions[spelling] {
                    XCTAssertEqual(parsed.book.name, owner,
                                   "'\(spelling)' is an intentional collision and must keep resolving to \(owner)")
                } else {
                    XCTAssertEqual(parsed.book.osisName, book.osisName,
                                   "spelling '\(spelling)' resolved to the wrong book")
                }
                resolved += 1
            }
            // Boundaries: the last verse of the last chapter parses, +1 does not.
            let lastChapter = book.chapterCount
            guard let lastVerse = resolver.verseMax(book: book, chapter: lastChapter) else { continue }
            XCTAssertNotNil(parser.parse("\(book.name) \(lastChapter):\(lastVerse)"))
            XCTAssertNil(parser.parse("\(book.name) \(lastChapter):\(lastVerse + 1)"))
            XCTAssertNil(parser.parse("\(book.name) \(lastChapter + 1)"))
        }
        print("[refsem/fast] book spellings resolved: \(resolved)")
        XCTAssertGreaterThan(resolved, 300)
    }

    // MARK: - Fast tier: the unreachability proof (the gate for step 8)
    //
    // Four parts. Three are pure data assertions over the baked store; the fourth
    // is the routing claim, which is why PSRefLinkRouter exists. Together they are
    // what licenses deleting attributeValueForEntryData:'s `x` and `scriptRef`
    // branches — this must be green BEFORE that deletion lands.
    //
    // These deliberately re-derive the finding from the store rather than trusting
    // the plan's scan.

    /// Part 1. Expand every record of all 1,189 chapters of both modules at both
    /// option endpoints, plus all 1,322 stored headings under `.forHeading`, and
    /// assert **zero** `action=showRef` anchors. `showRef` is the only action that
    /// reaches the `scriptRef` branch.
    ///
    /// The headings pass matters and is easy to miss: `headings.html` is a *text*
    /// column, not a blob, so a blob-shaped scan of the store silently skips all
    /// 1,322 rows — which is exactly where the plan's Phase-2 finding claimed
    /// canonical Psalm titles carried an un-option-gated `showRef` anchor.
    func testNoShippedContentEmitsAShowRefAnchor() throws {
        let store = try store()
        let resolver = try resolver()

        var chaptersScanned = 0, recordsScanned = 0, headingsScanned = 0
        var showRefHits: [String] = []

        for (module, kind) in [("KJV", "bible"), ("MHCC", "commentary")] {
            _ = kind
            for book in resolver.books {
                for chapter in 1...book.chapterCount {
                    guard let records = store.chapterRecords(module: module,
                                                             bookOsis: book.osisName,
                                                             chapter: chapter) else { continue }
                    chaptersScanned += 1
                    for options in [PSChapterExpander.Options.allOn, .allOff] {
                        for record in records.records where !record.isEmpty {
                            recordsScanned += 1
                            guard let html = PSChapterExpander.expand(record, options: options) else {
                                XCTFail("\(module) \(book.name) \(chapter): expander refused a record")
                                return
                            }
                            if html.contains("action=showRef") {
                                showRefHits.append("\(module) \(book.name) \(chapter) [expanded]")
                            }
                        }
                    }
                }
            }
        }

        // The headings axis, keyed by the module's own key text (long name).
        for module in ["KJV", "MHCC"] {
            for book in resolver.books {
                for chapter in 1...book.chapterCount {
                    let byVerse = store.headings(module: module, bookName: book.longName, chapter: chapter)
                    for (verse, headings) in byVerse {
                        for heading in headings {
                            headingsScanned += 1
                            // .forHeading is the option set a stored heading is
                            // expanded under — the title wrapper is unconditional
                            // inside one (see PSChapterExpander's header).
                            for options in [PSChapterExpander.Options.allOn.forHeading,
                                            PSChapterExpander.Options.allOff.forHeading] {
                                guard let html = PSChapterExpander.expand(heading.html, options: options) else {
                                    XCTFail("\(module) \(book.longName) \(chapter):\(verse): expander refused a heading")
                                    return
                                }
                                if html.contains("action=showRef") {
                                    showRefHits.append("\(module) \(book.longName) \(chapter):\(verse) [heading]")
                                }
                            }
                        }
                    }
                }
            }
        }

        print("[refsem/fast] unreachability part 1: \(chaptersScanned) chapter records,"
              + " \(recordsScanned) record expansions, \(headingsScanned) headings scanned")
        XCTAssertEqual(chaptersScanned, 2378, "1,189 chapters x 2 modules")
        // 1,322 headings x 2 modules-worth of lookups; KJV holds them all.
        XCTAssertEqual(headingsScanned, 1322, "the stored heading count changed")
        XCTAssertTrue(showRefHits.isEmpty,
                      "shipped content emits \(showRefHits.count) showRef anchor(s): \(showRefHits.prefix(5))")
    }

    /// Part 2. All 6,959 notes are `type='study'` with an **empty** refList, so the
    /// `x` branch — which parses that refList — has nothing to act on even if an
    /// `x` anchor could be emitted (none is: zero `\u{0007}`/`\u{0008}` tokens).
    func testEveryNoteIsAStudyNoteWithAnEmptyRefList() throws {
        let store = try store()
        let keys = store.allNoteKeys(module: "KJV")
        XCTAssertEqual(keys.count, 6959, "the note set changed size")

        var study = 0, nonEmptyRefLists: [String] = [], otherTypes: Set<String> = []
        for (osisRef, marker) in keys {
            guard let note = store.note(module: "KJV", osisRef: osisRef, marker: marker) else {
                XCTFail("note \(osisRef) #\(marker) is indexed but unreadable")
                return
            }
            if note.type == "study" { study += 1 } else { otherTypes.insert(note.type) }
            if !note.refList.isEmpty { nonEmptyRefLists.append("\(osisRef) #\(marker)") }
        }
        print("[refsem/fast] unreachability part 2: \(study)/\(keys.count) study notes,"
              + " \(nonEmptyRefLists.count) with a refList")
        XCTAssertEqual(study, 6959, "not every note is type='study'; found \(otherTypes)")
        XCTAssertTrue(nonEmptyRefLists.isEmpty,
                      "\(nonEmptyRefLists.count) notes carry a refList: \(nonEmptyRefLists.prefix(5))")
    }

    /// Part 3. Enumerate every href in all 15,824 lexicon entries and assert the
    /// `sword://` shape set is exactly the two `sword://Strongs*` forms — i.e. the
    /// only `sword://` links in the whole shipped corpus are lexicon->lexicon.
    func testTheOnlyBakedSwordLinksAreLexiconToLexicon() throws {
        let store = try store()
        var hosts: [String: Int] = [:]
        var entries = 0

        for module in ["StrongsRealGreek", "StrongsRealHebrew", "Robinson"] {
            for key in store.dictKeys(module: module) {
                guard let html = store.dictEntry(module: module, key: key) else {
                    XCTFail("\(module) key '\(key)' is indexed but unreadable")
                    return
                }
                entries += 1
                for host in Self.swordLinkHosts(in: html) {
                    hosts[host, default: 0] += 1
                }
            }
        }

        print("[refsem/fast] unreachability part 3: \(entries) lexicon entries,"
              + " sword:// hosts: \(hosts)")
        XCTAssertEqual(entries, 15824, "the lexicon entry count changed")
        XCTAssertEqual(Set(hosts.keys), ["StrongsRealGreek", "StrongsRealHebrew"],
                       "a sword:// link points somewhere new: \(hosts)")
        XCTAssertEqual(hosts.values.reduce(0, +), 14989, "the baked sword:// link count changed")
    }

    /// Part 4. **The routing claim.** Every baked `sword://` link must route to
    /// `.dictionary`, never to the bible-ref arm that reaches `scriptRef`.
    ///
    /// Module type comes from `content_meta`, not from `SwordManager`, so this
    /// assertion needs neither the engine nor a live manager and survives Phase 5.
    func testEveryBakedSwordLinkRoutesToTheDictionaryArm() throws {
        let store = try store()
        var routed = 0
        var wrongArm: [String] = []

        for module in ["StrongsRealGreek", "StrongsRealHebrew", "Robinson"] {
            for key in store.dictKeys(module: module) {
                guard let html = store.dictEntry(module: module, key: key) else { continue }
                for host in Self.swordLinkHosts(in: html) {
                    // What data(forLink:) produces for `sword://<host>/<value>`.
                    let linkData: [AnyHashable: Any] = [
                        ATTRTYPE_MODULE: host,
                        ATTRTYPE_TYPE: "scriptRef",
                        ATTRTYPE_ACTION: "showRef",
                    ]
                    let type = store.moduleMeta(host, key: "type")
                    XCTAssertEqual(type, PSRefLinkRouter.typeDictionary,
                                   "content_meta says \(host) is '\(type ?? "nil")'")
                    let destination = PSRefLinkRouter.destination(forLinkData: linkData, moduleType: type)
                    if destination != .dictionary {
                        wrongArm.append("\(module)/\(key) -> \(host)")
                    }
                    routed += 1
                }
            }
        }

        print("[refsem/fast] unreachability part 4: \(routed) baked links routed")
        XCTAssertEqual(routed, 14989)
        XCTAssertTrue(wrongArm.isEmpty,
                      "\(wrongArm.count) baked links take the bible-ref arm: \(wrongArm.prefix(5))")

        // And the router still answers .bibleRef for the three inputs that must
        // keep reaching the ref path, so this is a routing test and not a
        // "everything is a dictionary" tautology.
        XCTAssertEqual(PSRefLinkRouter.destination(forModuleName: nil, moduleType: nil), .bibleRef)
        XCTAssertEqual(PSRefLinkRouter.destination(forModuleName: "", moduleType: nil), .bibleRef)
        XCTAssertEqual(PSRefLinkRouter.destination(forModuleName: "KJV",
                                                   moduleType: PSRefLinkRouter.typeBible), .bibleRef)
        XCTAssertEqual(PSRefLinkRouter.destination(forModuleName: "MHCC",
                                                   moduleType: PSRefLinkRouter.typeCommentary), .bibleRef)
        // Not installed -> bible arm (then the caller's placeholder).
        XCTAssertEqual(PSRefLinkRouter.destination(forModuleName: "ESV", moduleType: nil), .bibleRef)
        // Unrecognised type string -> ModuleType defaults to `bible`.
        XCTAssertEqual(PSRefLinkRouter.destination(forModuleName: "Weird", moduleType: "Something Else"),
                       .bibleRef,
                       "+moduleTypeForModuleTypeString: defaults to bible for an unknown type")
    }

    /// The `sword://<host>` hosts appearing in an HTML fragment.
    private static func swordLinkHosts(in html: String) -> [String] {
        guard html.contains("sword://") else { return [] }
        var out: [String] = []
        var rest = Substring(html)
        while let start = rest.range(of: "sword://") {
            let after = rest[start.upperBound...]
            // Host runs to the next "/", quote, or whitespace.
            let end = after.firstIndex(where: { $0 == "/" || $0 == "\"" || $0 == "'" || $0.isWhitespace })
                ?? after.endIndex
            out.append(String(after[after.startIndex..<end]))
            rest = after[end...]
        }
        return out
    }

    // MARK: - The committed oracle fixture
    //
    // Dumps the live engine's entire answer so step 10 can delete SwordBook without
    // any test above having to be weakened: after Phase 5 the comparisons re-anchor
    // on this file. Assert-by-default, PSORACLE_CAPTURE to rewrite.

    func testCaptureVersificationTable() throws {
        guard let books = swordBooks() else {
            throw XCTSkip("+booksForVersificationSystem: unavailable (expected after Phase 5)")
        }
        let mod = try moduleForNavigation("KJV")

        var lines: [String] = []
        lines.append("# live-SWORD KJV versification oracle")
        lines.append("# books=\(books.count)")

        for (i, book) in books.enumerated() {
            lines.append("## [\(i)] name=\(book.name() ?? "<nil>")"
                         + " short=\(book.shortName() ?? "<nil>")"
                         + " osis=\(book.osisName() ?? "<nil>")"
                         + " chapters=\(book.chapters())")
            let maxima = (1...book.chapters()).map { String(book.verses($0)) }
            lines.append("verseMax=\(maxima.joined(separator: ","))")
        }

        // All 2,376 transitions, driven exactly as the app drives them.
        lines.append("# transitions: <from> -> next=<...> prev=<...>")
        for book in books {
            for chapter in 1...book.chapters() {
                let from = "\((book.name() ?? "")) \(chapter)"
                mod.setChapter(from)
                let next = mod.setToNextChapter() ?? "<nil>"
                mod.setChapter(from)
                let prev = mod.setToPreviousChapter() ?? "<nil>"
                lines.append("\(from) -> next=\(next) prev=\(prev)")
            }
        }

        try checkFixture("versification-KJV-oracle.txt",
                         actual: lines.joined(separator: "\n") + "\n")
    }

    // MARK: - Exhaustive tier (PSREF_EXHAUSTIVE=1)

    /// All 31,102 `displayRef` values against a live `SwordVerseKey`, in **both**
    /// the `name` and the `longName` form, so the choice of form is pinned per verse
    /// rather than per book.
    func testExhaustiveAllVersesAgreeWithVerseKey() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSREF_EXHAUSTIVE=1 to run the exhaustive tier")
        let resolver = try resolver()

        var compared = 0
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                guard let maxVerse = resolver.verseMax(book: book, chapter: chapter) else { continue }
                for verse in 1...maxVerse {
                    for form in [book.name, book.longName] {
                        let ref = "\(form) \(chapter):\(verse)"
                        guard let key = SwordVerseKey(ref: ref, v11n: "KJV") else {
                            XCTFail("VerseKey refused '\(ref)'")
                            return
                        }
                        // VerseKey normalises to its own book/chapter/verse; the
                        // table must agree on all three. Compare on the OSIS name
                        // rather than -book: VerseKey's book number is 1-based
                        // *within its testament*, so matching it against a flat
                        // 66-entry index would mean reconstructing BMAX arithmetic
                        // — the very thing the table exists to avoid.
                        XCTAssertEqual(key.osisBookName(), book.osisName, "\(ref): book differs")
                        XCTAssertEqual(Int(key.chapter()), chapter, "\(ref): chapter differs")
                        XCTAssertEqual(Int(key.verse()), verse, "\(ref): verse differs")
                        guard key.osisBookName() == book.osisName,
                              Int(key.chapter()) == chapter,
                              Int(key.verse()) == verse else { return }
                        compared += 1
                    }
                }
            }
        }
        print("[refsem/exhaustive] verses compared against VerseKey: \(compared) (expected 62204)")
        XCTAssertEqual(compared, 62204, "31,102 verses x 2 name forms")
    }

    /// All 31,102 verses round-trip through the parser: `parse(displayRef(v)) == v`.
    func testExhaustiveEveryVerseRoundTripsThroughTheParser() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSREF_EXHAUSTIVE=1 to run the exhaustive tier")
        let resolver = try resolver()
        let parser = try parser()

        var compared = 0
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                guard let maxVerse = resolver.verseMax(book: book, chapter: chapter) else { continue }
                for verse in 1...maxVerse {
                    let ref = "\(book.name) \(chapter):\(verse)"
                    guard let parsed = parser.parse(ref) else {
                        XCTFail("parser rejected its own output form '\(ref)'")
                        return
                    }
                    guard parsed.displayRef == ref,
                          parsed.book.osisName == book.osisName,
                          parsed.chapter == chapter, parsed.verse == verse else {
                        XCTFail("'\(ref)' round-tripped to '\(parsed.displayRef)'")
                        return
                    }
                    compared += 1
                }
            }
        }
        print("[refsem/exhaustive] verses round-tripped: \(compared) (expected 31102)")
        XCTAssertEqual(compared, 31102)
    }

    /// 1,189 parser-vs-resolver agreement checks: the parser and the reader's own
    /// `resolve(ref:)` must land on the same (book, chapter) for every chapter ref
    /// the app can produce.
    func testExhaustiveParserAgreesWithTheReadersResolveForEveryChapter() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSREF_EXHAUSTIVE=1 to run the exhaustive tier")
        let resolver = try resolver()
        let parser = try parser()

        var compared = 0
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                let ref = "\(book.name) \(chapter)"
                guard let viaResolver = resolver.resolve(ref: ref),
                      let viaParser = parser.parse(ref) else {
                    XCTFail("'\(ref)': resolver or parser declined")
                    return
                }
                guard viaResolver.book.osisName == viaParser.book.osisName,
                      viaResolver.chapter == viaParser.chapter else {
                    XCTFail("'\(ref)': resolver \(viaResolver.book.osisName) \(viaResolver.chapter)"
                            + " vs parser \(viaParser.book.osisName) \(viaParser.chapter)")
                    return
                }
                compared += 1
            }
        }
        print("[refsem/exhaustive] chapter refs agreed: \(compared) (expected 1189)")
        XCTAssertEqual(compared, 1189)
    }

    /// The `builtin_abbrevs` inclusion direction, one-way by design: assert that
    /// **everything the parser accepts, SWORD agrees on**, and *print* the forms
    /// SWORD accepts but the parser rejects rather than asserting on them. The
    /// parser is deliberately narrower (see its header), so the delta is visible
    /// instead of assumed — a later widening or narrowing shows up in this output.
    func testExhaustiveAbbreviationInclusionDirection() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSREF_EXHAUSTIVE=1 to run the exhaustive tier")
        let resolver = try resolver()
        let parser = try parser()

        var agreed = 0
        var parserRejectsSwordAccepts: [String] = []
        var disagreed: [(spelling: String, mine: String, sword: String)] = []

        // Every spelling in the table, plus the two fallback shapes the parser
        // adds (trailing ".", despaced numbered abbreviations).
        var candidates: Set<String> = []
        for book in resolver.books {
            for spelling in [book.name, book.longName, book.localisedName, book.osisName,
                             book.shortName, book.preferredAbbreviation, book.abbreviation]
            where !spelling.isEmpty {
                candidates.insert(spelling)
                candidates.insert(spelling + ".")
                candidates.insert(spelling.replacingOccurrences(of: " ", with: ""))
                if !spelling.contains(" "), let first = spelling.first, first.isNumber {
                    // "1Cor" -> "1 Cor"
                    candidates.insert("\(first) \(spelling.dropFirst())")
                }
            }
        }

        for spelling in candidates.sorted() {
            let ref = "\(spelling) 1:1"
            let mine = parser.parse(ref)
            let engineOsis = SwordVerseKey(ref: ref, v11n: "KJV")?.osisBookName()

            if let mine = mine {
                if mine.book.osisName == engineOsis {
                    agreed += 1
                } else {
                    disagreed.append((spelling, mine.book.osisName, engineOsis ?? "nil"))
                }
            } else if let engineOsis = engineOsis, resolver.book(osis: engineOsis) != nil {
                parserRejectsSwordAccepts.append("\(spelling) -> \(engineOsis)")
            }
        }

        print("[refsem/exhaustive] abbreviation forms both accept: \(agreed)")
        print("[refsem/exhaustive] forms SWORD accepts but the parser rejects"
              + " (\(parserRejectsSwordAccepts.count), deliberately out of scope):")
        for form in parserRejectsSwordAccepts.prefix(40) { print("    \(form)") }
        if parserRejectsSwordAccepts.count > 40 {
            print("    … and \(parserRejectsSwordAccepts.count - 40) more")
        }
        print("[refsem/exhaustive] forms both accept but resolve DIFFERENTLY"
              + " (\(disagreed.count)):")
        for d in disagreed { print("    \(d.spelling): table=\(d.mine) sword=\(d.sword)") }

        // The one disagreement is the ambiguous abbreviation "Jud", and it is
        // **today's visible behaviour**, not a bug. The resolver's index is
        // first-writer-wins over the books in canonical order, so "Jud" binds to
        // Judges (index 6) rather than Jude (index 64) — which is exactly what the
        // ref-selector strip does when you tap "Jud", and the plan requires keeping
        // it. SWORD's own table instead binds "JUD" -> Jude, by prefix-matching its
        // alphabetically-sorted list where "JUDE" precedes "JUDG"
        // (canon_abbrevs.h:429-430).
        //
        // Note "Phi" is NOT in this set: both sides answer Philippians, because
        // SWORD's "PHIL" -> Phil also precedes "PHILEMON" -> Phlm.
        //
        // Asserted as an exact set rather than tolerated: a second collision, or
        // this one flipping, fails here.
        let actualCollisions = Set(disagreed.map { "\($0.spelling):\($0.mine)/\($0.sword)" })
        XCTAssertEqual(actualCollisions, ["Jud:Judg/Jude", "Jud.:Judg/Jude"],
                       "the set of ambiguous-abbreviation disagreements changed")

        // The 33 rejected forms are all fully-despaced full names this test
        // synthesises ("1Corinthians", "IThessalonians", "SongofSolomon") — shapes
        // no part of the app emits. Two of them are worth noticing as evidence that
        // the parser's narrowness is a feature: SWORD's prefix match answers
        // "SongofSolomon" -> **Rev** and "RevelationofJohn" -> Rev, i.e. it
        // mis-resolves one of them outright. Declining is the better answer.
        XCTAssertEqual(parserRejectsSwordAccepts.count, 33,
                       "the accept-delta against SWORD changed size")
        XCTAssertGreaterThan(agreed, 300, "the candidate set collapsed")
        XCTAssertEqual(agreed, 424, "the agreeing-form count changed")
    }
}
