//
//  SwordBook.h
//  PocketSword
//
//  Created by Nic Carter on 11/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import <Foundation/Foundation.h>

// NOTE: The unguarded #import <versificationmgr.h>, the const
// sword::VersificationMgr::Book *book ivar, and -initWithBook: have been moved
// to the internal SwordBook+Cpp.h, imported only by .mm files. This public
// header is Foundation-only so it is safe to expose to the Swift bridging
// header. Do not re-add the C++ include here.

@interface SwordBook : NSObject {
	// const sword::VersificationMgr::Book *book ivar lives in SwordBook+Cpp.h.
	NSString *name;
	NSInteger chapters;
}

// C++ init (-initWithBook:) lives in SwordBook+Cpp.h, imported only by .mm files.
-(void)dealloc;

-(NSInteger)verses:(NSInteger)chapter;
-(NSInteger)chapters;
-(NSString*)name;
-(NSString*)osisName;
-(NSString*)shortName;

@end
