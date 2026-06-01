//
//  SwordKey+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordKey. Imported ONLY by .mm files.
//  Holds the C++ `sk` ivar (shared with the SwordVerseKey / SwordListKey
//  subclasses) plus the sword::SWKey-typed factory/init/accessor methods.
//  The public SwordKey.h is Foundation-only and safe for the Swift
//  bridging header.
//

#import "SwordKey.h"

#include <swkey.h>

@interface SwordKey () {
@protected
    sword::SWKey *sk;
}

+ (id)swordKeyWithSWKey:(sword::SWKey *)aSk;
+ (id)swordKeyWithSWKey:(sword::SWKey *)aSk makeCopy:(BOOL)copy;
- (id)initWithSWKey:(sword::SWKey *)aSk;
- (id)initWithSWKey:(sword::SWKey *)aSk makeCopy:(BOOL)copy;
- (sword::SWKey *)swKey;

@end
