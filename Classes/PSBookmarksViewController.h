//
//  PSBookmarksViewController.h
//  PocketSword
//
//  Created by Nic Carter on 19/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//


@interface PSBookmarksViewController : UITableViewController {
	IBOutlet UITableView *bookmarksTable;
	IBOutlet UINavigationItem *bookmarksNavBar;
	
	IBOutlet id moduleManager;
}

- (IBAction)toggleBookmarksTableEditing:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (void)removeBookmark:(NSString *)ref;

@end
