//
//  PSSearchResult.m
//  PocketSword
//

#import "PSSearchResult.h"

@implementation PSSearchResult

+ (instancetype)resultWithReference:(NSString *)reference fullText:(NSString *)fullText {
	PSSearchResult *r = [[PSSearchResult alloc] init];
	r.reference = reference;
	r.fullText = fullText;
	return r;
}

@end
