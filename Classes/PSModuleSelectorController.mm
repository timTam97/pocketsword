//
//  PSModuleSelectorController.m
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleSelectorController.h"
#import "PSModuleController.h"


@implementation PSModuleSelectorController

@synthesize listType;

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
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//NSString *ref = [[PSModuleController defaultModuleController] getCurrentBibleRef];
	NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	if(([[PSModuleController defaultModuleController] primaryBible] && [newModule isEqualToString:[[[PSModuleController defaultModuleController] primaryBible] name]]) || ([[PSModuleController defaultModuleController] primaryCommentary] && [newModule isEqualToString:[[[PSModuleController defaultModuleController] primaryCommentary] name]]) || ([[PSModuleController defaultModuleController] primaryDictionary] && [newModule isEqualToString:[[[PSModuleController defaultModuleController] primaryDictionary] name]])) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return; // do nothing, because we selected the currently loaded module.
	}
	// Update the module list to reflect the current module
	[tableView reloadData];
	BOOL locked = NO;
	switch (listType) {
		case BibleTab:
			[[PSModuleController defaultModuleController] loadPrimaryBible: newModule];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: BibleTab];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
			if([[[PSModuleController defaultModuleController] primaryBible] isLocked])
				locked = YES;
			break;
		case CommentaryTab:
			[[PSModuleController defaultModuleController] loadPrimaryCommentary:newModule];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
			//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: CommentaryTab];
			if([[[PSModuleController defaultModuleController] primaryCommentary] isLocked])
				locked = YES;
			break;
		case DictionaryTab:
			[[PSModuleController defaultModuleController] loadPrimaryDictionary:newModule];
			//[[[PSModuleController defaultModuleController] viewController] reloadDictionaryData];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			if([[[PSModuleController defaultModuleController] primaryDictionary] isLocked])
				locked = YES;
			break;
		case DevotionalTab:
			[[PSModuleController defaultModuleController] loadPrimaryDevotional:newModule];
			if([[[PSModuleController defaultModuleController] primaryDevotional] isLocked])
				locked = YES;
			break;
	}
	if(locked) {
		[self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
		//[[[PSModuleController defaultModuleController] viewController] toggleModulesList];
	}
	
	[pool release];
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
		[tableView reloadData];
	}
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: [tableView cellForRowAtIndexPath: indexPath].textLabel.text];
	[leafViewController displayInfoForModule:mod];
	[UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
                           forView:self.view //[[[PSModuleController defaultModuleController] viewController] modulesListView]
                             cache:YES];
	
    [UIView setAnimationDuration:1];
	//[[[[PSModuleController defaultModuleController] viewController] modulesListView] addSubview: leafViewController.view];
	[self.view addSubview:leafViewController.view];
    [UIView commitAnimations];
	[leafViewController performSelector:@selector(viewDidAppear) withObject:nil afterDelay:1.0];
	
}

@end
