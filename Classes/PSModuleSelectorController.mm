//
//  PSModuleSelectorController.m
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleSelectorController.h"
#import "PSModuleController.h"
#import "NavigatorSources.h"
#import "HistoryController.h"
#import "PSResizing.h"

@implementation PSModuleSelectorController

@synthesize listType, moduleToView;
//@synthesize reloadModuleViews;

- (void)viewDidLoad {
	[super viewDidLoad];
	//reloadModuleViews = NO;
	//modulesCloseButton.title = NSLocalizedString(@"CloseButtonTitle", @"");
	if((UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)) {
		return;
	}
	UIBarButtonItem	*modulesCloseButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"CloseButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(dismissModuleSelector)];
	modulesNavigationItem.leftBarButtonItem = modulesCloseButton;
	[modulesCloseButton release];
	UIBarButtonItem *modulesAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addModuleButtonPressed)];
	modulesNavigationItem.rightBarButtonItem = modulesAddButton;
	[modulesAddButton release];
}

- (void)dealloc {
	self.moduleToView = nil;
	[super dealloc];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		modulesListTable.backgroundColor = [UIColor blackColor];
	} else {
		modulesListTable.backgroundColor = [UIColor whiteColor];
	}
	
	if((UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)) {
		//for the iPad, we don't resize...
	} else {
		[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:modulesNavigationBar mainView:modulesListTable bottomBar:modulesToolbar useStatusBar:YES];
	}
	NSIndexPath *ip = nil;//default value
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	if([self listType] == BibleTab) {
		[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_BIBLES, @"")];
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_BIBLES];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleController primaryBible] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			ip = [NSIndexPath indexPathForRow: pos inSection: 0];
		}			
	} else if([self listType] == CommentaryTab) {
		[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_COMMENTARIES, @"")];
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleController primaryCommentary] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			ip = [NSIndexPath indexPathForRow: pos inSection: 0];
		}
	} else if([self listType] == DevotionalTab) {
		[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_DAILYDEVS, @"")];
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleController primaryDevotional] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			ip = [NSIndexPath indexPathForRow: pos inSection: 0];
		}
	} else {
		[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_DICTIONARIES, @"")];
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleController primaryDictionary] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			ip = [NSIndexPath indexPathForRow: pos inSection: 0];
		}			
	}
	if(self.moduleToView) {
		[leafViewController displayInfoForModule:self.moduleToView];
		//[self presentModalViewController:leafTabBarController animated:NO];
		[leafTabBarController setSelectedIndex:1];
		[self.navigationController pushViewController:leafTabBarController animated:NO];
	} else {
		//reloadModuleViews = NO;
		[modulesListTable reloadData];
		if(ip) {
			[modulesListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionMiddle animated:NO];
		}
		[self addButtonsToToolbar:NO];
	}
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if((UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)) {
		//for the iPad, we don't resize...
		return;
	}
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:modulesNavigationBar mainView:modulesListTable bottomBar:modulesToolbar fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
}

- (void)viewDidDisappear:(BOOL)animated {
//	if(UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone) {
//		if(reloadModuleViews) {
//			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
//		}
//	}
}

- (IBAction)addModuleButtonPressed {
//	if(reloadModuleViews) {
//		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
//		reloadModuleViews = NO;
//	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowDownloadsTab object:nil];
}

- (IBAction)dismissModuleSelector {
//	if(reloadModuleViews) {
//		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
//		reloadModuleViews = NO;
//	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
}

//
// UITableView delegate and data source methods
//
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (listType) {
		case BibleTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] count];
			break;
		case CommentaryTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
			break;
		case DictionaryTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] count];
			break;
		case DevotionalTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS] count];
			break;
		case DownloadsTab:
		case PreferencesTab:
			break;
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSString *theIdentifier = @"id-mod";
	
	// Try to recover a cell from the table view with the given identifier, this is for performance
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: theIdentifier];
	
	// If no cell is available, create a new one using the given identifier - 
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: theIdentifier] autorelease];
	}
	
	BOOL locked = NO;
	switch (listType) {
		case BibleTab:
			cell.textLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex:indexPath.row] descr];
			locked = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex:indexPath.row] isLocked];
			break;
		case CommentaryTab:
			cell.textLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex:indexPath.row] descr];
			locked = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex:indexPath.row] isLocked];
			break;
		case DictionaryTab:
			cell.textLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:indexPath.row] descr];
			locked = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:indexPath.row] isLocked];
			break;
		case DevotionalTab:
			cell.textLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS] objectAtIndex:indexPath.row] descr];
			locked = [[[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS] objectAtIndex:indexPath.row] isLocked];
			break;
		case DownloadsTab:
		case PreferencesTab:
			break;
	}
	if ([[PSModuleController defaultModuleController] isLoaded:cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor blueColor];
		cell.detailTextLabel.textColor = [UIColor blueColor];
	} else if(locked) {
		cell.textLabel.textColor = [UIColor brownColor];
		cell.detailTextLabel.textColor = [UIColor brownColor];
	} else {
		if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
			cell.textLabel.textColor = [UIColor whiteColor];
			cell.detailTextLabel.textColor = [UIColor whiteColor];
		} else {
			cell.textLabel.textColor = [UIColor blackColor];
			cell.detailTextLabel.textColor = [UIColor blackColor];
		}
	}
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		cell.backgroundColor = [UIColor blackColor];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//NSString *ref = [[PSModuleController defaultModuleController] getCurrentBibleRef];
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	if(([moduleController primaryBible] && [newModule isEqualToString:[[moduleController primaryBible] name]]) || ([moduleController primaryCommentary] && [newModule isEqualToString:[[moduleController primaryCommentary] name]]) || ([moduleController primaryDictionary] && [newModule isEqualToString:[[moduleController primaryDictionary] name]])) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
//		if(reloadModuleViews) {
//			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
//			reloadModuleViews = NO;
//		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
		return; // do nothing, because we selected the currently loaded module, but close the view & return to viewing the module.
	}
	// Update the module list to reflect the current module
	[tableView reloadData];
	BOOL locked = NO;
	switch (listType) {
		case BibleTab:
			[moduleController loadPrimaryBible: newModule];
			//[[moduleController viewController] displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			//[[moduleController viewController] addHistoryItem: BibleTab];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
			[HistoryController addHistoryItem:BibleTab];
			if([[moduleController primaryBible] isLocked])
				locked = YES;
			break;
		case CommentaryTab:
			[moduleController loadPrimaryCommentary:newModule];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			//[[moduleController viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
			[HistoryController addHistoryItem:CommentaryTab];
			if([[moduleController primaryCommentary] isLocked])
				locked = YES;
			break;
		case DictionaryTab:
			[moduleController loadPrimaryDictionary:newModule];
			//[[moduleController viewController] reloadDictionaryData];
			//[[moduleController viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			if([[moduleController primaryDictionary] isLocked])
				locked = YES;
			break;
		case DevotionalTab:
			[moduleController loadPrimaryDevotional:newModule];
			if([[moduleController primaryDevotional] isLocked])
				locked = YES;
			break;
		case DownloadsTab:
		case PreferencesTab:
			break;
	}
	if(locked) {
		[self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
		//[[moduleController viewController] toggleModulesList];
	}
	
	//[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *module = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[[PSModuleController defaultModuleController] removeModule: module];
		if(listType == DictionaryTab) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationReloadDictionaryData object:nil];
			//[[[PSModuleController defaultModuleController] viewController] reloadDictionaryData];
		}
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
	}
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: [tableView cellForRowAtIndexPath: indexPath].textLabel.text];
	[leafViewController displayInfoForModule:mod];
	//if(listType == BibleTab) {
		[self.navigationController pushViewController:leafTabBarController animated:YES];
	//} else {
	//	[self.navigationController pushViewController:leafViewController animated:YES];
	//}
	//[self presentModalViewController:leafTabBarController animated:YES];	
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)addButtonsToToolbar:(BOOL)animated {
	if(self.listType == BibleTab) {
		// create the array of buttons to show
		NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:4];
		SwordModule *swordModule = [[PSModuleController defaultModuleController] primaryBible];
		NSString *imageName;
		
		// strongs, morph, headings, x-refs, footnotes, red letter
		if([swordModule hasFeature: SWMOD_FEATURE_STRONGS] || [swordModule hasFeature: SWMOD_CONF_FEATURE_STRONGS]) {
			if(GetBoolPrefForMod(DefaultsStrongsPreference, [swordModule name])) {
				imageName = @"enabled-Strongs.png";
			} else {
				imageName = @"disabled-Strongs.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(strongsButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
		if([swordModule hasFeature: SWMOD_FEATURE_MORPH]) {
			if(GetBoolPrefForMod(DefaultsMorphPreference, [swordModule name])) {
				imageName = @"enabled-Morph.png";
			} else {
				imageName = @"disabled-Morph.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(morphButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
		if([swordModule hasFeature: SWMOD_FEATURE_HEADINGS]) {
			if(GetBoolPrefForMod(DefaultsHeadingsPreference, [swordModule name])) {
				imageName = @"enabled-Headings.png";
			} else {
				imageName = @"disabled-Headings.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(headingsButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
		if([swordModule hasFeature: SWMOD_FEATURE_FOOTNOTES]) {
			if(GetBoolPrefForMod(DefaultsFootnotesPreference, [swordModule name])) {
				imageName = @"enabled-Footnotes.png";
			} else {
				imageName = @"disabled-Footnotes.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(footnotesButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
		if([swordModule hasFeature: SWMOD_FEATURE_SCRIPTREF]) {
			if(GetBoolPrefForMod(DefaultsScriptRefsPreference, [swordModule name])) {
				imageName = @"enabled-Xrefs.png";
			} else {
				imageName = @"disabled-Xrefs.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(xrefsButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
//		if([swordModule hasFeature: SWMOD_FEATURE_REDLETTERWORDS]) {
//			if(GetBoolPrefForMod(DefaultsRedLetterPreference, [swordModule name])) {
//				imageName = @"enabled-RedLetter.png";
//			} else {
//				imageName = @"disabled-RedLetter.png";
//			}
//			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(redletterButtonPressed:)];
//			[buttons addObject:barButton];
//			[barButton release];
//		}
		
		// add buttons to the bottom toolbar.
		[modulesToolbar setItems:buttons animated:animated];
	}
}

- (void)redisplayFromButtonPress {
	switch (listType) {
		case BibleTab:
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			break;
		case CommentaryTab:
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			break;
		case DictionaryTab:
		case DevotionalTab:
		case DownloadsTab:
		case PreferencesTab:
			break;
	}
}

- (void)strongsButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsStrongsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	SetBoolPrefForMod(!pref, DefaultsStrongsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:YES];
	//reloadModuleViews = YES;
	[self redisplayFromButtonPress];
}

- (void)headingsButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsHeadingsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	SetBoolPrefForMod(!pref, DefaultsHeadingsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:YES];
	//reloadModuleViews = YES;
	[self redisplayFromButtonPress];
}

- (void)footnotesButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsFootnotesPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	SetBoolPrefForMod(!pref, DefaultsFootnotesPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:YES];
	//reloadModuleViews = YES;
	[self redisplayFromButtonPress];
}

- (void)xrefsButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsScriptRefsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	SetBoolPrefForMod(!pref, DefaultsScriptRefsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:YES];
	//reloadModuleViews = YES;
	[self redisplayFromButtonPress];
}

- (void)morphButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsMorphPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	SetBoolPrefForMod(!pref, DefaultsMorphPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:YES];
	//reloadModuleViews = YES;
	[self redisplayFromButtonPress];
}

@end
