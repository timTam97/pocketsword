//
//  SwordListKey.h
//  MacSword2
//
//  Created by Manfred Bergmann on 10.04.09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "SwordKey.h"
#import "VerseEnumerator.h"

// NOTE: The <swkey.h>/<listkey.h>/<versekey.h> includes and the
// sword::ListKey-typed factory/init/accessor methods have been moved to the
// internal SwordListKey+Cpp.h, imported only by .mm files (SwordListKey.mm and
// VerseEnumerator.mm). This public header is Foundation-only so it is safe to
// expose to the Swift bridging header.

@class SwordBible, VerseEnumerator;

@interface SwordListKey : SwordKey {
}

+ (id)listKeyWithRef:(NSString *)aRef;
+ (id)listKeyWithRef:(NSString *)aRef v11n:(NSString *)scheme;
+ (id)listKeyWithRef:(NSString *)aRef headings:(BOOL)headings v11n:(NSString *)scheme;

// C++ factory/init/accessors (listKeyWithSWListKey:, initWithSWListKey:,
// swListKey) live in SwordListKey+Cpp.h, imported only by .mm files.

- (id)initWithRef:(NSString *)aRef;
- (id)initWithRef:(NSString *)aRef v11n:(NSString *)scheme;
- (id)initWithRef:(NSString *)aRef headings:(BOOL)headings v11n:(NSString *)scheme;

- (void)parse;
- (void)parseWithHeaders;
- (VerseEnumerator *)verseEnumerator;

- (NSInteger)numberOfVerses;
- (NSInteger)count;
- (NSString *)refForElement:(NSInteger)elt;
- (BOOL)containsKey:(SwordKey *)aVerseKey;

@end
