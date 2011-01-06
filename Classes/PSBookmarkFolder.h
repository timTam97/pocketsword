//
//  PSBookmarkFolder.h
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkObject.h"

@interface PSBookmarkFolder : PSBookmarkObject {
	CGFloat red,green,blue,alpha;
	BOOL highlight;
	
	NSMutableArray *children;
}

@property (retain, readwrite) NSMutableArray *children;
@property (readwrite) BOOL highlight;
@property (readwrite) CGFloat red, green, blue, alpha;

- (void)addChild:(PSBookmarkObject*)child;
- (void)addChildren:(NSArray*)kids;

@end
