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


@implementation PSDictionaryViewController

BOOL dictionaryEnabled = NO;
PSDictionaryOverlayViewController *overlayViewController;

- (void)primaryDictionaryChanged {
	[dictionaryTitle setTitle: NSLocalizedString(@"None", @"None")];
}

- (void)reloadDictionaryData {
	[self reloadDictionaryData:YES];
}

- (void)reloadDictionaryData:(BOOL)reloadData {
	BOOL needsReload = reloadData;
	if(![[PSModuleController defaultModuleController] primaryDictionary]) {
		NSString *lastDictionary = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDictionary];
		
		if (lastDictionary) {
			[[PSModuleController defaultModuleController] loadPrimaryDictionary: lastDictionary];
			needsReload = YES;
		} else {
			[dictionaryTitle setTitle: NSLocalizedString(@"None", @"None")];
			[dictionarySearchBar setUserInteractionEnabled: NO];
			dictionaryEnabled = NO;
			[dictionaryEntriesTable reloadData];
			return;
		}
	}
	
	if([[PSModuleController defaultModuleController] primaryDictionary]) {
		if(![[[PSModuleController defaultModuleController] primaryDictionary] keysLoaded]) {
			if(![[[PSModuleController defaultModuleController] primaryDictionary] keysCached]) {
				//ask whether to cache the keys now or another time
				
				[[[UIAlertView alloc] initWithTitle: [NSString stringWithFormat: @"%@ %@", [[[PSModuleController defaultModuleController] primaryDictionary] name], NSLocalizedString(@"CacheDictionaryKeysTitle", @"Cache?")] message: NSLocalizedString(@"CacheDictionaryKeysMsg", @"Cache the keys?") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
				return;
			} else {
				//need to load it
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
				//[[PSModuleController defaultModuleController] displayBusyIndicator];
				
				[[[PSModuleController defaultModuleController] primaryDictionary] allKeys];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
				//[[PSModuleController defaultModuleController] hideBusyIndicator];
				needsReload = YES;
			}
		}
	}
	[dictionarySearchBar setUserInteractionEnabled: YES];
	dictionaryEnabled = YES;
	if(needsReload) {
		if(searching)
			[self searchDictionaryEntries];
		[dictionaryEntriesTable reloadData];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (buttonIndex == 1) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
		//[[PSModuleController defaultModuleController] displayBusyIndicator];
		
		[[[PSModuleController defaultModuleController] primaryDictionary] allKeys];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
		//[[PSModuleController defaultModuleController] hideBusyIndicator];
		dictionaryEnabled = YES;
		[dictionarySearchBar setUserInteractionEnabled: YES];
	} else {
		[dictionarySearchBar setUserInteractionEnabled: NO];
		dictionaryEnabled = NO;
	}
	
	if(searching)
		[self searchDictionaryEntries];
	[dictionaryEntriesTable reloadData];
	[pool release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[self reloadDictionaryData:NO];
	dictionaryEntriesTable.tableHeaderView = dictionarySearchBar;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)dealloc {
    [super dealloc];
	[dictionarySearchBar release];
	[searchResults release];
	[overlayViewController release];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidLoad {
	dictionaryTabBarItem.title = NSLocalizedString(@"TabBarTitleDictionary", @"Dictionary");
	dictionaryNavItem.title = NSLocalizedString(@"TabBarTitleDictionary", @"Dictionary");
	dictionarySearchBar.placeholder = NSLocalizedString(@"DictionarySearchPlaceholderText", @"Search Dictionary");
	[dictionarySearchBar retain];//hack to try to make our search bar never run away!
	dictionaryEntriesTable.tableHeaderView = dictionarySearchBar;
	searching = NO;
	letUserSelectRow = YES;
	searchResults = [[NSMutableArray alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(primaryDictionaryChanged) name:NotificationPrimaryDictionaryChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDictionaryData) name:NotificationReloadDictionaryData object:nil];
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationPrimaryDictionaryChanged object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationReloadDictionaryData object:nil];
	[searchResults release];
	searchResults = nil;
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
	if(searching && ([searchResults count] > 0))
		return [NSString stringWithFormat: @"%d %@", [searchResults count], NSLocalizedString(@"SearchResults", @"results")];
	else
		return @"";
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dict-id"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"dict-id"] autorelease];
	}
	if(searching)
		cell.textLabel.text = [searchResults objectAtIndex:indexPath.row];
	else
		cell.textLabel.text = [[[[PSModuleController defaultModuleController] primaryDictionary] allKeys] objectAtIndex:indexPath.row];
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[dictionarySearchBar resignFirstResponder];
	NSString *t = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	NSString *descr = [[[PSModuleController defaultModuleController] primaryDictionary] entryForKey: t];
	[self showDescription:descr withTitle:t];
}

- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (void)showDescription:(NSString*)description withTitle:(NSString*)t {
	NSString *javaScript = @"<script type=\"text/javascript\">\n<!--\n\
							window.onload = function() { document.documentElement.style.webkitTouchCallout = \"none\"; }\n\
							-->\
							</script>\n";
	NSString *descr = [PSModuleController createHTMLString: [NSString stringWithFormat: @"<b>%@</b><br />%@<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>", t, description] usingPreferences: YES withJS: javaScript];
	if([t length] > 20) {
		t = [NSString stringWithFormat: @"%@...", [t substringToIndex: 20]];
	}
	[dictionaryDescriptionTitle setTitle: t];
	[dictionaryDescriptionWebView loadHTMLString: descr baseURL: nil];
	//NSLog(@"%@", description);
	
	if(![dictionaryDescriptionViewController.view superview]) {
		[self presentModalViewController:dictionaryDescriptionViewController animated:YES];
		//[self showModal: dictionaryDescriptionView withTiming: 0.3];
	}
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
	
	//Add the overlay view.
	if(!overlayViewController) {
		overlayViewController = [[PSDictionaryOverlayViewController alloc] initWithNibName:nil bundle:nil];
	
		CGFloat yaxis = self.navigationController.navigationBar.frame.size.height;
		yaxis += dictionaryEntriesTable.tableHeaderView.frame.size.height;
		CGFloat width = self.view.frame.size.width;
		CGFloat height = self.view.frame.size.height;
		
		//Parameters x = origion on x-axis, y = origon on y-axis.
		CGRect frame = CGRectMake(0, yaxis, width, height);
		overlayViewController.view.frame = frame;
		
		overlayViewController.dictionaryViewController = self;
	}

	searching = YES;

	if([dictionarySearchBar.text length] <= 0) {
		dictionaryEntriesTable.separatorStyle = UITableViewCellSeparatorStyleNone;
		[dictionaryEntriesTable insertSubview:overlayViewController.view aboveSubview:self.parentViewController.view];
		letUserSelectRow = NO;
		dictionaryEntriesTable.scrollEnabled = NO;
	} else {
		letUserSelectRow = YES;
		dictionaryEntriesTable.scrollEnabled = YES;
	}
	
	[dictionarySearchBar setShowsCancelButton:YES animated:YES];
//	[dictionaryNavItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSearch:)] autorelease] animated:YES];
	[self searchDictionaryEntries];
	[dictionaryEntriesTable reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
//	int row = 0;
//	int count = [[[PSModuleController defaultModuleController] primaryDictionary] entryCount];
//	for(; row < count; row++) {
//		NSComparisonResult res = [searchText caseInsensitiveCompare: [[[[PSModuleController defaultModuleController] primaryDictionary] allKeys] objectAtIndex: row]];
//		if(res <= NSOrderedSame)
//			break;
//	}
//	if(row == count)
//		row--;
//	NSIndexPath *newIP = [NSIndexPath indexPathForRow: row inSection: 0];
//	[dictionaryEntriesTable scrollToRowAtIndexPath: newIP atScrollPosition: UITableViewScrollPositionTop animated: YES];

	[searchResults removeAllObjects];
	
	if([searchText length] > 0) {
		[overlayViewController.view removeFromSuperview];
		dictionaryEntriesTable.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
		searching = YES;
		letUserSelectRow = YES;
		dictionaryEntriesTable.scrollEnabled = YES;
		[self searchDictionaryEntries];
	} else {
		[dictionaryEntriesTable insertSubview:overlayViewController.view aboveSubview:self.parentViewController.view];
		dictionaryEntriesTable.separatorStyle = UITableViewCellSeparatorStyleNone;
		searching = YES;
		letUserSelectRow = NO;
		dictionaryEntriesTable.scrollEnabled = NO;
	}
	
	[dictionaryEntriesTable reloadData];
	
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	dictionaryEntriesTable.tableHeaderView = dictionarySearchBar;
}

- (void)cancelSearch:(id)sender {
	[self searchBarCancelButtonClicked:nil];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	if([dictionarySearchBar isFirstResponder])
		[dictionarySearchBar resignFirstResponder];
	
	letUserSelectRow = YES;
	searching = NO;
	dictionaryEntriesTable.scrollEnabled = YES;
	
	[overlayViewController.view removeFromSuperview];
	[overlayViewController release];
	overlayViewController = nil;
	//[dictionaryNavItem setLeftBarButtonItem:nil animated:YES];
	[dictionarySearchBar setShowsCancelButton:NO animated:YES];

	dictionaryEntriesTable.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
//	if([searchResults count] > 0)
//		[dictionaryEntriesTable reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
//	else
	[searchResults removeAllObjects];
	[dictionaryEntriesTable reloadData];
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

- (IBAction)hideDescription:(id)sender {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideInfoPane object:nil];
	//[[[PSModuleController defaultModuleController] viewController] hideInfo];
	[self dismissModalViewControllerAnimated:YES];
	//[self hideModal: dictionaryDescriptionView withTiming: 0.3];
}

// Use this to show the modal view (pops-up from the bottom)
// try a time of 0.7 to start with...
//- (void) showModal:(UIView*)modalView withTiming:(float)time
//{
//	
//	CGSize modalSize = modalView.bounds.size;
//	//CGPoint middleCenter = modalView.center;
//	CGSize offSize = [self view].bounds.size;
//	CGPoint middleCenter = CGPointMake(modalSize.width / 2.0, offSize.height - (modalSize.height / 2.0));
//	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
//	modalView.center = offScreenCenter; // we start off-screen
//	[[self view] addSubview:modalView];
//	
//	// Show it with a transition effect
//	[UIView beginAnimations:nil context:nil];
//	[UIView setAnimationDuration:time]; // animation duration in seconds
//	modalView.center = middleCenter;
//	[UIView commitAnimations];
//}
//
//- (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
//{
//	UIView* modalView = (UIView *)context;
//	[modalView removeFromSuperview];
//}
//
// Use this to slide the semi-modal view back down.
//- (void) hideModal:(UIView*) modalView withTiming:(float)time
//{
//	CGSize offSize = [self view].bounds.size;
//	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
//	[UIView beginAnimations:nil context:modalView];
//	[UIView setAnimationDuration:time];
//	[UIView setAnimationDelegate:self];
//	[UIView setAnimationDidStopSelector:@selector(hideModalEnded:finished:context:)];
//	modalView.center = offScreenCenter;
//	[UIView commitAnimations];
//}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	//NSLog(@"\nDictionaryDescription: requestString: %@", [[request URL] absoluteString]);
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;
	
	if(rData && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@"Bible"] && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@""] && ![[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showImage"]) {
		//
		// it's a dictionary entry to show. (&& it's not a link on an image.)
		//
		NSString *mod = [rData objectForKey:ATTRTYPE_MODULE];
		
		SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
		if(swordDictionary) {
			entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];
			//DLog(@"\n%@ = %@\n", mod, entry);
		} else {
			entry = [NSString stringWithFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ %@</p>", mod, NSLocalizedString(@"ModuleNotInstalled", @"is not installed.")];
		}
		[self showDescription: entry withTitle:[[rData objectForKey:ATTRTYPE_VALUE] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		entry = nil;
		
	} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
		BOOL strongs = [[NSUserDefaults standardUserDefaults] boolForKey:@"strongsPreference"];
		BOOL morphs = [[NSUserDefaults standardUserDefaults] boolForKey:@"morphPreference"];
		SwordManager *swordManager = [SwordManager defaultManager];
		[swordManager setGlobalOption: SW_OPTION_STRONGS value: SW_OFF ];
		[swordManager setGlobalOption: SW_OPTION_MORPHS value: SW_OFF ];
		NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
		[swordManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
		NSMutableString *tmpEntry = [@"" mutableCopy];
		for(NSDictionary *dict in array) {
			NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
			[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
			[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
		}
		if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
			entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
		}
		[tmpEntry release];
	}
	
	
	if(entry) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];

		//[[[PSModuleController defaultModuleController] viewController] showInfo: entry];
		load = NO;
	}
	
	
	[pool release];
	return load;
}

@end

@implementation PSDictionaryEntryViewController


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return YES;//(interfaceOrientation == UIInterfaceOrientationPortrait);
}


@end

