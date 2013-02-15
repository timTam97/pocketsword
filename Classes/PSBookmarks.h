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

@end
