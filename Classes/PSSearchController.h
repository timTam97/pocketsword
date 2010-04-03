//
//  PSSearchController.h
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "DataController.h"
#import "SwordListKey.h"

@interface PSSearchController : UIViewController {

	IBOutlet DataController *dataController;
	IBOutlet PSModuleController *moduleManager;
	IBOutlet UITableView *resultsTable;
	IBOutlet UISearchBar *sBar;
	IBOutlet UIBarButtonItem *closeButton;
	
	UIView *helpView;
	NSString *searchTerm;

	//SwordListKey *results;
	NSMutableArray *results;
}

@property (retain, readwrite) NSMutableArray *results;
@property (retain, readwrite) NSString *searchTerm;

- (void)refreshView;
//- (void)hideKeyboard;

- (IBAction)infoButtonPressed:(id)sender;

@end
