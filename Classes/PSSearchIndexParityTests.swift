//
//  PSSearchIndexParityTests.swift
//  PocketSwordTests
//
//  Proves the FTS index built from the baked content store is the same index the
//  live SWORD walk produced. SWORD_REMOVAL_PLAN.md Phase 3, step 7.
//
//  This is a *differential* test, not a fixture one: it builds the index BOTH
//  ways in the same process and compares. That matters because the failure mode
//  here is silent — a derivation bug does not crash, search results just quietly
//  go missing — and because no committed fixture covers 31,102 rows.
//
//  It runs the real `-buildWithProgress:`, so it takes tens of seconds. It is
//  kept in the default suite anyway: a search index that is subtly wrong is
//  exactly the kind of regression a nightly-only test would let through, and the
//  whole point of Phase 3 is that the two sides agree.
//

import XCTest
import SQLite3
@testable import PocketSword

final class PSSearchIndexParityTests: XCTestCase {

    /// One indexed row, in the columns the index actually stores.
    private struct Row: Equatable {
        let reference: String
        let bookOsis: String
        let testament: Int
        let textPlain: String
        let textNorm: String
        let lemmas: String
        let wordMap: String
    }

    private func waitForModule(_ name: String, timeout: TimeInterval = 90) throws -> SwordModule {
        guard let manager = SwordManager.default() else {
            throw XCTSkip("no SwordManager")
        }
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

    /// Pin the four global options that change what `stripText()` returns.
    ///
    /// This is necessary because **`-buildWithProgress:` pins nothing**: the
    /// engine-side walk renders under whatever global option state was last set,
    /// which in the app is whatever the previous chapter render's `setPreferences`
    /// pushed. So today's index CONTENT already varies with the user's per-module
    /// toggles — with Strong's on it gains `<H0430>` markers (which is why
    /// PSSearchCleanDisplayText exists at all), and with footnotes on the note
    /// bodies leak into the verse text in square brackets.
    ///
    /// The baked store fixes that by construction: it captures `stripText()` with
    /// all four OFF, so the indexed text is the verse and nothing else, the same
    /// on every device. That is a deliberate improvement, not a divergence — but it
    /// does mean "the two builds agree" is only a well-defined claim once the
    /// engine side is pinned to the same configuration. Hence this.
    private func pinStripTextOptions() throws {
        guard let manager = SwordManager.default() else { throw XCTSkip("no SwordManager") }
        for option in ["Strong's Numbers", "Morphological Tags", "Footnotes", "Cross-references"] {
            manager.setGlobalOption(option, value: "Off")
        }
    }

    /// Every row of the built index, in rowid order — which is the order the
    /// search results come back in, so comparing it also compares result ordering.
    private func readAllRows(dbPath: String) throws -> [Row] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw XCTSkip("cannot open the built index at \(dbPath)")
        }
        defer { sqlite3_close(db) }
        var st: OpaquePointer?
        let sql = "SELECT reference, book_osis, testament, text_plain, text_norm, lemmas, word_map"
            + " FROM verses ORDER BY rowid;"
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else {
            throw XCTSkip("cannot read the built index")
        }
        defer { sqlite3_finalize(st) }
        func text(_ c: Int32) -> String {
            guard let p = sqlite3_column_text(st, c) else { return "" }
            return String(cString: p)
        }
        var rows: [Row] = []
        while sqlite3_step(st) == SQLITE_ROW {
            rows.append(Row(reference: text(0), bookOsis: text(1),
                            testament: Int(sqlite3_column_int(st, 2)),
                            textPlain: text(3), textNorm: text(4),
                            lemmas: text(5), wordMap: text(6)))
        }
        return rows
    }

    /// Build the index with the flag in a given state and return every row.
    private func buildAndRead(module: SwordModule, viaReader: Bool) throws -> [Row] {
        let defaults = UserDefaults.standard
        let key = Defaults.swiftContentReaderPreference
        let saved = defaults.object(forKey: key)
        defaults.set(viaReader, forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        // Guard against the test silently measuring the same path twice.
        XCTAssertEqual(PSContentReader.isActive, viaReader,
                       "the flag did not take effect — this comparison would be vacuous")
        // The engine walk reads ambient global options; pin them so both sides
        // describe the same configuration (see pinStripTextOptions).
        try pinStripTextOptions()

        let engine = PSSearchEngine(for: module)
        do {
            try engine.build(progress: nil)
        } catch {
            XCTFail("index build (viaReader: \(viaReader)) failed: \(error.localizedDescription)")
            throw XCTSkip("build failed")
        }
        return try readAllRows(dbPath: engine.dbPath())
    }

    /// The acceptance criterion for step 7: both builds produce identical rows, in
    /// identical order.
    func testStoreBuiltIndexEqualsTheEngineBuiltIndex() throws {
        let kjv = try waitForModule("KJV")

        let fromStore = try buildAndRead(module: kjv, viaReader: true)
        let fromEngine = try buildAndRead(module: kjv, viaReader: false)

        // The count Phase 2 measured against the live engine — asserted on both
        // sides so a shared miscount cannot pass.
        XCTAssertEqual(fromEngine.count, 31102, "the engine walk no longer produces 31,102 rows")
        XCTAssertEqual(fromStore.count, 31102, "the store build no longer produces 31,102 rows")

        guard fromStore.count == fromEngine.count else { return }
        for (i, (a, b)) in zip(fromStore, fromEngine).enumerated() {
            if a != b {
                XCTFail("""
                    row \(i) differs between the two index builds:
                      engine: \(b)
                      store:  \(a)
                    """)
                return  // one report is enough; 31k would be unreadable
            }
        }
        print("[search-parity] \(fromStore.count) rows identical across both build paths")
    }

    /// And the same queries come back with the same results, which is what a user
    /// actually experiences. Run against the store-built index.
    func testQueriesReturnTheSameResultsFromBothIndexes() throws {
        let kjv = try waitForModule("KJV")

        func results(viaReader: Bool) throws -> [String: [String]] {
            let defaults = UserDefaults.standard
            let key = Defaults.swiftContentReaderPreference
            let saved = defaults.object(forKey: key)
            defaults.set(viaReader, forKey: key)
            defer {
                if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            try pinStripTextOptions()
            let engine = PSSearchEngine(for: kjv)
            do {
                try engine.build(progress: nil)
            } catch {
                throw XCTSkip("build failed: \(error.localizedDescription)")
            }
            var out: [String: [String]] = [:]
            // A spread of shapes: a common word, a phrase, a rare word, a
            // Strong's-bearing query, and one that should match nothing.
            for query in ["\"lovingkindness\"", "\"in the beginning\"", "\"Nicodemus\"",
                          "\"shepherd\"", "\"zzzzznotaword\""] {
                let hits = engine.runQuery(query, scope: .AllRange, bookName: nil,
                                           limit: 50, strongsTokens: nil, cancelFlag: nil)
                out[query] = hits.map { $0.reference ?? "" }
            }
            return out
        }

        let store = try results(viaReader: true)
        let engine = try results(viaReader: false)
        XCTAssertEqual(store, engine, "queries disagree between the two index builds")
        // Not vacuous: the corpus queries must actually hit.
        XCTAssertFalse(store["\"in the beginning\""]?.isEmpty ?? true, "phrase query found nothing")
        XCTAssertEqual(store["\"zzzzznotaword\""], [], "the negative control matched something")
        print("[search-parity] queries agree: \(store.mapValues { $0.count })")
    }
}
