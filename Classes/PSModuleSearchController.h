//
//  PSModuleSearchController.h
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"
#import "PSIndexController.h"
#import "MBProgressHUD.h"
#import "PSSearchOptionTableViewController.h"

@class PSSearchHistoryItem;

@protocol PSModuleSearchControllerDelegate <NSObject>
@required
- (void)searchDidFinish:(PSSearchHistoryItem*)newSearchHistoryItem;
@end

@interface PSModuleSearchController : UIViewController <PSSearchOptionsDelegate, UITabBarControllerDelegate, MBProgressHUDDelegate, PSIndexControllerDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource> {

	id <PSModuleSearchControllerDelegate> delegate;
	
	ShownTab listType;

	UITableView *searchQueryTable;
	UIView *searchQueryView;
	UITableView *searchResultsTable;
	UISearchBar *searchBar;
	BOOL switchingTabs;
	
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

@property (retain) UITableView *searchQueryTable;
@property (retain) UIView *searchQueryView;
@property (retain) UITableView *searchResultsTable;
@property (retain) UISearchBar *searchBar;

@property (nonatomic, assign) id <PSModuleSearchControllerDelegate> delegate;
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
- (void)setSearchTitle;

- (void)refreshView;
- (void)setListType:(ShownTab)listType;
- (ShownTab)listType;

- (void)saveTablePositionFromCurrentPosition;
- (void)notifyDelegateOfNewHistoryItem;

- (void)searchBarSearchButtonClicked:(UISearchBar *)sBar;

- (void)indexInstalled:(PSIndexController*)sender;

- (void)searchButtonPressed:(id)sender;

@end
