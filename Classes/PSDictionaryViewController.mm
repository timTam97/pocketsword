//
//  PSDictionaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSDictionaryViewController.h"
#import "PSModuleController.h"



@implementation PSDictionaryViewController

int prevLength = 0;
BOOL dictionaryEnabled = NO;

- (void)reloadDictionaryData:(BOOL)reloadData {
	BOOL needsReload = reloadData;
	if(![moduleManager primaryDictionary]) {
		NSString *lastDictionary = [[NSUserDefaults standardUserDefaults] stringForKey: @"lastDictionary"];
		
		if (lastDictionary) {
			[moduleManager loadPrimaryDictionary: lastDictionary];
			needsReload = YES;
		} else {
			[dictionaryTitle setTitle: NSLocalizedString(@"None", @"None")];
		}
	}
	
	if([moduleManager primaryDictionary]) {
		if(![[moduleManager primaryDictionary] keysLoaded]) {
			if(![[moduleManager primaryDictionary] keysCached]) {
				//ask whether to cache the keys now or another time
				
				[[[UIAlertView alloc] initWithTitle: [NSString stringWithFormat: @"%@ %@", [[moduleManager primaryDictionary] name], NSLocalizedString(@"CacheDictionaryKeysTitle", @"Cache?")] message: NSLocalizedString(@"CacheDictionaryKeysMsg", @"Cache the keys?") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
				return;
			} else {
				//need to load it
				[moduleManager displayBusyIndicator];
				
				[[moduleManager primaryDictionary] allKeys];
				
				[moduleManager hideBusyIndicator];
				needsReload = YES;
			}
		}
	}
	[dictionarySearchBar setUserInteractionEnabled: YES];
	dictionaryEnabled = YES;
	if(needsReload) {
		[dictionaryEntriesTable reloadData];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (buttonIndex == 1) {
		[moduleManager displayBusyIndicator];
		
		[[moduleManager primaryDictionary] allKeys];
		
		[moduleManager hideBusyIndicator];
		dictionaryEnabled = YES;
		[dictionarySearchBar setUserInteractionEnabled: YES];
	} else {
		[dictionarySearchBar setUserInteractionEnabled: NO];
		dictionaryEnabled = NO;
	}
	
	[dictionaryEntriesTable reloadData];
	[pool release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[self reloadDictionaryData:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)dealloc {
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(dictionaryEnabled)
		return [[moduleManager primaryDictionary] entryCount];
	else
		return 0;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
//	tableView.sectionHeaderHeight = 22.5;
//	if ([[moduleManager primaryDictionary] entryCount] == 0) {
//		return @"";//NSLocalizedString(@"NoModulesRefresh", @"No modules here. Try a refresh.");
//	}
//	else
//		return [[moduleManager primaryDictionary] descr];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dict-id"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"dict-id"] autorelease];
	}
	
	cell.textLabel.text = [[[moduleManager primaryDictionary] allKeys] objectAtIndex:indexPath.row];
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[dictionarySearchBar resignFirstResponder];
	//NSLog(@"selected: %@", [[moduleManager primaryDictionary] entryForKey: [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text]);
	[dictionaryDescriptionTitle setTitle: [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text];
	NSString *descr = [[moduleManager primaryDictionary] entryForKey: dictionaryDescriptionTitle.title];
	descr = [PSModuleController createHTMLString: descr usingPreferences: YES withJS: @""];
	[dictionaryDescriptionWebView loadHTMLString: descr baseURL: nil];
	
	[self showDescription: nil];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	int row = 0;
	if([searchText length] > prevLength) {
		NSIndexPath *tableSelection = [[dictionaryEntriesTable indexPathsForVisibleRows] objectAtIndex: 0];
		if(tableSelection)
			row = tableSelection.row;
		//we can continue searching from the current index
	} else {
		//start searching from the start
	}
	int count = [[moduleManager primaryDictionary] entryCount];
	for(; row < count; row++) {
		NSComparisonResult res = [searchText caseInsensitiveCompare: [[[moduleManager primaryDictionary] allKeys] objectAtIndex: row]];
		if(res <= NSOrderedSame)
			break;
	}
	if(row == count)
		row--;
	NSIndexPath *newIP = [NSIndexPath indexPathForRow: row inSection: 0];
	[dictionaryEntriesTable scrollToRowAtIndexPath: newIP atScrollPosition: UITableViewScrollPositionTop animated: YES];
	prevLength = [searchText length];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (IBAction)showDescription:(id)sender {
	[self showModal: dictionaryDescriptionView withTiming: 0.3];
}

- (IBAction)hideDescription:(id)sender {
	[self hideModal: dictionaryDescriptionView withTiming: 0.3];
}

// Use this to show the modal view (pops-up from the bottom)
// try a time of 0.7 to start with...
- (void) showModal:(UIView*)modalView withTiming:(float)time
{
	
	CGSize modalSize = modalView.bounds.size;
	//CGPoint middleCenter = modalView.center;
	CGSize offSize = [self view].bounds.size;
	CGPoint middleCenter = CGPointMake(modalSize.width / 2.0, offSize.height - (modalSize.height / 2.0));
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
	modalView.center = offScreenCenter; // we start off-screen
	[[self view] addSubview:modalView];
	
	// Show it with a transition effect
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:time]; // animation duration in seconds
	modalView.center = middleCenter;
	[UIView commitAnimations];
}

- (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	UIView* modalView = (UIView *)context;
	[modalView removeFromSuperview];
}

// Use this to slide the semi-modal view back down.
- (void) hideModal:(UIView*) modalView withTiming:(float)time
{
	CGSize offSize = [self view].bounds.size;
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
	[UIView beginAnimations:nil context:modalView];
	[UIView setAnimationDuration:time];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(hideModalEnded:finished:context:)];
	modalView.center = offScreenCenter;
	[UIView commitAnimations];
}


@end
