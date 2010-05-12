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
			return [[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] count];
			break;
		case CommentaryTab:
			return [[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
			break;
		case DictionaryTab:
			return [[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] count];
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
	
	switch (listType) {
		case BibleTab:
			cell.textLabel.text = [[[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex:indexPath.row] descr];
			break;
		case CommentaryTab:
			cell.textLabel.text = [[[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex:indexPath.row] descr];
			break;
		case DictionaryTab:
			cell.textLabel.text = [[[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [[[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:indexPath.row] descr];
			break;
	}
	if ([moduleManager isLoaded:cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor blueColor];
		cell.detailTextLabel.textColor = [UIColor blueColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.textColor = [UIColor blackColor];
	}
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSString *ref = [moduleManager getCurrentBibleRef];
	NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
	if(([moduleManager primaryBible] && [newModule isEqualToString:[[moduleManager primaryBible] name]]) || ([moduleManager primaryCommentary] && [newModule isEqualToString:[[moduleManager primaryCommentary] name]]) || ([moduleManager primaryDictionary] && [newModule isEqualToString:[[moduleManager primaryDictionary] name]])) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return; // do nothing, because we selected the currently loaded module.
	}
	// Update the module list to reflect the current module
	[tableView reloadData];
	BOOL locked = NO;
	switch (listType) {
		case BibleTab:
			[moduleManager loadPrimaryBible: newModule];
			[[moduleManager viewController] displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[[moduleManager viewController] addHistoryItem: BibleTab];
			if([[moduleManager primaryBible] isLocked])
				locked = YES;
			break;
		case CommentaryTab:
			[moduleManager loadPrimaryCommentary:newModule];
			[[moduleManager viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[[moduleManager viewController] addHistoryItem: CommentaryTab];
			if([[moduleManager primaryCommentary] isLocked])
				locked = YES;
			break;
		case DictionaryTab:
			[moduleManager loadPrimaryDictionary:newModule];
			[[moduleManager viewController] reloadDictionaryData];
			//[[moduleManager viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			if([[moduleManager primaryDictionary] isLocked])
				locked = YES;
			break;
	}
	if(locked)
		[self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
	else
		[[moduleManager viewController] toggleModulesList: nil];
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *module = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[moduleManager removeModule: module];
		//[tableView reloadData];
		//[moduleManager reload];
		//[moduleTable reloadData];
	}
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	SwordModule *mod = [[moduleManager swordManager] moduleWithName: [tableView cellForRowAtIndexPath: indexPath].textLabel.text];
	[leafViewController displayInfoForModule:mod];
	[UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
                           forView:[[moduleManager viewController] modulesListView]
                             cache:YES];
	
    [UIView setAnimationDuration:1];
	[[[moduleManager viewController] modulesListView] addSubview: leafViewController.view];
    [UIView commitAnimations];
	
}

@end
