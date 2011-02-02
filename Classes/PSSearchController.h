//
//  PSSearchController.h
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"
#import "PSSearchHistoryItem.h"
#import "PSSearchOptionTableViewController.h"

@protocol PSSearchControllerDelegate <NSObject>
@required
- (void)searchDidFinish:(PSSearchHistoryItem*)newSearchHistoryItem;
@end

@interface PSSearchController : UIViewController <PSSearchOptionsDelegate> {

	id <PSSearchControllerDelegate> delegate;
	
	ShownTab listType;

	IBOutlet UITableView *searchQueryTable;
	IBOutlet UIView *searchQueryView;
	IBOutlet UITableView *searchResultsTable;
	IBOutlet UISearchBar *searchBar;
	
	UIView *helpView;
	
	// the below are basically the current PSSearchHistoryItem
	//  should we remove them & simply have our own item instead?
	NSString *searchTerm;
	NSString *searchTermToDisplay;
	BOOL searchingEnabled;
	BOOL strongsSearch;
	BOOL fuzzySearch;
	PSSearchType searchType;
	PSSearchRange searchRange;
	NSString *bookName;
	NSMutableArray *results;
	NSArray *savedTablePosition;
}

@property (nonatomic, assign) id <PSSearchControllerDelegate> delegate;
@property (retain, readwrite) NSString *searchTerm;
@property (retain, readwrite) NSString *searchTermToDisplay;
@property (assign, readwrite) BOOL strongsSearch;
@property (assign, readwrite) BOOL fuzzySearch;
@property (assign, readwrite) PSSearchType searchType;
@property (assign, readwrite) PSSearchRange searchRange;
@property (retain, readwrite) NSString *bookName;
@property (retain, readwrite) NSMutableArray *results;
@property (retain, readwrite) NSArray *savedTablePosition;

- (id)initWithSearchHistoryItem:(PSSearchHistoryItem*)searchHistoryItem;

- (void)setSearchHistoryItem:(PSSearchHistoryItem*)searchHistoryItem;

- (void)refreshView;
- (void)setListType:(ShownTab)listType;

- (void)saveTablePositionFromCurrentPosition;
- (void)notifyDelegateOfNewHistoryItem;

- (IBAction)infoButtonPressed:(id)sender;
- (IBAction)closeButtonPressed;

- (IBAction)searchButtonPressed:(id)sender;

@end
