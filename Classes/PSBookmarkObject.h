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
	//NSNumber *red,*green,*blue,*alpha;
	BOOL highlight;
}

@property (retain, readwrite) NSString *name;
@property (retain, readwrite) NSDate *dateAdded;
@property (retain, readwrite) NSDate *dateLastAccessed;
@property (readonly)		  BOOL folder;

//the following properties are only permanent for a folder.  bookmarks inherit them from their containing folder.
@property (readwrite) BOOL highlight;
//@property (retain, readwrite) NSNumber *red, *green, *blue, *alpha;
@property (retain, readwrite) NSString *rgbHexString;


- (id)initWithName:(NSString*)n dateAdded:(NSDate*)da dateLastAccessed:(NSDate*)dla;

@end
