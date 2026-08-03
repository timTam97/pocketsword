//
//  PSSearchEngine.mm
//  PocketSword
//

#import "PSSearchEngine.h"
#import "PocketSword-Swift.h"
#import "SwordModule.h"
#import "SwordModule+Cpp.h"
#import <sqlite3.h>
#import <swmodule.h>
#import <versekey.h>
#import <listkey.h>
#import <swkey.h>

NSString * const PSSearchEngineErrorDomain = @"PSSearchEngineErrorDomain";
NSString * const PSSearchHighlightOpen     = @"[[HL]]";
NSString * const PSSearchHighlightClose    = @"[[/HL]]";

const int PSSearchSchemaVersion = 4;

@interface PSSearchEngine () {
	sqlite3 *_db;
}
@property (nonatomic, weak) SwordModule *module;
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

+ (instancetype)engineForModule:(SwordModule *)mod {
	if(!mod) return nil;
	NSMapTable *cache = [self cache];
	@synchronized(cache) {
		PSSearchEngine *existing = [cache objectForKey:mod.name];
		if(existing) {
			// Re-attach the module in case it was reloaded between calls.
			existing.module = mod;
			return existing;
		}
		PSSearchEngine *engine = [[PSSearchEngine alloc] initWithModule:mod];
		if(engine) [cache setObject:engine forKey:mod.name];
		return engine;
	}
}

+ (void)invalidateEngineForModule:(SwordModule *)mod {
	if(!mod) return;
	NSMapTable *cache = [self cache];
	@synchronized(cache) {
		PSSearchEngine *existing = [cache objectForKey:mod.name];
		if(existing) [existing closeDB];
		[cache removeObjectForKey:mod.name];
	}
}

#pragma mark - Init / paths

- (instancetype)initWithModule:(SwordModule *)mod {
	self = [super init];
	if(self) {
		_module = mod;
		_moduleName = [mod.name copy];
		NSString *dataPath = [mod configEntryForKey:@"AbsoluteDataPath"];
		_dbDirectory = [dataPath stringByAppendingPathComponent:@"search"];
		_dbFilePath  = [_dbDirectory stringByAppendingPathComponent:@"fts.db"];
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

	SwordModule *mod = self.module;
	NSString *currentVersion = mod ? [mod version] : nil;
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

// Extract the space-separated lemma string for the current verse position on
// swModule. Each `H`-prefixed Strong's number is emitted in BOTH forms (e.g.
// "H430 H0430") so either input spelling hits. Greek lemmas ("G25", etc.) are
// emitted once as-is.
static NSString *PSLemmasForCurrentVerse(sword::SWModule *swModule) {
	NSMutableString *out = [NSMutableString string];
	sword::AttributeList &words = swModule->getEntryAttributes()["Word"];
	for(sword::AttributeList::iterator it = words.begin(); it != words.end(); ++it) {
		int parts = atoi(it->second["PartCount"].c_str());
		if(parts < 1) parts = 1;
		for(int i = 1; i <= parts; ++i) {
			sword::SWBuf key = (parts == 1) ? "Lemma" : sword::SWBuf().setFormatted("Lemma.%d", i);
			sword::AttributeValue::iterator li = it->second.find(key);
			if(li == it->second.end()) continue;
			const char *lemmaCStr = li->second.c_str();
			if(!lemmaCStr || !*lemmaCStr) continue;
			// Lemma values can contain class prefixes like "strong:H0430" —
			// split on ':' if present and keep the trailing token.
			const char *colon = strrchr(lemmaCStr, ':');
			const char *token = colon ? (colon + 1) : lemmaCStr;
			if(!*token) continue;

			if(out.length > 0) [out appendString:@" "];
			NSString *t = [NSString stringWithUTF8String:token];
			[out appendString:t];

			// H-numbers come in two forms depending on module (H0430 vs H430);
			// emit both so queries work regardless of which the module uses.
			if(t.length >= 2 && [t characterAtIndex:0] == 'H') {
				if([t characterAtIndex:1] == '0') {
					[out appendFormat:@" H%@", [t substringFromIndex:2]];
				} else {
					[out appendFormat:@" H0%@", [t substringFromIndex:1]];
				}
			}
		}
	}
	return out;
}

// Emit per-verse word→lemmas map, one line per Word entry:
//   <surface text>\t<lemma1> <lemma2> ...
// Lemmas include BOTH H-forms (H0430 and H430) to match PSLemmasForCurrentVerse
// and the query builder, so either spelling the user types resolves correctly.
// Entries with no surface text (SWORD occasionally emits empty Word slots) are
// skipped. Tabs/newlines in surface text are replaced with spaces to protect
// the line/column delimiters we control.
static NSString *PSWordMapForCurrentVerse(sword::SWModule *swModule) {
	NSMutableString *out = [NSMutableString string];
	sword::AttributeList &words = swModule->getEntryAttributes()["Word"];
	for(sword::AttributeList::iterator it = words.begin(); it != words.end(); ++it) {
		const char *textCStr = it->second["Text"].c_str();
		if(!textCStr || !*textCStr) continue;
		NSString *surface = [NSString stringWithUTF8String:textCStr];
		if(!surface) continue;
		surface = [surface stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if(surface.length == 0) continue;
		surface = [surface stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
		surface = [surface stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

		NSMutableArray<NSString *> *lemmas = [NSMutableArray array];
		int parts = atoi(it->second["PartCount"].c_str());
		if(parts < 1) parts = 1;
		for(int i = 1; i <= parts; ++i) {
			sword::SWBuf key = (parts == 1) ? "Lemma" : sword::SWBuf().setFormatted("Lemma.%d", i);
			sword::AttributeValue::iterator li = it->second.find(key);
			if(li == it->second.end()) continue;
			const char *lemmaCStr = li->second.c_str();
			if(!lemmaCStr || !*lemmaCStr) continue;
			const char *colon = strrchr(lemmaCStr, ':');
			const char *token = colon ? (colon + 1) : lemmaCStr;
			if(!*token) continue;
			NSString *t = [NSString stringWithUTF8String:token];
			if(t.length == 0) continue;
			[lemmas addObject:t];
			if(t.length >= 2 && [t characterAtIndex:0] == 'H') {
				if([t characterAtIndex:1] == '0') {
					[lemmas addObject:[@"H" stringByAppendingString:[t substringFromIndex:2]]];
				} else {
					[lemmas addObject:[@"H0" stringByAppendingString:[t substringFromIndex:1]]];
				}
			}
		}
		if(lemmas.count == 0) continue;

		if(out.length > 0) [out appendString:@"\n"];
		[out appendFormat:@"%@\t%@", surface, [lemmas componentsJoinedByString:@" "]];
	}
	return out;
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
// the column is TEXT.
- (void)stampMetaForModule:(SwordModule *)mod {
	NSString *currentVersion = [mod version];
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
	SwordModule *mod = self.module;
	if(!mod) {
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:-1
									  userInfo:@{NSLocalizedDescriptionKey:@"module is nil"}];
		return NO;
	}

	// Start fresh: if there's any prior DB, drop it. A half-built index is
	// worse than none.
	[self dropIndex];

	if(![self openDBCreatingIfNeeded:YES error:err]) return NO;
	if(![self createSchemaIfNeeded:err])              return NO;

	// Build from the baked store. Phase 5 step 1 removed the
	// `if([PSContentReader isActive])` gate along with the feature flag: the store
	// path is now unconditional, and the SWORD walk below survives only as the
	// failure fallback until step 7 deletes it outright.
	//
	// -dropIndex above has already cleared any partial DB, and the store path rolls
	// its own transaction back, so the fallback starts from a clean schema either way.
	{
		NSError *storeErr = nil;
		if([self buildFromContentStoreWithProgress:progress error:&storeErr]) {
			[self stampMetaForModule:mod];
			if(progress) { BOOL ignored = NO; progress(1.0f, &ignored); }
			return YES;
		}
		// A user cancellation must NOT silently restart the build against SWORD.
		if(storeErr.code == NSUserCancelledError) {
			[self dropIndex];
			if(err) *err = storeErr;
			return NO;
		}
		ALog(@"PSSearchEngine: content-store index build failed (%@); falling back to the engine",
			 storeErr.localizedDescription);
	}

	sword::SWModule *swModule = [mod swModule];
	if(!swModule) {
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:-2
									  userInfo:@{NSLocalizedDescriptionKey:@"no sword::SWModule"}];
		return NO;
	}

	// Upper bound for the progress fraction. Was 32000 — a guess, against an
	// actual 31,102 for KJV, so the bar never got past ~97% before jumping to 1.0.
	// The real count is knowable now that the store records it, and it is the same
	// number this loop produces (verified: the converter measured 31,102 against a
	// replica of this very loop).
	const int kExpected = 31102;

	[mod aquireModuleLock];

	// Snapshot the module's current key so we can restore the reader's
	// position afterwards, then drive off the module's own VerseKey (which
	// is what stripText() / getEntryAttributes() read from).
	sword::VerseKey *modKey = My_SWDYNAMIC_CAST(VerseKey, swModule->getKey());
	if(!modKey) {
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:-3
									  userInfo:@{NSLocalizedDescriptionKey:@"module key is not a VerseKey"}];
		[mod releaseModuleLock];
		return NO;
	}
	sword::VerseKey savedKey = *modKey;
	BOOL savedIntros = modKey->isIntros();
	modKey->setIntros(false);
	*modKey = sword::TOP;

	if(![self execSQL:@"BEGIN IMMEDIATE;" error:err]) {
		modKey->setIntros(savedIntros);
		*modKey = savedKey;
		[mod releaseModuleLock];
		return NO;
	}

	sqlite3_stmt *stmt = NULL;
	const char *insertSQL =
		"INSERT INTO verses (reference, book_osis, testament, text_plain, text_norm, lemmas, word_map) "
		"VALUES (?, ?, ?, ?, ?, ?, ?);";
	if(sqlite3_prepare_v2(_db, insertSQL, -1, &stmt, NULL) != SQLITE_OK) {
		NSString *msg = [NSString stringWithUTF8String:sqlite3_errmsg(_db)];
		if(err) *err = [NSError errorWithDomain:PSSearchEngineErrorDomain code:sqlite3_errcode(_db)
									   userInfo:@{NSLocalizedDescriptionKey: msg ?: @""}];
		[self execSQL:@"ROLLBACK;" error:NULL];
		modKey->setIntros(savedIntros);
		*modKey = savedKey;
		[mod releaseModuleLock];
		return NO;
	}

	BOOL cancelled = NO;
	BOOL success = YES;
	int count = 0;

	while(!modKey->popError()) {
		// stripText() triggers parsing, which populates getEntryAttributes()
		// (the lemmas live there). Must be called before PSLemmasForCurrentVerse.
		const char *plainC = swModule->stripText();
		if(!plainC) plainC = "";
		NSString *rawPlain = [NSString stringWithUTF8String:plainC];
		if(!rawPlain) rawPlain = [NSString stringWithCString:plainC encoding:NSISOLatin1StringEncoding] ?: @"";
		// Strip Strong's / morph markers that SWORD interleaves inline when
		// the global Strong's-display option is ON. Must run before norm/
		// lemma extraction so search results render cleanly.
		NSString *plain = PSSearchCleanDisplayText(rawPlain);

		if(plain.length > 0) {
			const char *refC       = modKey->getText();
			const char *bookOsisC  = modKey->getOSISBookName();
			int testament          = modKey->getTestament();
			NSString *reference    = refC      ? [NSString stringWithUTF8String:refC]      : @"";
			NSString *bookOsis     = bookOsisC ? [NSString stringWithUTF8String:bookOsisC] : @"";
			NSString *norm         = PSFoldForIndex(plain);
			NSString *lemmas       = PSLemmasForCurrentVerse(swModule);
			NSString *wordMap      = PSWordMapForCurrentVerse(swModule);

			sqlite3_bind_text(stmt, 1, [reference UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 2, [bookOsis  UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_int (stmt, 3, testament);
			sqlite3_bind_text(stmt, 4, [plain     UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 5, [norm      UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 6, [lemmas    UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(stmt, 7, [wordMap   UTF8String], -1, SQLITE_TRANSIENT);

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
			float fraction = MIN(0.99f, (float)count / (float)kExpected);
			BOOL localCancel = NO;
			progress(fraction, &localCancel);
			if(localCancel) { cancelled = YES; break; }
		}

		(*modKey)++;
	}

	sqlite3_finalize(stmt);

	if(cancelled || !success) {
		[self execSQL:@"ROLLBACK;" error:NULL];
	} else {
		if(![self execSQL:@"COMMIT;" error:err]) success = NO;
	}

	// Restore the module's original key position so other readers aren't
	// left at the end of the Bible.
	modKey->setIntros(savedIntros);
	*modKey = savedKey;
	[mod releaseModuleLock];

	if(cancelled || !success) {
		[self dropIndex];
		if(cancelled && err) {
			*err = [NSError errorWithDomain:PSSearchEngineErrorDomain
									   code:NSUserCancelledError
								   userInfo:@{NSLocalizedDescriptionKey:@"Index build cancelled"}];
		}
		return NO;
	}

	[self stampMetaForModule:mod];

	if(progress) {
		BOOL ignored = NO;
		progress(1.0f, &ignored);
	}

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
	// Try to remove the enclosing search/ dir if it ended up empty.
	NSArray *remaining = [fm contentsOfDirectoryAtPath:_dbDirectory error:NULL];
	if(remaining && remaining.count == 0) {
		[fm removeItemAtPath:_dbDirectory error:NULL];
	}
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
