//
//  PSMultiListController.mm
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSSearchController.h"
#import "PSIndexController.h"
#import "SwordModuleTextEntry.h"


@implementation PSSearchController

@synthesize results;
@synthesize busyTimer;
@synthesize searchTerm;

BOOL searchingEnabled;

- (void)awakeFromNib {
	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"Close");
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	ShownTab tab = [dataController listType];
	BOOL showIndexController = NO;
	switch(tab) {
		case BibleTab:
			if(![[moduleManager primaryBible] hasSearchIndex])
				showIndexController = YES;
			break;
		case CommentaryTab:
			if(![[moduleManager primaryCommentary] hasSearchIndex])
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
		[indexC setModuleManager:moduleManager];
		[indexC setSearchController: self];
		[ViewController showModal:indexC.view withTiming:0.3];
	} else {
		
	}
	[self refreshView];
	[pool release];
}

- (void)refreshView {
	ShownTab tab = [dataController listType];
	searchingEnabled = NO;
	switch(tab) {
		case BibleTab:
			if([[moduleManager primaryBible] hasSearchIndex])
				searchingEnabled = YES;
			break;
		case CommentaryTab:
			if([[moduleManager primaryCommentary] hasSearchIndex])
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
	return 65;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resultsCell"];
    UILabel *mainLabel, *secondLabel;

	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"resultsCell"] autorelease];
		mainLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20.0, 0.0, 320.0, 15.0)] autorelease];
        mainLabel.tag = 477;
        mainLabel.font = [UIFont boldSystemFontOfSize:14.0];
        mainLabel.textColor = [UIColor blackColor];
        mainLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;// | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:mainLabel];
		
        secondLabel = [[[UILabel alloc] initWithFrame:CGRectMake(5.0, 20.0, 310.0, 45.0)] autorelease];
        secondLabel.tag = 577;
        secondLabel.font = [UIFont systemFontOfSize:12.0];
		secondLabel.numberOfLines = 3;
		secondLabel.lineBreakMode = UILineBreakModeWordWrap;
        secondLabel.textColor = [UIColor darkGrayColor];
        secondLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;// | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:secondLabel];
		
	} else {
        mainLabel = (UILabel *)[cell.contentView viewWithTag:477];
        secondLabel = (UILabel *)[cell.contentView viewWithTag:577];
	}
	if(!((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text || [((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text isEqualToString: @""]) {
		ShownTab tab = [dataController listType];
		SwordModuleTextEntry *entry;
		switch(tab) {
			case BibleTab:
				entry = [[moduleManager primaryBible] textEntryForKey:[PSModuleController createRefString:((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key] textType:TextTypeStripped];
				break;
			case CommentaryTab:
				entry = [[moduleManager primaryCommentary] textEntryForKey:[PSModuleController createRefString:((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key] textType:TextTypeStripped];
				break;
		}
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
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: @"commentaryVersePosition"];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: @"bibleVersePosition"];
		[[NSUserDefaults standardUserDefaults] synchronize];

		ShownTab tab = [dataController listType];
		PollingType pt;
		switch(tab) {
			case BibleTab:
				pt = BibleViewPoll;
				break;
			case CommentaryTab:
				pt = CommentaryViewPoll;
				break;
		}
		[viewController displayChapter: ref withPollingType: pt restoreType: RestoreVersePosition];
		//self.searchTerm = nil;
		[viewController toggleMultiList: nil];
		[viewController highlightSearchTerm: searchTerm forTab: tab];
	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[searchBar resignFirstResponder];
	if(busyTimer) {
		[busyTimer invalidate];
		self.busyTimer = nil;
	}
	[viewController performSelectorInBackground: @selector(displayBusyIndicator) withObject: nil];
	ShownTab tab = [dataController listType];
	self.results = nil;
	self.searchTerm = [searchBar text];
	switch(tab) {
		case BibleTab:
			self.results = [[moduleManager primaryBible] search: [searchBar text]];
			break;
		case CommentaryTab:
			self.results = [[moduleManager primaryCommentary] search: [searchBar text]];
			break;
	}
	[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
	self.busyTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doubleClose:) userInfo:nil repeats:NO];
	[resultsTable reloadData];
	[pool release];
}

- (void)doubleClose:(NSTimer *)theTimer {
	[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
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
		navItem.leftBarButtonItem = nil;
		navItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeSearchHelp)] autorelease];
		[navBar pushNavigationItem: navItem animated: NO];
		[navItem release];
		[helpView addSubview: navBar];
		[helpView retain];
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
}

@end
