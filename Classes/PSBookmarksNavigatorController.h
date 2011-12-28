//
//  PSBookmarksNavigatorController.h
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolder.h"

@interface PSBookmarksNavigatorController : UITableViewController {
	PSBookmarkFolder *bookmarkFolder;
	BOOL isAddingBookmark;
	NSString *parentFolders;
	BOOL displayAddFolderRow;
	NSIndexPath *rowToDelete;
	BOOL bookmarksEditing;
}

@property (retain, readwrite) PSBookmarkFolder *bookmarkFolder;
@property (readwrite) BOOL isAddingBookmark;
@property (readonly) NSString* parentFolders;

- (id)initWithBookmarkFolder:(PSBookmarkFolder*)folder parentFolders:(NSString*)parentFoldersString isAddingBookmark:(BOOL)adding;
- (void)deleteChildAtIndexPath:(NSIndexPath *)indexPath;

@end
