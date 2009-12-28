//
//  SwordListKey.h
//  MacSword2
//
//  Created by Manfred Bergmann on 10.04.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SwordKey.h"

#ifdef __cplusplus
//#include <swkey.h>
#include <listkey.h>
#include <versekey.h>
#endif

@class SwordBible;

@interface SwordListKey : SwordKey {
}

+ (id)listKeyWithRef:(NSString *)aRef;
+ (id)listKeyWithRef:(NSString *)aRef versification:(NSString *)scheme;

#ifdef __cplusplus
- (id)initWithSWListKey:(sword::ListKey *)aLk;
- (sword::ListKey *)swListKey;
#endif

- (id)initWithRef:(NSString *)aRef;
- (id)initWithRef:(NSString *)aRef versification:(NSString *)scheme;

- (NSInteger)numberOfVerses;
- (NSInteger)count;
- (NSString *)refForElement:(NSInteger)elt;
//- (BOOL)containsKey:(SwordKey *)aVerseKey;

@end
