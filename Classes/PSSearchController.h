//
//  PSSearchController.h
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "HistoryController.h"
#import "PSModuleController.h"
#import "SwordListKey.h"

@interface PSSearchController : UIViewController {

	IBOutlet HistoryController *historyController;
	IBOutlet UITableView *searchResultsTable;
	IBOutlet UISearchBar *searchBar;
	IBOutlet UIBarButtonItem *closeButton;
	IBOutlet UINavigationBar *searchNavigationBar;
	
	UIView *helpView;
	NSString *searchTerm;
	BOOL searchingEnabled;

	NSMutableArray *results;
}

@property (retain, readwrite) NSMutableArray *results;
@property (retain, readwrite) NSString *searchTerm;

- (void)refreshView;
//- (void)hideKeyboard;

- (IBAction)infoButtonPressed:(id)sender;

@end
