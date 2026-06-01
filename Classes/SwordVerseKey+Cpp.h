//
//  SwordVerseKey+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordVerseKey. Imported ONLY by .mm files.
//  Holds the sword::VerseKey-typed factory/init/accessor methods. The shared
//  `sk` ivar is inherited from SwordKey+Cpp.h. The public SwordVerseKey.h is
//  Foundation-only and safe for the Swift bridging header.
//

#import "SwordVerseKey.h"
#import "SwordKey+Cpp.h"

#include <versekey.h>

@interface SwordVerseKey ()

+ (id)verseKeyWithSWVerseKey:(sword::VerseKey *)aVk;
+ (id)verseKeyWithSWVerseKey:(sword::VerseKey *)aVk makeCopy:(BOOL)copy;
- (id)initWithSWVerseKey:(sword::VerseKey *)aVk;
- (id)initWithSWVerseKey:(sword::VerseKey *)aVk makeCopy:(BOOL)copy;
- (sword::VerseKey *)swVerseKey;

@end
