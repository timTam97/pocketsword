//
//  PSBookmarksViewController.h
//  PocketSword
//
//  Created by Nic Carter on 19/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//


@interface PSBookmarksViewController : UITableViewController {
	IBOutlet UITableView *bookmarksTable;
	IBOutlet UINavigationItem *bookmarksNavItem;
	IBOutlet UINavigationBar *bookmarksNavBar;
	
	//IBOutlet id moduleManager;
	IBOutlet id viewController;
}

+ (void)addBookmarkForRef:(NSString*)bookAndChapterRef withVerse:(NSString*)verse;

- (IBAction)toggleBookmarksTableEditing:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (void)removeBookmark:(NSString *)ref;

@end
