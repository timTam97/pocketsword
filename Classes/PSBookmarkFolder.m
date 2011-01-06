//
//  PSBookmarkFolder.m
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolder.h"


@implementation PSBookmarkFolder

@synthesize red, green, blue, alpha, highlight, children;

- (void)dealloc {
	self.children = nil;
	[super dealloc];
}

- (void)addChild:(PSBookmarkObject*)child {
	if(!children) {
		self.children = [NSMutableArray arrayWithCapacity:1];
	}
	[children addObject:child];
}

- (void)addChildren:(NSArray*)kids {
	if(!children) {
		self.children = [NSMutableArray arrayWithCapacity:[kids count]];
	}
	[children addObjectsFromArray:kids];
}

@end
