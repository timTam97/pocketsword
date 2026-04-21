//
//  PSSearchQuery.h
//  PocketSword
//
//  Translates user-typed search input into an FTS5 MATCH expression. Handles:
//    * quoted "phrases"
//    * All (AND) / Any (OR) / Exact (whole-input phrase) match types
//    * Fuzzy toggle (suffix '*' on each non-phrase token)
//    * Strong's toggle (H0xxx / Hxxx equivalence under a lemmas: column filter)
//    * Diacritic folding so accented input matches unaccented storage
//

#import <Foundation/Foundation.h>
#import "globals.h"

NS_ASSUME_NONNULL_BEGIN

@interface PSSearchQuery : NSObject

/// Build an FTS5 MATCH expression for the given user input. Returns nil for
/// trivial input (empty / pure whitespace / just quotes).
+ (nullable NSString *)fts5ExpressionFromUserInput:(NSString *)raw
										 matchType:(PSSearchType)matchType
											 fuzzy:(BOOL)fuzzy
										   strongs:(BOOL)strongs;

/// Fold diacritics for storage/query normalisation. Exposed so the engine's
/// stored `text_norm` column and the parser use the same rules.
+ (NSString *)foldForIndex:(NSString *)s;

@end

NS_ASSUME_NONNULL_END
