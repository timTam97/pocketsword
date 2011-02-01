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
#import "PSModuleController.h"
#import "SwordListKey.h"
#import "HistoryController.h"
#import "SwordVerseKey.h"

@implementation PSSearchController

@synthesize results;
@synthesize searchTerm, searchTermToDisplay;
@synthesize delegate;
@synthesize searchRange, searchType, strongsSearch;

- (id)init {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		UITabBarItem *tBI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:0];
		self.tabBarItem = tBI;
		[tBI release];
	}
	return self;
}

- (void)setListType:(ShownTab)listT {
	listType = listT;
}

- (IBAction)closeButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"Close");
	strongsSearch = NO;
	searchType = AndSearch;
	searchRange = AllRange;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	BOOL showIndexController = NO;
	switch(listType) {
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
}

- (void)viewWillAppear:(BOOL)animated {
	if(self.searchTermToDisplay) {
		searchBar.text = searchTermToDisplay;
	}
	[super viewWillAppear:animated];
	if(self.searchTerm) {
		// we need to perform a search...  searchTerm should already be well formatted.
		self.strongsSearch = YES;
		[self performSelectorInBackground:@selector(search) withObject:nil];
	} else if(!self.results) {
		[self.view addSubview:searchQueryView];
	}
	if(strongsSearch) {
		searchNavigationItem.title = NSLocalizedString(@"SearchStrongsTitle", @"");
	} else {
		searchNavigationItem.title = NSLocalizedString(@"SearchTitle", @"");
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		searchResultsTable.backgroundColor = [UIColor blackColor];
	} else {
		searchResultsTable.backgroundColor = [UIColor whiteColor];
	}
	// TODO: when we rip this view to pieces, this needs to be switched to be:
	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:searchNavigationBar mainView:searchResultsTable useStatusBar:YES];
	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:searchNavigationBar mainView:searchQueryView useStatusBar:YES];

//	UIInterfaceOrientation interfaceOrientation = self.tabBarController.interfaceOrientation;
//	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//		searchNavigationBar.frame = CGRectMake(0.0, 0.0, 480.0, 32.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 360.0, 32.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 32.0, 480.0, 219.0);//219.0 instead of 268.0
//	} else {
//		searchNavigationBar.frame = CGRectMake(0.0, 0.0, 320.0, 44.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 200.0, 44.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 44.0, 320.0, 367.0);//367.0 instead of 416.0 -- removed 49 (tab bar!)
//	}
	[self refreshView];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:searchNavigationBar mainView:searchResultsTable fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:searchNavigationBar mainView:searchQueryView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
//	if(toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//		searchNavigationBar.frame = CGRectMake(0.0, 0.0, 320.0, 32.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 200.0, 32.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 32.0, 320.0, 379.0);//428.0
//	} else {
//		searchNavigationBar.frame = CGRectMake(0.0, 0.0, 480.0, 44.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 360.0, 44.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 44.0, 480.0, 207.0);//256.0
//	}
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (buttonIndex == 1) {
		PSIndexController *indexC = [[PSIndexController alloc] initWithNibName:@"IndexDownloader" bundle:nil];
		[indexC setSearchController: self];
		[self presentModalViewController:indexC animated:YES];
	} else {
		
	}
	[self refreshView];
	[pool release];
}

- (void)refreshView {
	searchingEnabled = NO;
	switch(listType) {
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
		[searchBar setUserInteractionEnabled: YES];
	} else {
		//disable search
		[searchBar setUserInteractionEnabled: NO];
	}
	[searchResultsTable reloadData];
	[searchQueryTable reloadData];
}

- (void)dealloc {
	self.results = nil;
	self.searchTerm = nil;
	if(helpView)
		[helpView release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	// Release any cached data, images, etc that aren't in use.
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([tableView isEqual:searchQueryTable]) {
		return 40;
	}
	return 70;
}

#define SearchTypeSection		0
#define SearchRangeSection		1
#define SearchStrongsSection	2

#define SearchType_All			0
#define SearchType_Any			1
#define SearchType_Exact		2
#define SearchType_ROWS			3

#define SearchRange_All			0
#define SearchRange_OT			1
#define SearchRange_NT			2
#define SearchRange_Book		3
#define SearchRange_ROWS		4


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(searchingEnabled && [tableView isEqual:searchQueryTable]) {
		switch(listType) {
			case BibleTab:
			{
				SwordModule *primaryBible = [[PSModuleController defaultModuleController] primaryBible];
				if([primaryBible hasFeature: SWMOD_FEATURE_STRONGS] || [primaryBible hasFeature: SWMOD_CONF_FEATURE_STRONGS]) {
					return 3;
				}
				return 2;
			}
				break;
			case CommentaryTab:
				return 2;
		}
	}
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(!searchingEnabled)
		return 0;
	
	if([tableView isEqual:searchQueryTable]) {
		switch(section) {
			case 0:
				return SearchType_ROWS;
			case 1:
				return SearchRange_ROWS;
			case 2:
				return 1;
		}
	}
	
	if(results)
		return [results count];
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(!searchingEnabled) {
		return NSLocalizedString(@"NoSearchIndexInstalled", @"No Search Index Installed");
	}
	if([tableView isEqual:searchQueryTable]) {
		switch(section) {
			case SearchTypeSection:
				return NSLocalizedString(@"SearchTypeSectionHeader", @"");
			case SearchRangeSection:
				return NSLocalizedString(@"SearchRangeSectionHeader", @"");
			case SearchStrongsSection:
				return NSLocalizedString(@"SearchStrongsSectionHeader", @"");
		}
	}
	if(results)
		return [NSString stringWithFormat: @"%d %@", [results count], NSLocalizedString(@"SearchResults", @"results")];
	return @"";
}

- (UITableViewCell *)searchQueryTableCellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [searchQueryTable dequeueReusableCellWithIdentifier:@"queryCell"];
	
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"queryCell"] autorelease];
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	switch(indexPath.section) {
		case SearchTypeSection:
		{
			switch(indexPath.row) {
				case SearchType_All:
				{
					cell.textLabel.text = NSLocalizedString(@"SearchTypeAllRow", @"");
					if(searchType == AndSearch) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
				case SearchType_Any:
				{
					cell.textLabel.text = NSLocalizedString(@"SearchTypeAnyRow", @"");
					if(searchType == OrSearch) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
				case SearchType_Exact:
				{
					cell.textLabel.text = NSLocalizedString(@"SearchTypeExactRow", @"");
					if(searchType == ExactSearch) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
			}
		}
			break;
		case SearchRangeSection:
		{
			switch(indexPath.row) {
				case SearchRange_All:
				{
					cell.textLabel.text = NSLocalizedString(@"SearchRangeAllRow", @"");
					if(searchRange == AllRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
				case SearchRange_OT:
				{
					cell.textLabel.text = NSLocalizedString(@"SearchRangeOTRow", @"");
					if(searchRange == OTRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
				case SearchRange_NT:
				{
					cell.textLabel.text = NSLocalizedString(@"SearchRangeNTRow", @"");
					if(searchRange == NTRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
				case SearchRange_Book:
				{
					NSString *currentBook = [PSModuleController getCurrentBibleRef];
					NSRange lastSpace = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
					if(lastSpace.location != NSNotFound) {
						currentBook = [currentBook substringToIndex:lastSpace.location];
					}
					cell.textLabel.text = currentBook;
					if(searchRange == BookRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
			}
		}
			break;
		case SearchStrongsSection:
		{
			cell.textLabel.text = NSLocalizedString(@"SearchStrongsRow", @"");
			if(strongsSearch) {
				cell.accessoryType = UITableViewCellAccessoryCheckmark;
			} else {
				cell.accessoryType = UITableViewCellAccessoryNone;
			}
		}
			break;
	}
	
	return cell;
}

- (UITableViewCell *)resultsTableCellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [searchResultsTable dequeueReusableCellWithIdentifier:@"resultsCell"];
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		mainLabel.textColor = [UIColor whiteColor];
		secondLabel.textColor = [UIColor lightGrayColor];
		mainLabel.backgroundColor = [UIColor blackColor];
		secondLabel.backgroundColor = [UIColor blackColor];
	} else {
		mainLabel.textColor = [UIColor blackColor];
		secondLabel.textColor = [UIColor darkGrayColor];
		mainLabel.backgroundColor = [UIColor whiteColor];
		secondLabel.backgroundColor = [UIColor whiteColor];
	}
	if(!((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text || [((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text isEqualToString: @""]) {
		SwordModuleTextEntry *entry;
		switch(listType) {
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if([tableView isEqual:searchQueryTable]) {
		return [self searchQueryTableCellForRowAtIndexPath:indexPath];
	} else {
		return [self resultsTableCellForRowAtIndexPath:indexPath];
	}
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if(![tableView isEqual:searchQueryTable] && [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		cell.backgroundColor = [UIColor blackColor];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(searchingEnabled && results && [tableView isEqual:searchResultsTable]) {
		NSString *ref = ((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key;
		NSString *verse = [[ref componentsSeparatedByString:@":"] objectAtIndex: 1];
		ref = [[ref componentsSeparatedByString:@":"] objectAtIndex: 0];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] synchronize];

		switch(listType) {
			case BibleTab:
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
				[HistoryController addHistoryItem:BibleTab];
				break;
			case CommentaryTab:
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
				[HistoryController addHistoryItem:CommentaryTab];
				break;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
	} else if([tableView isEqual:searchQueryTable]) {
		switch(indexPath.section) {
			case SearchTypeSection:
			{
				switch(indexPath.row) {
					case SearchType_All:
					{
						searchType = AndSearch;
					}
						break;
					case SearchType_Any:
					{
						searchType = OrSearch;
					}
						break;
					case SearchType_Exact:
					{
						searchType = ExactSearch;
					}
						break;
				}
			}
				break;
			case SearchRangeSection:
			{
				switch(indexPath.row) {
					case SearchRange_All:
					{
						searchRange = AllRange;
					}
						break;
					case SearchRange_OT:
					{
						searchRange = OTRange;
					}
						break;
					case SearchRange_NT:
					{
						searchRange = NTRange;
					}
						break;
					case SearchRange_Book:
					{
						searchRange = BookRange;
					}
						break;
				}
			}
				break;
			case SearchStrongsSection:
			{
				strongsSearch = !strongsSearch;
				if(strongsSearch) {
					searchNavigationItem.title = NSLocalizedString(@"SearchStrongsTitle", @"");
				} else {
					searchNavigationItem.title = NSLocalizedString(@"SearchTitle", @"");
				}
			}
				break;
		}
		[tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationNone];
		//[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (void)createSearchTerm {
	// TODO: this should be changed to reflect the new searchQueryView.
	//self.searchTerm = searchTermToDisplay;
	NSMutableArray *components = [NSMutableArray arrayWithCapacity:1];
	NSInteger i =0;
	BOOL insideQuotes = NO;
	NSMutableString *current = [@"" mutableCopy];
	for(;i<[searchTermToDisplay length];i++) {
		if([searchTermToDisplay characterAtIndex:i] == '"') {
			if(insideQuotes) {
				insideQuotes = NO;
				[current appendString:@"\""];
				[components addObject:current];
				[current release];
				current = [@"" mutableCopy];
			} else {
				insideQuotes = YES;
				[current appendString:@"\""];
			}
		} else if(insideQuotes) {
			[current appendFormat:@"%c", [searchTermToDisplay characterAtIndex:i]];
		} else if([searchTermToDisplay characterAtIndex:i] == ' ') {
			[components addObject:current];
			[current release];
			current = [@"" mutableCopy];
		} else {
			[current appendFormat:@"%c", [searchTermToDisplay characterAtIndex:i]];
		}
	}
	
	if([current length] > 0)
		[components addObject:current];
	[current release];
	current = nil;
	
	NSMutableString *fullSearchTerm = [@"" mutableCopy];
	NSString *joiningString;
	if(searchType == AndSearch) {
		joiningString = @" && ";
	} else if(searchType == OrSearch) {
		joiningString = @" || ";
	} else if(searchType == ExactSearch) {
		joiningString = @" ";
		[fullSearchTerm appendString:@"\""];
	}
	NSString *prefix = @"";
	if(strongsSearch) {
		prefix = @"lemma:";
	}
	i = 0;
	for(NSString *component in components) {
		if(i == ([components count] - 1)) {
			joiningString = @"";
		}
		if(strongsSearch && [component characterAtIndex:0] == 'H') {
			NSMutableString *hebrew = [component mutableCopy];
			if([component length] > 1 && [component characterAtIndex:1] == '0') {
				// also search for this number without the '0' prefix
				[hebrew deleteCharactersInRange:NSMakeRange(1, 1)];
			} else if([component length] > 1) {
				// also search for this number with the '0' prefix
				[hebrew insertString:@"0" atIndex:1];
			}
			[fullSearchTerm appendFormat:@"(%@%@ || %@%@)%@", prefix, hebrew, prefix, component, joiningString];
		} else {
			[fullSearchTerm appendFormat:@"%@%@%@", prefix, component, joiningString];
		}
		i++;
	}
	if(searchType == ExactSearch) {
		[fullSearchTerm appendString:@"\""];
	}
	self.searchTerm = fullSearchTerm;
	[fullSearchTerm release];
}

- (SwordVerseKey *)createSearchScope {
	//SwordListKey *testScope = [SwordListKey listKeyWithRef:@"matt-rev" v11n:[self versification]];
	NSString *v11n;
	if(listType == BibleTab)
		v11n = [[[PSModuleController defaultModuleController] primaryBible] versification];
	else
		v11n = [[[PSModuleController defaultModuleController] primaryCommentary] versification];
	
	SwordVerseKey *scope;

	switch(searchRange) {
		case OTRange:
			scope = [SwordVerseKey verseKeyForOTForVersification:v11n];
//			[firstKey setTestament:1];
//			[firstKey setBook:1];
//			[firstKey setChapter:1];
//			[firstKey setVerse:1];
//			[lastKey setTestament:1];
//			[lastKey setBook:(sword::MAXBOOK)];
//			[lastKey setChapter:(sword::MAXCHAPTER)];
//			[lastKey setVerse:(sword::MAXVERSE)];
			break;
		case NTRange:
			scope = [SwordVerseKey verseKeyForNTForVersification:v11n];
//			[firstKey setTestament:2];
//			[firstKey setBook:1];
//			[firstKey setChapter:1];
//			[firstKey setVerse:1];
//			[lastKey setTestament:2];
//			[lastKey setBook:(sword::MAXBOOK)];
//			[lastKey setChapter:(sword::MAXCHAPTER)];
//			[lastKey setVerse:(sword::MAXVERSE)];
			break;
		case BookRange:
			scope = [SwordVerseKey verseKeyForWholeBook:[PSModuleController getCurrentBibleRef] v11n:v11n];
//			[firstKey setKeyText:[PSModuleController getCurrentBibleRef]];
//			[firstKey setChapter:1];
//			[firstKey setVerse:1];
//			[lastKey setKeyText:[PSModuleController getCurrentBibleRef]];
//			[lastKey setChapter:(sword::MAXCHAPTER)];
//			[lastKey setVerse:(sword::MAXVERSE)];
			break;
		case AllRange:default:
			scope = [SwordVerseKey verseKeyForWholeBibleForVersification:v11n];
//			[firstKey setTestament:1];
//			[firstKey setBook:1];
//			[firstKey setChapter:1];
//			[firstKey setVerse:1];
//			[lastKey setTestament:2];
//			[lastKey setBook:(sword::MAXBOOK)];
//			[lastKey setChapter:(sword::MAXCHAPTER)];
//			[lastKey setVerse:(sword::MAXVERSE)];
			break;
	}
	
	return scope;
}

- (void)search {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
	self.results = nil;
	if(self.searchTerm) {
		// the search is already formatted
	} else {
		// need to create the formatted search term
		self.searchTermToDisplay = searchBar.text;
		[self createSearchTerm];
	}
	DLog(@"\nsearchTerm = %@", searchTerm);
	switch(listType) {
		case BibleTab:
			self.results = [[[PSModuleController defaultModuleController] primaryBible] search: searchTerm withScope:[self createSearchScope]];
			break;
		case CommentaryTab:
			self.results = [[[PSModuleController defaultModuleController] primaryCommentary] search: searchTerm withScope:[self createSearchScope]];
			break;
	}

	//remove duplicate entries manually.  why do these appear? *sad face*
	if(results && [results count] > 0) {
		for(int i = 0; i < ([results count] -1); i++) {
			if([((SwordModuleTextEntry *)[results objectAtIndex: i]).key isEqualToString:((SwordModuleTextEntry *)[results objectAtIndex: i+1]).key])
				[results removeObjectAtIndex:i+1];//remove the duplicate.
		}
	}
	
	// call our delegate to say we have a new searchTerm & results.
	if([searchTermToDisplay isEqualToString:@""]) {
		[delegate searchTermDidChange:nil withResults:nil];
	} else {
		[delegate searchTermDidChange:searchTermToDisplay withResults:results];
	}
	
	self.searchTerm = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	[searchResultsTable reloadData];
	[pool release];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sBar {
	[sBar resignFirstResponder];
	[self search];
	[searchQueryView removeFromSuperview];
//	self.results = nil;
//	self.searchTerm = [sBar text];
//	switch(listType) {
//		case BibleTab:
//			self.results = [[[PSModuleController defaultModuleController] primaryBible] search: [sBar text]];
//			break;
//		case CommentaryTab:
//			self.results = [[[PSModuleController defaultModuleController] primaryCommentary] search: [sBar text]];
//			break;
//	}
//
//	//remove duplicate entries manually.  why do these appear? *sad face*
//	if(results && [results count] > 0) {
//		for(int i = 0; i < ([results count] -1); i++) {
//			if([((SwordModuleTextEntry *)[results objectAtIndex: i]).key isEqualToString:((SwordModuleTextEntry *)[results objectAtIndex: i+1]).key])
//				[results removeObjectAtIndex:i+1];//remove the duplicate.
//		}
//	}
//	
//	// call our delegate to say we have a new searchTerm & results.
//	if([searchTerm isEqualToString:@""]) {
//		[delegate searchTermDidChange:nil withResults:nil];
//	} else {
//		[delegate searchTermDidChange:searchTerm withResults:results];
//	}
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)sBar {
	[sBar resignFirstResponder];
	if(self.results) {
		[searchQueryView removeFromSuperview];
	}
}

//- (void)hideKeyboard {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	[searchBar resignFirstResponder];
//	[pool release];
//}

- (void)createHelpView {
	UIWebView *webView = nil;
	UINavigationBar *navBar = nil;
	UIInterfaceOrientation interfaceOrientation = self.tabBarController.interfaceOrientation;
	//UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	//if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		helpView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 480, 251)];// 320-69
		webView = [[UIWebView alloc] initWithFrame: CGRectMake(0, 44, 480, 212)];//320-113
		navBar = [[UINavigationBar alloc] initWithFrame: CGRectMake(0, 0, 480, 44)];
	} else {
		helpView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 320, 411)];
		webView = [[UIWebView alloc] initWithFrame: CGRectMake(0, 44, 320, 367)];
		navBar = [[UINavigationBar alloc] initWithFrame: CGRectMake(0, 0, 320, 44)];
		
	}
	helpView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
	navBar.barStyle = UIBarStyleBlackOpaque;
	UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle: NSLocalizedString(@"SearchHelpTitle", @"Search Help") ];
	navItem.rightBarButtonItem = nil;
	navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeSearchHelp)] autorelease];
	[navBar pushNavigationItem: navItem animated: NO];
	[navItem release];
	[helpView addSubview: navBar];
	[navBar release];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	//NSLog(@"rotating...");
	if(helpView) {
		//NSLog(@"rotating...2");
		[helpView removeFromSuperview];
		[helpView release];
		helpView = nil;
		[self createHelpView];
		[self.view addSubview:helpView];
	}
}

- (IBAction)searchButtonPressed:(id)sender {
	if(![searchQueryView superview]) {
		[self.view addSubview:searchQueryView];
	}
	[searchBar becomeFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[searchBar resignFirstResponder];
}

- (IBAction)infoButtonPressed:(id)sender {
	if(!helpView) {
		[self createHelpView];
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
