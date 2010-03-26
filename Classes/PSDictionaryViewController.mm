//
//  PSDictionaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSDictionaryViewController.h"
#import "PSModuleController.h"
#import "ViewController.h"


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
			[dictionarySearchBar setUserInteractionEnabled: NO];
			dictionaryEnabled = NO;
			return;
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
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"dict-id"] autorelease];
	}
	
	cell.textLabel.text = [[[moduleManager primaryDictionary] allKeys] objectAtIndex:indexPath.row];
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[dictionarySearchBar resignFirstResponder];
	NSString *t = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	NSString *descr = [[moduleManager primaryDictionary] entryForKey: t];
	[self showDescription:descr withTitle:t];
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
	//NSLog(@"%@", descr);
	
	if(![dictionaryDescriptionView superview])
		[self showModal: dictionaryDescriptionView withTiming: 0.3];
}


- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	int row = 0;
//	if([searchText length] > prevLength) {
//		NSIndexPath *tableSelection = [[dictionaryEntriesTable indexPathsForVisibleRows] objectAtIndex: 0];
//		if(tableSelection)
//			row = tableSelection.row;
//		//we can continue searching from the current index
//	} else {
//		//start searching from the start
//	}
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

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (IBAction)hideDescription:(id)sender {
	[viewController hideInfo: nil];
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

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	//NSLog(@"\nDictionaryDescription: requestString: %@", [[request URL] absoluteString]);
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;
	
	if(rData && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@"Bible"]) {
		//
		// it's a dictionary entry to show.
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
		NSArray *array = (NSArray*)[[moduleManager primaryBible] attributeValueForEntryData:rData];
		[swordManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
		NSMutableString *tmpEntry = [@"" mutableCopy];
		for(NSDictionary *dict in array) {
			[tmpEntry appendFormat:@"<b>%@:</b> ", [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]]];
			[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
		}
		if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
			entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
		}
		[tmpEntry release];
	}
	
	
	if(entry) {
		[viewController showInfo: entry];
		load = NO;
	}
	
	
	[pool release];
	return load;
}

@end
