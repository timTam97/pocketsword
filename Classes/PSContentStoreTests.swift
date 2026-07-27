//
//  PSContentStoreTests.swift
//  PocketSwordTests
//
//  Tests for the baked content store (Resources/PSContent.sqlite) and the
//  pure-Swift reader that Phase 3 of the SWORD-removal plan builds on top of it.
//
//  This file starts with the one thing the rest of Phase 3 depends on: the
//  artifacts are actually in the app bundle. They are bundled by path, so a
//  converter re-run replaces them in place without touching the pbxproj — but a
//  missing Copy-Resources entry would make every later reader test fail for a
//  reason that has nothing to do with the reader.
//

import XCTest
@testable import PocketSword

final class PSContentStoreTests: XCTestCase {

    // MARK: - Fixture plumbing

    /// Same derivation as SwordOracleCaptureTests: from #filePath, so the tests
    /// read the committed fixtures rather than anything in the simulator sandbox.
    private static func fixtureDir() -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return repoRoot.appendingPathComponent("Tests/Fixtures", isDirectory: true)
    }

    private func fixture(_ name: String) throws -> String {
        let url = Self.fixtureDir().appendingPathComponent(name)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("fixture \(name) is not present")
        }
        return text
    }

    /// Report the first divergence rather than dumping two chapters of HTML.
    private func assertEqualHTML(_ actual: String, _ expected: String, _ label: String) {
        guard actual != expected else { return }
        let a = Array(actual), e = Array(expected)
        var i = 0
        while i < min(a.count, e.count), a[i] == e[i] { i += 1 }
        let lo = max(0, i - 60)
        XCTFail("""
            \(label): reader output differs from the live-SWORD fixture.
              first difference at character \(i) (fixture \(e.count) chars, reader \(a.count))
              fixture: …\(String(e[lo..<min(e.count, i + 60)]))…
              reader:  …\(String(a[lo..<min(a.count, i + 60)]))…
            """)
    }

    private func store() throws -> PSContentStore {
        guard let store = PSContentStore.shared else {
            throw XCTSkip("PSContentStore did not open — see the logged failure")
        }
        return store
    }

    private func resolver() throws -> PSBookOSISResolver {
        guard let resolver = PSBookOSISResolver.shared else {
            throw XCTSkip("PSBookOSISResolver did not load")
        }
        return resolver
    }

    /// The reader's equivalent of `-chapterBodyHTML:`: store -> expander ->
    /// assembler. Deliberately assembled here from the pieces rather than through
    /// PSContentReader, so a failure localises to one of the four core files.
    private func renderBody(module: String,
                           ref: String,
                           options: PSChapterExpander.Options,
                           kind: PSChapterAssembler.ModuleKind = .bible,
                           versePerLine: Bool = false,
                           highlight: @escaping (Int) -> String? = { _ in nil }) throws -> PSChapterAssembler.Result {
        let store = try store()
        let resolver = try resolver()
        guard let (book, chapter) = resolver.resolve(ref: ref) else {
            XCTFail("\(ref) did not resolve to a book + chapter")
            throw XCTSkip("unresolvable ref")
        }
        guard let records = store.chapterRecords(module: module, bookOsis: book.osisName, chapter: chapter) else {
            XCTFail("\(module) \(ref) is not in the store")
            throw XCTSkip("missing chapter")
        }
        // Headings are keyed by the module's own key text, which uses the long
        // (roman-numeral) name — "I Corinthians 1:1", not "1 Corinthians 1:1".
        let headings = store.headings(module: module, bookName: book.longName, chapter: chapter)

        var expanded: [String] = []
        expanded.reserveCapacity(records.records.count)
        for record in records.records {
            if record.isEmpty {
                expanded.append("")
                continue
            }
            guard let html = PSChapterExpander.expand(record, options: options) else {
                XCTFail("\(module) \(ref): a record failed to expand")
                throw XCTSkip("expansion failed")
            }
            expanded.append(html)
        }

        var config = PSChapterAssembler.Config()
        config.kind = kind
        config.versePerLine = versePerLine
        config.headingsOn = options.headings
        guard let result = PSChapterAssembler.assemble(
            records: expanded,
            headings: headings,
            config: config,
            headingHTML: { PSChapterExpander.expand($0.html, options: options.forHeading) },
            highlightColour: highlight,
            emptyChapterMessage: "") else {
            XCTFail("\(module) \(ref): assembly failed")
            throw XCTSkip("assembly failed")
        }
        return result
    }

    // MARK: - Bundling (plan step 1)

    func testContentArtifactsAreBundled() throws {
        let store = Bundle.main.url(forResource: "PSContent", withExtension: "sqlite")
        XCTAssertNotNil(store, "PSContent.sqlite is missing from the app bundle's Copy Resources phase")

        let versification = Bundle.main.url(forResource: "Versification-KJV", withExtension: "json")
        XCTAssertNotNil(versification, "Versification-KJV.json is missing from the app bundle")

        // Non-empty and readable, not just present: a Copy Resources entry that
        // points at a stale path would still resolve to a zero-byte file.
        if let store {
            let size = try FileManager.default.attributesOfItem(atPath: store.path)[.size] as? Int ?? 0
            XCTAssertGreaterThan(size, 1_000_000, "PSContent.sqlite looks truncated (\(size) bytes)")
        }
        if let versification {
            let json = try Data(contentsOf: versification)
            XCTAssertGreaterThan(json.count, 1000, "Versification-KJV.json looks truncated")
        }
    }

    // MARK: - Store opens and validates (plan step 4)

    func testStoreOpensAndMatchesTheExpectedSchema() throws {
        let store = try store()
        // The counts the converter validated against live SWORD at bake time. If
        // these drift, the store was rebuilt from different modules.
        XCTAssertEqual(store.dictEntryCount(module: "Robinson"), 1526)
        XCTAssertEqual(store.dictEntryCount(module: "StrongsRealGreek"), 5624)
        XCTAssertEqual(store.dictEntryCount(module: "StrongsRealHebrew"), 8674)
        XCTAssertEqual(store.moduleMeta("KJV", key: "type"), "Biblical Texts")
        XCTAssertEqual(store.moduleMeta("MHCC", key: "type"), "Commentaries")
    }

    // MARK: - Chapter bodies vs the live-SWORD fixtures

    /// The acceptance criterion: the reader reproduces the captured engine output
    /// byte-for-byte, at BOTH option endpoints, for every fixture chapter.
    func testChapterBodiesMatchFixturesAllOptionsOn() throws {
        for ref in ["Gen 1", "Ps 3", "Ps 119", "Matt 1", "John 3", "Gen 4", "Ps 23", "Rev 22"] {
            let result = try renderBody(module: "KJV", ref: ref, options: .allOn)
            let name = "KJV-\(ref.replacingOccurrences(of: " ", with: "_")).html"
            assertEqualHTML(result.body, try fixture(name), name)
        }
    }

    /// The state a fresh install renders. Passing both endpoints is what proves the
    /// option gating is wired to the right axes at all — a reader that ignored the
    /// options entirely would pass the all-on set alone.
    func testChapterBodiesMatchFixturesAllOptionsOff() throws {
        for ref in ["Gen 1", "Ps 3", "Ps 119", "Matt 1", "John 3", "Gen 4", "Ps 23", "Rev 22"] {
            let result = try renderBody(module: "KJV", ref: ref, options: .allOff)
            let name = "KJV-\(ref.replacingOccurrences(of: " ", with: "_"))-alloff.html"
            assertEqualHTML(result.body, try fixture(name), name)
        }
    }

    /// MHCC exercises the `bodyref` indirection (28,970 slots dedup to 4,435
    /// bodies) and the commentary formatting, whose anchor is `#verse{i}` rather
    /// than `pocketsword:versemenu:{i}`.
    func testCommentaryBodiesMatchFixtures() throws {
        for (ref, suffix) in [("Gen 1", ""), ("Matt 1", ""), ("Ps 23", ""),
                              ("Gen 1", "-alloff"), ("Matt 1", "-alloff"), ("Ps 23", "-alloff")] {
            let options: PSChapterExpander.Options = suffix.isEmpty ? .allOn : .allOff
            let result = try renderBody(module: "MHCC", ref: ref, options: options, kind: .commentary)
            let name = "MHCC-\(ref.replacingOccurrences(of: " ", with: "_"))\(suffix).html"
            assertEqualHTML(result.body, try fixture(name), name)
        }
    }

    /// The production render path: -getChapter: passes
    /// applyBookmarkHighlights:YES, and -highlightVerse: re-opens its span around
    /// every block element, so this is the subtlest thing in the assembler.
    func testBookmarkHighlightedBodyMatchesFixture() throws {
        let colour = "rgba(255,204,0,0.8)"
        let highlighted: Set<Int> = [1, 3, 6]
        let result = try renderBody(module: "KJV", ref: "Psalms 23", options: .allOn,
                                    highlight: { highlighted.contains($0) ? colour : nil })
        assertEqualHTML(result.body, try fixture("KJV-Ps_23-highlighted.html"), "KJV-Ps_23-highlighted.html")
    }

    /// The counter is a loop counter, not a verse count: Gen 1's 31 verses yield
    /// 32. It drives the vv{i} anchors, the versemenu links, the bookmark lookup
    /// and the JS versepos bounds, so it has to come out identical.
    func testEntryCountsMatchTheCapturedLoopCounter() throws {
        let expected = ["Gen 1": 32, "Ps 3": 9, "Ps 119": 177, "Matt 1": 26,
                        "John 3": 37, "Gen 4": 27, "Ps 23": 7, "Rev 22": 22]
        for (ref, count) in expected {
            let result = try renderBody(module: "KJV", ref: ref, options: .allOn)
            XCTAssertEqual(result.entryCount, count, "\(ref) loop counter")
        }
    }

    // MARK: - Book resolution

    /// The gap SWORD currently absorbs: refs carry book NAMES while the store is
    /// keyed on OSIS abbreviations. "Genesis 1" is what
    /// PSModuleController.getCurrentBibleRef() actually returns on a fresh install.
    func testBookNamesTheAppActuallyPassesResolve() throws {
        let resolver = try resolver()
        let cases: [(String, String, Int)] = [
            ("Genesis 1", "Gen", 1),            // the seeded default
            ("Gen 1", "Gen", 1),                // the abbreviation the fixtures use
            ("Psalms 119", "Ps", 119),
            ("1 Corinthians 13", "1Cor", 13),   // post-createRefString
            ("I Corinthians 13", "1Cor", 13),   // pre-createRefString / SWORD key text
            ("III John 1", "3John", 1),
            ("3 John 1", "3John", 1),
            ("Song of Solomon 2", "Song", 2),   // multi-word name
            ("Revelation 22", "Rev", 22),
            ("Genesis 1:1", "Gen", 1),          // a verse ref resolves to its chapter
        ]
        for (ref, osis, chapter) in cases {
            guard let resolved = resolver.resolve(ref: ref) else {
                XCTFail("\(ref) did not resolve")
                continue
            }
            XCTAssertEqual(resolved.book.osisName, osis, "\(ref) book")
            XCTAssertEqual(resolved.chapter, chapter, "\(ref) chapter")
        }
    }

    /// Out-of-range and nonsense must return nil, never a plausible wrong chapter:
    /// the caller treats nil as "fall back to SWORD".
    func testUnresolvableRefsReturnNil() throws {
        let resolver = try resolver()
        for ref in ["Genesis 51",        // 50 chapters
                    "Nonexistent 1",
                    "Genesis",           // no chapter
                    "Genesis 0",
                    "1",
                    ""] {
            XCTAssertNil(resolver.resolve(ref: ref), "\(ref.debugDescription) should not resolve")
        }
    }

    /// "Genesis 1" — the string the app passes — renders, not just resolves.
    func testTheAppsOwnDefaultRefRenders() throws {
        let result = try renderBody(module: "KJV", ref: "Genesis 1", options: .allOn)
        assertEqualHTML(result.body, try fixture("KJV-Gen_1.html"), "Genesis 1 via the app's own ref form")
        XCTAssertEqual(result.entryCount, 32)
    }
}
