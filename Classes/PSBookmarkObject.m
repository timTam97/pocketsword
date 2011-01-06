//
//  PSBookmarkObject.m
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkObject.h"


@implementation PSBookmarkObject

@synthesize name, dateAdded, dateLastAccessed;

- (void)dealloc {
	self.name = nil;
	self.dateAdded = nil;
	self.dateLastAccessed = nil;
	[super dealloc];
}

@end
