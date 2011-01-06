//
//  PSBookmarkObject.h
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//


@interface PSBookmarkObject : NSObject {
	NSString *name;
	NSDate *dateAdded;
	NSDate *dateLastAccessed;
}

@property (retain, readwrite) NSString *name;
@property (retain, readwrite) NSDate *dateAdded;
@property (retain, readwrite) NSDate *dateLastAccessed;

@end
