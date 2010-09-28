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


@implementation PSModuleSelectorController

@synthesize listType;

-(void)viewWillAppear:(BOOL)animated {
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
	[modulesListTable reloadData];
	if(ip) {
		[modulesListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionMiddle animated:NO];
	}

	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
		modulesNavigationBar.frame = CGRectMake(0.0, 0.0, 480.0, 32.0);
		modulesListTable.frame = CGRectMake(0.0, 32.0, 480.0, 268.0);
	} else {
		modulesNavigationBar.frame = CGRectMake(0.0, 0.0, 320.0, 44.0);
		modulesListTable.frame = CGRectMake(0.0, 44.0, 320.0, 416.0);
	}
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if(toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		modulesNavigationBar.frame = CGRectMake(0.0, 0.0, 320.0, 32.0);
		modulesListTable.frame = CGRectMake(0.0, 32.0, 320.0, 428.0);
	} else {
		modulesNavigationBar.frame = CGRectMake(0.0, 0.0, 480.0, 44.0);
		modulesListTable.frame = CGRectMake(0.0, 44.0, 480.0, 256.0);
	}
}

- (IBAction)addModuleButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowDownloadsTab object:nil];
}

- (IBAction)dismissModuleSelector {
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
	}
	if ([[PSModuleController defaultModuleController] isLoaded:cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor blueColor];
		cell.detailTextLabel.textColor = [UIColor blueColor];
	} else if(locked) {
		cell.textLabel.textColor = [UIColor brownColor];
		cell.detailTextLabel.textColor = [UIColor brownColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.textColor = [UIColor blackColor];
	}
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//NSString *ref = [[PSModuleController defaultModuleController] getCurrentBibleRef];
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	if(([moduleController primaryBible] && [newModule isEqualToString:[[moduleController primaryBible] name]]) || ([moduleController primaryCommentary] && [newModule isEqualToString:[[moduleController primaryCommentary] name]]) || ([moduleController primaryDictionary] && [newModule isEqualToString:[[moduleController primaryDictionary] name]])) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
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
	[self presentModalViewController:leafViewController animated:YES];
	
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

@end
