//
//  PSBookmarkObject.m
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkObject.h"


@implementation PSBookmarkObject

@synthesize name, dateAdded, dateLastAccessed, folder, rgbHexString;

- (id)init {
	self = [super init];
	if(self) {
		folder = NO;
	}
	return self;
}

- (id)initWithName:(NSString*)n dateAdded:(NSDate*)da dateLastAccessed:(NSDate*)dla {
	self = [super init];
	if(self) {
		self.name = n;
		self.dateAdded = da;
		self.dateLastAccessed = dla;
	}
	return self;
}

- (void)dealloc {
	self.name = nil;
	self.dateAdded = nil;
	self.dateLastAccessed = nil;
	[super dealloc];
}

@end
