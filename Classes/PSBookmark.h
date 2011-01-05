//
//  PSBookmark.h
//  PocketSword
//
//  Created by Nic Carter on 5/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//


@interface PSBookmark : NSObject {
	NSString *name;
	NSDate *dateAdded;
	NSDate *dateLastAccessed;
	CGFloat red,green,blue,alpha;
	BOOL highlight;

	// if this is a folder, ref will be nil & children may contain more bookmarks
	// if this is a bookmark proper, children will be nil & ref cannot be nil!
	NSArray *children;
	NSString *ref;
}

@end
