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
	BOOL folder;

	NSString *rgbHexString;
}

@property (retain, readwrite) NSString *name;
@property (retain, readwrite) NSDate *dateAdded;
@property (retain, readwrite) NSDate *dateLastAccessed;
@property (readonly)		  BOOL folder;

// rgbHexString is only used for a folder.  bookmarks inherit them from their containing folder.
@property (retain, readwrite) NSString *rgbHexString;


- (id)initWithName:(NSString*)n dateAdded:(NSDate*)da dateLastAccessed:(NSDate*)dla;

@end
