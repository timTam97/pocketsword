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
#import "PSHistoryController.h"
#import "PSResizing.h"
#import "PocketSwordAppDelegate.h"
#import "PSModuleInfoViewController.h"
#import "SwordModule.h"
#import "PSModulePreferencesController.h"
#import "SwordManager.h"
#import "PSTabBarControllerDelegate.h"

@implementation PSModuleSelectorController

@synthesize listType, modulesListTable, modulesToolbar;

- (void)loadView {
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		baseView.backgroundColor = [UIColor blackColor];
	} else {
		baseView.backgroundColor = [UIColor whiteColor];
	}
	
	UITableView *listTable = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, (viewHeight - 44.0)) style:UITableViewStylePlain];
	listTable.delegate = self;
	listTable.dataSource = self;
	listTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[baseView addSubview:listTable];
	self.modulesListTable = listTable;
	[listTable release];
	
	//CGFloat y = viewHeight - 44 - self.navigationController.navigationBar.frame.size.height;
	//y -= [[UIApplication sharedApplication] statusBarFrame].size.height;

	UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, viewHeight - 44, viewWidth, 44)];
	toolbar.barStyle = UIBarStyleBlack;
	toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
	[baseView addSubview:toolbar];
	self.modulesToolbar = toolbar;
	[toolbar release];
	
	self.view = baseView;
	[baseView release];
}

- (void)dealloc {
	[super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSInteger moduleCount = 0;
	
	if(listType == PreferencesTab) {
		modulesToolbar.hidden = YES;
	} else if(![PSResizing iPad]) {
		UIBarButtonItem	*modulesCloseButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"CloseButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(dismissModuleSelector)];
		self.navigationItem.leftBarButtonItem = modulesCloseButton;
		[modulesCloseButton release];
		UIBarButtonItem *modulesAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addModuleButtonPressed)];
		self.navigationItem.rightBarButtonItem = modulesAddButton;
		[modulesAddButton release];
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		modulesListTable.backgroundColor = [UIColor blackColor];
	} else {
		modulesListTable.backgroundColor = [UIColor whiteColor];
	}
	
	NSIndexPath *ip = nil;//default value
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	if([self listType] == BibleTab) {
		self.navigationItem.title = NSLocalizedString(SWMOD_CATEGORY_BIBLES, @"");
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_BIBLES];
		moduleCount = [array count];
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
		self.navigationItem.title = NSLocalizedString(SWMOD_CATEGORY_COMMENTARIES, @"");
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES];
		moduleCount = [array count];
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
		self.navigationItem.title = NSLocalizedString(SWMOD_CATEGORY_DAILYDEVS, @"");
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS];
		moduleCount = [array count];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleController primaryDevotional] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			ip = [NSIndexPath indexPathForRow: pos inSection: 0];
		}
	} else if([self listType] == DictionaryTab){
		self.navigationItem.title = NSLocalizedString(SWMOD_CATEGORY_DICTIONARIES, @"");
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES];
		moduleCount = [array count];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleController primaryDictionary] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			ip = [NSIndexPath indexPathForRow: pos inSection: 0];
		}			
	} else if([self listType] == PreferencesTab) {
		self.navigationItem.title = NSLocalizedString(@"PreferencesModulePreferencesTitle", @"Module Preferences");
		ip = nil;
	}
	[modulesListTable reloadData];
	if(ip) {
		[modulesListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionMiddle animated:NO];
	}
	[self addButtonsToToolbar:NO];
	
	if([self respondsToSelector:@selector(contentSizeForViewInPopover)]) {
		CGFloat height = 0.0;
		height += modulesToolbar.frame.size.height;
		height += self.navigationController.navigationBar.frame.size.height;
		height += moduleCount * 44.0;
		self.contentSizeForViewInPopover = CGSizeMake(540.0, height);
	}
}

- (void)addModuleButtonPressed {
	//close the selector first, then show the downloads tab.
	[self dismissModuleSelector];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowDownloadsTab object:nil];
}

- (void)dismissModuleSelector {
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
		case CommentaryTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
		case DictionaryTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] count];
		case DevotionalTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS] count];
		case PreferencesTab:
			return [[[[PSModuleController defaultModuleController] swordManager] moduleNames] count];
		case DownloadsTab:
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
		{
			SwordModule *currentModule = [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex:indexPath.row];
			cell.textLabel.text = [currentModule name];
			cell.detailTextLabel.text = [currentModule descr];
			locked = [currentModule isLocked];
		}
			break;
		case CommentaryTab:
		{
			SwordModule *currentModule = [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex:indexPath.row];
			cell.textLabel.text = [currentModule name];
			cell.detailTextLabel.text = [currentModule descr];
			locked = [currentModule isLocked];
		}
			break;
		case DictionaryTab:
		{
			SwordModule *currentModule = [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:indexPath.row];
			cell.textLabel.text = [currentModule name];
			cell.detailTextLabel.text = [currentModule descr];
			locked = [currentModule isLocked];
		}
			break;
		case DevotionalTab:
		{
			SwordModule *currentModule = [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS] objectAtIndex:indexPath.row];
			cell.textLabel.text = [currentModule name];
			cell.detailTextLabel.text = [currentModule descr];
			locked = [currentModule isLocked];
		}
			break;
		case PreferencesTab:
		{
			SwordModule *currentModule = [[[[PSModuleController defaultModuleController] swordManager] listModules] objectAtIndex:indexPath.row];
			cell.textLabel.text = [currentModule name];
			cell.detailTextLabel.text = [currentModule descr];
			locked = [currentModule isLocked];
		}
			break;
		case DownloadsTab:
			break;
	}
	if ((listType != PreferencesTab) && [[PSModuleController defaultModuleController] isLoaded:cell.textLabel.text]) {
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
	if(listType == PreferencesTab) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else {
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}
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
	
	if(listType == PreferencesTab) {
		[self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
		return;
	}

	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	if(([moduleController primaryBible] && [newModule isEqualToString:[[moduleController primaryBible] name]]) || ([moduleController primaryCommentary] && [newModule isEqualToString:[[moduleController primaryCommentary] name]]) || ([moduleController primaryDictionary] && [newModule isEqualToString:[[moduleController primaryDictionary] name]])) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		[self dismissModuleSelector];
		return; // do nothing, because we selected the currently loaded module, but close the view & return to viewing the module.
	}
	// Update the module list to reflect the current module
	[tableView reloadData];
	BOOL locked = NO;
    BOOL iPad = [PSResizing iPad];
	switch (listType) {
		case BibleTab:
			[moduleController loadPrimaryBible: newModule];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			[PSHistoryController addHistoryItem:BibleTab];
			if([[moduleController primaryBible] isLocked])
				locked = YES;
			break;
		case CommentaryTab:
			[moduleController loadPrimaryCommentary:newModule];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			[PSHistoryController addHistoryItem:CommentaryTab];
			if([[moduleController primaryCommentary] isLocked])
				locked = YES;
			break;
		case DictionaryTab:
			[moduleController loadPrimaryDictionary:newModule];
			if(iPad) {
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationReloadDictionaryData object:nil];
			}
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
		[self dismissModuleSelector];
	}
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *module = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[[PSModuleController defaultModuleController] removeModule: module];
		if(listType == DictionaryTab) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationReloadDictionaryData object:nil];
		}
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
	}
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: [tableView cellForRowAtIndexPath: indexPath].textLabel.text];
	
	UITabBarController *moduleTabBarController = [[UITabBarController alloc] initWithNibName:nil bundle:nil];
//	if([moduleTabBarController.tabBar respondsToSelector:@selector(isTranslucent)]) {
//		[moduleTabBarController.tabBar setTranslucent:[PSTabBarControllerDelegate getBarTranslucentDefault]];
//		[moduleTabBarController.tabBar setBarTintColor:[PSTabBarControllerDelegate getBarColorDefault]];
//	}
	
	PSModuleInfoViewController *detailsViewController = [[PSModuleInfoViewController alloc] initWithNibName:nil bundle:nil];
	[detailsViewController displayInfoForModule:mod];
	PSModulePreferencesController *preferencesViewController = [[PSModulePreferencesController alloc] initWithStyle:UITableViewStyleGrouped];
	preferencesViewController.listType = self.listType;
	preferencesViewController.hackTableView = (listType == PreferencesTab) ? NO : YES;
	[preferencesViewController displayPrefsForModule:mod];
	NSArray *tabs = [NSArray arrayWithObjects:detailsViewController, preferencesViewController, nil];
	[moduleTabBarController setViewControllers:tabs];
	CGSize contentSize = self.contentSizeForViewInPopover;
	contentSize.height = 2200;
	moduleTabBarController.contentSizeForViewInPopover = contentSize;
	if(listType == PreferencesTab) {
		// jump straight to the preferences tab...
		[moduleTabBarController setSelectedViewController:preferencesViewController];
	}
	[self.navigationController pushViewController:moduleTabBarController animated:YES];
	[detailsViewController release];
	[preferencesViewController release];
	[moduleTabBarController release];
	
//	leafTabBarController.contentSizeForViewInPopover = self.contentSizeForViewInPopover;
//	[self.navigationController pushViewController:leafTabBarController animated:YES];
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
		if([swordModule hasFeature: SWMOD_FEATURE_REDLETTERWORDS]) {
			if(GetBoolPrefForMod(DefaultsRedLetterPreference, [swordModule name])) {
				imageName = @"enabled-RedLetter.png";
			} else {
				imageName = @"disabled-RedLetter.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(redletterButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
		if([swordModule hasFeature:SWMOD_FEATURE_GLOSSES] || [swordModule hasFeature:@"Ruby"]) {
			if(GetBoolPrefForMod(DefaultsGlossesPreference, [swordModule name])) {
				imageName = @"enabled-Glosses.png";
			} else {
				imageName = @"disabled-Glosses.png";
			}
			UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(glossesButtonPressed:)];
			[buttons addObject:barButton];
			[barButton release];
		}
		
		// add VPL at the end of the toolbar.
		if(GetBoolPrefForMod(DefaultsVPLPreference, [swordModule name])) {
			imageName = @"enabled-VPL.png";
		} else {
			imageName = @"disabled-VPL.png";
		}
		UIBarButtonItem *vplBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStylePlain target:self action:@selector(vplButtonPressed:)];
		[buttons addObject:vplBarButton];
		[vplBarButton release];
		vplBarButton = nil;

		
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

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	[hud release];
	hud = nil;
}

- (void)showHUDWithTitle:(NSString*)titleText withTick:(BOOL)tick {
	UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:viewToUse];
	HUD.delegate = self;
	HUD.labelText = titleText;
	if(tick) {
		HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
	} else {
		HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
	}
	HUD.mode = MBProgressHUDModeCustomView;
	[viewToUse addSubview:HUD];
	[HUD show:YES];
	[HUD hide:YES afterDelay:0.85];
}

- (void)strongsButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsStrongsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesStrongsPreferencesTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsStrongsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)headingsButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsHeadingsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesHeadingsTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsHeadingsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)footnotesButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsFootnotesPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesFootnotesTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsFootnotesPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)xrefsButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsScriptRefsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesCrossReferencesTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsScriptRefsPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)morphButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsMorphPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesMorphologyPreferencesTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsMorphPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)redletterButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsRedLetterPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesRedLetterTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsRedLetterPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)glossesButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsGlossesPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesGlossesTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsGlossesPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

- (void)vplButtonPressed:(id)sender {
	BOOL pref = GetBoolPrefForMod(DefaultsVPLPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self showHUDWithTitle:NSLocalizedString(@"PreferencesVPLTitle", @"") withTick:!pref];
	SetBoolPrefForMod(!pref, DefaultsVPLPreference, [[[PSModuleController defaultModuleController] primaryBible] name]);
	[self addButtonsToToolbar:NO];
	[self redisplayFromButtonPress];
}

@end
