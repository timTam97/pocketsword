//
//  PSBookmark.m
//  PocketSword
//
//  Created by Nic Carter on 5/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmark.h"


@implementation PSBookmark

@synthesize ref;

- (id)initWithName:(NSString *)n dateAdded:(NSDate *)da dateLastAccessed:(NSDate *)dla bibleReference:(NSString*)r {
	self = [super initWithName:n dateAdded:da dateLastAccessed:dla];
	if(self) {
		self.ref = r;
	}
	return self;
}

- (void)dealloc {
	self.ref = nil;
	[super dealloc];
}



@end
