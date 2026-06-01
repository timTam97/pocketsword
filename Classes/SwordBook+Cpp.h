//
//  SwordBook+Cpp.h
//  PocketSword
//
//  Internal Obj-C++ interface for SwordBook. Imported ONLY by .mm files
//  (SwordBook.mm, PSRefSelectorController.mm). Holds the C++ `book` ivar and
//  the sword::VersificationMgr::Book-typed init method. The public SwordBook.h
//  is Foundation-only and safe for the Swift bridging header.
//

#import "SwordBook.h"

#include <versificationmgr.h>

@interface SwordBook () {
@protected
    const sword::VersificationMgr::Book *book;
}

- (id)initWithBook:(const sword::VersificationMgr::Book *)aBook;

@end
