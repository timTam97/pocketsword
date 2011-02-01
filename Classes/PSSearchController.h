//
//  PSSearchController.h
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"
#import "PSSearchHistoryItem.h"

@protocol PSSearchControllerDelegate <NSObject>
@required
- (void)searchDidFinish:(PSSearchHistoryItem*)newSearchHistoryItem;
@end

@interface PSSearchController : UIViewController {

	id <PSSearchControllerDelegate> delegate;
	
	ShownTab listType;

	//IBOutlet HistoryController *historyController;
	IBOutlet UITableView *searchQueryTable;
	IBOutlet UIView *searchQueryView;
	IBOutlet UITableView *searchResultsTable;
	IBOutlet UISearchBar *searchBar;
	IBOutlet UIBarButtonItem *closeButton;
	IBOutlet UINavigationBar *searchNavigationBar;
	IBOutlet UINavigationItem *searchNavigationItem;
	
	UIView *helpView;
	NSString *searchTerm;
	NSString *searchTermToDisplay;
	BOOL searchingEnabled;
	
	BOOL strongsSearch;
	PSSearchType searchType;
	PSSearchRange searchRange;
	NSString *bookName;

	NSMutableArray *results;
}

@property (nonatomic, assign) id <PSSearchControllerDelegate> delegate;
@property (retain, readwrite) NSString *searchTerm;
@property (retain, readwrite) NSString *searchTermToDisplay;
@property (assign, readwrite) BOOL strongsSearch;
@property (assign, readwrite) PSSearchType searchType;
@property (assign, readwrite) PSSearchRange searchRange;
@property (retain, readwrite) NSString *bookName;
@property (retain, readwrite) NSMutableArray *results;

- (id)initWithSearchHistoryItem:(PSSearchHistoryItem*)searchHistoryItem;

- (void)setSearchHistoryItem:(PSSearchHistoryItem*)searchHistoryItem;

- (void)refreshView;
- (void)setListType:(ShownTab)listType;

- (IBAction)infoButtonPressed:(id)sender;
- (IBAction)closeButtonPressed;

- (IBAction)searchButtonPressed:(id)sender;

@end
