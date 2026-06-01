//
//  SwordModule+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordModule. Imported ONLY by .mm files
//  (SwordModule.mm, SwordDictionary.mm, SwordManager.mm, PSModuleController.mm,
//  PSSearchEngine.mm). Holds the C++ `swModule` ivar (shared with the
//  SwordDictionary subclass), the sword::SWModule-typed init/accessor methods,
//  and the My_SWDYNAMIC_CAST helper. The public SwordModule.h is Foundation-only
//  and safe for the Swift bridging header.
//

#import "SwordModule.h"

#include <swtext.h>
#include <versekey.h>
#include <regex.h>
using sword::SWModule;

#define My_SWDYNAMIC_CAST(className, object) (sword::className *)((object)?((object->getClass()->isAssignableFrom(#className))?object:0):0)

@interface SwordModule () {
@protected
    sword::SWModule *swModule;
}

- (id)initWithSWModule:(sword::SWModule *)aModule;
- (id)initWithSWModule:(sword::SWModule *)aModule swordManager:(SwordManager *)aManager;
- (sword::SWModule *)swModule;

@end
