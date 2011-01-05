//
//  PSDictionaryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//


@interface PSDictionaryEntryViewController : UIViewController {
	IBOutlet UIToolbar	*dictionaryDescriptionToolbar;
	IBOutlet UIWebView	*dictionaryDescriptionWebView;
}

@end

@interface PSDictionaryViewController : UIViewController <UISearchBarDelegate, UITableViewDelegate> {

	IBOutlet UITabBarItem		*dictionaryTabBarItem;
	IBOutlet UITableView		*dictionaryEntriesTable;
	IBOutlet UISearchBar		*dictionarySearchBar;
	IBOutlet UIBarButtonItem	*dictionaryTitle;
	IBOutlet UINavigationItem	*dictionaryNavItem;
	IBOutlet UINavigationBar	*dictionaryNavBar;
	
	IBOutlet PSDictionaryEntryViewController	*dictionaryDescriptionViewController;
	IBOutlet UIBarButtonItem	*dictionaryDescriptionTitle;
	IBOutlet UIWebView			*dictionaryDescriptionWebView;
	
	//IBOutlet id moduleManager;
	
	BOOL searching;
	BOOL letUserSelectRow;
	NSMutableArray *searchResults;
	BOOL dictionaryEnabled;

	id overlayViewController;
}

- (void)reloadDictionaryData;
- (void)reloadDictionaryData:(BOOL)reloadData;
- (void)showDescription:(NSString*)description withTitle:(NSString*)t;
- (IBAction)hideDescription:(id)sender;
- (void)searchDictionaryEntries;

@end
