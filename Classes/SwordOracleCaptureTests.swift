//
//  SwordOracleCaptureTests.swift
//  PocketSwordTests
//
//  Captures the live SWORD engine's output as checked-in golden fixtures, while
//  the engine is still in the tree.
//
//  This is the Phase-2 half of the SWORD-removal plan's oracle strategy: SWORD is
//  deleted forever in Phase 5, so the only way Phase 3's pure-Swift content
//  reader can be held to account is against data captured now. Everything these
//  tests write under Tests/Fixtures/ becomes Phase 3's acceptance criterion.
//
//  Two modes:
//
//  * Assertion mode (default). If a fixture already exists on disk, the captured
//    output is compared against it and any difference fails. This is what keeps
//    the fixtures honest in CI once they are committed.
//  * Capture mode. Set the PSORACLE_CAPTURE environment variable and the tests
//    (re)write the fixtures instead of asserting, into the directory named by
//    PSORACLE_FIXTURE_DIR (defaults to a path derived from #filePath, i.e. the
//    source tree, not the simulator sandbox).
//
//  Capturing is deliberately opt-in: a test that rewrites its own expectations
//  on every run asserts nothing.
//
//  IMPORTANT: these tests drive the *real* singleton SwordManager that the host
//  app is using, and they set global SWORD options to a fixed configuration to
//  make output reproducible. -[SwordModule getChapter:] calls -setPreferences,
//  which pushes the per-module NSUserDefaults prefs back into those same global
//  options, so the option state here is not durable across a render by the app.
//  That is exactly why the converter sets options directly rather than via prefs.
//

import XCTest
@testable import PocketSword

final class SwordOracleCaptureTests: XCTestCase {

    // MARK: - Configuration

    /// The render configuration the offline converter (tools/swordbake) uses.
    /// Capturing under any other configuration would produce an oracle that the
    /// content store cannot possibly match.
    ///
    /// Headings is **On**: 1,250 of KJV's 1,388 `<title>` tags are
    /// non-canonical and live in intro-only entry slots, and
    /// osisheadings.cpp:132 only emits interverse titles into the body when the
    /// option is on. Lemmas is **Off**: KJV declares
    /// `GlobalOptionFilter=OSISLemma`, and leaving it on makes
    /// osishtmlhref.cpp:66 emit ~145k anchors for `lemma.TR:` Greek parts.
    private static let renderOptions: [(String, String)] = [
        (SW_OPTION_STRONGS, SW_ON),
        (SW_OPTION_MORPHS, SW_ON),
        (SW_OPTION_FOOTNOTES, SW_ON),
        (SW_OPTION_SCRIPTREFS, SW_ON),
        (SW_OPTION_REDLETTERWORDS, SW_ON),
        (SW_OPTION_HEADINGS, SW_ON),
        (SW_OPTION_VARIANTS, SW_OPTION_VARIANTS_PRIMARY),
        (SW_OPTION_LEMMAS, SW_OFF),
        (SW_OPTION_GLOSSES, SW_OFF),
        (SW_OPTION_GREEKACCENTS, SW_OFF),
        (SW_OPTION_HEBREWPOINTS, SW_OFF),
        (SW_OPTION_HEBREWCANTILLATION, SW_OFF),
    ]

    /// Chapters chosen to cover the edge cases the plan calls out, not for
    /// breadth. Each one exists to catch a specific way the reader can go wrong.
    private static let bibleChapters: [(ref: String, why: String)] = [
        ("Gen 1",   "book + chapter intro titles in the verse-0 slot"),
        ("Ps 3",    "canonical preverse title (Heading/Preverse bucket)"),
        ("Ps 119",  "acrostic titles throughout the chapter"),
        ("Matt 1",  "NT boundary + type=\"main\" title"),
        ("John 3",  "red-letter (Words of Christ) spans"),
        ("Gen 4",   "footnote-dense chapter"),
        ("Ps 23",   "short chapter, canonical title"),
        ("Rev 22",  "last chapter of the versification"),
    ]

    private static let commentaryChapters = ["Gen 1", "Matt 1", "Ps 23"]

    /// Sampled lexicon keys. Includes the fixed-width-padding cases that
    /// SWLD::strongsPad mishandles for prefixed input (see testStrongsPadning...).
    private static let greekKeys  = ["25", "3056", "2316", "4018", "5547"]
    private static let hebrewKeys = ["430", "1", "7225", "3068", "0430"]
    private static let morphKeys  = ["N-NSF", "V-PAI-3S", "CONJ", "PREP"]

    // MARK: - Fixture plumbing

    private static var isCapturing: Bool {
        ProcessInfo.processInfo.environment["PSORACLE_CAPTURE"] != nil
    }

    /// Fixture directory. Derived from this file's path so capture writes into
    /// the source tree rather than the simulator's data container.
    private static func fixtureDir() -> URL {
        if let override = ProcessInfo.processInfo.environment["PSORACLE_FIXTURE_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        // <repo>/Classes/SwordOracleCaptureTests.swift -> <repo>/Tests/Fixtures
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return repoRoot.appendingPathComponent("Tests/Fixtures", isDirectory: true)
    }

    /// Compare `actual` against the committed fixture named `name`, or write it
    /// when capturing. A missing fixture in assertion mode is reported as a skip
    /// rather than a failure, so the suite is green on a fresh clone before the
    /// fixtures have been generated.
    private func checkFixture(_ name: String, actual: String) throws {
        let dir = Self.fixtureDir()
        let url = dir.appendingPathComponent(name)

        if Self.isCapturing {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try actual.write(to: url, atomically: true, encoding: .utf8)
            print("[oracle] captured \(name) (\(actual.utf8.count) bytes)")
            return
        }

        guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("fixture \(name) not captured yet; run with PSORACLE_CAPTURE=1")
        }

        if expected != actual {
            // Report the first divergence rather than dumping two chapters of HTML.
            let e = Array(expected), a = Array(actual)
            var i = 0
            while i < min(e.count, a.count), e[i] == a[i] { i += 1 }
            let lo = max(0, i - 60)
            XCTFail("""
                fixture \(name) does not match live SWORD output.
                  first difference at character \(i) (expected \(e.count) chars, got \(a.count))
                  expected: …\(String(e[lo..<min(e.count, i + 60)]))…
                  actual:   …\(String(a[lo..<min(a.count, i + 60)]))…
                """)
        }
    }

    // MARK: - Engine readiness

    /// The bundled modules are seeded on a detached background thread from
    /// PocketSwordSceneDelegate with no completion signal, so a test that touches
    /// a module immediately after launch can race the unzip. Poll instead.
    private func waitForModules(_ names: [String], timeout: TimeInterval = 90) throws {
        guard let manager = SwordManager.default() else {
            throw XCTSkip("no SwordManager — the host app has not initialised the engine")
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if names.allSatisfy({ manager.isModuleInstalled($0) }) { return }
            // The seeding thread also needs the manager's lock; sleep rather than
            // spin so we are not contending with it.
            Thread.sleep(forTimeInterval: 0.25)
        }
        throw XCTSkip("modules \(names) not installed within \(timeout)s — seeding did not complete")
    }

    private func configuredModule(_ name: String) throws -> SwordModule {
        try waitForModules([name])
        guard let manager = SwordManager.default() else {
            throw XCTSkip("no SwordManager")
        }
        guard let mod = manager.module(withName: name) else {
            throw XCTSkip("module \(name) not available")
        }
        for (option, value) in Self.renderOptions {
            manager.setGlobalOption(option, value: value)
        }
        return mod
    }

    // MARK: - Chapter bodies

    func testCaptureKJVChapterBodies() throws {
        let mod = try configuredModule("KJV")
        var summary: [String] = []

        for entry in Self.bibleChapters {
            mod.aquireModuleLock()
            var entryCount: NSInteger = 0
            // applyBookmarkHighlights:NO — the highlight injection reads
            // PSBookmarks, i.e. the user's own data, which is not reproducible.
            let maybeBody = mod.chapterBodyHTML(entry.ref,
                                                applyBookmarkHighlights: false,
                                                entryCount: &entryCount)
            mod.releaseModuleLock()
            let body = try XCTUnwrap(maybeBody, "\(entry.ref) returned no body")

            let safe = entry.ref.replacingOccurrences(of: " ", with: "_")
            try checkFixture("KJV-\(safe).html", actual: body)
            summary.append("\(entry.ref)\tentries=\(entryCount)\tbytes=\(body.utf8.count)\t\(entry.why)")

            XCTAssertGreaterThan(entryCount, 0, "\(entry.ref) produced no entries")
            XCTAssertFalse(body.isEmpty, "\(entry.ref) produced an empty body")
        }

        try checkFixture("KJV-chapter-summary.tsv", actual: summary.joined(separator: "\n") + "\n")
    }

    func testCaptureMHCCChapterBodies() throws {
        let mod = try configuredModule("MHCC")
        var summary: [String] = []

        for ref in Self.commentaryChapters {
            mod.aquireModuleLock()
            var entryCount: NSInteger = 0
            let maybeBody = mod.chapterBodyHTML(ref,
                                                applyBookmarkHighlights: false,
                                                entryCount: &entryCount)
            mod.releaseModuleLock()
            let body = try XCTUnwrap(maybeBody, "\(ref) returned no body")

            let safe = ref.replacingOccurrences(of: " ", with: "_")
            try checkFixture("MHCC-\(safe).html", actual: body)
            summary.append("\(ref)\tentries=\(entryCount)\tbytes=\(body.utf8.count)")
        }

        try checkFixture("MHCC-chapter-summary.tsv", actual: summary.joined(separator: "\n") + "\n")
    }

    /// The loop counter that drives `id="vv{i}"` and `pocketsword:versemenu:i`
    /// is NOT the verse number — it advances even for entries the loop skips as
    /// empty or duplicate. Pin that: Gen 1 has 31 verses, so a counter equal to
    /// 31 would mean the intro slot had been dropped.
    func testChapterEntryCountIsNotAVerseCount() throws {
        let mod = try configuredModule("KJV")
        mod.aquireModuleLock()
        var entryCount: NSInteger = 0
        _ = mod.chapterBodyHTML("Gen 1", applyBookmarkHighlights: false, entryCount: &entryCount)
        mod.releaseModuleLock()

        // Measured: 32, for Gen 1's 31 verses. The counter starts at 0 on the
        // verse-0 intro slot and is incremented at the bottom of each iteration,
        // including the final one that steps out of the chapter — so it lands on
        // (verses + 1), not on the verse count and not on (verses + 2).
        // This is exactly the off-by-one the converter had to design around: it
        // stores the loop's input sequence so a Phase-3 port reproduces the
        // counter rather than recomputing it.
        XCTAssertEqual(entryCount, 32,
                       "Gen 1's loop counter changed; the vv{i} anchors and versemenu links depend on it")
    }

    /// Headings are the subtlest axis in the whole conversion, so assert the two
    /// distinct mechanisms are both actually present in the captured bodies
    /// rather than trusting the byte comparison alone.
    ///
    /// * Non-canonical titles (1,250 of KJV's 1,388) sit in intro-only entry
    ///   slots and reach the body only because Headings is On.
    /// * Canonical Psalm titles (138) are routed to
    ///   EntryAttributes["Heading"]["Preverse"] and are injected by getChapter's
    ///   own glue, not by the markup filter.
    func testCapturedBodiesContainBothHeadingMechanisms() throws {
        let mod = try configuredModule("KJV")

        mod.aquireModuleLock()
        var count: NSInteger = 0
        let gen1 = mod.chapterBodyHTML("Gen 1", applyBookmarkHighlights: false, entryCount: &count)
        let ps3 = mod.chapterBodyHTML("Ps 3", applyBookmarkHighlights: false, entryCount: &count)
        mod.releaseModuleLock()

        // Genesis 1's intro slots carry <title type="main"> and
        // <title type="chapter">CHAPTER 1.</title>, emitted unclassed as
        // <p><b>…</b></p> by osishtmlhref.cpp:439.
        let g = try XCTUnwrap(gen1)
        XCTAssertTrue(g.contains("<p><b>"),
                      "Gen 1 body lost its intro titles — Headings is probably Off")
        XCTAssertTrue(g.uppercased().contains("CHAPTER 1"),
                      "Gen 1 body lost the chapter title specifically")

        // Psalm 3's canonical title is a preverse heading.
        let p = try XCTUnwrap(ps3)
        XCTAssertTrue(p.contains("<p><b>"),
                      "Ps 3 body lost its canonical preverse title")
    }

    // MARK: - Lexicons

    func testCaptureLexiconEntries() throws {
        let cases: [(module: String, keys: [String])] = [
            ("StrongsRealGreek", Self.greekKeys),
            ("StrongsRealHebrew", Self.hebrewKeys),
            ("Robinson", Self.morphKeys),
        ]

        for c in cases {
            guard let dict = try configuredModule(c.module) as? SwordDictionary else {
                XCTFail("\(c.module) is not a SwordDictionary")
                continue
            }
            var lines: [String] = []
            for key in c.keys {
                let entry = dict.entry(forKey: key) ?? "<nil>"
                lines.append("### key=\(key)")
                lines.append(entry)
            }
            try checkFixture("\(c.module)-entries.txt", actual: lines.joined(separator: "\n") + "\n")
        }
    }

    /// Documents a real, user-visible SWORD bug that Phase 3 is expected to FIX,
    /// so the fix is not later mistaken for a regression.
    ///
    /// `SWLD::strongsPad` (swld.cpp:124-167) pads a numeric key to 5 digits, but
    /// when the key carries a leading `G`/`H` it advances past the letter and
    /// pads to *4* digits without re-prepending it — so `"H430"` becomes
    /// `"0430"`, which is not a key. `rawstr4.cpp:234-241` then snaps to a
    /// neighbouring entry and sets no error, silently returning the wrong
    /// definition.
    ///
    /// The app itself is unaffected today because it passes the bare number
    /// (osishtmlhref.cpp:66 strips the prefix), which is the path asserted first.
    func testStrongsPaddingBareNumbersAreCorrectPrefixedAreNot() throws {
        guard let dict = try configuredModule("StrongsRealHebrew") as? SwordDictionary else {
            XCTFail("StrongsRealHebrew is not a SwordDictionary")
            return
        }

        // The path the app actually uses: a bare number pads to 5 digits.
        let bare = dict.entry(forKey: "430")
        XCTAssertNotNil(bare, "bare Strong's number should resolve")
        XCTAssertEqual(dict.entry(forKey: "0430"), bare,
                       "'430' and '0430' must resolve to the same entry (strongsPad zero-fills)")

        // The broken path, recorded as-is. If Phase 3 makes this return nil, that
        // is the intended fix -- update this test and say so.
        let prefixed = dict.entry(forKey: "H430")
        if prefixed == bare {
            XCTFail("unexpected: 'H430' now matches '430'; strongsPad behaviour changed")
        } else {
            let note = """
                strongsPad drops a leading G/H without re-prepending it, so 'H430'
                pads to '0430' (4 digits) and rawstr4 snaps to a neighbour with no
                error set. Phase 3 must return nil on a miss instead.
                  entry(forKey: "430")  -> \(bare?.prefix(60) ?? "<nil>")…
                  entry(forKey: "H430") -> \(prefixed?.prefix(60) ?? "<nil>")…
                """
            try checkFixture("strongsPad-prefixed-key-bug.txt", actual: note + "\n")
        }
    }

    // MARK: - Notes and cross-references

    /// `attributeValueForEntryData:` is the footnote / xref / scriptRef lookup
    /// that PSInfoPopupViewController drives. Capture its output shape for both
    /// the string case (`type=n`) and the array-of-dictionaries case
    /// (`type=scriptRef`).
    func testCaptureFootnoteAndScriptRefAttributes() throws {
        let mod = try configuredModule("KJV")
        var lines: [String] = []

        // Passages verified to carry footnotes in the KJV module (`value` is the
        // swordFootnote number the anchor embedded). Esther 1:19 carries four,
        // which exercises marker numbering beyond the first.
        //
        // All 6,959 of KJV's notes are type="study" with an empty refList -- the
        // module emits no type="crossReference" notes at all -- so the `x` branch
        // of attributeValueForEntryData: (which parses refList into a ListKey) is
        // unreachable for the shipped content and is deliberately not captured.
        for (passage, value) in [("Genesis 4:1", "1"),
                                 ("Genesis 4:10", "1"),
                                 ("Esther 1:19", "1"),
                                 ("Esther 1:19", "4")] {
            // ATTRTYPE_* / SW_OUTPUT_*_KEY come from SwordModule.h via the test
            // bridging header, so the keys cannot drift from the Obj-C side.
            let data: [AnyHashable: Any] = [
                ATTRTYPE_PASSAGE: passage,
                ATTRTYPE_VALUE: value,
                ATTRTYPE_TYPE: "n",
                ATTRTYPE_MODULE: "KJV",
            ]
            let result = mod.attributeValue(forEntryData: data)
            lines.append("### footnote passage=\(passage) value=\(value)")
            lines.append(Self.describe(result))
        }

        try checkFixture("KJV-footnote-attributes.txt", actual: lines.joined(separator: "\n") + "\n")
    }

    /// The `scriptRef` branch returns an array of {OutputRefKey, OutputTextKey}
    /// dictionaries, one per resolved reference — a different shape from the
    /// footnote branch's plain string, and the one the reference popup consumes.
    ///
    /// Note this branch calls `-setChapter:[PSModuleController getCurrentBibleRef]`
    /// to establish the parse context, so its output depends on where the app is
    /// currently sitting. Pin the context first so the fixture is reproducible.
    func testCaptureScriptRefAttributes() throws {
        let mod = try configuredModule("KJV")
        mod.setChapter("Genesis 1")

        var lines: [String] = []
        for ref in ["Gen 1:1", "John 3:16", "Ps 23:1-3", "Rom 8:28"] {
            let data: [AnyHashable: Any] = [
                ATTRTYPE_VALUE: ref,
                ATTRTYPE_TYPE: "scriptRef",
                ATTRTYPE_MODULE: "KJV",
            ]
            let result = mod.attributeValue(forEntryData: data)
            lines.append("### scriptRef value=\(ref)")
            lines.append(Self.describe(result))
        }

        try checkFixture("KJV-scriptref-attributes.txt", actual: lines.joined(separator: "\n") + "\n")
    }

    /// Renders `attributeValue(forEntryData:)`'s heterogeneous return (NSString
    /// for note bodies, NSArray of {OutputRefKey, OutputTextKey} for reference
    /// lists) into a stable, diffable text form.
    private static func describe(_ value: Any?) -> String {
        switch value {
        case nil:
            return "<nil>"
        case let s as String:
            return "string: \(s)"
        case let arr as [Any]:
            var out = ["array(\(arr.count)):"]
            for element in arr {
                if let dict = element as? [AnyHashable: Any] {
                    let ref = dict[SW_OUTPUT_REF_KEY] as? String ?? "<no-ref>"
                    let text = dict[SW_OUTPUT_TEXT_KEY] as? String ?? "<no-text>"
                    out.append("  ref=\(ref)")
                    out.append("  text=\(text)")
                } else {
                    out.append("  \(element)")
                }
            }
            return out.joined(separator: "\n")
        case let dict as [AnyHashable: Any]:
            let ref = dict[SW_OUTPUT_REF_KEY] as? String ?? "<no-ref>"
            let text = dict[SW_OUTPUT_TEXT_KEY] as? String ?? "<no-text>"
            return "dict: ref=\(ref) text=\(text)"
        default:
            return "other: \(String(describing: value))"
        }
    }

    // MARK: - Fold-equivalence guard

    /// `PSFoldForIndex` (Obj-C, index side) and `PSSearchQuery.foldForIndex`
    /// (Swift, query side) are a byte-for-byte duplicated algorithm. Both files
    /// warn about the duplication in prose and neither had an executable guard —
    /// if they drift, queries silently stop matching the rows the index built.
    ///
    /// Fixtures come from the **lexicon** entries rather than KJV verses: the
    /// index's `text_norm` column is built from KJV `stripText()`, which is plain
    /// English and exercises almost none of the Hebrew-points / polytonic-Greek
    /// ranges the fold actually targets.
    func testFoldForIndexAgreesBetweenObjCAndSwift() throws {
        var samples: [String] = [
            "",
            "plain ascii text",
            "MiXeD CaSe",
            // Greek polytonic (U+0300-U+036F after NFD)
            "ἀγάπη", "Θεός", "λόγος", "περιβόλαιον",
            // Hebrew with points + cantillation (U+0591-U+05C7)
            "אֱלֹהִים", "בְּרֵאשִׁית", "יְהוָ֣ה", "חֹשֶׁךְ",
            // Latin diacritics, precomposed and decomposed
            "café", "cafe\u{0301}", "pilchâ'", "zeh'-eek",
            // Non-BMP, to exercise the surrogate-pair branch
            "𝔊𝔯𝔢𝔢𝔨 text", "😀 emoji",
            // Combining marks from the other dropped ranges
            "a\u{20D0}b", "x\u{FE20}y", "q\u{1DC0}r",
        ]

        // Plus real lexicon text, which is where the exotic ranges actually live.
        if let greek = try? configuredModule("StrongsRealGreek") as? SwordDictionary,
           let entry = greek.entry(forKey: "25") {
            samples.append(entry)
        }
        if let hebrew = try? configuredModule("StrongsRealHebrew") as? SwordDictionary,
           let entry = hebrew.entry(forKey: "430") {
            samples.append(entry)
        }

        for sample in samples {
            let objc = PSFoldForIndex(sample)
            let swift = PSSearchQuery.foldForIndex(sample)
            XCTAssertEqual(objc, swift,
                           "fold mismatch for \(sample.debugDescription): Obj-C \(objc.debugDescription) vs Swift \(swift.debugDescription)")
        }
    }

    /// The display-side cleaner is only defined in Obj-C, but Phase 3 has to
    /// reproduce it, so pin its behaviour on the marker forms SWORD emits.
    func testCleanDisplayTextStripsInlineMarkers() {
        XCTAssertEqual(PSSearchCleanDisplayText("And God <H0430> divided <H0996> the light"),
                       "And God divided the light")
        XCTAssertEqual(PSSearchCleanDisplayText("word <TH8799> in <TG5707> place"),
                       "word in place")
        XCTAssertEqual(PSSearchCleanDisplayText("in the field <H7704> , and"),
                       "in the field, and")
        XCTAssertEqual(PSSearchCleanDisplayText("a [] b"), "a b")
        XCTAssertEqual(PSSearchCleanDisplayText(""), "")
    }
}
