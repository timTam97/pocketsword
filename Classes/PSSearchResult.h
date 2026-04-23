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
/// For Strong's searches, the English surface word(s) in this verse that mapped
/// to the searched Strong's number(s). nil for text searches. Order-preserving
/// and de-duped.
@property (nonatomic, copy, nullable) NSArray<NSString *> *strongsHighlightWords;

+ (instancetype)resultWithReference:(NSString *)reference fullText:(nullable NSString *)fullText;

@end

NS_ASSUME_NONNULL_END
