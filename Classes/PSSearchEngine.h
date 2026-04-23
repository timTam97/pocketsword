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

typedef void (^PSSearchProgressBlock)(float fraction, BOOL *cancel);

@interface PSSearchEngine : NSObject

/// Returns a cached engine for the given module. Never nil for a valid module.
+ (instancetype)engineForModule:(SwordModule *)mod;

/// Drops the in-memory cache entry for this module. Call after deleting the
/// on-disk index so a subsequent engineForModule: reopens cleanly.
+ (void)invalidateEngineForModule:(SwordModule *)mod;

/// Absolute path to the FTS5 database file for this module
/// (<AbsoluteDataPath>/search/fts.db).
- (NSString *)dbPath;

/// YES iff the DB file exists and its meta row matches the module's current
/// Version and our schema version. A NO return means either absent or stale
/// — either way, the caller should offer to rebuild.
- (BOOL)indexIsFresh;

/// Builds the index from scratch. Blocks the calling thread; expected to run
/// on a background queue. Progress is reported on the calling thread every
/// few hundred rows; set *cancel = YES inside the block to abort cleanly.
/// On cancel or error the partial DB is dropped.
- (BOOL)buildWithProgress:(nullable PSSearchProgressBlock)progress
					error:(NSError **)err;

/// Removes the on-disk index (and the enclosing search/ directory if empty).
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
