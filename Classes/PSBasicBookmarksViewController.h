//
//  PSBookmarksViewController.h
//  PocketSword
//
//  Created by Nic Carter on 19/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//
//
//	Bookmarks v3 should have the following:
//
//  Edit button in the top right corner, to delete a bookmark, add a folder & reorder.  Also deletes a folder, after a confirmation dialogue?
//  Embedded into a NavigationController.
//  Title is the current folder's name, or bookmark's ref
//  Each bookmark has a disclosure button which shows the details of the Bookmark
//  Each folder has a disclosure button which allows editing of the colour used for highlighting.
//
//  Each page of the Nav has: list of folders & bookmarks at this level.
//		UITableViewCellStyleSubtitle -> text = name && detailText = ref; imageView = either folder or bookmark icon.
//  Each Bookmark item, therefore, can be a folder or proper bookmark?


@interface PSBasicBookmarksViewController : UITableViewController {
	IBOutlet UITableView *bookmarksTable;
	IBOutlet UINavigationItem *bookmarksNavItem;
	IBOutlet UINavigationBar *bookmarksNavBar;
	
	//IBOutlet id moduleManager;
	//IBOutlet id viewController;
}

+ (void)addBookmarkForRef:(NSString*)bookAndChapterRef withVerse:(NSString*)verse;

- (IBAction)toggleBookmarksTableEditing:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (void)removeBookmark:(NSString *)ref;

@end
