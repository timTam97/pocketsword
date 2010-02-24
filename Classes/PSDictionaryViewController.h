//
//  PSDictionaryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//


@interface PSDictionaryViewController : UIViewController <UISearchBarDelegate, UITableViewDelegate> {

	IBOutlet UITableView *dictionaryEntriesTable;
	IBOutlet UISearchBar *dictionarySearchBar;
	IBOutlet UIBarButtonItem *dictionaryTitle;
	
	IBOutlet UIView *dictionaryDescriptionView;
	IBOutlet UIBarButtonItem *dictionaryDescriptionTitle;
	IBOutlet UIWebView *dictionaryDescriptionWebView;
	
	IBOutlet id moduleManager;
	
}

- (void)reloadDictionaryData:(BOOL)reloadData;
- (IBAction)showDescription:(id)sender;
- (IBAction)hideDescription:(id)sender;

- (void) showModal:(UIView*)modalView withTiming:(float)time;
- (void) hideModal:(UIView*) modalView withTiming:(float)time;

@end
