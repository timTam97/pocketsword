//
//  PSContentStore.swift
//  PocketSword
//
//  Read-only access to the baked content store (Resources/PSContent.sqlite),
//  the pure-Swift replacement for the SWORD engine's data access. Phase 3 of
//  SWORD_REMOVAL_PLAN.md.
//
//  This layer knows about SQLite and chunk framing and nothing else: no HTML, no
//  option gating, no assembly. Callers see rows.
//
//  Schema v2 (tools/swordbake/main.mm is the writer, and the two must be changed
//  together):
//
//    chapters(module, book_osis, chapter, ordinal, entry_count, raw_size,
//             blob_kind, blob)      -- blob = zlib(records joined by \0)
//    bodies(module, id, blob)       -- for blob_kind='bodyref' (MHCC)
//    headings(module, osis_ref, bucket, seq, canonical, html)
//    notes_chunks / notes_index
//    dict_chunks  / dict_keys       -- key column is COLLATE NOCASE
//    plain_texts_chunks             -- ids dense, so row n is at chunk n/256 slot n%256
//    verses_plain(module, ordinal, osis_ref, book_osis, testament, text_id)
//
//  Chunk framing: inflate the blob, split rows on \x1E, fields on \x1F. Both
//  `row_count` and `raw_size` are stored per chunk and are CHECKED here rather
//  than trusted — the converter proves them at bake time by re-inflating every
//  chunk, and this is the reader-side half of the same assertion.
//
//  DECOMPRESSION USES zlib, NOT Compression.framework. The blobs are
//  zlib-with-header (`78 da`, from compress2 at level 9), `raw_size` gives the
//  exact output length, and the iOS SDK ships a `zlib` Clang module
//  (usr/include/zlib.modulemap), so `uncompress()` is directly callable.
//  Compression.framework's COMPRESSION_ZLIB is *raw* deflate and would need the
//  2-byte header stripped and the Adler-32 trailer ignored.
//
//  FAILURE POLICY: every method that can fail returns nil and reports through
//  `PSContentStore.fail(_:)`. See PSContentReader.swift's header for the policy
//  and for the list of conditions Phase 5 has to convert into hard failures once
//  there is no SWORD to fall back to.
//

import Foundation
import SQLite3
import zlib

/// One row of `plain_texts` joined with its `verses_plain` skeleton — the FTS
/// build source. `@objc` and NSString-only so `PSSearchEngine.mm` can consume it
/// across the bridge (it already imports `PocketSword-Swift.h`), following
/// `SwordModuleTextEntry` as the precedent for a DTO that crosses the boundary.
@objc(PSContentVerseRow)
final class PSContentVerseRow: NSObject {
    @objc let ordinal: Int
    @objc let osisRef: String
    @objc let bookOsis: String
    @objc let testament: Int
    @objc let textPlain: String
    @objc let lemmas: String
    @objc let wordMap: String

    init(ordinal: Int, osisRef: String, bookOsis: String, testament: Int,
         textPlain: String, lemmas: String, wordMap: String) {
        self.ordinal = ordinal
        self.osisRef = osisRef
        self.bookOsis = bookOsis
        self.testament = testament
        self.textPlain = textPlain
        self.lemmas = lemmas
        self.wordMap = wordMap
        super.init()
    }
}

/// One record slot of a chapter, in the order `-[SwordModule chapterBodyHTML:]`'s
/// loop visits them: verse 0 (the intro slot) upward, **empties preserved**. The
/// loop counter is not a verse number, so dropping an empty slot would shift
/// every `vv{i}` anchor after it.
struct PSChapterRecords {
    let entryCount: Int
    /// Tokenised entry bodies. An empty string is a slot the loop skips.
    let records: [String]
}

/// A preverse/interverse heading, as `EntryAttributes["Heading"]` held it.
struct PSHeading {
    let verse: Int
    let bucket: String
    let seq: Int
    let canonical: Bool
    /// Tokenised; expand with `PSChapterExpander`.
    let html: String
}

/// A footnote / cross-reference body.
struct PSNote {
    let type: String
    /// Tokenised.
    let body: String
    let refList: String
}

@objc(PSContentStore)
final class PSContentStore: NSObject {

    // MARK: - Schema expectations

    static let expectedSchemaVersion = 2
    static let expectedTokenGrammar = "v2"

    /// Rows per chunk, per table. Read back out of `content_meta` at open time
    /// rather than hardcoded here, so a converter change cannot silently skew the
    /// reader's arithmetic — a mismatch would address the wrong slot and return
    /// *plausible but wrong* text, which is the worst failure mode available.
    private var chunkRowsPlain = 256
    private var chunkRowsDict = 64
    private var chunkRowsNotes = 256

    // MARK: - Failure reporting

    /// Loud in debug, logged in release, and always nil-returning at the call
    /// site. A blank chapter must never be the user-visible outcome of a reader
    /// bug: while the feature flag exists the caller falls back to SWORD.
    static func fail(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
        alog("PSContentStore: \(message)")
        assertionFailure("PSContentStore: \(message)", file: file, line: line)
    }

    // MARK: - Connection

    private var db: OpaquePointer?
    /// SQLite handles and the prepared-statement cache are not thread-safe for
    /// concurrent use, and the search index build runs off the main thread while
    /// the reader serves the UI. Everything funnels through here.
    private let queue = DispatchQueue(label: "org.timsams.PocketSword.contentstore")
    private var statements: [String: OpaquePointer] = [:]

    /// The shared instance over the bundled store. `nil` if the store is missing
    /// or fails validation — callers fall back to SWORD.
    @objc(sharedStore)
    static let shared: PSContentStore? = {
        guard let url = Bundle.main.url(forResource: "PSContent", withExtension: "sqlite") else {
            PSContentStore.fail("PSContent.sqlite is not in the app bundle")
            return nil
        }
        return PSContentStore(path: url.path)
    }()

    /// Designated init. Internal rather than private so tests can point it at a
    /// deliberately-broken copy (missing file, wrong schemaVersion, truncated
    /// chunk) and assert the failure seam.
    init?(path: String) {
        super.init()
        var handle: OpaquePointer?
        // SQLITE_OPEN_READONLY: the bundle is not writable anyway, and it also
        // stops SQLite trying to create a -wal/-journal sidecar next to it.
        let rc = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let handle = handle else {
            PSContentStore.fail("cannot open \(path): \(rc)")
            if handle != nil { sqlite3_close(handle) }
            return nil
        }
        db = handle
        guard validateMeta() else {
            close()
            return nil
        }
    }

    deinit {
        // No queue hop: deinit means nothing else holds a reference.
        for (_, st) in statements { sqlite3_finalize(st) }
        if let db { sqlite3_close(db) }
    }

    private func close() {
        for (_, st) in statements { sqlite3_finalize(st) }
        statements = [:]
        if let db { sqlite3_close(db) }
        db = nil
    }

    private func validateMeta() -> Bool {
        var meta: [String: String] = [:]
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT key, value FROM content_meta;", -1, &st, nil) == SQLITE_OK else {
            PSContentStore.fail("content_meta is unreadable: \(lastError())")
            return false
        }
        while sqlite3_step(st) == SQLITE_ROW {
            guard let k = sqlite3_column_text(st, 0), let v = sqlite3_column_text(st, 1) else { continue }
            meta[String(cString: k)] = String(cString: v)
        }
        sqlite3_finalize(st)

        let version = Int(meta["schemaVersion"] ?? "") ?? -1
        guard version == Self.expectedSchemaVersion else {
            PSContentStore.fail("schemaVersion is \(meta["schemaVersion"] ?? "absent"), expected \(Self.expectedSchemaVersion)")
            return false
        }
        guard meta["tokenGrammar"] == Self.expectedTokenGrammar else {
            PSContentStore.fail("tokenGrammar is \(meta["tokenGrammar"] ?? "absent"), expected \(Self.expectedTokenGrammar)")
            return false
        }
        // Absent chunk-size keys are a v2 store written before they were added;
        // there is no such artifact, so treat it as a mismatch rather than
        // silently defaulting and mis-addressing every chunk.
        guard let plain = Int(meta["chunkRows.plain_texts"] ?? ""),
              let dict = Int(meta["chunkRows.dict"] ?? ""),
              let notes = Int(meta["chunkRows.notes"] ?? ""),
              plain > 0, dict > 0, notes > 0 else {
            PSContentStore.fail("content_meta is missing the chunkRows.* sizes")
            return false
        }
        chunkRowsPlain = plain
        chunkRowsDict = dict
        chunkRowsNotes = notes
        return true
    }

    private func lastError() -> String {
        guard let db, let msg = sqlite3_errmsg(db) else { return "?" }
        return String(cString: msg)
    }

    // MARK: - Statement cache

    /// Prepared statements are cached by SQL text and reset (not finalized) after
    /// use. Callers must already be on `queue`.
    private func statement(_ sql: String) -> OpaquePointer? {
        if let cached = statements[sql] {
            sqlite3_reset(cached)
            sqlite3_clear_bindings(cached)
            return cached
        }
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK, let st else {
            PSContentStore.fail("prepare failed for \(sql): \(lastError())")
            return nil
        }
        statements[sql] = st
        return st
    }

    /// SQLITE_TRANSIENT, not the default SQLITE_STATIC. Bridging a Swift `String`
    /// to a C `const char *` produces a buffer that is only valid for the duration
    /// of the call, so a nil destructor (== SQLITE_STATIC, "the pointer stays
    /// valid") leaves SQLite holding a dangling pointer by the time
    /// `sqlite3_step` runs. The symptom is not a crash: every query silently
    /// matches nothing.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func bind(_ st: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(st, index, value, -1, Self.transient)
    }

    private static func text(_ st: OpaquePointer, _ column: Int32) -> String {
        guard let c = sqlite3_column_text(st, column) else { return "" }
        return String(cString: c)
    }

    // MARK: - Inflate

    /// zlib-inflate a blob whose uncompressed length is known exactly.
    /// `expected` comes from the row's own `raw_size`; a disagreement is a
    /// corrupt store, not something to paper over with a growing buffer.
    private static func inflate(_ data: Data, expected: Int) -> Data? {
        if expected == 0 { return data.isEmpty ? Data() : nil }
        var out = Data(count: expected)
        var outLen = uLongf(expected)
        let rc: Int32 = out.withUnsafeMutableBytes { outBuf in
            data.withUnsafeBytes { inBuf in
                uncompress(outBuf.bindMemory(to: Bytef.self).baseAddress,
                           &outLen,
                           inBuf.bindMemory(to: Bytef.self).baseAddress,
                           uLong(data.count))
            }
        }
        guard rc == Z_OK else {
            fail("zlib uncompress failed: \(rc)")
            return nil
        }
        guard Int(outLen) == expected else {
            fail("inflated \(outLen) bytes, raw_size said \(expected)")
            return nil
        }
        return out
    }

    /// Read one chunk and split it into rows of fields, validating the framing.
    /// Callers must already be on `queue`.
    private func chunkRows(table: String, module: String, chunkID: Int) -> [[String]]? {
        guard let st = statement(
            "SELECT row_count, raw_size, blob FROM \(table) WHERE module=? AND chunk_id=?;") else { return nil }
        bind(st, 1, module)
        sqlite3_bind_int64(st, 2, sqlite3_int64(chunkID))
        guard sqlite3_step(st) == SQLITE_ROW else {
            Self.fail("\(table): no chunk \(chunkID) for \(module)")
            return nil
        }
        let rowCount = Int(sqlite3_column_int(st, 0))
        let rawSize = Int(sqlite3_column_int64(st, 1))
        guard let bytes = sqlite3_column_blob(st, 2) else {
            Self.fail("\(table) chunk \(chunkID): null blob")
            return nil
        }
        let blob = Data(bytes: bytes, count: Int(sqlite3_column_bytes(st, 2)))
        sqlite3_reset(st)

        guard let raw = Self.inflate(blob, expected: rawSize) else { return nil }
        guard let joined = String(data: raw, encoding: .utf8) else {
            Self.fail("\(table) chunk \(chunkID): not UTF-8")
            return nil
        }
        let rows = joined.components(separatedBy: "\u{001E}")
        guard rows.count == rowCount else {
            Self.fail("\(table) chunk \(chunkID): row_count \(rowCount) but blob holds \(rows.count)")
            return nil
        }
        return rows.map { $0.components(separatedBy: "\u{001F}") }
    }

    // MARK: - Chapters

    /// The ordered entry slots of one chapter, or nil if the store has no such
    /// chapter (which the converter does for wholly-empty ones — the caller then
    /// renders the same "empty chapter" message the engine does).
    func chapterRecords(module: String, bookOsis: String, chapter: Int) -> PSChapterRecords? {
        queue.sync {
            guard let st = statement(
                "SELECT entry_count, raw_size, blob_kind, blob FROM chapters"
                + " WHERE module=? AND book_osis=? AND chapter=?;") else { return nil }
            bind(st, 1, module)
            bind(st, 2, bookOsis)
            sqlite3_bind_int(st, 3, Int32(chapter))
            guard sqlite3_step(st) == SQLITE_ROW else { return nil }

            let entryCount = Int(sqlite3_column_int(st, 0))
            let rawSize = Int(sqlite3_column_int64(st, 1))
            let kind = Self.text(st, 2)
            guard let bytes = sqlite3_column_blob(st, 3) else {
                Self.fail("chapters \(module) \(bookOsis) \(chapter): null blob")
                return nil
            }
            let blob = Data(bytes: bytes, count: Int(sqlite3_column_bytes(st, 3)))
            sqlite3_reset(st)

            guard let raw = Self.inflate(blob, expected: rawSize),
                  let joined = String(data: raw, encoding: .utf8) else { return nil }
            var records = joined.components(separatedBy: "\u{0000}")

            if kind == "bodyref" {
                // MHCC: each non-empty record is a decimal body id, and 28,970
                // verse slots dedup to 4,435 bodies. An off-by-one here yields
                // plausible-but-wrong commentary text rather than a crash, so an
                // unresolvable id is a hard failure, not a blank slot.
                guard let bodies = self.bodiesLocked(module: module) else { return nil }
                var resolved: [String] = []
                resolved.reserveCapacity(records.count)
                for record in records {
                    if record.isEmpty {
                        resolved.append("")
                        continue
                    }
                    guard let id = Int(record), let body = bodies[id] else {
                        Self.fail("chapters \(module) \(bookOsis) \(chapter): unresolvable body id '\(record)'")
                        return nil
                    }
                    resolved.append(body)
                }
                records = resolved
            }

            guard records.count == entryCount else {
                Self.fail("chapters \(module) \(bookOsis) \(chapter): entry_count \(entryCount) but \(records.count) records")
                return nil
            }
            return PSChapterRecords(entryCount: entryCount, records: records)
        }
    }

    /// `bodies` for one module, inflated once and kept. MHCC's whole body table is
    /// 4,435 rows / ~2 MB compressed; re-reading it per chapter turn would make
    /// every commentary page-turn a full table scan. Callers must be on `queue`.
    private var bodyCache: [String: [Int: String]] = [:]

    private func bodiesLocked(module: String) -> [Int: String]? {
        if let cached = bodyCache[module] { return cached }
        guard let st = statement("SELECT id, blob FROM bodies WHERE module=?;") else { return nil }
        bind(st, 1, module)
        var out: [Int: String] = [:]
        while sqlite3_step(st) == SQLITE_ROW {
            let id = Int(sqlite3_column_int64(st, 0))
            guard let bytes = sqlite3_column_blob(st, 1) else { continue }
            let blob = Data(bytes: bytes, count: Int(sqlite3_column_bytes(st, 1)))
            // bodies rows carry no raw_size of their own, so this is the one
            // inflate that has to discover its output length. Grow until it fits
            // rather than guessing once.
            guard let body = Self.inflateUnknownLength(blob) else {
                sqlite3_reset(st)
                Self.fail("bodies \(module) id \(id): inflate failed")
                return nil
            }
            out[id] = body
        }
        sqlite3_reset(st)
        bodyCache[module] = out
        return out
    }

    /// Inflate without a stored length. Only `bodies` needs this; every chunk
    /// carries `raw_size`.
    private static func inflateUnknownLength(_ data: Data) -> String? {
        if data.isEmpty { return "" }
        var capacity = max(1024, data.count * 6)
        for _ in 0..<8 {
            var out = Data(count: capacity)
            var outLen = uLongf(capacity)
            let rc: Int32 = out.withUnsafeMutableBytes { outBuf in
                data.withUnsafeBytes { inBuf in
                    uncompress(outBuf.bindMemory(to: Bytef.self).baseAddress,
                               &outLen,
                               inBuf.bindMemory(to: Bytef.self).baseAddress,
                               uLong(data.count))
                }
            }
            if rc == Z_OK {
                return String(data: out.prefix(Int(outLen)), encoding: .utf8)
            }
            guard rc == Z_BUF_ERROR else {
                fail("zlib uncompress failed: \(rc)")
                return nil
            }
            capacity *= 4
        }
        fail("zlib uncompress did not fit after 8 doublings")
        return nil
    }

    /// Preverse/interverse headings for one chapter, keyed by verse.
    ///
    /// The store keys them by the module's own key text ("Psalms 3:1"), which is
    /// the *localised* long name, not the OSIS abbreviation — hence `bookName`
    /// rather than `bookOsis`.
    func headings(module: String, bookName: String, chapter: Int) -> [Int: [PSHeading]] {
        queue.sync {
            guard let st = statement(
                "SELECT osis_ref, bucket, seq, canonical, html FROM headings"
                + " WHERE module=? AND osis_ref LIKE ? ORDER BY seq;") else { return [:] }
            bind(st, 1, module)
            bind(st, 2, "\(bookName) \(chapter):%")
            var out: [Int: [PSHeading]] = [:]
            while sqlite3_step(st) == SQLITE_ROW {
                let ref = Self.text(st, 0)
                // LIKE 'Ps 11:%' would also match 'Ps 11:1' for chapter 11 only,
                // but 'Ps 1:%' must not match 'Ps 1:1' of a *different* chapter —
                // the prefix already pins the chapter, so only the verse tail is
                // parsed here. Re-parse rather than trust: a ref that does not fit
                // the shape is skipped, exactly as crosscheck.py does.
                guard let colon = ref.lastIndex(of: ":"),
                      let verse = Int(ref[ref.index(after: colon)...]) else { continue }
                let heading = PSHeading(verse: verse,
                                        bucket: Self.text(st, 1),
                                        seq: Int(sqlite3_column_int(st, 2)),
                                        canonical: sqlite3_column_int(st, 3) != 0,
                                        html: Self.text(st, 4))
                out[verse, default: []].append(heading)
            }
            sqlite3_reset(st)
            return out
        }
    }

    // MARK: - Notes

    /// A footnote / cross-reference body, or nil when there is none. `osisRef` is
    /// the module's key text ("Psalms 23:2") and `marker` the 1-based note number
    /// the anchor embedded.
    func note(module: String, osisRef: String, marker: String) -> PSNote? {
        queue.sync {
            guard let st = statement(
                "SELECT chunk_id, slot FROM notes_index WHERE module=? AND osis_ref=? AND marker=?;")
            else { return nil }
            bind(st, 1, module)
            bind(st, 2, osisRef)
            bind(st, 3, marker)
            guard sqlite3_step(st) == SQLITE_ROW else { return nil }
            let chunkID = Int(sqlite3_column_int64(st, 0))
            let slot = Int(sqlite3_column_int(st, 1))
            sqlite3_reset(st)

            guard let rows = chunkRows(table: "notes_chunks", module: module, chunkID: chunkID) else { return nil }
            guard slot < rows.count, rows[slot].count == 3 else {
                Self.fail("notes \(module) \(osisRef) #\(marker): slot \(slot) is not a 3-field row")
                return nil
            }
            return PSNote(type: rows[slot][0], body: rows[slot][1], refList: rows[slot][2])
        }
    }

    // MARK: - Lexicons

    /// A lexicon entry, or nil on a miss.
    ///
    /// Matching mirrors the engine, not the schema:
    ///   1. `COLLATE NOCASE` on the key column, because SWORD compares
    ///      uppercase-both-sides for a module without CaseSensitiveKeys
    ///      (rawstr.cpp:188) and the UI hands back `capitalizedString`.
    ///   2. for an all-digit key, retry zero-padded to 5, which is what
    ///      `SWLD::strongsPad` does for the bare numbers `osishtmlhref.cpp` emits.
    ///   3. otherwise **nil**.
    ///
    /// Step 3 is the deliberate behaviour change. `SWLD::strongsPad` drops a
    /// leading `G`/`H` without re-prepending it (swld.cpp:134), so "H430" pads to
    /// "0430" and `rawstr4.cpp:234-241` then snaps to a *neighbouring* entry with
    /// no error set — silently showing the wrong definition. Returning nil is the
    /// fix; `Tests/Fixtures/strongsPad-prefixed-key-bug.txt` records the engine's
    /// behaviour so the change is not later mistaken for a regression.
    func dictEntry(module: String, key: String) -> String? {
        queue.sync {
            if let html = dictEntryLocked(module: module, key: key) { return html }
            // strongsPad's zero-fill, for the bare-number path the app uses.
            if !key.isEmpty, key.allSatisfy({ $0.isASCII && $0.isNumber }), key.count < 5 {
                let padded = String(repeating: "0", count: 5 - key.count) + key
                return dictEntryLocked(module: module, key: padded)
            }
            return nil
        }
    }

    private func dictEntryLocked(module: String, key: String) -> String? {
        guard let st = statement(
            "SELECT chunk_id, slot FROM dict_keys WHERE module=? AND key=?;") else { return nil }
        bind(st, 1, module)
        bind(st, 2, key)
        guard sqlite3_step(st) == SQLITE_ROW else {
            sqlite3_reset(st)
            return nil
        }
        let chunkID = Int(sqlite3_column_int64(st, 0))
        let slot = Int(sqlite3_column_int(st, 1))
        sqlite3_reset(st)

        guard let rows = chunkRows(table: "dict_chunks", module: module, chunkID: chunkID) else { return nil }
        guard slot < rows.count, let html = rows[slot].first else {
            // Not a miss — the index pointed somewhere that does not exist.
            Self.fail("dict \(module) key '\(key)': index points at slot \(slot) of a \(rows.count)-row chunk")
            return nil
        }
        return html
    }

    /// Every key of a lexicon, in stored order.
    ///
    /// Stored order is the module's own `.idx` order, which is what the
    /// Dictionary tab shows today: `-[SwordDictionary allKeys]` walks the module
    /// from TOP. The caller applies `capitalizedString` for display — see
    /// PSContentReader for why that (wrong) display casing is preserved this
    /// phase rather than fixed.
    func dictKeys(module: String) -> [String] {
        queue.sync {
            guard let st = statement(
                "SELECT key FROM dict_keys WHERE module=? ORDER BY chunk_id, slot;") else { return [] }
            bind(st, 1, module)
            var out: [String] = []
            while sqlite3_step(st) == SQLITE_ROW { out.append(Self.text(st, 0)) }
            sqlite3_reset(st)
            return out
        }
    }

    func dictEntryCount(module: String) -> Int {
        queue.sync {
            guard let st = statement("SELECT count(*) FROM dict_keys WHERE module=?;") else { return 0 }
            bind(st, 1, module)
            guard sqlite3_step(st) == SQLITE_ROW else { return 0 }
            let n = Int(sqlite3_column_int64(st, 0))
            sqlite3_reset(st)
            return n
        }
    }

    // MARK: - FTS build source

    /// Row-oriented cursor over `verses_plain` joined with its chunked text, so
    /// callers never see chunk framing. `@objc` because `PSSearchEngine.mm` drives
    /// the index build and already imports `PocketSword-Swift.h`.
    ///
    /// Rows come out in `ordinal` order, which for KJV is also `rowid` order —
    /// `verses_plain.ordinal` is strictly increasing and unique across all 31,102
    /// rows, so this reproduces today's insert order exactly.
    @objc(PSContentVerseCursor)
    final class Cursor: NSObject {
        private let store: PSContentStore
        private let module: String
        private var rows: [PSContentVerseRow] = []
        private var index = 0
        /// Chunk currently inflated, so a sequential walk inflates each chunk once.
        private var loadedChunk: Int = -1
        private var chunkFields: [[String]] = []
        private var pending: [(ordinal: Int, osisRef: String, bookOsis: String, testament: Int, textID: Int)] = []
        private var pendingIndex = 0
        @objc private(set) var failed = false

        init(store: PSContentStore, module: String) {
            self.store = store
            self.module = module
            super.init()
            pending = store.versesPlainSkeleton(module: module)
        }

        /// Total row count, known up front so the progress UI can show a real
        /// fraction instead of an estimate.
        @objc var count: Int { pending.count }

        /// The next row, or nil at the end. A nil return with `failed == true`
        /// means the store is broken, not that the walk finished.
        @objc func next() -> PSContentVerseRow? {
            guard pendingIndex < pending.count else { return nil }
            let row = pending[pendingIndex]
            pendingIndex += 1

            let perChunk = store.chunkRowsPlain
            let chunk = row.textID / perChunk
            let slot = row.textID % perChunk
            if chunk != loadedChunk {
                guard let fields = store.queue.sync(execute: {
                    store.chunkRows(table: "plain_texts_chunks", module: module, chunkID: chunk)
                }) else {
                    failed = true
                    return nil
                }
                chunkFields = fields
                loadedChunk = chunk
            }
            guard slot < chunkFields.count, chunkFields[slot].count == 3 else {
                PSContentStore.fail("plain_texts \(module): text_id \(row.textID) is not a 3-field row")
                failed = true
                return nil
            }
            let f = chunkFields[slot]
            return PSContentVerseRow(ordinal: row.ordinal, osisRef: row.osisRef,
                                     bookOsis: row.bookOsis, testament: row.testament,
                                     textPlain: f[0], lemmas: f[1], wordMap: f[2])
        }
    }

    @objc(verseCursorForModule:)
    func verseCursor(module: String) -> Cursor {
        Cursor(store: self, module: module)
    }

    fileprivate func versesPlainSkeleton(module: String) -> [(ordinal: Int, osisRef: String, bookOsis: String, testament: Int, textID: Int)] {
        queue.sync {
            guard let st = statement(
                "SELECT ordinal, osis_ref, book_osis, testament, text_id FROM verses_plain"
                + " WHERE module=? ORDER BY ordinal;") else { return [] }
            bind(st, 1, module)
            var out: [(ordinal: Int, osisRef: String, bookOsis: String, testament: Int, textID: Int)] = []
            while sqlite3_step(st) == SQLITE_ROW {
                out.append((ordinal: Int(sqlite3_column_int64(st, 0)),
                            osisRef: Self.text(st, 1),
                            bookOsis: Self.text(st, 2),
                            testament: Int(sqlite3_column_int(st, 3)),
                            textID: Int(sqlite3_column_int64(st, 4))))
            }
            sqlite3_reset(st)
            return out
        }
    }

    // MARK: - Module metadata

    /// `content_meta`'s per-module values (`module.<name>.type` / `.version`).
    func moduleMeta(_ name: String, key: String) -> String? {
        queue.sync {
            guard let st = statement("SELECT value FROM content_meta WHERE key=?;") else { return nil }
            bind(st, 1, "module.\(name).\(key)")
            guard sqlite3_step(st) == SQLITE_ROW else {
                sqlite3_reset(st)
                return nil
            }
            let value = Self.text(st, 0)
            sqlite3_reset(st)
            return value
        }
    }
}
