//
//  PSDictionaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSDictionaryOverlayViewController.h"
#import "PSDictionaryViewController.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import "PSDictionaryEntryViewController.h"
#import "globals.h"
#import "SwordModule.h"
#import "SwordDictionary.h"
#import "SwordManager.h"

@implementation PSDictionaryViewController

@synthesize dictionarySearchBar, delegate;

- (void)dictionaryModuleSelectorButtonPressed:(id)sender {
	[delegate toggleModulesListFromButton:sender];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = NSLocalizedString(@"TabBarTitleDictionary", @"Dictionary");
	
	UIBarButtonItem *dictButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"None", @"None") style:UIBarButtonItemStylePlain target:self action:@selector(dictionaryModuleSelectorButtonPressed:)];
	self.navigationItem.rightBarButtonItem = dictButton;
	
	UISearchBar *dSB = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, 44)];
	dSB.delegate = self;
	dSB.barStyle = UIBarStyleBlack;
	dSB.placeholder = NSLocalizedString(@"DictionarySearchPlaceholderText", @"Search Dictionary");
	self.dictionarySearchBar = dSB;
	
	self.tableView.tableHeaderView = dictionarySearchBar;
	searching = NO;
	letUserSelectRow = YES;
	dictionaryEnabled = NO;
	searchResults = [[NSMutableArray alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(primaryDictionaryChanged) name:NotificationPrimaryDictionaryChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDictionaryData) name:NotificationReloadDictionaryData object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDictionaryEntriesTable) name:NotificationNightModeChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setDictionaryTitleViaNotification) name:NotificationNewPrimaryDictionary object:nil];
	//[self setDictionaryTitleViaNotification];
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	searchResults = nil;
	[super viewDidUnload];
}


- (void)primaryDictionaryChanged {
	[self.navigationItem.rightBarButtonItem setTitle: NSLocalizedString(@"None", @"None")];
}

- (void)reloadDictionaryData {
	[self reloadDictionaryData:YES];
}

- (void)setDictionaryTitleViaNotification {
	@autoreleasepool {
		SwordModule *primaryDictionary = [[PSModuleController defaultModuleController] primaryDictionary];
		if(primaryDictionary) {
			NSString *newText = [primaryDictionary name];
			NSUInteger i = ([newText length] > 8) ? 8 : [newText length];
			//but ".." is the equiv of another char, so if length <= 9, use the full name.  eg "Swe1917Of" should display full name.
			NSString *newTitle = ([newText length] <= 9) ? newText : [NSString stringWithFormat:@"%@..", [newText substringToIndex:i]];
			[self.navigationItem.rightBarButtonItem setTitle: newTitle];
		} else {
			[self.navigationItem.rightBarButtonItem setTitle: NSLocalizedString(@"None", @"None")];
		}
	}
}

- (void)reloadDictionaryData:(BOOL)reloadData {
	//BOOL needsReload = reloadData;
	if(![[PSModuleController defaultModuleController] primaryDictionary]) {
		NSString *lastDictionary = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDictionary];
		
		if (lastDictionary) {
			[[PSModuleController defaultModuleController] loadPrimaryDictionary: lastDictionary];
			//needsReload = YES;
		} else {
			[self.navigationItem.rightBarButtonItem setTitle: NSLocalizedString(@"None", @"None")];
			[dictionarySearchBar setUserInteractionEnabled: NO];
			dictionaryEnabled = NO;
			[self.tableView reloadData];
			return;
		}
	}
	
	if([[PSModuleController defaultModuleController] primaryDictionary]) {
		if(![[[PSModuleController defaultModuleController] primaryDictionary] keysLoaded]) {
			if(![[[PSModuleController defaultModuleController] primaryDictionary] keysCached]) {
				//ask whether to cache the keys now or another time
				
				UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat: @"%@ %@", [[[PSModuleController defaultModuleController] primaryDictionary] name], NSLocalizedString(@"CacheDictionaryKeysTitle", @"Cache?")] message: NSLocalizedString(@"CacheDictionaryKeysMsg", @"Cache the keys?") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
				[alertView show];
				return;
			} else {
				
                 //need to load it
                
                MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                [self.view addSubview:HUD];

                // Regiser for HUD callbacks so we can remove it from the window at the right time
                HUD.delegate = self;
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    
                    
                    [[[PSModuleController defaultModuleController] primaryDictionary] performSelector:@selector(allKeys) withObject:nil];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [HUD hideAnimated:YES];
                    });
                });

                //needsReload = YES;
                
                
                
                
//                //need to load it
//				MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:self.view];
//				[self.view addSubview:HUD];
//				
//				// Regiser for HUD callbacks so we can remove it from the window at the right time
//				HUD.delegate = self;
//				
//				// Show the HUD while the provided method executes in a new thread
//				[HUD showWhileExecuting:@selector(allKeys) onTarget:[[PSModuleController defaultModuleController] primaryDictionary] withObject:nil animated:YES];
//
//				needsReload = YES;
			}
		}
	}
	[dictionarySearchBar setUserInteractionEnabled: YES];
	dictionaryEnabled = YES;
//	if(needsReload) {
//		if(searching)
//			[self searchDictionaryEntries];
//		[self.tableView reloadData];
//	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	@autoreleasepool {
	
		if (buttonIndex == 1) {
            
            
            
            
            MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            
            [self.view addSubview:HUD];
            
            // Regiser for HUD callbacks so we can remove it from the window at the right time
            
            HUD.delegate = self;
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                
                [[[PSModuleController defaultModuleController] primaryDictionary] performSelector:@selector(allKeys) withObject:nil];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [HUD hideAnimated:YES];
                });
            });
            
            
            
            ////////////////////////////////////////////////////////////////////////////////
            // Code updated to newer MBProgressHUD code
            ////////////////////////////////////////////////////////////////////////////////
//
//			MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:self.view];
//			[self.view addSubview:HUD];
//			
//			// Regiser for HUD callbacks so we can remove it from the window at the right time
//			HUD.delegate = self;
//			
//			// Show the HUD while the provided method executes in a new thread
//			[HUD showWhileExecuting:@selector(allKeys) onTarget:[[PSModuleController defaultModuleController] primaryDictionary] withObject:nil animated:YES];
//            
            ////////////////////////////////////////////////////////////////////////////////
            
			dictionaryEnabled = YES;
			[dictionarySearchBar setUserInteractionEnabled: YES];
		} else {
			[dictionarySearchBar setUserInteractionEnabled: NO];
			dictionaryEnabled = NO;
			[self.tableView reloadData];
		}
	
//	if(searching)
//		[self searchDictionaryEntries];
//	[self.tableView reloadData];
	}
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	hud = nil;
	if(searching)
		[self searchDictionaryEntries];
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:self.tableView useStatusBar:YES];
	[self reloadDictionaryData:NO];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:self.tableView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)reloadDictionaryEntriesTable {
	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(searching)
		return [searchResults count];
	else if(dictionaryEnabled)
		return [[[PSModuleController defaultModuleController] primaryDictionary] entryCount];
	else
		return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(searching && ([searchResults count] > 0)) {
		return [NSString stringWithFormat: @"%lu %@", (unsigned long)[searchResults count], NSLocalizedString(@"SearchResults", @"results")];
	} else if(!dictionaryEnabled) {
		return NSLocalizedString(@"DictionaryNoneLoaded", @"DictionaryNoneLoaded");
	} else {
		return @"";
	}
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dict-id"];
	if (!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"dict-id"];
	}
	if(searching) {
		cell.textLabel.text = [searchResults objectAtIndex:indexPath.row];
	} else if(dictionaryEnabled) {
		cell.textLabel.text = [[[[PSModuleController defaultModuleController] primaryDictionary] allKeys] objectAtIndex:indexPath.row];
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[dictionarySearchBar resignFirstResponder];
	NSString *t = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	NSString *descr = [[[PSModuleController defaultModuleController] primaryDictionary] entryForKey: t];
	descr = [PSModuleController createInfoHTMLString: [NSString stringWithFormat: @"<div style=\"-webkit-text-size-adjust: none;\"><b>%@</b><br /><p>%@</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>", t, descr] usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryDictionary] name]];
	
	PSDictionaryEntryViewController *entryVC = [[PSDictionaryEntryViewController alloc] initWithNibName:nil bundle:nil];
	[entryVC setDictionaryEntryTitle:t];
	[entryVC setDictionaryEntryText:descr];
	if([[[PSModuleController defaultModuleController] primaryDictionary] hasFeature:SWMOD_CONF_FEATURE_IMAGES]) {
		[entryVC setScalesPageToFit:YES];
	} else {
		[entryVC setScalesPageToFit:NO];
	}
	if(self.navigationController) {
		[self.navigationController pushViewController:entryVC animated:YES];
	} else {
		[self presentModalViewController:entryVC animated:YES];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
	
	//Add the overlay view.
	if(!overlayViewController) {
		overlayViewController = [[PSDictionaryOverlayViewController alloc] initWithNibName:nil bundle:nil];
	
//		CGFloat yaxis = self.navigationController.navigationBar.frame.size.height;
//		yaxis += self.tableView.tableHeaderView.frame.size.height;
		CGFloat yaxis = self.tableView.tableHeaderView.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		
		//Parameters x = origion on x-axis, y = origon on y-axis.
		CGRect frame = CGRectMake(0, yaxis, width, height);
		overlayViewController.view.frame = frame;
		
		overlayViewController.dictionaryViewController = self;
	}

	searching = YES;

	if([dictionarySearchBar.text length] <= 0) {
		//self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		[self.tableView insertSubview:overlayViewController.view aboveSubview:self.parentViewController.view];
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	} else {
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
	}
	
	[dictionarySearchBar setShowsCancelButton:YES animated:YES];
	[self searchDictionaryEntries];
	[self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {

	[searchResults removeAllObjects];
	
	if([searchText length] > 0) {
		[overlayViewController.view removeFromSuperview];
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
		searching = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[self searchDictionaryEntries];
	} else {
		[self.tableView insertSubview:overlayViewController.view aboveSubview:self.parentViewController.view];
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		searching = YES;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	[self.tableView reloadData];
	
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	self.tableView.tableHeaderView = dictionarySearchBar;
}

//- (void)cancelSearch:(id)sender {
//	[self searchBarCancelButtonClicked:nil];
//}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	if([dictionarySearchBar isFirstResponder])
		[dictionarySearchBar resignFirstResponder];
	
	letUserSelectRow = YES;
	searching = NO;
	self.tableView.scrollEnabled = YES;
	
	[overlayViewController.view removeFromSuperview];
	overlayViewController = nil;
	[dictionarySearchBar setShowsCancelButton:NO animated:YES];

	self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	[searchResults removeAllObjects];
	[self.tableView reloadData];
	dictionarySearchBar.text = @"";
}

- (void)searchDictionaryEntries {
	
	[searchResults removeAllObjects];
	NSString *searchText = dictionarySearchBar.text;
	NSArray *keys = [[[PSModuleController defaultModuleController] primaryDictionary] allKeys];
	
	for (NSString *t in keys) {
		NSRange titleResultsRange = [t rangeOfString:searchText options:NSCaseInsensitiveSearch];
		
		if (titleResultsRange.length > 0)
			[searchResults addObject:t];
	}
}

- (void)hideDescription:(id)sender {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideInfoPane object:nil];
	[self dismissModalViewControllerAnimated:YES];
}

@end

