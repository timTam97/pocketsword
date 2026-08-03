//
//  PSSearchEngine.h
//  PocketSword
//
//  SQLite FTS5-backed search engine for Bible/commentary modules. Replaces
//  the CLucene + downloaded-index pipeline. One engine instance per module,
//  keyed by module name; the underlying sqlite3 handle is shared across
//  threads (SQLITE_OPEN_FULLMUTEX).
//
//  Highlight delimiters emitted by the FTS5 snippet() function are the
//  literal strings PSSearchHighlightOpen / PSSearchHighlightClose, chosen
//  because they do not appear in biblical text.
//

#import <Foundation/Foundation.h>
#import "globals.h"

@class SwordModule;
@class PSSearchResult;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const PSSearchEngineErrorDomain;
extern NSString * const PSSearchHighlightOpen;   // @"[[HL]]"
extern NSString * const PSSearchHighlightClose;  // @"[[/HL]]"

/// Bumped when the on-disk schema changes in any incompatible way. An index
/// built with a different version is treated as stale and rebuilt.
extern const int PSSearchSchemaVersion;

/// Strip SWORD's inline Strong's / morph markers (e.g. `<H0430>`, `<TH8799>`)
/// and the `" [] "` empty-tag marker from a `stripText()` result, collapsing
/// any whitespace the removal left behind — including a space stranded just
/// before punctuation.
///
/// C linkage: this free function is defined in the Obj-C++ PSSearchEngine.mm
/// (which #imports this header before the definition, so the definition inherits
/// this linkage). The `extern "C"` guard suppresses C++ name mangling so the
/// Swift caller (PSModuleSearchController) resolves the unmangled symbol
/// `_PSSearchCleanDisplayText`. Plain C / Obj-C TUs ignore the guard.
/// Returns a diacritic-folded, NFC-normalised, lower-cased copy of `s`. Folding
/// drops Hebrew points + cantillation (U+0591–U+05C7, which FTS5's
/// remove_diacritics=2 leaves alone) plus the generic Unicode combining-mark
/// ranges, catching Greek polytonic accents and anything else unicode61 keeps.
///
/// This is the index-side half of a byte-for-byte duplicated algorithm: the
/// Swift `PSSearchQuery.foldForIndex` (PSSearchQuery.swift:31-67) must fold
/// query text identically or a query silently stops matching the rows this
/// produced. Both copies warn about the duplication in prose; exposing this one
/// lets `SwordOracleCaptureTests` assert the two actually agree.
#ifdef __cplusplus
extern "C" {
#endif
extern NSString *PSSearchCleanDisplayText(NSString *plain);
extern NSString *PSFoldForIndex(NSString *s);
#ifdef __cplusplus
}
#endif

typedef void (^PSSearchProgressBlock)(float fraction, BOOL *cancel);

@interface PSSearchEngine : NSObject

/// Returns a cached engine for the named module. Never nil for a non-nil name.
///
/// **Name-keyed as of SWORD_REMOVAL_PLAN.md Phase 5 step 6.** The engine used to
/// take a `SwordModule` and derive its db path from that module's
/// `AbsoluteDataPath` conf entry; it now needs only the name, because the path is
/// `<Caches>/search/<name>.db` and the version comes from `content_meta`.
+ (instancetype)engineForModuleName:(NSString *)name;

/// Drops the in-memory cache entry for this module, closing its handle first.
/// Call after deleting the on-disk index so a subsequent lookup reopens cleanly.
+ (void)invalidateEngineForModuleName:(NSString *)name;

/// Deprecated `SwordModule`-taking spellings, kept for the one commit-range where
/// both exist. They forward to the by-name versions above and are deleted with the
/// bridge in step 7.
+ (instancetype)engineForModule:(SwordModule *)mod;
+ (void)invalidateEngineForModule:(SwordModule *)mod;

/// Absolute path to the FTS5 database file for this module
/// (`<Caches>/search/<module>.db`).
- (NSString *)dbPath;

/// YES iff the DB file exists and its meta row matches the module's current
/// Version (read from `content_meta`) and our schema version. A NO return means
/// either absent or stale — either way, the caller should offer to rebuild.
///
/// Note this is what makes the step-6 relocation a one-time rebuild rather than a
/// migration: `PSSearchSchemaVersion` went 4 -> 5, so an index carrying 4 is stale
/// wherever it sits.
- (BOOL)indexIsFresh;

/// Builds the index from scratch. Blocks the calling thread; expected to run
/// on a background queue. Progress is reported on the calling thread every
/// few hundred rows; set *cancel = YES inside the block to abort cleanly.
/// On cancel or error the partial DB is dropped.
- (BOOL)buildWithProgress:(nullable PSSearchProgressBlock)progress
					error:(NSError **)err;

/// Removes the on-disk index. Does NOT remove the enclosing directory: as of step 6
/// every module's index shares `<Caches>/search`, so dropping KJV's must not delete
/// MHCC's.
- (void)dropIndex;

/// Runs a query against an already-built index. Returns an empty array if
/// the index isn't fresh. The FTS5 expression should be produced by
/// PSSearchQuery. If `strongsTokens` is non-empty, each returned result has
/// its `strongsHighlightWords` populated with the English surface form(s) in
/// that verse that map to any of the given Strong's tokens.
- (NSArray<PSSearchResult *> *)runQuery:(NSString *)fts5Expression
								  scope:(PSSearchRange)scope
							   bookName:(nullable NSString *)bookName
								  limit:(int)limit
						  strongsTokens:(nullable NSArray<NSString *> *)strongsTokens
							 cancelFlag:(nullable volatile BOOL *)cancel;

@end

NS_ASSUME_NONNULL_END
