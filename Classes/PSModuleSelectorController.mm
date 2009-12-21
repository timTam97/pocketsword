//
//  PSModuleSelectorController.m
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
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
	// TODO: Add other section headers for other module types
//	NSInteger tag = [tableView tag];
//	if (tag == MODULE_TABLE) {
//		@try {
//			NSUInteger modCount = [[[moduleManager swordManager] moduleListByType] count];
//			if (modCount > 0) {
//				return [[[[moduleManager swordManager] moduleListByType] objectAtIndex: section] moduleType];
//			} else {
//				return NSLocalizedString(@"NoModulesInstalled", @"");
//			}
//		}
//		@catch (id except) {
//			return NSLocalizedString(@"NoModulesInstalled", @"");
//		}
//	}
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
	//			cell.accessoryType = UITableViewCellAccessoryCheckmark;
	//		} else {
	//			cell.accessoryType = UITableViewCellAccessoryNone;
	//		}
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
	switch (listType) {
		case BibleTab:
			[moduleManager loadPrimaryBible: newModule];
			[viewController displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[viewController addHistoryItem: BibleTab];
			break;
		case CommentaryTab:
			[moduleManager loadPrimaryCommentary:newModule];
			[viewController displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[viewController addHistoryItem: CommentaryTab];
			break;
		case DictionaryTab:
			[moduleManager loadPrimaryDictionary:newModule];
			[viewController reloadDictionaryData];
			//[viewController displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			break;
	}
	[viewController toggleModulesList: nil];
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *module = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[moduleManager removeModule: module];
		//[moduleManager reload];
		//[moduleTable reloadData];
	}
	
	[pool release];
}



@end
