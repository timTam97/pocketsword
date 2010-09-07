//
//  PSMultiListController.mm
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSSearchController.h"
#import "PSIndexController.h"
#import "SwordModuleTextEntry.h"


@implementation PSSearchController

@synthesize results;
@synthesize searchTerm;

BOOL searchingEnabled;

- (void)viewDidLoad {
	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"Close");
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	ShownTab tab = [historyController listType];
	BOOL showIndexController = NO;
	switch(tab) {
		case BibleTab:
			if(![[[PSModuleController defaultModuleController] primaryBible] hasSearchIndex])
				showIndexController = YES;
			break;
		case CommentaryTab:
			if(![[[PSModuleController defaultModuleController] primaryCommentary] hasSearchIndex])
				showIndexController = YES;
			break;
	}
	if(showIndexController) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"NoSearchIndexTitle", @"No Search Index") message: NSLocalizedString(@"NoSearchIndexMsg", @"No search index is installed for this module, install one?") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
	}
	[self refreshView];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (buttonIndex == 1) {
		PSIndexController *indexC = [[PSIndexController alloc] initWithNibName:@"IndexDownloader" bundle:nil];
		//[indexC setModuleManager:[PSModuleController defaultModuleController]];
		[indexC setSearchController: self];
		[self presentModalViewController:indexC animated:YES];
		//[ViewController showModal:indexC.view withTiming:0.3];
	} else {
		
	}
	[self refreshView];
	[pool release];
}

- (void)refreshView {
	ShownTab tab = [historyController listType];
	searchingEnabled = NO;
	switch(tab) {
		case BibleTab:
			if([[[PSModuleController defaultModuleController] primaryBible] hasSearchIndex])
				searchingEnabled = YES;
			break;
		case CommentaryTab:
			if([[[PSModuleController defaultModuleController] primaryCommentary] hasSearchIndex])
				searchingEnabled = YES;
			break;
	}
	if(searchingEnabled) {
		//enable search
		[sBar setUserInteractionEnabled: YES];
	} else {
		//disable search
		[sBar setUserInteractionEnabled: NO];
	}
	[resultsTable reloadData];
}

- (void)dealloc {
	self.results = nil;
	self.searchTerm = nil;
	if(helpView)
		[helpView release];
    [super dealloc];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(results)
		return [results count];
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if(!searchingEnabled) {
		return NSLocalizedString(@"NoSearchIndexInstalled", @"No Search Index Installed");
	} else {
		if(results)
			return [NSString stringWithFormat: @"%d %@", [results count], NSLocalizedString(@"SearchResults", @"results")];
	}
	return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 70;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resultsCell"];
    UILabel *mainLabel, *secondLabel;

	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"resultsCell"] autorelease];
		mainLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20.0, 0.0, 320.0, 22.0)] autorelease];
        mainLabel.tag = 477;
        mainLabel.font = [UIFont boldSystemFontOfSize:14.0];
        mainLabel.textColor = [UIColor blackColor];
        mainLabel.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin & UIViewAutoresizingFlexibleTopMargin);// | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:mainLabel];
		
        secondLabel = [[[UILabel alloc] initWithFrame:CGRectMake(5.0, 22.0, 310.0, 45.0)] autorelease];
        secondLabel.tag = 577;
        secondLabel.font = [UIFont systemFontOfSize:12.0];
		secondLabel.numberOfLines = 3;
		secondLabel.lineBreakMode = UILineBreakModeWordWrap;
        secondLabel.textColor = [UIColor darkGrayColor];
        secondLabel.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin & UIViewAutoresizingFlexibleTopMargin);// | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:secondLabel];
		
	} else {
        mainLabel = (UILabel *)[cell.contentView viewWithTag:477];
        secondLabel = (UILabel *)[cell.contentView viewWithTag:577];
	}
	if(!((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text || [((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text isEqualToString: @""]) {
		ShownTab tab = [historyController listType];
		SwordModuleTextEntry *entry;
		switch(tab) {
			case BibleTab:
				entry = [[[PSModuleController defaultModuleController] primaryBible] textEntryForKey:[PSModuleController createRefString:((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key] textType:TextTypeStripped];
				break;
			case CommentaryTab:
				entry = [[[PSModuleController defaultModuleController] primaryCommentary] textEntryForKey:[PSModuleController createRefString:((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key] textType:TextTypeStripped];
				break;
		}
		//if showNotes or showMorph or showStrongs are on, there will be " [] " littered throughout the results, so remove them!
		entry.text = [entry.text stringByReplacingOccurrencesOfString:@" [] " withString:@""];
		[results replaceObjectAtIndex:indexPath.row withObject:entry];
	}
	mainLabel.text = ((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key;
	NSMutableString *txt = [((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text mutableCopy];
	[txt replaceOccurrencesOfString:@"\n" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [txt length])];
	//DLog(@"\n%@", txt);
	secondLabel.text = txt;
	[txt release];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(searchingEnabled && results) {
		NSString *ref = ((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key;
		NSString *verse = [[ref componentsSeparatedByString:@":"] objectAtIndex: 1];
		ref = [[ref componentsSeparatedByString:@":"] objectAtIndex: 0];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] synchronize];

		ShownTab tab = [historyController listType];
		//PollingType pt;
		switch(tab) {
			case BibleTab:
				//pt = BibleViewPoll;
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
				//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
				[HistoryController addHistoryItem:BibleTab];
				break;
			case CommentaryTab:
				//pt = CommentaryViewPoll;
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
				//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
				[HistoryController addHistoryItem:CommentaryTab];
				break;
		}
		//[[[PSModuleController defaultModuleController] viewController] displayChapter: ref withPollingType: pt restoreType: RestoreVersePosition];
		//self.searchTerm = nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
		//[[[PSModuleController defaultModuleController] viewController] toggleMultiList];
		//[[[PSModuleController defaultModuleController] viewController] highlightSearchTerm: searchTerm forTab: tab]; -- doesn't work atm 31/7/10 nicc
//		if(tab == BibleTab) {
//			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
//		} else {
//			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
//		}
		//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: tab];
	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[searchBar resignFirstResponder];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
	//[[PSModuleController defaultModuleController] displayBusyIndicator];
	ShownTab tab = [historyController listType];
	self.results = nil;
	self.searchTerm = [searchBar text];
	switch(tab) {
		case BibleTab:
			self.results = [[[PSModuleController defaultModuleController] primaryBible] search: [searchBar text]];
			break;
		case CommentaryTab:
			self.results = [[[PSModuleController defaultModuleController] primaryCommentary] search: [searchBar text]];
			break;
	}

	//remove duplicate entries manually.  why do these appear? *sad face*
	if(results && [results count] > 0) {
		for(int i = 0; i < ([results count] -1); i++) {
			if([((SwordModuleTextEntry *)[results objectAtIndex: i]).key isEqualToString:((SwordModuleTextEntry *)[results objectAtIndex: i+1]).key])
				[results removeObjectAtIndex:i+1];//remove the duplicate.
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	//[[PSModuleController defaultModuleController] hideBusyIndicator];
	[resultsTable reloadData];
	[pool release];
}

//- (void)hideKeyboard {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	[sBar resignFirstResponder];
//	[pool release];
//}

- (IBAction)infoButtonPressed:(id)sender {
	if(!helpView) {
		helpView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 320, 411)];
		UIWebView *webView = [[UIWebView alloc] initWithFrame: CGRectMake(0, 44, 320, 367)];
		NSString *helpHTML = @"<html><body><font face=\"Helvetica\"><dl><dt>loved one</dt><dd>search for verses that contain \"loved\" or \"one\"<br/>NB: this is the same as searching for loved OR one</dd>\n\
		<dt>\"loved one\"</dt><dd>search for verses that contain the phrase \"loved one\"</dd>\n\
		<dt>love*</dt><dd>search for verses that contain a word starting with \"love\" (love OR loves OR loved OR etc...)</dd>\n\
		<dt>loved AND one</dt><dd>search for verses that contains the word \"loved\" and the word \"one\"<br />NB: && can be used in place of AND</dd>\n\
		<dt>+loved one</dt><dd>search for verses that must contain \"loved\" and may contain \"one\"</dd>\n\
		<dt>loved NOT one</dt><dd>search for verses that contain \"loved\" but not \"one\"</dd>\n\
		<dt>(loved one) AND God</dt><dd>search for verses that contain \"loved\" or \"one\" and \"God\"</dd>\n\
		</font></body></html>";
		[webView loadHTMLString: helpHTML baseURL:nil];
		[helpView addSubview: webView];
		[webView release];
		UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame: CGRectMake(0, 0, 320, 44)];
		navBar.barStyle = UIBarStyleBlackOpaque;
		UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle: NSLocalizedString(@"SearchHelpTitle", @"Search Help") ];
		navItem.rightBarButtonItem = nil;
		navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeSearchHelp)] autorelease];
		[navBar pushNavigationItem: navItem animated: NO];
		[navItem release];
		[helpView addSubview: navBar];
		//[helpView retain];
	}
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
                           forView:self.view
                             cache:YES]; 
	
    [UIView setAnimationDuration:1];
	[self.view addSubview:helpView];
    [UIView commitAnimations];
}

- (void)closeSearchHelp {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight
                           forView:self.view
                             cache:YES];
	
    [UIView setAnimationDuration:1];
	[helpView removeFromSuperview];
    [UIView commitAnimations];
	[helpView release];
	helpView = nil;
}

@end
