//
//  PSSearchResult.h
//  PocketSword
//
//  Value type for a single FTS5 search hit: the verse reference plus the raw
//  snippet string (containing [[HL]]…[[/HL]] delimiters to be rendered into an
//  attributed string by the UI layer).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSSearchResult : NSObject

@property (nonatomic, copy) NSString *reference;
/// Full plain-text of the verse, exactly as stored in FTS5's text_plain column.
@property (nonatomic, copy, nullable) NSString *fullText;

+ (instancetype)resultWithReference:(NSString *)reference fullText:(nullable NSString *)fullText;

@end

NS_ASSUME_NONNULL_END
