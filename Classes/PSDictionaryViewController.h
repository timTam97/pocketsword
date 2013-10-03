//
//  PSDictionaryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "MBProgressHUD.h"

@protocol PSDictionaryViewControllerDelegate <NSObject>
@required
- (void)toggleModulesListFromButton:(id)sender;
@end

@class PSDictionaryOverlayViewController;

@interface PSDictionaryViewController : UITableViewController <UISearchBarDelegate, MBProgressHUDDelegate> {

	UISearchBar		*dictionarySearchBar;
	
	BOOL			searching;
	BOOL			letUserSelectRow;
	NSMutableArray	*searchResults;
	BOOL			dictionaryEnabled;

	PSDictionaryOverlayViewController *overlayViewController;
	id <PSDictionaryViewControllerDelegate> delegate;
}

@property (nonatomic, assign) id <PSDictionaryViewControllerDelegate> delegate;
@property (retain) UISearchBar *dictionarySearchBar;

- (void)reloadDictionaryData;
- (void)reloadDictionaryData:(BOOL)reloadData;
- (void)hideDescription:(id)sender;
- (void)searchDictionaryEntries;
- (void)setDictionaryTitleViaNotification;

@end
