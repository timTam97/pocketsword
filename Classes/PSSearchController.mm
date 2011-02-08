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

@synthesize results, savedTablePosition;
@synthesize searchTerm, searchTermToDisplay, bookName;
@synthesize delegate;
@synthesize searchRange, searchType, strongsSearch, fuzzySearch;

- (id)initWithSearchHistoryItem:(PSSearchHistoryItem*)searchHistoryItem {
	self = [self init];
	if(self) {
		[self setSearchHistoryItem:searchHistoryItem];
	}
	return self;
}

- (id)init {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		UITabBarItem *tBI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:0];
		self.tabBarItem = tBI;
		[tBI release];
		switchingTabs = YES;
		self.searchTerm = nil;
		self.searchTermToDisplay = nil;
		self.results = nil;
		self.bookName = nil;
		self.strongsSearch = NO;
		self.fuzzySearch = NO;
		self.searchType = AndSearch;
		self.searchRange = AllRange;
		self.savedTablePosition = nil;
//		titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
//		titleLabel.autoresizingMask = (UIViewAutoresizingFlexibleWidth || UIViewAutoresizingFlexibleHeight) && !UIViewAutoresizingFlexibleRightMargin && !UIViewAutoresizingFlexibleLeftMargin;
//		titleLabel.backgroundColor = [UIColor clearColor];
//		titleLabel.textAlignment = UITextAlignmentCenter;
//		titleLabel.textColor = [UIColor whiteColor];
//		titleLabel.shadowColor = [UIColor blackColor];
//		titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
		self.navigationItem.title = NSLocalizedString(@"SearchTitle", @"");
//		self.navigationItem.titleView = titleLabel;
		[self setSearchTitle];
	}
	return self;
}

- (void)dealloc {
	self.results = nil;
	self.searchTerm = nil;
	self.savedTablePosition = nil;
//	[titleLabel release];
//	if(helpView)
//		[helpView release];
    [super dealloc];
}

- (void)setSearchTitle {
	NSString *newTitle = NSLocalizedString(@"SearchTitle", @"");
	if(self.results && ![searchQueryView superview] && self.searchTermToDisplay) {
		newTitle = self.searchTermToDisplay;
	} else if(strongsSearch) {
		newTitle = NSLocalizedString(@"SearchStrongsTitle", @"");
	}
//	[UIView beginAnimations:nil context:NULL];
//    [UIView setAnimationDuration:1.0];
//    titleLabel.text = newTitle;
//	[UIView commitAnimations];
	self.navigationItem.title = newTitle;
	
}

- (void)setSearchHistoryItem:(PSSearchHistoryItem*)searchHistoryItem {
	if(searchHistoryItem) {
		self.searchTerm = searchHistoryItem.searchTerm;
		self.searchTermToDisplay = searchHistoryItem.searchTermToDisplay;
		self.searchType = searchHistoryItem.searchType;
		self.searchRange = searchHistoryItem.searchRange;
		self.strongsSearch = searchHistoryItem.strongsSearch;
		self.fuzzySearch = searchHistoryItem.fuzzySearch;
		self.results = searchHistoryItem.results;
		self.bookName = searchHistoryItem.bookName;
		self.savedTablePosition = searchHistoryItem.savedTablePosition;
		[self setSearchTitle];
	}
}

- (void)setListType:(ShownTab)listT {
	listType = listT;
}

- (IBAction)closeButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeButtonPressed)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonPressed:)] autorelease];
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

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
	if([[tabBarController selectedViewController] isMemberOfClass:[UINavigationController class]]) {
		switchingTabs = NO;
	} else {
		switchingTabs = YES;
	}
	return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
	if([viewController isMemberOfClass:[UINavigationController class]] && !switchingTabs) {
		// the only tab with a nav controller is the search tab
		[self searchButtonPressed:nil];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	searchBar.placeholder = NSLocalizedString(@"SearchTitle", @"");
	if(self.searchTermToDisplay) {
		searchBar.text = searchTermToDisplay;
	}
	if(self.searchTerm) {
		// we need to perform a search...  searchTerm should already be well formatted.
		[self performSelectorInBackground:@selector(search) withObject:nil];
	} else if(!self.results) {
		searchQueryView.bounds = searchResultsTable.bounds;
		searchQueryView.center = searchResultsTable.center;
		[self.view addSubview:searchQueryView];
	}
//	if(strongsSearch) {
//		self.navigationItem.title = NSLocalizedString(@"SearchStrongsTitle", @"");
//	} else {
//		self.navigationItem.title = NSLocalizedString(@"SearchTitle", @"");
//	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		searchResultsTable.backgroundColor = [UIColor blackColor];
	} else {
		searchResultsTable.backgroundColor = [UIColor whiteColor];
	}
	// TODO: when we rip this view to pieces, this needs to be switched to be:
	
	//[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:searchResultsTable useStatusBar:YES];
	//[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:searchQueryView useStatusBar:YES];

//	UIInterfaceOrientation interfaceOrientation = self.tabBarController.interfaceOrientation;
//	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//		self.navigationController.navigationBar.frame = CGRectMake(0.0, 0.0, 480.0, 32.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 360.0, 32.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 32.0, 480.0, 219.0);//219.0 instead of 268.0
//	} else {
//		self.navigationController.navigationBar.frame = CGRectMake(0.0, 0.0, 320.0, 44.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 200.0, 44.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 44.0, 320.0, 367.0);//367.0 instead of 416.0 -- removed 49 (tab bar!)
//	}
	[self refreshView];
	if(self.results) {
		if(self.savedTablePosition && [savedTablePosition count] > 0) {
			if([savedTablePosition count] > 1) {
				[searchResultsTable scrollToRowAtIndexPath:[savedTablePosition objectAtIndex:1] atScrollPosition:UITableViewScrollPositionTop animated:NO];
			} else {
				[searchResultsTable scrollToRowAtIndexPath:[savedTablePosition objectAtIndex:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
			}
		}
	}
	[self setSearchTitle];
}

//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	//[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:searchResultsTable fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
	//[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:searchQueryView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
//	if(toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//		self.navigationController.navigationBar.frame = CGRectMake(0.0, 0.0, 320.0, 32.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 200.0, 32.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 32.0, 320.0, 379.0);//428.0
//	} else {
//		self.navigationController.navigationBar.frame = CGRectMake(0.0, 0.0, 480.0, 44.0);
//		searchBar.frame = CGRectMake(97.0, 0.0, 360.0, 44.0);//396,236
//		searchResultsTable.frame = CGRectMake(0.0, 44.0, 480.0, 207.0);//256.0
//	}
//}


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
#define SearchFuzzySection		2
#define SearchStrongsSection	3

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(!searchingEnabled)
		return 1;

	if([tableView isEqual:searchQueryTable]) {
		return 2;
	} else {
		return 1;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(!searchingEnabled)
		return 0;
	
	if([tableView isEqual:searchQueryTable]) {
		if(section == 0) {
			switch(listType) {
				case BibleTab:
				{
					SwordModule *primaryBible = [[PSModuleController defaultModuleController] primaryBible];
					if([primaryBible hasFeature: SWMOD_FEATURE_STRONGS] || [primaryBible hasFeature: SWMOD_CONF_FEATURE_STRONGS]) {
						return 4;
					}
					return 3;
				}
					break;
				case CommentaryTab:
					return 3;
			}
		} else if(section == 1) {
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
	if([tableView isEqual:searchQueryTable] && section == 0) {
		return [NSString stringWithFormat:@"%@:", NSLocalizedString(@"SearchOptionsTitle", @"")];
//		switch(section) {
//			case SearchTypeSection:
//				return NSLocalizedString(@"SearchTypeSectionHeader", @"");
//			case SearchRangeSection:
//				return NSLocalizedString(@"SearchRangeSectionHeader", @"");
//			case SearchStrongsSection:
//				return NSLocalizedString(@"SearchStrongsSectionHeader", @"");
//		}
	} else if(section == 1) {
		return @"";
	} else if(results) {
		return [NSString stringWithFormat: @"%d %@", [results count], NSLocalizedString(@"SearchResults", @"results")];
	}
	return @"";
}

- (UITableViewCell *)searchQueryTableCellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [searchQueryTable dequeueReusableCellWithIdentifier:@"queryCell"];
	
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"queryCell"] autorelease];
	}
	
	if(indexPath.section == 0) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.backgroundColor = [UIColor whiteColor];
		cell.textLabel.textColor = [UIColor blackColor];
		switch(indexPath.row) {
			case SearchTypeSection:
			{
				cell.textLabel.text = NSLocalizedString(@"SearchTypeSectionHeader", @"");
				switch(searchType) {
					case AndSearch:
						cell.detailTextLabel.text = NSLocalizedString(@"SearchTypeAllRowShort", @"");
						break;
					case OrSearch:
						cell.detailTextLabel.text = NSLocalizedString(@"SearchTypeAnyRowShort", @"");
						break;
					case ExactSearch:
						cell.detailTextLabel.text = NSLocalizedString(@"SearchTypeExactRowShort", @"");
						break;
				}
			}
				break;
			case SearchRangeSection:
			{
				cell.textLabel.text = NSLocalizedString(@"SearchRangeSectionHeader", @"");
				switch(searchRange) {
					case AllRange:
						cell.detailTextLabel.text = NSLocalizedString(@"SearchRangeAllRowShort", @"");
						break;
					case OTRange:
						cell.detailTextLabel.text = NSLocalizedString(@"SearchRangeOTRowShort", @"");
						break;
					case NTRange:
						cell.detailTextLabel.text = NSLocalizedString(@"SearchRangeNTRowShort", @"");
						break;
					case BookRange:
						NSString *currentBook = bookName;
						if(!self.bookName) {
							currentBook = [PSModuleController getCurrentBibleRef];
							NSRange lastSpace = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
							if(lastSpace.location != NSNotFound) {
								currentBook = [currentBook substringToIndex:lastSpace.location];
							}
						}
						cell.detailTextLabel.text = currentBook;
						break;
				}
			}
				break;
			case SearchFuzzySection:
			{
				cell.textLabel.text = NSLocalizedString(@"SearchFuzzySectionHeader", @"");
				if(fuzzySearch) {
					cell.detailTextLabel.text = NSLocalizedString(@"On", @"");
				} else {
					cell.detailTextLabel.text = NSLocalizedString(@"Off", @"");
				}
			}
				break;
			case SearchStrongsSection:
			{
				cell.textLabel.text = NSLocalizedString(@"SearchStrongsSectionHeader", @"");
				if(strongsSearch) {
					cell.detailTextLabel.text = NSLocalizedString(@"On", @"");
				} else {
					cell.detailTextLabel.text = NSLocalizedString(@"Off", @"");
				}
			}
				break;
		}
	} else if(indexPath.section == 1) {
		// TODO: make this a proper UIButton?
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.textLabel.text = NSLocalizedString(@"SearchStartSearchButton", @"Start Search");
		cell.detailTextLabel.text = @"";
		cell.textLabel.textColor = [UIColor whiteColor];
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
	} else if([tableView isEqual:searchQueryTable] && indexPath.section == 1) {
		// our search row:
		cell.backgroundColor = [UIColor blueColor];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(searchingEnabled && results && [tableView isEqual:searchResultsTable]) {
		[self notifyDelegateOfNewHistoryItem];
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
		[searchBar resignFirstResponder];
		if(indexPath.section == 0) {
			PSSearchOptionTableViewController *optionTVC;
			switch(indexPath.row) {
				case SearchTypeSection:
				{
					optionTVC = [[PSSearchOptionTableViewController alloc] initWithTableType:PSSearchOptionTableTypeSelector];
					optionTVC.searchType = self.searchType;
				}
					break;
				case SearchRangeSection:
				{
					optionTVC = [[PSSearchOptionTableViewController alloc] initWithTableType:PSSearchOptionTableRangeSelector];
					optionTVC.searchRange = self.searchRange;
					NSString *currentBook = bookName;
					if(!self.bookName) {
						currentBook = [PSModuleController getCurrentBibleRef];
						NSRange lastSpace = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
						if(lastSpace.location != NSNotFound) {
							currentBook = [currentBook substringToIndex:lastSpace.location];
						}
					}
					optionTVC.bookName = currentBook;
				}
					break;
				case SearchFuzzySection:
				{
					optionTVC = [[PSSearchOptionTableViewController alloc] initWithTableType:PSSearchOptionTableFuzzySelector];
					optionTVC.fuzzySearch = self.fuzzySearch;
				}
					break;
				case SearchStrongsSection:
				{
					optionTVC = [[PSSearchOptionTableViewController alloc] initWithTableType:PSSearchOptionTableStrongsSelector];
					optionTVC.strongsSearch = self.strongsSearch;
				}
					break;
			}
			optionTVC.delegate = self;
			[self.navigationController pushViewController:optionTVC animated:YES];
			[optionTVC release];
		} else if(indexPath.section == 1) {
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
			[self searchBarSearchButtonClicked:nil];
		}
	}
}

- (void)createSearchTerm {
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
			[current appendFormat:@"%C", [searchTermToDisplay characterAtIndex:i]];
		} else if([searchTermToDisplay characterAtIndex:i] == ' ') {
			[components addObject:current];
			[current release];
			current = [@"" mutableCopy];
		} else {
			[current appendFormat:@"%C", [searchTermToDisplay characterAtIndex:i]];
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
		} else if((searchType != ExactSearch) && fuzzySearch && ([component length] > 0) && [component characterAtIndex:0] != '"') {
			// fuzzy search appends a '*' to each component, unless it's a quote && unless it's an exact search.
			[fullSearchTerm appendFormat:@"%@%@*%@", prefix, component, joiningString];
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
	NSString *v11n;
	if(listType == BibleTab)
		v11n = [[[PSModuleController defaultModuleController] primaryBible] versification];
	else
		v11n = [[[PSModuleController defaultModuleController] primaryCommentary] versification];
	
	SwordVerseKey *scope;

	switch(searchRange) {
		case OTRange:
			scope = [SwordVerseKey verseKeyForOTForVersification:v11n];
			break;
		case NTRange:
			scope = [SwordVerseKey verseKeyForNTForVersification:v11n];
			break;
		case BookRange:
		{
			NSString *currentBook = bookName;
			if(!self.bookName) {
				currentBook = [PSModuleController getCurrentBibleRef];
				NSRange lastSpace = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
				if(lastSpace.location != NSNotFound) {
					currentBook = [currentBook substringToIndex:lastSpace.location];
				}
			}
			self.bookName = currentBook;
			scope = [SwordVerseKey verseKeyForWholeBook:currentBook v11n:v11n];
		}
			break;
		case AllRange:default:
			scope = [SwordVerseKey verseKeyForWholeBibleForVersification:v11n];
			break;
	}
	
	return scope;
}

- (void)search {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
	self.results = nil;
	self.savedTablePosition = nil;
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
	[self notifyDelegateOfNewHistoryItem];
	
	self.searchTerm = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	[searchResultsTable reloadData];
	[pool release];
}

- (void)notifyDelegateOfNewHistoryItem {
	if([searchTermToDisplay isEqualToString:@""]) {
		[delegate searchDidFinish:nil];
	} else {
		NSString *bName = nil;
		if(searchRange == BookRange) {
			bName = self.bookName;
		}
		PSSearchHistoryItem *searchHistoryItem = [[PSSearchHistoryItem alloc] initWithSearchTermToDisplay:searchTermToDisplay strongs:strongsSearch fuzzy:fuzzySearch type:searchType range:searchRange book:bName];
		searchHistoryItem.results = self.results;
		[self saveTablePositionFromCurrentPosition];
		searchHistoryItem.savedTablePosition = self.savedTablePosition;
		[delegate searchDidFinish:searchHistoryItem];
		[searchHistoryItem release];
	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sBar {
	[sBar resignFirstResponder];
	[self search];
	[searchQueryView removeFromSuperview];
	[self setSearchTitle];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)sBar {
	[sBar resignFirstResponder];
	if(self.results) {
		if(self.savedTablePosition && [savedTablePosition count] > 0) {
			if([savedTablePosition count] > 1) {
				[searchResultsTable scrollToRowAtIndexPath:[savedTablePosition objectAtIndex:1] atScrollPosition:UITableViewScrollPositionTop animated:NO];
			} else {
				[searchResultsTable scrollToRowAtIndexPath:[savedTablePosition objectAtIndex:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
			}
		}
		[searchQueryView removeFromSuperview];
	}
	[self setSearchTitle];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)sBar {
	[sBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)sBar {
	[sBar setShowsCancelButton:NO animated:YES];
}


//- (void)hideKeyboard {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	[searchBar resignFirstResponder];
//	[pool release];
//}

//- (void)createHelpView {
//	UIWebView *webView = nil;
//	UINavigationBar *navBar = nil;
//	UIInterfaceOrientation interfaceOrientation = self.tabBarController.interfaceOrientation;
//	//UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
//	//if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
//	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//		helpView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 480, 251)];// 320-69
//		webView = [[UIWebView alloc] initWithFrame: CGRectMake(0, 44, 480, 212)];//320-113
//		navBar = [[UINavigationBar alloc] initWithFrame: CGRectMake(0, 0, 480, 44)];
//	} else {
//		helpView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 320, 411)];
//		webView = [[UIWebView alloc] initWithFrame: CGRectMake(0, 44, 320, 367)];
//		navBar = [[UINavigationBar alloc] initWithFrame: CGRectMake(0, 0, 320, 44)];
//		
//	}
//	helpView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//	navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//	NSString *helpHTML = @"<html><body><font face=\"Helvetica\"><dl><dt>loved one</dt><dd>search for verses that contain \"loved\" or \"one\"<br/>NB: this is the same as searching for loved OR one</dd>\n\
//	<dt>\"loved one\"</dt><dd>search for verses that contain the phrase \"loved one\"</dd>\n\
//	<dt>love*</dt><dd>search for verses that contain a word starting with \"love\" (love OR loves OR loved OR etc...)</dd>\n\
//	<dt>loved AND one</dt><dd>search for verses that contains the word \"loved\" and the word \"one\"<br />NB: && can be used in place of AND</dd>\n\
//	<dt>+loved one</dt><dd>search for verses that must contain \"loved\" and may contain \"one\"</dd>\n\
//	<dt>loved NOT one</dt><dd>search for verses that contain \"loved\" but not \"one\"</dd>\n\
//	<dt>(loved one) AND God</dt><dd>search for verses that contain \"loved\" or \"one\" and \"God\"</dd>\n\
//	</font></body></html>";
//	[webView loadHTMLString: helpHTML baseURL:nil];
//	[helpView addSubview: webView];
//	[webView release];
//	navBar.barStyle = UIBarStyleBlackOpaque;
//	UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle: NSLocalizedString(@"SearchHelpTitle", @"Search Help") ];
//	navItem.rightBarButtonItem = nil;
//	navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeSearchHelp)] autorelease];
//	[navBar pushNavigationItem: navItem animated: NO];
//	[navItem release];
//	[helpView addSubview: navBar];
//	[navBar release];
//}

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//	//NSLog(@"rotating...");
//	if(helpView) {
//		//NSLog(@"rotating...2");
//		[helpView removeFromSuperview];
//		[helpView release];
//		helpView = nil;
//		[self createHelpView];
//		[self.view addSubview:helpView];
//	}
//}

- (void)saveTablePositionFromCurrentPosition {
	if(self.results && [results count] > 0) {
		self.savedTablePosition = [searchResultsTable indexPathsForVisibleRows];
		if(savedTablePosition && [savedTablePosition count] > 0) {
			NSIndexPath *indexPath = [savedTablePosition objectAtIndex:0];
			if(indexPath.section == 0 && indexPath.row == 0) {
				self.savedTablePosition = nil;
			}
		}
	}
}

- (IBAction)searchButtonPressed:(id)sender {
	if(![searchQueryView superview]) {
		if(self.results && [results count] > 0) {
			[self saveTablePositionFromCurrentPosition];
			[searchResultsTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
		}
		searchQueryView.bounds = searchResultsTable.bounds;
		searchQueryView.center = searchResultsTable.center;
		[self.view addSubview:searchQueryView];
	}
	if([searchBar isFirstResponder]) {
		[searchBar resignFirstResponder];
	} else {
		[searchBar becomeFirstResponder];
	}
	[self setSearchTitle];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[searchBar resignFirstResponder];
}

//- (IBAction)infoButtonPressed:(id)sender {
//	if(!helpView) {
//		[self createHelpView];
//	}
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
//                           forView:self.view
//                             cache:YES]; 
//	
//    [UIView setAnimationDuration:1];
//	[self.view addSubview:helpView];
//    [UIView commitAnimations];
//}

//- (void)closeSearchHelp {
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight
//                           forView:self.view
//                             cache:YES];
//	
//    [UIView setAnimationDuration:1];
//	[helpView removeFromSuperview];
//    [UIView commitAnimations];
//	[helpView release];
//	helpView = nil;
//}

@end
