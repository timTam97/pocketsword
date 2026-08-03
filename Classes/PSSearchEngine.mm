//
//  PSSearchEngine.mm
//  PocketSword
//

#import "PSSearchEngine.h"
#import "PocketSword-Swift.h"
#import <sqlite3.h>

NSString * const PSSearchEngineErrorDomain = @"PSSearchEngineErrorDomain";
NSString * const PSSearchHighlightOpen     = @"[[HL]]";
NSString * const PSSearchHighlightClose    = @"[[/HL]]";

// Bumped 4 -> 5 by SWORD_REMOVAL_PLAN.md Phase 5 step 6, which MOVED the index from
// <AbsoluteDataPath>/search/fts.db to <Caches>/search/<module>.db. The bump is what
// forces the one-time rebuild for an upgrading user: -indexIsFresh compares the
// stored schema_version, so an index at the old path is never even looked for and a
// freshly-created one at the new path is stale until built. No migration — see the
// plan's decision table; moving the file would buy nothing over a rebuild the
// existing prompt already handles, and the old tree is swept by step 9's one-shot.
const int PSSearchSchemaVersion = 5;

@interface PSSearchEngine () {
	sqlite3 *_db;
}
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic, copy) NSString *dbDirectory;
@property (nonatomic, copy) NSString *dbFilePath;

@end

@implementation PSSearchEngine

#pragma mark - Instance cache

+ (NSMapTable<NSString *, PSSearchEngine *> *)cache {
	static NSMapTable *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [NSMapTable strongToStrongObjectsMapTable];
	});
	return cache;
}

// Keyed by NAME as of Phase 5 step 6. It always was, in effect — the old
// +engineForModule: used mod.name as the cache key — but the engine no longer holds
// the SwordModule at all, so there is nothing to "re-attach" on a cache hit and the
// module-reload dance is gone with it.
+ (instancetype)engineForModuleName:(NSString *)name {
	if(!name) return nil;
	NSMapTable *cache = [self cache];
	@synchronized(cache) {
		PSSearchEngine *existing = [cache objectForKey:name];
		if(existing) return existing;
		PSSearchEngine *engine = [[PSSearchEngine alloc] initWithModuleName:name];
		if(engine) [cache setObject:engine forKey:name];
		return engine;
	}
}

+ (void)invalidateEngineForModuleName:(NSString *)name {
	if(!name) return;
	NSMapTable *cache = [self cache];
	@synchronized(cache) {
		PSSearchEngine *existing = [cache objectForKey:name];
		// closeDB BEFORE removing, or the handle leaks with the last reference.
		if(existing) [existing closeDB];
		[cache removeObjectForKey:name];
	}
}

#pragma mark - Init / paths

// A module NAME is all the engine needs. The path is <Caches>/search/<name>.db and
// the version comes from content_meta, so nothing here touches SWORD — which as of
// Phase 5 step 7 is not a design choice but a fact: there is no SWORD.
- (instancetype)initWithModuleName:(NSString *)name {
	if(!name) return nil;
	self = [super init];
	if(self) {
		_moduleName = [name copy];
		_dbDirectory = [PSPaths searchIndexDirectory];
		_dbFilePath  = [PSPaths searchIndexPathForModule:name];
	}
	return self;
}

- (void)dealloc {
	[self closeDB];
}

- (NSString *)dbPath {
	return _dbFilePath;
}

#pragma mark - Database open / close

- (BOOL)ensureDirectoryExists:(NSError **)err {
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;
	if([fm fileExistsAtPath:_dbDirectory isDirectory:&isDir] && isDir) return YES;
	return [fm createDirectoryAtPath:_dbDirectory
		 withIntermediateDirectories:YES
						  attributes:nil
							   error:err];
}

- (BOOL)openDBCreatingIfNeeded:(BOOL)create error:(NSError **)err {
	if(_db) return YES;

	if(create && ![self ensureDirectoryExists:err]) {
		return NO;
	}

	int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX;
	if(create) flags |= SQLITE_OPEN_CREATE;

	int rc = sqlite3_open_v2([_dbFilePath UTF8String], &_db, flags, NULL);
	if(rc != SQLITE_OK) {
		if(err) {
			NSString *msg = _db ? [NSString stringWithUTF8String:sqlite3_errmsg(_db)]
								: @"sqlite3_open_v2 failed";
			*err = [NSError errorWithDomain:PSSearchEngineErrorDomain
									   code:rc
								   userInfo:@{NSLocalizedDescriptionKey: msg ?: @""}];
		}
		if(_db) { sqlite3_close(_db); _db = NULL; }
		return NO;
	}

	// Busy timeout so concurrent readers don't immediately SQLITE_BUSY.
	sqlite3_busy_timeout(_db, 2000);
	return YES;
}

- (void)closeDB {
	if(_db) {
		sqlite3_close(_db);
		_db = NULL;
	}
}

- (BOOL)execSQL:(NSString *)sql error:(NSError **)err {
	char *errmsg = NULL;
	int rc = sqlite3_exec(_db, [sql UTF8String], NULL, NULL, &errmsg);
	if(rc != SQLITE_OK) {
		if(err) {
			NSString *msg = errmsg ? [NSString stringWithUTF8String:errmsg] : @"sqlite3_exec failed";
			*err = [NSError errorWithDomain:PSSearchEngineErrorDomain
									   code:rc
								   userInfo:@{NSLocalizedDescriptionKey: msg}];
		}
		if(errmsg) sqlite3_free(errmsg);
		return NO;
	}
	return YES;
}

- (BOOL)createSchemaIfNeeded:(NSError **)err {
	if(![self execSQL:
		 @"CREATE TABLE IF NOT EXISTS meta ("
		 @"  module_name    TEXT PRIMARY KEY,"
		 @"  module_version TEXT,"
		 @"  built_at       INTEGER,"
		 @"  schema_version INTEGER"
		 @");"
			error:err]) return NO;

	// FTS5 virtual table. `reference`, `book_num`, `testament` are UNINDEXED
	// (they're scope/display metadata, not searched as text). `text_plain`
	// is indexed so snippet() can highlight against readable text;
	// `text_norm` holds diacritic-folded text for recall; `lemmas` holds
	// Strong's numbers in both H0xxx and Hxxx forms, space-separated.
	// `word_map` is UNINDEXED per-verse metadata: one line per scripture
	// word, surface form TAB lemma1 lemma2 ..., used at query time to
	// recover which English word(s) a Strong's match lit up.
	NSString *createFts =
		@"CREATE VIRTUAL TABLE IF NOT EXISTS verses USING fts5("
		@"  reference UNINDEXED,"
		@"  book_osis UNINDEXED,"
		@"  testament UNINDEXED,"
		@"  text_plain,"
		@"  text_norm,"
		@"  lemmas,"
		@"  word_map UNINDEXED,"
		@"  tokenize='unicode61 remove_diacritics 2'"
		@");";
	return [self execSQL:createFts error:err];
}

#pragma mark - Freshness

- (BOOL)indexIsFresh {
	NSFileManager *fm = [NSFileManager defaultManager];
	if(![fm fileExistsAtPath:_dbFilePath]) return NO;

	NSError *err = nil;
	if(![self openDBCreatingIfNeeded:NO error:&err]) {
		DLog(@"PSSearchEngine: cannot open %@: %@", _dbFilePath, err);
		return NO;
	}

	sqlite3_stmt *stmt = NULL;
	const char *sql = "SELECT module_version, schema_version FROM meta WHERE module_name = ? LIMIT 1;";
	if(sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
		DLog(@"PSSearchEngine: prepare meta failed: %s", sqlite3_errmsg(_db));
		return NO;
	}

	// The module's Version= conf value, from content_meta rather than [mod version]
	// (Phase 5 step 4 made PSContentStore.moduleVersion @objc for exactly this).
	// Same string either way — the converter captured it from the same conf entry —
	// so an index built before this change still compares equal on version. What
	// forces the rebuild is the schema_version bump, not this.
	NSString *currentVersion = [[PSContentStore sharedStore] moduleVersionForModule:_moduleName];
	sqlite3_bind_text(stmt, 1, [_moduleName UTF8String], -1, SQLITE_TRANSIENT);

	BOOL fresh = NO;
	if(sqlite3_step(stmt) == SQLITE_ROW) {
		const unsigned char *storedVer = sqlite3_column_text(stmt, 0);
		int storedSchema = sqlite3_column_int(stmt, 1);
		NSString *storedVerStr = storedVer ? [NSString stringWithUTF8String:(const char *)storedVer] : nil;
		BOOL versionMatches = (currentVersion == nil && storedVerStr == nil)
			|| [currentVersion isEqualToString:storedVerStr];
		fresh = (storedSchema == PSSearchSchemaVersion) && versionMatches;
	}
	sqlite3_finalize(stmt);
	return fresh;
}

#pragma mark - Text normalisation

// Returns a diacritic-folded, NFC-normalised, lower-cased copy of `s`.
// Folding drops:
//   * Hebrew points + cantillation (U+0591–U+05C7) — FTS5's
//     remove_diacritics=2 doesn't touch these.
//   * Generic Unicode combining-mark ranges — catches Greek polytonic
//     accents and anything else unicode61 leaves in place.
NSString *PSFoldForIndex(NSString *s) {
	if(s.length == 0) return @"";
	NSString *decomposed = [s decomposedStringWithCanonicalMapping];
	NSMutableString *out = [NSMutableString stringWithCapacity:decomposed.length];
	for(NSUInteger i = 0; i < decomposed.length; ) {
		unichar c = [decomposed characterAtIndex:i];
		BOOL drop =
			(c >= 0x0300 && c <= 0x036F) ||
			(c >= 0x0591 && c <= 0x05C7) ||
			(c >= 0x1AB0 && c <= 0x1AFF) ||
			(c >= 0x1DC0 && c <= 0x1DFF) ||
			(c >= 0x20D0 && c <= 0x20FF) ||
			(c >= 0xFE20 && c <= 0xFE2F);
		if(!drop) {
			if(CFStringIsSurrogateHighCharacter(c) && i + 1 < decomposed.length) {
				[out appendFormat:@"%C%C", c, [decomposed characterAtIndex:i + 1]];
				i += 2;
				continue;
			}
			[out appendFormat:@"%C", c];
		}
		i += 1;
	}
	return [[out precomposedStringWithCanonicalMapping] lowercaseString];
}

// When SWORD's global Strong's-display option is ON, stripText() returns verse
// text with Strong's and morph markers interleaved inline — e.g. "And God
// <H0430> divided <H0996> <H0914> the light". These markers are unreadable in
// search results, so strip any `<[A-Z]+\d+[A-Z0-9-]*>` token (Strong's: H0430,
// G3056; morph: TH8799, TG5707). Also drop SWORD's `" [] "` empty-tag marker
// and collapse any whitespace left behind — including the space a stripped
// marker leaves stranded immediately before punctuation (e.g. "field ,").
NSString *PSSearchCleanDisplayText(NSString *plain) {
	if(plain.length == 0) return @"";
	static NSRegularExpression *markerRe;
	static NSRegularExpression *wsRe;
	static NSRegularExpression *wsBeforePunctRe;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		markerRe = [NSRegularExpression regularExpressionWithPattern:@"<[A-Z][A-Z0-9]*\\d[A-Z0-9-]*>"
															 options:0 error:NULL];
		wsRe = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:NULL];
		wsBeforePunctRe = [NSRegularExpression regularExpressionWithPattern:@"\\s+([,.;:!?\\)\\]])"
																	options:0 error:NULL];
	});
	NSMutableString *out = [plain mutableCopy];
	if(markerRe) {
		[markerRe replaceMatchesInString:out options:0
								   range:NSMakeRange(0, out.length) withTemplate:@" "];
	}
	[out replaceOccurrencesOfString:@" [] " withString:@" "
							options:0 range:NSMakeRange(0, out.length)];
	if(wsRe) {
		[wsRe replaceMatchesInString:out options:0
							   range:NSMakeRange(0, out.length) withTemplate:@" "];
	}
	if(wsBeforePunctRe) {
		[wsBeforePunctRe replaceMatchesInString:out options:0
										  range:NSMakeRange(0, out.length) withTemplate:@"$1"];
	}
	return [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#pragma mark - Build

// Build the index from the baked content store instead of walking the live
// module (SWORD_REMOVAL_PLAN.md Phase 3, step 7).
//
// Everything about the index itself is deliberately unchanged: the same FTS5
// schema, the same seven columns in the same order, PSSearchCleanDisplayText and
// PSFoldForIndex applied at the same points, and — critically — the SAME
// emptiness test AFTER cleaning, because that test is what decides which rows
// exist at all. Only the source of (reference, book_osis, testament, text_plain,
// lemmas, word_map) changes: it comes from PSContentStore's row cursor rather
// than from stripText() + getEntryAttributes().
//
// The cursor is used rather than a direct join against plain_texts because that
// table is chunk-compressed as of schema v2 — the framing is the store's business,
// not the index builder's.
//
// PSSearchCleanDisplayText stays in the path even though `text_plain` in the store
// carries ZERO rows with `<H…>` markers (the converter already applied it), so it
// is a no-op on this input. Leaving it in means the two build paths cannot drift
// on that axis, and costs one regex pass per row.
- (BOOL)buildFromContentStoreWithProgress:(PSSearchProgressBlock)progress error:(NSError **)err {
	PSContentStore *store = [PSContentStore sharedStore];
	if(!store) {
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:-4
									  userInfo:@{NSLocalizedDescriptionKey:@"no content store"}];
		return NO;
	}

	PSContentVerseCursor *cursor = [store verseCursorForModule:_moduleName];
	// The real row count, known up front — so the progress fraction is exact
	// rather than divided by an estimate (the old loop's kExpected was 32000
	// against an actual 31,102 for KJV, so it never reached ~97%).
	const NSInteger total = cursor.count;
	if(total == 0) {
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:-5
									  userInfo:@{NSLocalizedDescriptionKey:@"content store has no rows for this module"}];
		return NO;
	}

	if(![self execSQL:@"BEGIN IMMEDIATE;" error:err]) return NO;

	sqlite3_stmt *stmt = NULL;
	const char *insertSQL =
		"INSERT INTO verses (reference, book_osis, testament, text_plain, text_norm, lemmas, word_map) "
		"VALUES (?, ?, ?, ?, ?, ?, ?);";
	if(sqlite3_prepare_v2(_db, insertSQL, -1, &stmt, NULL) != SQLITE_OK) {
		NSString *msg = [NSString stringWithUTF8String:sqlite3_errmsg(_db)];
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:sqlite3_errcode(_db)
									   userInfo:@{NSLocalizedDescriptionKey: msg ?: @""}];
		[self execSQL:@"ROLLBACK;" error:NULL];
		return NO;
	}

	BOOL cancelled = NO, success = YES;
	NSInteger count = 0;
	PSContentVerseRow *row = nil;
	// Rows arrive in `ordinal` order, which for KJV is also the order the old
	// loop inserted them in (verses_plain.ordinal is strictly increasing and
	// unique across all 31,102 rows) — so `ORDER BY rowid` in -search: keeps
	// giving biblical order.
	while((row = [cursor next]) != nil) {
		NSString *plain = PSSearchCleanDisplayText(row.textPlain);
		if(plain.length > 0) {
			NSString *norm = PSFoldForIndex(plain);
			sqlite3_bind_text(stmt, 1, [row.osisRef  UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 2, [row.bookOsis UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_int (stmt, 3, (int)row.testament);
			sqlite3_bind_text(stmt, 4, [plain        UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 5, [norm         UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 6, [row.lemmas   UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 7, [row.wordMap  UTF8String], -1, SQLITE_TRANSIENT);

			if(sqlite3_step(stmt) != SQLITE_DONE) {
				NSString *msg = [NSString stringWithUTF8String:sqlite3_errmsg(_db)];
				if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain
												   code:sqlite3_errcode(_db)
											   userInfo:@{NSLocalizedDescriptionKey: msg ?: @""}];
				success = NO;
				sqlite3_reset(stmt);
				break;
			}
			sqlite3_reset(stmt);
		}

		++count;
		if(progress && (count % 500 == 0)) {
			float fraction = MIN(0.99f, (float)count / (float)total);
			BOOL localCancel = NO;
			progress(fraction, &localCancel);
			if(localCancel) { cancelled = YES; break; }
		}
	}
	sqlite3_finalize(stmt);

	// A cursor that stopped because the STORE is broken must not be mistaken for
	// one that reached the end: that would commit a silently-truncated index.
	if(success && !cancelled && cursor.failed) {
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:-6
									  userInfo:@{NSLocalizedDescriptionKey:@"content store read failed mid-build"}];
		success = NO;
	}

	if(cancelled || !success) {
		[self execSQL:@"ROLLBACK;" error:NULL];
		// Report cancellation with the same code the engine path uses, so the
		// caller can tell "the user stopped it" from "it broke" — and so
		// -buildWithProgress: does not restart the build against SWORD.
		if(cancelled && err) {
			*err = [NSError errorWithDomain:PSSearchEngineErrorDomain
									   code:NSUserCancelledError
								   userInfo:@{NSLocalizedDescriptionKey:@"Index build cancelled"}];
		}
		return NO;
	}
	if(![self execSQL:@"COMMIT;" error:err]) return NO;
	return YES;
}

// The meta row, shared by both build paths. module_version is nil-safe because
// the column is TEXT. Reads the version from content_meta, not from a SwordModule.
- (void)stampMeta {
	NSString *currentVersion = [[PSContentStore sharedStore] moduleVersionForModule:_moduleName];
	sqlite3_stmt *meta = NULL;
	const char *metaSQL =
		"INSERT OR REPLACE INTO meta (module_name, module_version, built_at, schema_version) "
		"VALUES (?, ?, ?, ?);";
	if(sqlite3_prepare_v2(_db, metaSQL, -1, &meta, NULL) == SQLITE_OK) {
		sqlite3_bind_text(meta, 1, [_moduleName UTF8String], -1, SQLITE_TRANSIENT);
		if(currentVersion) {
			sqlite3_bind_text(meta, 2, [currentVersion UTF8String], -1, SQLITE_TRANSIENT);
		} else {
			sqlite3_bind_null(meta, 2);
		}
		sqlite3_bind_int64(meta, 3, (sqlite3_int64)[[NSDate date] timeIntervalSince1970]);
		sqlite3_bind_int  (meta, 4, PSSearchSchemaVersion);
		sqlite3_step(meta);
		sqlite3_finalize(meta);
	}
}

- (BOOL)buildWithProgress:(PSSearchProgressBlock)progress error:(NSError **)err {
	// Start fresh: if there's any prior DB, drop it. A half-built index is
	// worse than none.
	[self dropIndex];

	if(![self openDBCreatingIfNeeded:YES error:err]) return NO;
	if(![self createSchemaIfNeeded:err])              return NO;

	// The baked store is the ONLY source (SWORD_REMOVAL_PLAN.md Phase 5 step 7).
	//
	// What used to follow this was a ~145-line SWORD fallback walk: a VerseKey
	// iteration from TOP, stripText() per verse, and the PSLemmasForCurrentVerse /
	// PSWordMapForCurrentVerse entry-attribute readers. It is deleted along with the
	// engine. What it produced is not lost — Tests/Fixtures/search-index-KJV.digest
	// records all 31,102 of its rows, and PSSearchIndexParityTests compares this path
	// against that digest on every run.
	//
	// The `NSUserCancelledError` re-entry guard went with it: it existed only to stop
	// a user cancellation silently restarting the build against SWORD. A cancellation
	// now simply propagates, like any other failure.
	NSError *storeErr = nil;
	if(![self buildFromContentStoreWithProgress:progress error:&storeErr]) {
		// -dropIndex so a partial index is never left behind to be treated as fresh.
		[self dropIndex];
		if(err) *err = storeErr;
		return NO;
	}

	[self stampMeta];
	if(progress) { BOOL ignored = NO; progress(1.0f, &ignored); }
	return YES;
}

#pragma mark - Drop

- (void)dropIndex {
	[self closeDB];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *err = nil;
	if([fm fileExistsAtPath:_dbFilePath]) {
		[fm removeItemAtPath:_dbFilePath error:&err];
		if(err) ALog(@"PSSearchEngine: failed to remove %@: %@", _dbFilePath, err);
	}
	// The enclosing directory is deliberately LEFT IN PLACE (Phase 5 step 6).
	//
	// This used to remove <AbsoluteDataPath>/search when it was empty, which was
	// safe because that directory held exactly one module's fts.db. The index now
	// lives at <Caches>/search/<module>.db, so KJV and MHCC SHARE the directory and
	// removing it on one module's drop would delete the other's index — or, if the
	// other engine had it open, leave it writing to an unlinked file.
	//
	// Not removing it costs an empty directory in Caches, which the OS may purge
	// anyway and -ensureDirectoryExists recreates on demand.
}

#pragma mark - Query

- (NSArray<PSSearchResult *> *)runQuery:(NSString *)fts5Expression
								  scope:(PSSearchRange)scope
							   bookName:(NSString *)bookName
								  limit:(int)limit
						  strongsTokens:(NSArray<NSString *> *)strongsTokens
							 cancelFlag:(volatile BOOL *)cancel {
	if(fts5Expression.length == 0) return @[];
	if(![self indexIsFresh]) return @[];

	NSError *err = nil;
	if(![self openDBCreatingIfNeeded:NO error:&err]) {
		DLog(@"PSSearchEngine: runQuery openDB failed: %@", err);
		return @[];
	}

	BOOL wantWordMap = strongsTokens.count > 0;
	NSSet<NSString *> *tokenSet = wantWordMap ? [NSSet setWithArray:strongsTokens] : nil;

	// We return the FULL stored verse text (text_plain) and let the UI do
	// its own highlighting. FTS5's snippet() truncates to ~64 tokens and
	// drops highlight markers for matches that hit non-visible columns
	// (e.g. Strong's lemmas), so snippet() is the wrong tool for this app.
	// For Strong's searches we also pull word_map so the caller can learn
	// which English surface word(s) to highlight.
	NSMutableString *sql = [NSMutableString stringWithString:
		wantWordMap
			? @"SELECT reference, text_plain, word_map FROM verses WHERE verses MATCH ?"
			: @"SELECT reference, text_plain FROM verses WHERE verses MATCH ?"];

	BOOL hasTestament = NO, hasBook = NO;
	int testamentValue = 0;
	if(scope == OTRange) { hasTestament = YES; testamentValue = 1; }
	else if(scope == NTRange) { hasTestament = YES; testamentValue = 2; }
	if(hasTestament) [sql appendString:@" AND testament = ?"];

	NSString *bookOsis = nil;
	if(scope == BookRange && bookName.length > 0) {
		// SWORD_REMOVAL_PLAN.md Phase 4: name -> OSIS now comes from the baked
		// versification table rather than from a live sword::VerseKey, which
		// removes the last SWORD use from the *query* path. Verified equivalent for
		// all 66 books in PSRefSemanticsTests.testOsisNameMatchesTheEngine; the
		// deleted shim's whole body was setText() + getOSISBookName(), and the
		// "localised" in its name was aspirational (translateBookName: is identity
		// on every device — there is no `en` locale conf).
		//
		// A nil resolver (bundled table missing) simply leaves the scope filter
		// off, which is the same outcome the shim's popError() path produced: an
		// unrecognised book name searches the whole Bible rather than nothing.
		bookOsis = [[PSBookOSISResolver sharedResolver] osisNameForBookName:bookName];
		if(bookOsis.length > 0) { hasBook = YES; [sql appendString:@" AND book_osis = ?"]; }
	}

	// Rows are inserted during build in canonical VerseKey iteration order
	// (Genesis 1:1 upward), so rowid gives us biblical order directly.
	//
	// This stays `rowid` rather than becoming `ORDER BY ordinal` now that the store
	// drives the build, and the equivalence was verified rather than assumed:
	// verses_plain.ordinal is strictly increasing and unique across all 31,102 KJV
	// rows, and the cursor walks it in that order — so rowid order IS ordinal
	// order. Switching would also mean adding an `ordinal` column to the FTS table
	// (bumping PSSearchSchemaVersion and forcing every user to rebuild) to buy
	// nothing.
	[sql appendString:@" ORDER BY rowid"];
	if(limit > 0) [sql appendFormat:@" LIMIT %d", limit];

	sqlite3_stmt *stmt = NULL;
	if(sqlite3_prepare_v2(_db, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
		DLog(@"PSSearchEngine: prepare query failed: %s (sql=%@)", sqlite3_errmsg(_db), sql);
		return @[];
	}

	int p = 1;
	sqlite3_bind_text(stmt, p++, [fts5Expression UTF8String], -1, SQLITE_TRANSIENT);
	if(hasTestament) sqlite3_bind_int (stmt, p++, testamentValue);
	if(hasBook)      sqlite3_bind_text(stmt, p++, [bookOsis UTF8String], -1, SQLITE_TRANSIENT);

	NSMutableArray<PSSearchResult *> *results = [NSMutableArray array];
	while(YES) {
		if(cancel && *cancel) break;
		int rc = sqlite3_step(stmt);
		if(rc == SQLITE_ROW) {
			const unsigned char *refC  = sqlite3_column_text(stmt, 0);
			const unsigned char *textC = sqlite3_column_text(stmt, 1);
			NSString *ref  = refC  ? [NSString stringWithUTF8String:(const char *)refC]  : @"";
			NSString *text = textC ? [NSString stringWithUTF8String:(const char *)textC] : nil;
			PSSearchResult *result = [PSSearchResult resultWithReference:ref fullText:text];

			if(wantWordMap) {
				const unsigned char *mapC = sqlite3_column_text(stmt, 2);
				if(mapC && *mapC) {
					NSString *map = [NSString stringWithUTF8String:(const char *)mapC];
					NSMutableArray<NSString *> *words = [NSMutableArray array];
					NSMutableSet<NSString *> *seen = [NSMutableSet set];
					for(NSString *line in [map componentsSeparatedByString:@"\n"]) {
						NSRange tab = [line rangeOfString:@"\t"];
						if(tab.location == NSNotFound) continue;
						NSString *surface = [line substringToIndex:tab.location];
						NSString *lemmaStr = [line substringFromIndex:NSMaxRange(tab)];
						if(surface.length == 0 || lemmaStr.length == 0) continue;
						BOOL hit = NO;
						for(NSString *lemma in [lemmaStr componentsSeparatedByString:@" "]) {
							if(lemma.length > 0 && [tokenSet containsObject:lemma]) { hit = YES; break; }
						}
						if(!hit) continue;
						if([seen containsObject:surface]) continue;
						[seen addObject:surface];
						[words addObject:surface];
					}
					if(words.count > 0) result.strongsHighlightWords = words;
				}
			}

			[results addObject:result];
		} else if(rc == SQLITE_DONE) {
			break;
		} else {
			DLog(@"PSSearchEngine: step returned %d: %s", rc, sqlite3_errmsg(_db));
			break;
		}
	}
	sqlite3_finalize(stmt);
	return results;
}

@end
