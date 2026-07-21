//
//  SwordKey.h
//  MacSword2
//
//  Created by Manfred Bergmann on 17.12.09.
//  Copyright 2009 Software by MABE. All rights reserved.
//


#import <Foundation/Foundation.h>

// NOTE: The sword::SWKey *sk ivar, the <swkey.h> include, and the sword-typed
// factory/init/accessor methods have been moved to the internal SwordKey+Cpp.h,
// imported only by .mm files (and shared with the SwordVerseKey / SwordListKey
// subclass .mm's so they can cast `sk`). This public header is Foundation-only
// so it is safe to expose to the Swift bridging header.

@interface SwordKey : NSObject {
    // sword::SWKey *sk ivar lives in SwordKey+Cpp.h (@protected, shared with subclasses).
    BOOL created;
}

+ (id)swordKey;
+ (id)swordKeyWithRef:(NSString *)aRef;

// C++ factory/init/accessors (swordKeyWithSWKey:, initWithSWKey:, swKey) live
// in SwordKey+Cpp.h, imported only by .mm files.

- (id)initWithRef:(NSString *)aRef;

- (id)clone;
- (void)setPersist:(BOOL)flag;
- (BOOL)persist;

- (int)error;

- (void)setPosition:(int)aPosition;
- (void)decrement;
- (void)increment;
- (NSString *)keyText;
- (void)setKeyText:(NSString *)aKey;

@end
