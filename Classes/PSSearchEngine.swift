//
//  PSSearchEngine.swift
//  PocketSword
//
//  SQLite FTS5-backed search engine for Bible/commentary modules. One engine
//  instance per module, keyed by module name; the underlying sqlite3 handle is
//  shared across threads (SQLITE_OPEN_FULLMUTEX).
//
//  **Ported from PSSearchEngine.{h,mm} by SWORD_REMOVAL_PLAN.md Phase 5 step 8**,
//  which is the commit that makes the app target pure Swift: this was the last
//  Objective-C(++) translation unit under `Classes/`. The port is a translation,
//  not a redesign — step 7 had already stripped the engine's SWORD half (the
//  VerseKey walk, `stripText()`, `PSLemmasForCurrentVerse` /
//  `PSWordMapForCurrentVerse`), so what arrived here was already SQLite-only and
//  already driven by `PSContentStore`.
//
//  Five things here are load-bearing and a plausible-looking "simplification"
//  breaks each of them silently rather than loudly:
//
//   1. **`SQLITE_TRANSIENT` on every `sqlite3_bind_text`.** Bridging a Swift
//      `String` to `const char *` yields a buffer valid only for the duration of
//      the call, so the default `SQLITE_STATIC` ("the pointer stays valid") leaves
//      SQLite holding a dangling pointer by the time `sqlite3_step` runs. The
//      symptom is not a crash — every query silently matches nothing. Same hazard
//      for the SQL text handed to `prepare_v2` / `exec`, which is why both go
//      through `withCString`.
//   2. **`SQLITE_OPEN_FULLMUTEX` + `sqlite3_busy_timeout(2000)`, and NO serial
//      queue.** `PSContentStore` funnels everything through a serial queue; this
//      class deliberately does not. A ~30-second index build runs on one global
//      queue while queries run on another, and FULLMUTEX serialises per *call*
//      rather than per transaction — a serial queue would serialise the whole
//      build against every keystroke. (In practice the build is a modal sheet with
//      `isModalInPresentation = true`, so the user cannot query during it, but
//      matching the shipped concurrency is the zero-risk choice.)
//   3. **The FTS5 schema, its seven columns and their order are unchanged**, as is
//      `ORDER BY rowid` — see `runQuery` for why that is not `ORDER BY ordinal`.
//   4. **`PSSearchQuery.cleanDisplayText` is applied BEFORE the emptiness test**
//      in the build loop, so it decides which rows exist at all, not merely how
//      they read.
//   5. **`dropIndex` must NOT remove the enclosing directory.** As of step 6 every
//      module's index lives at `<Caches>/search/<module>.db`, so KJV and MHCC SHARE
//      that directory — removing it on one module's drop would delete the other's
//      index, or leave an engine holding it open writing to an unlinked file. It
//      used to remove the directory, safely, back when the directory held exactly
//      one module's `fts.db`.
//
//  Two things the Obj-C version carried that are deliberately NOT reproduced:
//
//   * **`PSFoldForIndex` is gone, not ported.** `PSSearchQuery.foldForIndex` was a
//     byte-for-byte duplicate of it — the query half and the index half of one
//     algorithm, kept in sync only by a test asserting they agreed. There is one
//     copy now, and the duplication that both files warned about ends here.
//   * **The `PSSearchEngineErrorDomain` + negative-sentinel-code contract.** No
//     caller ever read it: the build's only caller catches the error generically and
//     reports cancellation from its own cancellation flag, not from a code. (That
//     caller was `PSSearchIndexBuilder`, a modal progress sheet; it is now
//     `SearchIndexCoordinator`, whose state machine drives `SearchView`'s inline
//     progress. Same treatment of the error.) It is replaced by a plain Swift error
//     enum whose cases are descriptive rather than numbered. `PSSearchHighlightOpen` / `PSSearchHighlightClose` are gone
//     for the same reason — they were the FTS5 `snippet()` delimiters, and this
//     engine returns the full `text_plain` and lets the UI highlight (see
//     `runQuery`), so nothing had referenced them since that decision.
//

import Foundation
import SQLite3

/// Reported every few hundred rows during a build, on the **calling** thread.
/// Set `cancel = true` to abort cleanly; the partial DB is then dropped.
typealias PSSearchProgressBlock = (_ fraction: Float, _ cancel: inout Bool) -> Void

enum PSSearchEngineError: LocalizedError {
    case cannotOpenDatabase(String)
    case sqlite(String)
    case noContentStore
    case noRowsForModule(String)
    case contentStoreReadFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cannotOpenDatabase(let detail): return "cannot open the search index: \(detail)"
        case .sqlite(let detail):             return detail
        case .noContentStore:                 return "no content store"
        case .noRowsForModule(let module):    return "content store has no rows for \(module)"
        case .contentStoreReadFailed:         return "content store read failed mid-build"
        case .cancelled:                      return "Index build cancelled"
        }
    }
}

final class PSSearchEngine {

    /// Bumped when the on-disk schema changes in any incompatible way. An index
    /// built with a different version is treated as stale and rebuilt.
    ///
    /// Bumped 4 -> 5 by Phase 5 step 6, which MOVED the index from
    /// `<AbsoluteDataPath>/search/fts.db` to `<Caches>/search/<module>.db`. The bump
    /// is what forces the one-time rebuild for an upgrading user: `indexIsFresh`
    /// compares the stored `schema_version`, so an index at the old path is never
    /// even looked for and a freshly-created one at the new path is stale until
    /// built. No migration — moving the file would buy nothing over a rebuild the
    /// existing prompt already handles, and the old tree is swept by step 9's
    /// `DefaultsSwordRetired` one-shot.
    static let schemaVersion = 5

    private let moduleName: String
    private let dbDirectory: String
    private let dbFilePath: String
    private var db: OpaquePointer?

    /// SQLITE_TRANSIENT. See point 1 in the file header.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Instance cache

    /// Keyed by NAME. It always was, in effect — the pre-step-6 `+engineForModule:`
    /// used `mod.name` as the cache key — but the engine no longer holds a module at
    /// all, so there is nothing to re-attach on a cache hit.
    ///
    /// A dictionary behind a lock, where the Obj-C original used a strong-to-strong
    /// `NSMapTable` under `@synchronized`. Equivalent: entries are never evicted
    /// either way.
    private static let cacheLock = NSLock()
    private static var cache: [String: PSSearchEngine] = [:]

    /// The cached engine for the named module.
    ///
    /// Spelled as a factory rather than an initialiser because it returns a shared
    /// instance. (The Obj-C `+engineForModuleName:` was imported into Swift as
    /// `init(forModuleName:)` by the factory-method rule, which read like it made a
    /// new one each time and did not.)
    static func engine(forModuleName name: String) -> PSSearchEngine {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let existing = cache[name] { return existing }
        let engine = PSSearchEngine(moduleName: name)
        cache[name] = engine
        return engine
    }

    // There is deliberately no `invalidate(forModuleName:)`.
    //
    // The Obj-C original had one — it closed the handle and dropped the cache entry —
    // and its only caller was the KJV re-seed path's `-deleteSearchIndex`, which went
    // with the seeding in Phase 5 step 9. It is not ported for the same reason the
    // `PSSearchEngineErrorDomain` contract was not: nothing read it.
    //
    // Nothing is lost by its absence, which is the part worth stating. `dropIndex()`
    // already closes the handle before unlinking the file, and a cached engine whose
    // file has been dropped is not stale — the next `runQuery` / `indexIsFresh`
    // reopens on demand, and `indexIsFresh` returns false while the file is missing.
    // So the cache never hands back a handle to a deleted index.
    //
    // If a future caller does need to evict, note the ordering the original had:
    // close the handle FIRST, then remove the entry, or the handle leaks with the
    // last reference.

    // MARK: - Init / paths

    /// A module NAME is all the engine needs: the path is
    /// `<Caches>/search/<name>.db` and the version comes from `content_meta`.
    private init(moduleName: String) {
        self.moduleName = moduleName
        self.dbDirectory = AppPaths.searchIndexDirectory
        self.dbFilePath = AppPaths.searchIndexPath(for: moduleName)
    }

    deinit {
        closeDB()
    }

    /// Absolute path to the FTS5 database file for this module
    /// (`<Caches>/search/<module>.db`).
    var dbPath: String { dbFilePath }

    // MARK: - Database open / close

    private func ensureDirectoryExists() throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: dbDirectory, isDirectory: &isDir), isDir.boolValue { return }
        try fm.createDirectory(atPath: dbDirectory, withIntermediateDirectories: true)
    }

    private func openDB(creatingIfNeeded create: Bool) throws {
        if db != nil { return }

        if create { try ensureDirectoryExists() }

        var flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if create { flags |= SQLITE_OPEN_CREATE }

        var handle: OpaquePointer?
        let rc = dbFilePath.withCString { sqlite3_open_v2($0, &handle, flags, nil) }
        guard rc == SQLITE_OK else {
            let msg = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) }
                ?? "sqlite3_open_v2 failed (\(rc))"
            if let handle { sqlite3_close(handle) }
            throw PSSearchEngineError.cannotOpenDatabase(msg)
        }
        db = handle
        // Busy timeout so concurrent readers don't immediately SQLITE_BUSY.
        sqlite3_busy_timeout(handle, 2000)
    }

    private func closeDB() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    private func lastError() -> String {
        guard let db, let msg = sqlite3_errmsg(db) else { return "?" }
        return String(cString: msg)
    }

    private func execSQL(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sql.withCString { sqlite3_exec(db, $0, nil, nil, &errmsg) }
        guard rc == SQLITE_OK else {
            let msg = errmsg.map { String(cString: $0) } ?? "sqlite3_exec failed (\(rc))"
            if let errmsg { sqlite3_free(errmsg) }
            throw PSSearchEngineError.sqlite(msg)
        }
    }

    /// Best-effort variant for the rollback / teardown paths, which must not mask
    /// the error that got them there.
    private func execSQLIgnoringErrors(_ sql: String) {
        try? execSQL(sql)
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var st: OpaquePointer?
        let rc = sql.withCString { sqlite3_prepare_v2(db, $0, -1, &st, nil) }
        guard rc == SQLITE_OK, let st else {
            throw PSSearchEngineError.sqlite(lastError())
        }
        return st
    }

    private func bind(_ st: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(st, index, value, -1, Self.transient)
    }

    private static func text(_ st: OpaquePointer, _ column: Int32) -> String? {
        guard let c = sqlite3_column_text(st, column) else { return nil }
        return String(cString: c)
    }

    private func createSchemaIfNeeded() throws {
        try execSQL("""
            CREATE TABLE IF NOT EXISTS meta (\
              module_name    TEXT PRIMARY KEY,\
              module_version TEXT,\
              built_at       INTEGER,\
              schema_version INTEGER\
            );
            """)

        // FTS5 virtual table. `reference`, `book_num`, `testament` are UNINDEXED
        // (they're scope/display metadata, not searched as text). `text_plain`
        // is indexed so snippet() can highlight against readable text;
        // `text_norm` holds diacritic-folded text for recall; `lemmas` holds
        // Strong's numbers in both H0xxx and Hxxx forms, space-separated.
        // `word_map` is UNINDEXED per-verse metadata: one line per scripture
        // word, surface form TAB lemma1 lemma2 ..., used at query time to
        // recover which English word(s) a Strong's match lit up.
        try execSQL("""
            CREATE VIRTUAL TABLE IF NOT EXISTS verses USING fts5(\
              reference UNINDEXED,\
              book_osis UNINDEXED,\
              testament UNINDEXED,\
              text_plain,\
              text_norm,\
              lemmas,\
              word_map UNINDEXED,\
              tokenize='unicode61 remove_diacritics 2'\
            );
            """)
    }

    // MARK: - Freshness

    /// True iff the DB file exists and its meta row matches the module's current
    /// `Version` (read from `content_meta`) and our schema version. A false return
    /// means either absent or stale — either way, the caller should offer to
    /// rebuild.
    func indexIsFresh() -> Bool {
        guard FileManager.default.fileExists(atPath: dbFilePath) else { return false }

        do {
            try openDB(creatingIfNeeded: false)
        } catch {
            dlog("PSSearchEngine: cannot open \(dbFilePath): \(error.localizedDescription)")
            return false
        }

        let st: OpaquePointer
        do {
            st = try prepare("SELECT module_version, schema_version FROM meta WHERE module_name = ? LIMIT 1;")
        } catch {
            dlog("PSSearchEngine: prepare meta failed: \(lastError())")
            return false
        }
        defer { sqlite3_finalize(st) }

        // The module's `Version=` conf value, from `content_meta` rather than from a
        // live module. Same string either way — the converter captured it from the
        // same conf entry — so an index built before Phase 5 still compares equal on
        // version. What forces the rebuild is the `schemaVersion` bump, not this.
        let currentVersion = PSContentStore.shared?.moduleVersion(moduleName)
        bind(st, 1, moduleName)

        guard sqlite3_step(st) == SQLITE_ROW else { return false }
        let storedVersion = Self.text(st, 0)
        let storedSchema = Int(sqlite3_column_int(st, 1))
        return storedSchema == Self.schemaVersion && storedVersion == currentVersion
    }

    // MARK: - Build

    /// Builds the index from scratch. Blocks the calling thread; expected to run on
    /// a background queue. On cancel or error the partial DB is dropped.
    func build(progress: PSSearchProgressBlock?) throws {
        // Start fresh: if there's any prior DB, drop it. A half-built index is worse
        // than none.
        dropIndex()

        try openDB(creatingIfNeeded: true)
        try createSchemaIfNeeded()

        // The baked store is the ONLY source (Phase 5 step 7).
        //
        // What used to follow this was a ~145-line SWORD fallback walk: a VerseKey
        // iteration from TOP, `stripText()` per verse, and the
        // `PSLemmasForCurrentVerse` / `PSWordMapForCurrentVerse` entry-attribute
        // readers. It went with the engine. What it produced is not lost —
        // `Tests/Fixtures/search-index-KJV.digest` records all 31,102 of its rows,
        // and `PSSearchIndexParityTests` compares this path against that digest on
        // every run.
        //
        // The `NSUserCancelledError` re-entry guard went with it too: it existed only
        // to stop a user cancellation silently restarting the build against SWORD. A
        // cancellation now simply propagates, like any other failure.
        do {
            try buildFromContentStore(progress: progress)
        } catch {
            // dropIndex so a partial index is never left behind to be treated as fresh.
            dropIndex()
            throw error
        }

        stampMeta()
        if let progress {
            var ignored = false
            progress(1.0, &ignored)
        }
    }

    /// Build the index from the baked content store (Phase 3 step 7 introduced this
    /// path; Phase 5 step 7 made it the only one).
    ///
    /// Everything about the index itself is deliberately unchanged from the SWORD
    /// walk it replaced: the same FTS5 schema, the same seven columns in the same
    /// order, the same cleaning and folding applied at the same points, and —
    /// critically — the SAME emptiness test AFTER cleaning, because that test is
    /// what decides which rows exist at all. Only the source of
    /// `(reference, book_osis, testament, text_plain, lemmas, word_map)` changed: it
    /// comes from `PSContentStore`'s row cursor rather than from `stripText()` +
    /// `getEntryAttributes()`.
    ///
    /// The cursor is used rather than a direct join against `plain_texts` because
    /// that table is chunk-compressed as of schema v2 — the framing is the store's
    /// business, not the index builder's.
    ///
    /// `PSSearchQuery.cleanDisplayText` stays in the path even though `text_plain`
    /// in the store carries ZERO rows with `<H…>` markers (the converter already
    /// applied it), so it is a no-op on this input. Leaving it in means the two
    /// build paths cannot drift on that axis, and costs one regex pass per row.
    private func buildFromContentStore(progress: PSSearchProgressBlock?) throws {
        guard let store = PSContentStore.shared else {
            throw PSSearchEngineError.noContentStore
        }

        let cursor = store.verseCursor(module: moduleName)
        // The real row count, known up front — so the progress fraction is exact
        // rather than divided by an estimate (the old loop's kExpected was 32000
        // against an actual 31,102 for KJV, so it never reached ~97%).
        let total = cursor.count
        guard total > 0 else {
            throw PSSearchEngineError.noRowsForModule(moduleName)
        }

        try execSQL("BEGIN IMMEDIATE;")

        let insertSQL = "INSERT INTO verses (reference, book_osis, testament, text_plain,"
            + " text_norm, lemmas, word_map) VALUES (?, ?, ?, ?, ?, ?, ?);"
        let stmt: OpaquePointer
        do {
            stmt = try prepare(insertSQL)
        } catch {
            execSQLIgnoringErrors("ROLLBACK;")
            throw error
        }

        var cancelled = false
        var failure: Error?
        var count = 0
        // Rows arrive in `ordinal` order, which for KJV is also the order the old
        // loop inserted them in (`verses_plain.ordinal` is strictly increasing and
        // unique across all 31,102 rows) — so `ORDER BY rowid` in `runQuery` keeps
        // giving biblical order.
        while let row = cursor.next() {
            let plain = PSSearchQuery.cleanDisplayText(row.textPlain)
            if !plain.isEmpty {
                let norm = PSSearchQuery.foldForIndex(plain)
                bind(stmt, 1, row.osisRef)
                bind(stmt, 2, row.bookOsis)
                sqlite3_bind_int(stmt, 3, Int32(row.testament))
                bind(stmt, 4, plain)
                bind(stmt, 5, norm)
                bind(stmt, 6, row.lemmas)
                bind(stmt, 7, row.wordMap)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    failure = PSSearchEngineError.sqlite(lastError())
                    sqlite3_reset(stmt)
                    break
                }
                sqlite3_reset(stmt)
            }

            count += 1
            if let progress, count % 500 == 0 {
                let fraction = min(Float(0.99), Float(count) / Float(total))
                var localCancel = false
                progress(fraction, &localCancel)
                if localCancel { cancelled = true; break }
            }
        }
        sqlite3_finalize(stmt)

        // A cursor that stopped because the STORE is broken must not be mistaken for
        // one that reached the end: that would commit a silently-truncated index.
        if failure == nil, !cancelled, cursor.failed {
            failure = PSSearchEngineError.contentStoreReadFailed
        }

        if cancelled || failure != nil {
            execSQLIgnoringErrors("ROLLBACK;")
            throw failure ?? PSSearchEngineError.cancelled
        }
        try execSQL("COMMIT;")
    }

    /// The meta row. `module_version` is nil-safe because the column is TEXT.
    private func stampMeta() {
        let currentVersion = PSContentStore.shared?.moduleVersion(moduleName)
        guard let meta = try? prepare(
            "INSERT OR REPLACE INTO meta (module_name, module_version, built_at, schema_version)"
            + " VALUES (?, ?, ?, ?);") else { return }
        defer { sqlite3_finalize(meta) }
        bind(meta, 1, moduleName)
        if let currentVersion {
            bind(meta, 2, currentVersion)
        } else {
            sqlite3_bind_null(meta, 2)
        }
        sqlite3_bind_int64(meta, 3, sqlite3_int64(Date().timeIntervalSince1970))
        sqlite3_bind_int(meta, 4, Int32(Self.schemaVersion))
        sqlite3_step(meta)
    }

    // MARK: - Drop

    /// Removes the on-disk index. Does NOT remove the enclosing directory: as of
    /// step 6 every module's index shares `<Caches>/search`, so dropping KJV's must
    /// not delete MHCC's.
    func dropIndex() {
        closeDB()
        let fm = FileManager.default
        guard fm.fileExists(atPath: dbFilePath) else { return }
        do {
            try fm.removeItem(atPath: dbFilePath)
        } catch {
            alog("PSSearchEngine: failed to remove \(dbFilePath): \(error)")
        }
        // The enclosing directory is deliberately LEFT IN PLACE (Phase 5 step 6).
        //
        // This used to remove `<AbsoluteDataPath>/search` when it was empty, which
        // was safe because that directory held exactly one module's `fts.db`. The
        // index now lives at `<Caches>/search/<module>.db`, so KJV and MHCC SHARE the
        // directory and removing it on one module's drop would delete the other's
        // index — or, if the other engine had it open, leave it writing to an
        // unlinked file.
        //
        // Not removing it costs an empty directory in Caches, which the OS may purge
        // anyway and `ensureDirectoryExists` recreates on demand.
    }

    // MARK: - Query

    /// Runs a query against an already-built index. Returns an empty array if the
    /// index isn't fresh. The FTS5 expression should be produced by `PSSearchQuery`.
    /// If `strongsTokens` is non-empty, each returned result has its
    /// `strongsHighlightWords` populated with the English surface form(s) in that
    /// verse that map to any of the given Strong's tokens.
    ///
    /// The Obj-C signature ended in a `volatile BOOL *cancelFlag` that both call
    /// sites passed nil for, so it is not reproduced. Nothing regressed by dropping
    /// it: `PSModuleSearchController` runs this on a global queue under a generation
    /// counter and discards a superseded result on the main thread, so a cancel flag
    /// could only have saved CPU on a `LIMIT 1000` query, never correctness.
    func runQuery(_ fts5Expression: String,
                  scope: PSSearchRange,
                  bookName: String?,
                  limit: Int32,
                  strongsTokens: [String]?) -> [PSSearchResult] {
        if fts5Expression.isEmpty { return [] }
        if !indexIsFresh() { return [] }

        do {
            try openDB(creatingIfNeeded: false)
        } catch {
            dlog("PSSearchEngine: runQuery openDB failed: \(error.localizedDescription)")
            return []
        }

        let wantWordMap = (strongsTokens?.isEmpty == false)
        let tokenSet: Set<String> = wantWordMap ? Set(strongsTokens ?? []) : []

        // We return the FULL stored verse text (`text_plain`) and let the UI do its
        // own highlighting. FTS5's `snippet()` truncates to ~64 tokens and drops
        // highlight markers for matches that hit non-visible columns (e.g. Strong's
        // lemmas), so `snippet()` is the wrong tool for this app. For Strong's
        // searches we also pull `word_map` so the caller can learn which English
        // surface word(s) to highlight.
        var sql = wantWordMap
            ? "SELECT reference, text_plain, word_map FROM verses WHERE verses MATCH ?"
            : "SELECT reference, text_plain FROM verses WHERE verses MATCH ?"

        var testamentValue: Int32?
        if scope == .OTRange { testamentValue = 1 }
        else if scope == .NTRange { testamentValue = 2 }
        if testamentValue != nil { sql += " AND testament = ?" }

        var bookOsis: String?
        if scope == .BookRange, let bookName, !bookName.isEmpty {
            // Phase 4: name -> OSIS comes from the baked versification table rather
            // than from a live `sword::VerseKey`. Verified equivalent for all 66
            // books; the deleted shim's whole body was `setText()` +
            // `getOSISBookName()`, and the "localised" in its name was aspirational
            // (`translateBookName:` is identity on every device — there is no `en`
            // locale conf).
            //
            // A nil resolver (bundled table missing) simply leaves the scope filter
            // off, which is the same outcome the shim's `popError()` path produced: an
            // unrecognised book name searches the whole Bible rather than nothing.
            if let osis = PSBookOSISResolver.shared?.book(named: bookName)?.osisName,
               !osis.isEmpty {
                bookOsis = osis
                sql += " AND book_osis = ?"
            }
        }

        // Rows are inserted during build in canonical iteration order (Genesis 1:1
        // upward), so rowid gives us biblical order directly.
        //
        // This stays `rowid` rather than becoming `ORDER BY ordinal` now that the
        // store drives the build, and the equivalence was verified rather than
        // assumed: `verses_plain.ordinal` is strictly increasing and unique across all
        // 31,102 KJV rows, and the cursor walks it in that order — so rowid order IS
        // ordinal order. Switching would also mean adding an `ordinal` column to the
        // FTS table (bumping `schemaVersion` and forcing every user to rebuild) to buy
        // nothing.
        sql += " ORDER BY rowid"
        if limit > 0 { sql += " LIMIT \(limit)" }

        let st: OpaquePointer
        do {
            st = try prepare(sql)
        } catch {
            dlog("PSSearchEngine: prepare query failed: \(lastError()) (sql=\(sql))")
            return []
        }
        defer { sqlite3_finalize(st) }

        var p: Int32 = 1
        bind(st, p, fts5Expression); p += 1
        if let testamentValue { sqlite3_bind_int(st, p, testamentValue); p += 1 }
        if let bookOsis { bind(st, p, bookOsis); p += 1 }

        var results: [PSSearchResult] = []
        while true {
            let rc = sqlite3_step(st)
            if rc == SQLITE_ROW {
                let ref = Self.text(st, 0) ?? ""
                let result = PSSearchResult(reference: ref, fullText: Self.text(st, 1))

                if wantWordMap, let map = Self.text(st, 2), !map.isEmpty {
                    var words: [String] = []
                    var seen = Set<String>()
                    for line in map.components(separatedBy: "\n") {
                        guard let tab = line.range(of: "\t") else { continue }
                        let surface = String(line[line.startIndex..<tab.lowerBound])
                        let lemmaStr = String(line[tab.upperBound...])
                        if surface.isEmpty || lemmaStr.isEmpty { continue }
                        let hit = lemmaStr.components(separatedBy: " ")
                            .contains { !$0.isEmpty && tokenSet.contains($0) }
                        if !hit { continue }
                        if seen.contains(surface) { continue }
                        seen.insert(surface)
                        words.append(surface)
                    }
                    if !words.isEmpty { result.strongsHighlightWords = words }
                }

                results.append(result)
            } else if rc == SQLITE_DONE {
                break
            } else {
                dlog("PSSearchEngine: step returned \(rc): \(lastError())")
                break
            }
        }
        return results
    }
}
