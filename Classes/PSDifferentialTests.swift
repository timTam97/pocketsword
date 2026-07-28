//
//  PSDifferentialTests.swift
//  PocketSwordTests
//
//  The acceptance criterion for the whole SWORD-removal project: render the same
//  content BOTH ways in the same process — the pure-Swift reader over the baked
//  store, and the live SWORD engine — and assert they agree. Phase 3, step 8.
//
//  This is what the committed fixtures cannot be: they cover 11 of 1,189 chapters,
//  and Phase 5 deletes the engine, so this is the last chance to compare against it
//  at scale. Where the two disagree, SWORD wins.
//
//  === Two tiers (plan decision 2) ===
//
//  * FAST — runs on every `test` invocation. All 15,824 dictionary entries keyed
//    as the UI keys them, all 6,959 notes, and a strided chapter sample across
//    both modules at both option endpoints.
//  * EXHAUSTIVE — set `PSDIFF_EXHAUSTIVE=1`. All 1,189 KJV chapters x both option
//    sets, all 1,189 MHCC chapters, and all 31,102 search-source rows. Runs for
//    minutes, and MUST be run before the feature flag is flipped default-on.
//
//  Both tiers print their actual coverage. A silently-sampled gate reads as
//  "covered everything" when it did not, so the numbers are in the output.
//
//  === Pinning ===
//
//  `-[SwordModule setPreferences]` pushes ELEVEN global options
//  (SwordModule.mm:188-213), and `-chapterBodyHTML:` additionally reads two prefs
//  of its own off NSUserDefaults (vpl, headings). Both sides must describe the
//  same configuration or the equality assertion is noise rather than a gate — an
//  unpinned option drifts and the failure looks like a reader bug. So each
//  configuration below pins all eleven options AND both prefs.
//

import XCTest
@testable import PocketSword

final class PSDifferentialTests: XCTestCase {

    // MARK: - Configuration

    private static var isExhaustive: Bool {
        ProcessInfo.processInfo.environment["PSDIFF_EXHAUSTIVE"] != nil
    }

    /// One end of the option space, as both a SWORD global-option list and the
    /// reader's own option set. The two representations are declared together so
    /// they cannot drift apart.
    private struct Config {
        let name: String
        /// All eleven options `setPreferences` pushes, plus Lemmas (which it does
        /// not push — it sits at SWOptionFilter's constructor default of Off, and
        /// is pinned here so the comparison does not depend on that).
        let swordOptions: [(String, String)]
        let readerOptions: PSChapterExpander.Options
        let versePerLine: Bool
        let headings: Bool

        static let allOn = Config(
            name: "all-on",
            swordOptions: [
                ("Strong's Numbers", "On"), ("Morphological Tags", "On"),
                ("Footnotes", "On"), ("Cross-references", "On"),
                ("Words of Christ in Red", "On"), ("Headings", "On"),
                ("Textual Variants", "Primary Reading"), ("Lemmas", "Off"),
                ("Glosses", "Off"), ("Greek Accents", "Off"),
                ("Hebrew Vowel Points", "Off"), ("Hebrew Cantillation", "Off"),
            ],
            readerOptions: .allOn, versePerLine: false, headings: true)

        static let allOff = Config(
            name: "all-off",
            swordOptions: [
                ("Strong's Numbers", "Off"), ("Morphological Tags", "Off"),
                ("Footnotes", "Off"), ("Cross-references", "Off"),
                ("Words of Christ in Red", "Off"), ("Headings", "Off"),
                ("Textual Variants", "Primary Reading"), ("Lemmas", "Off"),
                ("Glosses", "Off"), ("Greek Accents", "Off"),
                ("Hebrew Vowel Points", "Off"), ("Hebrew Cantillation", "Off"),
            ],
            readerOptions: .allOff, versePerLine: false, headings: false)
    }

    // MARK: - Pref save / restore

    private var savedPrefs: [String: Any?] = [:]

    override func tearDown() {
        let defaults = UserDefaults.standard
        for (key, value) in savedPrefs {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        savedPrefs = [:]
        super.tearDown()
    }

    private func pin(_ pref: String, module: String, to value: Bool) {
        let key = UserDefaults.standard.psModuleKey(pref, module)
        if savedPrefs[key] == nil { savedPrefs[key] = UserDefaults.standard.object(forKey: key) }
        UserDefaults.standard.set(value, forKey: key)
    }

    /// Put BOTH sides into `config`. The SWORD options go through the manager; the
    /// two accumulator-loop prefs go through NSUserDefaults, which is where
    /// -chapterBodyHTML: reads them.
    private func apply(_ config: Config, module: String) throws {
        guard let manager = SwordManager.default() else { throw XCTSkip("no SwordManager") }
        for (option, value) in config.swordOptions {
            manager.setGlobalOption(option, value: value)
        }
        pin(Defaults.vplPreference, module: module, to: config.versePerLine)
        pin(Defaults.headingsPreference, module: module, to: config.headings)
    }

    // MARK: - Helpers

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

    private func reader() throws -> PSContentReader {
        let reader = PSContentReader.shared
        guard reader.isAvailable else { throw XCTSkip("content reader unavailable") }
        return reader
    }

    private func resolver() throws -> PSBookOSISResolver {
        guard let resolver = PSBookOSISResolver.shared else { throw XCTSkip("no resolver") }
        return resolver
    }

    /// Report the first divergence with context, and the ref that produced it.
    private func assertEqual(_ actual: String, _ expected: String, _ label: String) -> Bool {
        guard actual != expected else { return true }
        let a = Array(actual), e = Array(expected)
        var i = 0
        while i < min(a.count, e.count), a[i] == e[i] { i += 1 }
        let lo = max(0, i - 60)
        XCTFail("""
            \(label): reader and SWORD disagree.
              first difference at character \(i) (SWORD \(e.count) chars, reader \(a.count))
              SWORD:  …\(String(e[lo..<min(e.count, i + 60)]))…
              reader: …\(String(a[lo..<min(a.count, i + 60)]))…
            """)
        return false
    }

    // MARK: - Chapters

    /// Compare a set of chapter refs both ways. Returns the number compared.
    @discardableResult
    private func compareChapters(module name: String,
                                 kind: PSChapterAssembler.ModuleKind,
                                 refs: [String],
                                 config: Config) throws -> Int {
        let mod = try module(name)
        let reader = try reader()
        try apply(config, module: name)

        var compared = 0
        for ref in refs {
            // SWORD side. applyBookmarkHighlights:NO on both sides — the highlight
            // path is pinned byte-exactly by the step-2 fixture, and a user's
            // bookmarks are not reproducible here.
            mod.aquireModuleLock()
            var entryCount: NSInteger = 0
            let swordBody = mod.chapterBodyHTML(ref, applyBookmarkHighlights: false, entryCount: &entryCount)
            mod.releaseModuleLock()

            // Reader side.
            let rendered = reader.chapterBody(module: name, ref: ref, kind: kind,
                                              applyBookmarkHighlights: false,
                                              options: config.readerOptions)

            guard let swordBody, let rendered else {
                XCTFail("\(name) \(ref) [\(config.name)]: sword=\(swordBody == nil ? "nil" : "ok") reader=\(rendered == nil ? "nil" : "ok")")
                continue
            }
            if !assertEqual(rendered.body, swordBody, "\(name) \(ref) [\(config.name)]") { return compared }
            XCTAssertEqual(rendered.entryCount, entryCount,
                           "\(name) \(ref) [\(config.name)]: loop counter differs")
            compared += 1
        }
        return compared
    }

    /// Every chapter ref of a module, as the app would express it.
    private func allRefs(module name: String) throws -> [String] {
        let resolver = try resolver()
        var refs: [String] = []
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                refs.append("\(book.name) \(chapter)")
            }
        }
        return refs
    }

    /// A fixed stride across the whole Bible, plus the fixture chapters. Fixed so
    /// the fast tier is deterministic — a randomly-sampled gate that passes today
    /// and fails tomorrow is worse than one with known coverage.
    private func sampledRefs(module name: String, stride strideBy: Int) throws -> [String] {
        let all = try allRefs(module: name)
        var refs = ["Genesis 1", "Psalms 3", "Psalms 23", "Psalms 119",
                    "Matthew 1", "John 3", "Genesis 4", "Revelation 22"]
        for (i, ref) in all.enumerated() where i % strideBy == 0 {
            if !refs.contains(ref) { refs.append(ref) }
        }
        return refs
    }

    // MARK: - Fast tier

    func testChaptersAgreeOnASampleAtBothEndpoints() throws {
        // stride 53 over 1,189 chapters -> ~23 per module per config, plus the 8
        // fixture chapters. Prime, so the sample is not aligned to book boundaries.
        var total = 0
        for config in [Config.allOn, Config.allOff] {
            total += try compareChapters(module: "KJV", kind: .bible,
                                         refs: try sampledRefs(module: "KJV", stride: 53),
                                         config: config)
            total += try compareChapters(module: "MHCC", kind: .commentary,
                                         refs: try sampledRefs(module: "MHCC", stride: 53),
                                         config: config)
        }
        print("[differential/fast] chapters compared: \(total)")
        XCTAssertGreaterThan(total, 100, "the sample collapsed — coverage would be misleading")
    }

    /// The one key where the reader is deliberately better than the engine, and so
    /// the one expected difference in the whole differential gate.
    ///
    /// `StrongsRealHebrew` has TWO on-disk entries each for `02200` and `06401`, and
    /// for `06401` the second is a 21-byte `</dictionary>` stub. The converter takes
    /// the FIRST occurrence and reports the collision at bake time (see
    /// tools/swordbake/README.md), so the reader returns the real definition; SWORD's
    /// own key iteration lands on the stub, so `-entryForKey:@"06401"` answers
    /// `</dictionary>`.
    ///
    /// Two consequences, both asserted below rather than tolerated:
    ///  * `-allKeys` lists 15,826 keys, not 15,824, because both duplicated keys
    ///    appear twice in it. `dict_keys` holds the deduped 15,824.
    ///  * the `06401` comparison is checked POSITIVELY — the engine must still
    ///    return the stub and the reader must still return the real entry — so if
    ///    either side changes, this fails instead of quietly widening.
    private static let knownEngineStubKey = (module: "StrongsRealHebrew", key: "06401")
    /// The keys `-allKeys` lists twice (they are duplicated on disk).
    private static let duplicatedOnDiskKeys: Set<String> = ["02200", "06401"]

    /// All 15,824 lexicon entries, keyed the way the UI keys them.
    func testAllDictionaryEntriesAgree() throws {
        let reader = try reader()
        var compared = 0, allowed = 0
        for name in ["StrongsRealGreek", "StrongsRealHebrew", "Robinson"] {
            guard let dict = try module(name) as? SwordDictionary else {
                XCTFail("\(name) is not a SwordDictionary")
                continue
            }
            // -allKeys is the key set the Dictionary tab can produce. As of
            // Phase 4 step 9 that is the module's TRUE casing: the
            // -capitalizedString that -readKeys used to apply is gone, on both this
            // side and the reader's. The engine's own lookup is case-insensitive for
            // a module without CaseSensitiveKeys, so it resolves either form; the
            // point of comparing on this set is that it is exactly what the UI can
            // ask for.
            //
            // NOTE this depends on the on-disk key cache having been rebuilt — the
            // app's DefaultsDictKeyCaseFixed migration does that, and the test host
            // runs it at launch. A stale cache would make `keys` the old mangled set,
            // which still resolves on both sides (COLLATE NOCASE plus the engine's
            // own uppercasing), so this test would still pass; the true-casing
            // assertion lives in
            // PSContentStoreTests.testDictionaryKeysAreReturnedInTrueCasing.
            let keys = (dict.allKeys() as? [String]) ?? []
            XCTAssertFalse(keys.isEmpty, "\(name) produced no keys")
            for key in keys {
                let swordEntry = dict.entry(forKey: key)
                let readerEntry = reader.dictionaryEntry(module: name, key: key)

                if name == Self.knownEngineStubKey.module, key == Self.knownEngineStubKey.key {
                    // Assert the difference is EXACTLY the one documented, not just
                    // that these two keys are allowed to differ somehow.
                    XCTAssertEqual(swordEntry, "</dictionary>",
                                   "the engine no longer returns the duplicate-key stub for \(key) — re-check the allowlist")
                    XCTAssertTrue(readerEntry?.contains("<b>6401</b>") == true,
                                  "the reader should return the real 06401 definition, got: \(readerEntry?.prefix(80) ?? "<nil>")")
                    allowed += 1
                    continue
                }

                if swordEntry != readerEntry {
                    XCTFail("""
                        \(name) key=\(key): reader and SWORD disagree.
                          SWORD:  \(swordEntry?.prefix(120) ?? "<nil>")
                          reader: \(readerEntry?.prefix(120) ?? "<nil>")
                        """)
                    return
                }
                compared += 1
            }
        }
        print("[differential/fast] dictionary entries compared: \(compared) (+\(allowed) known engine-bug allowance)")
        // 15,826 = the 15,824 distinct keys the store holds, plus the two keys
        // -allKeys lists twice because they are duplicated on disk. `allowed` is 2
        // for the same reason: 06401 is visited twice.
        XCTAssertEqual(compared + allowed, 15826, "the lexicon key set changed size")
        XCTAssertEqual(allowed, 2, "06401 should be visited exactly twice (it is duplicated on disk)")
    }

    /// All 6,959 notes, through the `n` branch.
    func testAllNotesAgree() throws {
        let mod = try module("KJV")
        let reader = try reader()
        try apply(.allOn, module: "KJV")
        guard let store = PSContentStore.shared else { throw XCTSkip("no store") }

        // The (osis_ref, marker) pairs the store holds — i.e. every note the app
        // can possibly ask for.
        let pairs = store.allNoteKeys(module: "KJV")
        XCTAssertEqual(pairs.count, 6959, "the note set changed size")

        var compared = 0
        for (osisRef, marker) in pairs {
            let data: [AnyHashable: Any] = [
                ATTRTYPE_PASSAGE: osisRef,
                ATTRTYPE_VALUE: marker,
                ATTRTYPE_TYPE: "n",
                ATTRTYPE_MODULE: "KJV",
            ]
            let swordBody = mod.attributeValue(forEntryData: data) as? String
            let readerBody = reader.noteBody(module: "KJV", osisRef: osisRef, marker: marker)
            if swordBody != readerBody {
                XCTFail("""
                    KJV note \(osisRef) #\(marker): reader and SWORD disagree.
                      SWORD:  \(swordBody?.prefix(120) ?? "<nil>")
                      reader: \(readerBody?.prefix(120) ?? "<nil>")
                    """)
                return
            }
            compared += 1
        }
        print("[differential/fast] notes compared: \(compared)")
        XCTAssertEqual(compared, 6959)
    }

    // MARK: - Exhaustive tier (PSDIFF_EXHAUSTIVE=1)

    func testExhaustiveAllKJVChaptersBothEndpoints() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSDIFF_EXHAUSTIVE=1 to run the exhaustive tier")
        var total = 0
        for config in [Config.allOn, Config.allOff] {
            let n = try compareChapters(module: "KJV", kind: .bible,
                                        refs: try allRefs(module: "KJV"), config: config)
            print("[differential/exhaustive] KJV \(config.name): \(n) chapters")
            total += n
        }
        print("[differential/exhaustive] KJV total: \(total) (expected 2378)")
        XCTAssertEqual(total, 2378, "1,189 chapters x 2 configurations")
    }

    func testExhaustiveAllMHCCChapters() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSDIFF_EXHAUSTIVE=1 to run the exhaustive tier")
        var total = 0
        for config in [Config.allOn, Config.allOff] {
            let n = try compareChapters(module: "MHCC", kind: .commentary,
                                        refs: try allRefs(module: "MHCC"), config: config)
            print("[differential/exhaustive] MHCC \(config.name): \(n) chapters")
            total += n
        }
        print("[differential/exhaustive] MHCC total: \(total) (expected 2378)")
        XCTAssertEqual(total, 2378)
    }

    /// All 31,102 search-source rows: the store's plain text must equal what
    /// stripText() produces under the same configuration. This is the same claim
    /// PSSearchIndexParityTests makes through the index; here it is made directly,
    /// row by row, so a failure names the verse rather than a rowid.
    func testExhaustiveAllSearchSourceRows() throws {
        try XCTSkipUnless(Self.isExhaustive, "set PSDIFF_EXHAUSTIVE=1 to run the exhaustive tier")
        let mod = try module("KJV")
        guard let store = PSContentStore.shared else { throw XCTSkip("no store") }
        guard let manager = SwordManager.default() else { throw XCTSkip("no SwordManager") }

        // stripText() is what the store captured, so pin the four options that
        // change it — see the converter's comment and PSSearchIndexParityTests.
        for option in ["Strong's Numbers", "Morphological Tags", "Footnotes", "Cross-references"] {
            manager.setGlobalOption(option, value: "Off")
        }

        let cursor = store.verseCursor(module: "KJV")
        var compared = 0
        while let row = cursor.next() {
            mod.aquireModuleLock()
            mod.setVerseKeyText(row.osisRef)
            let swordPlain = PSSearchCleanDisplayText(mod.strippedText() ?? "")
            mod.releaseModuleLock()

            let storePlain = PSSearchCleanDisplayText(row.textPlain)
            if swordPlain != storePlain {
                XCTFail("""
                    \(row.osisRef): search source text differs.
                      SWORD: \(swordPlain)
                      store: \(storePlain)
                    """)
                return
            }
            compared += 1
        }
        XCTAssertFalse(cursor.failed, "the store cursor failed mid-walk")
        print("[differential/exhaustive] search-source rows compared: \(compared) (expected 31102)")
        XCTAssertEqual(compared, 31102)
    }
}
