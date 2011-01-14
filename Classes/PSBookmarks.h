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

+ (PSBookmarks *)defaultBookmarks;
+ (BOOL)addBookmarkObject:(PSBookmarkObject*)bookmark withFolderString:(NSString*)folderString;
+ (BOOL)addBookmarkWithRef:(NSString*)r name:(NSString*)n folderString:(NSString*)folderString;

+ (PSBookmarkFolder*)getBookmarkFolderForFolderString:(NSString*)folderString;

@end
