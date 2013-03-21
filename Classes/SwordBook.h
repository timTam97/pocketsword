//
//  SwordBook.h
//  PocketSword
//
//  Created by Nic Carter on 11/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import <versificationmgr.h>



@interface SwordBook : NSObject {
	const sword::VersificationMgr::Book *book;
	NSString *name;
	NSInteger chapters;
}

-(id)initWithBook:(const sword::VersificationMgr::Book *)aBook;
-(void)dealloc;

-(NSInteger)verses:(NSInteger)chapter;
-(NSInteger)chapters;
-(NSString*)name;
-(NSString*)osisName;
-(NSString*)shortName;

@end
