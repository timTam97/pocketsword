//
//  PSBookmarkFolder.h
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkObject.h"

@interface PSBookmarkFolder : PSBookmarkObject {
	
	NSArray *children;
}

@property (retain, readwrite) NSArray *children;

+ (NSString*)hexStringFromColor:(UIColor *)color;
+ (UIColor*)colorFromHexString:(NSString*)hexString;
+ (NSString*)rgbStringFromHexString:(NSString*)hexString;

- (id)initWithName:(NSString *)n dateAdded:(NSDate *)da dateLastAccessed:(NSDate *)dla rgbHexString:(NSString*)rgb children:(NSArray*)c;

- (void)addChild:(PSBookmarkObject*)child;
- (void)addChildren:(NSArray*)kids;
- (NSArray*)folders;
- (NSString *)getHighlightRGBColourStringForBookAndChapterRef:(NSString*)bookAndChapterRef withVerse:(NSString *)verse;
- (NSMutableArray *)getBookmarksForBookAndChapterRef:(NSString*)bookAndChapterRef;

@end
