//
//  SwordDictionary+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordDictionary. Imported ONLY by .mm files
//  (SwordDictionary.mm, SwordManager.mm). Holds the sole sword::SWModule-typed
//  init method. The public SwordDictionary.h is Foundation-only and safe for
//  the Swift bridging header.
//

#import "SwordDictionary.h"
#import "SwordModule+Cpp.h"

@interface SwordDictionary ()

- (id)initWithSWModule:(sword::SWModule *)aModule swordManager:(SwordManager *)aManager;

@end
