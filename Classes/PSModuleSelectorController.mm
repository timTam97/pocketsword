//
//  PSModuleSelectorController.m
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleSelectorController.h"
#import "PSModuleController.h"
#import "PSHistoryController.h"
#import "PSResizing.h"
#import "PocketSwordAppDelegate.h"
#import "SwordModule.h"
#import "PSModulePreferencesController.h"
#import "SwordManager.h"
#import "PSTabBarControllerDelegate.h"
#import "SwordDictionary.h"

@implementation PSModuleSelectorController

@synthesize listType, modulesListTable;

- (void)loadView {
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;

	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	baseView.backgroundColor = [UIColor systemBackgroundColor];

	UITableView *listTable = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight) style:UITableViewStylePlain];
	listTable.delegate = self;
	listTable.dataSource = self;
	listTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[baseView addSubview:listTable];
	self.modulesListTable = listTable;

	self.view = baseView;
}


- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSInteger moduleCount = 0;

	if(listType != PreferencesTab && ![PSResizing iPad]) {
		UIBarButtonItem	*modulesCloseButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"CloseButtonTitle", @"") style:UIBarButtonItemStylePlain target:self action:@selector(dismissModuleSelector)];
		self.navigationItem.leftBarButtonItem = modulesCloseButton;
	}

	modulesListTable.backgroundColor = [UIColor systemBackgroundColor];

	NSIndexPath *ip = nil;//default value
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	if([self listType] == CommentaryTab) {
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
	} else if([self listType] == DictionaryTab){
		self.navigationItem.title = NSLocalizedString(SWMOD_CATEGORY_DICTIONARIES, @"");
		NSArray *array = [[moduleController swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES];
		moduleCount = [array count];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString:[[moduleController primaryDictionary] name]]) {
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

	CGFloat height = 0.0;
	height += self.navigationController.navigationBar.frame.size.height;
	height += moduleCount * 44.0;
	self.preferredContentSize = CGSizeMake(540.0, height);
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
		case CommentaryTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
		case DictionaryTab:
			return [[[[PSModuleController defaultModuleController] swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] count];
		case PreferencesTab:
			return [[[[PSModuleController defaultModuleController] swordManager] moduleNames] count];
		case BibleTab:
		case DevotionalTab:
		case DownloadsTab:
			break;
	}
	return 0;
}
// BibleTab, DevotionalTab and DownloadsTab above are dead placeholders kept only
// so that the ShownTab enum values in globals.h do not shift (which would break
// any persisted raw-int tab prefs). The Bible-tab module picker is gone because
// KJV is the only Bible module; devotional and downloads were removed earlier.

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	NSString *theIdentifier = @"id-mod";

	// Try to recover a cell from the table view with the given identifier, this is for performance
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: theIdentifier];

	// If no cell is available, create a new one using the given identifier -
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: theIdentifier];
	}

	BOOL locked = NO;
	switch (listType) {
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
		case PreferencesTab:
		{
			SwordModule *currentModule = [[[[PSModuleController defaultModuleController] swordManager] listModules] objectAtIndex:indexPath.row];
			cell.textLabel.text = [currentModule name];
			cell.detailTextLabel.text = [currentModule descr];
			locked = [currentModule isLocked];
		}
			break;
		case BibleTab:
		case DevotionalTab:
		case DownloadsTab:
			break;
	}
	if ((listType != PreferencesTab) && [[PSModuleController defaultModuleController] isLoaded:cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor systemBlueColor];
		cell.detailTextLabel.textColor = [UIColor systemBlueColor];
	} else if(locked) {
		cell.textLabel.textColor = [UIColor systemBrownColor];
		cell.detailTextLabel.textColor = [UIColor systemBrownColor];
	} else {
		cell.textLabel.textColor = [UIColor labelColor];
		cell.detailTextLabel.textColor = [UIColor labelColor];
	}
	if(listType == PreferencesTab) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else {
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	cell.backgroundColor = [UIColor systemBackgroundColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	if(listType == PreferencesTab) {
		[self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
		return;
	}

	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	if(([moduleController primaryCommentary] && [newModule isEqualToString:[[moduleController primaryCommentary] name]]) || ([moduleController primaryDictionary] && [newModule isEqualToString:[[moduleController primaryDictionary] name]])) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		[self dismissModuleSelector];
		return; // do nothing, because we selected the currently loaded module, but close the view & return to viewing the module.
	}
	// Update the module list to reflect the current module
	[tableView reloadData];
	BOOL locked = NO;
    BOOL iPad = [PSResizing iPad];
	switch (listType) {
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
		case BibleTab:
		case DevotionalTab:
		case DownloadsTab:
		case PreferencesTab:
			// Dead placeholders (bible picker moved to dropdown menu; devotional/downloads removed).
			break;
	}
	if(locked) {
		[self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
	} else {
		[self dismissModuleSelector];
	}
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	@autoreleasepool {

		if (editingStyle == UITableViewCellEditingStyleDelete) {
			NSString *module = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
			[[PSModuleController defaultModuleController] removeModule: module];
			if(listType == DictionaryTab) {
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationReloadDictionaryData object:nil];
			}
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
		}

	}
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: [tableView cellForRowAtIndexPath: indexPath].textLabel.text];

	PSModulePreferencesController *preferencesViewController = [[PSModulePreferencesController alloc] initWithStyle:UITableViewStyleGrouped];
	preferencesViewController.listType = self.listType;
	preferencesViewController.hackTableView = (listType == PreferencesTab) ? NO : YES;
	[preferencesViewController displayPrefsForModule:mod];
	CGSize contentSize = self.preferredContentSize;
	contentSize.height = 2200;
	preferencesViewController.preferredContentSize = contentSize;
	[self.navigationController pushViewController:preferencesViewController animated:YES];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}

@end
