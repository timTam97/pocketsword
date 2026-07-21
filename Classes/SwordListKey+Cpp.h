//
//  SwordListKey+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordListKey. Imported ONLY by .mm files
//  (SwordListKey.mm and VerseEnumerator.mm). Holds the sword::ListKey-typed
//  factory/init/accessor methods. The shared `sk` ivar is inherited from
//  SwordKey+Cpp.h. The public SwordListKey.h is Foundation-only and safe for
//  the Swift bridging header.
//

#import "SwordListKey.h"
#import "SwordKey+Cpp.h"

#include <swkey.h>
#include <listkey.h>
#include <versekey.h>

@interface SwordListKey ()

+ (id)listKeyWithSWListKey:(sword::ListKey *)aLk;
+ (id)listKeyWithSWListKey:(sword::ListKey *)aLk makeCopy:(BOOL)copy;
- (id)initWithSWListKey:(sword::ListKey *)aLk;
- (id)initWithSWListKey:(sword::ListKey *)aLk makeCopy:(BOOL)copy;
- (sword::ListKey *)swListKey;

@end
