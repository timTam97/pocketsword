//
//  SwordVerseKey.h
//  MacSword2
//
//  Created by Manfred Bergmann on 17.03.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SwordKey.h"

// NOTE: The <versekey.h> include and the sword::VerseKey-typed
// factory/init/accessor methods have been moved to the internal
// SwordVerseKey+Cpp.h, imported only by .mm files. This public header is
// Foundation-only so it is safe to expose to the Swift bridging header.

@interface SwordVerseKey : SwordKey {
}

+ (id)verseKey;
+ (id)verseKeyWithVersification:(NSString *)scheme;
+ (id)verseKeyWithRef:(NSString *)aRef;
+ (id)verseKeyWithRef:(NSString *)aRef v11n:(NSString *)scheme;
+ (id)verseKeyForOTForVersification:(NSString *)scheme;
+ (id)verseKeyForNTForVersification:(NSString *)scheme;
+ (id)verseKeyForWholeBibleForVersification:(NSString *)scheme;
+ (id)verseKeyForWholeBook:(NSString *)aRef v11n:(NSString *)scheme;

// C++ factory/init/accessors (verseKeyWithSWVerseKey:, initWithSWVerseKey:,
// swVerseKey) live in SwordVerseKey+Cpp.h, imported only by .mm files.

- (id)initWithVersification:(NSString *)scheme;
- (id)initWithRef:(NSString *)aRef;
- (id)initWithRef:(NSString *)aRef v11n:(NSString *)scheme;

- (long)index;
- (int)testament;
- (void)setTestament:(int)val;
- (int)book;
- (void)setBook:(int)val;
- (int)chapter;
- (void)setChapter:(int)val;
- (int)verse;
- (void)setVerse:(int)val;
- (BOOL)introductions;
- (void)setIntroductions:(BOOL)flag;
- (BOOL)autoNormalize;
- (void)setAutoNormalize:(BOOL)flag;
- (NSString *)bookName;
- (NSString *)osisBookName;
- (NSString *)osisRef;
- (void)setVersification:(NSString *)versification;
- (NSString *)versification;

@end
