//
//  PSBookmarks.h
//  PocketSword
//
//  Created by Nic Carter on 12/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolder.h"

@interface PSBookmarks : PSBookmarkFolder {

}

- (id)initLocalBookmarks;
- (id)initCloudBookmarks;

+ (PSBookmarks *)defaultBookmarks;
+ (BOOL)addBookmarkObject:(PSBookmarkObject*)bookmark withFolderString:(NSString*)folderString;
+ (BOOL)addBookmarkWithRef:(NSString*)r name:(NSString*)n folderString:(NSString*)folderString;
+ (void)deleteBookmark:(NSString*)n fromFolderString:(NSString*)folderString;

+ (PSBookmarkFolder*)getBookmarkFolderForFolderString:(NSString*)folderString;
+ (NSMutableArray *)getBookmarksForBookAndChapterRef:(NSString*)bookAndChapterRef;
+ (NSMutableArray *)getBookmarksForCurrentRef;
+ (NSString *)getHighlightRGBColourStringForBookAndChapterRef:(NSString*)bookAndChapterRef withVerse:(NSInteger)verse;

+ (NSDate *)lastModified;

+ (BOOL)saveBookmarksToFile;
+ (void)importBookmarksFromV2;

// Positional-array (de)serialization for the on-disk PSBookmarks.plist schema.
// Exposed for the Wave-0c persisted-format guard tests; behaviour is unchanged.
//   WRITE +parseBookmarkObject:  folder   -> [name, dateAdded, dateLastAccessed, @"YES", rgb-or-@"", children] (6)
//                                bookmark -> [name, dateAdded, dateLastAccessed, @"NO", ref] (5)
//   READ  -parseArray:           idx3 -boolValue selects folder/bookmark; folder rgb@4 (""->nil) + children@5; bookmark ref@4.
+ (NSArray *)parseBookmarkObject:(PSBookmarkObject*)bookmarkObject;
- (PSBookmarkObject *)parseArray:(NSArray *)array;

@end
