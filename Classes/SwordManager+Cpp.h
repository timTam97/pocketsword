//
//  SwordManager+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordManager. Imported ONLY by .mm files
//  (SwordManager.mm). Holds the C++ `swManager` ivar, the sword API includes,
//  and the sword::SWMgr/SWModule-typed init/accessor methods. The public
//  SwordManager.h is Foundation-only and safe for the Swift bridging header.
//  (PSModuleController was ported to Swift in Wave 4 and now reaches the engine
//  exclusively through the Foundation-only SwordManager.h facade.)
//

#import "SwordManager.h"

#include <swmgr.h>		// C++ Sword API
#include <localemgr.h>
#include <markupfiltmgr.h>
// Filters
#include <osishtmlhref.h>
#include <thmlhtmlhref.h>
#include <gbfhtmlhref.h>
#include <versekey.h>
using sword::SWModule;

@interface SwordManager () {
@protected
    sword::SWMgr *swManager;
}

- (id)initWithSWMgr:(sword::SWMgr *)smgr;
- (sword::SWModule *)getSWModuleWithName:(NSString *)moduleName;
- (sword::SWMgr *)swManager;

@end
