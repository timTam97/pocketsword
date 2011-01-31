//
//  PSSearchController.h
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"

@protocol PSSearchControllerDelegate <NSObject>
@required
- (void)searchTermDidChange:(NSString *)newSearchTerm withResults:(NSMutableArray *)newResults;
@end

@interface PSSearchController : UIViewController {

	id <PSSearchControllerDelegate> delegate;
	
	ShownTab listType;

	//IBOutlet HistoryController *historyController;
	IBOutlet UITableView *searchResultsTable;
	IBOutlet UISearchBar *searchBar;
	IBOutlet UIBarButtonItem *closeButton;
	IBOutlet UINavigationBar *searchNavigationBar;
	
	UIView *helpView;
	NSString *searchTerm;
	NSString *searchTermToDisplay;
	BOOL searchingEnabled;

	NSMutableArray *results;
}

@property (retain, readwrite) NSMutableArray *results;
@property (retain, readwrite) NSString *searchTerm;
@property (retain, readwrite) NSString *searchTermToDisplay;
@property (nonatomic, assign) id <PSSearchControllerDelegate> delegate;

- (void)refreshView;
//- (void)hideKeyboard;

- (void)setListType:(ShownTab)listType;
//- (ShownTab)listType;

- (IBAction)infoButtonPressed:(id)sender;
- (IBAction)closeButtonPressed;

@end
