/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2010 CrossWire Bible Society

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "PSHistoryController.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import "PSBookmarkTableViewCell.h"
#import "PSHistoryItem.h"
#import "SwordManager.h"


@implementation PSHistoryController

- (id)init {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		UITabBarItem *tBI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory tag:0];
		self.tabBarItem = tBI;
		[tBI release];
	}
	return self;
}

- (void)closeButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
}

- (void)setListType:(ShownTab)listT {
	listType = listT;
}

// used for iCloud sync just in case our history changes while we're viewing it.
- (void)reloadTableViewFromNotification {
	[self.tableView reloadData];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeButtonPressed)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"HistoryClearButtonTitle", @"Clear") style: UIBarButtonItemStyleBordered target: self action: @selector(trashButtonPressed)] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableViewFromNotification) name:NotificationHistoryChanged object:nil];
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationHistoryChanged object:nil];
	[super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
	
	[super viewWillAppear:animated];
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		self.tableView.backgroundColor = [UIColor blackColor];
	} else {
		self.tableView.backgroundColor = [UIColor whiteColor];
	}
	//[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:historyNavigationBar mainView:self.tableView useStatusBar:YES];
	self.navigationItem.title = NSLocalizedString(@"HistoryTitle", @"History");
	[self.tableView reloadData];
	
	if(([self.tableView numberOfSections] > 0) && [self.tableView numberOfRowsInSection: 0] > 0) {
		NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: 0];
		if(ip)
			[self.tableView scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionTop animated:NO];
	}
	
}

// This should be called just AFTER:
//    "nextChapter".
//    or "prevChapter".
//    or navigation to a new ref from the refPicker.
//    or when the user selects a new module to view.
//    or when the user selects a bookmark.
//    or when the user selects a search result.
+ (void)addHistoryItem:(ShownTab)tabForHistory {
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *verse;
	NSString *mod;
	NSMutableArray *history = [[defaults arrayForKey: PSHistoryName] mutableCopy];
	BOOL valid = NO;
	
	if(tabForHistory == BibleTab) {
		verse = [defaults stringForKey: DefaultsBibleVersePosition];
		if([[PSModuleController defaultModuleController] primaryBible]) {
			valid = YES;
			mod = [[[PSModuleController defaultModuleController] primaryBible] name];
		}
//		historyName = PS_HISTORY_NAME;
//		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else if(tabForHistory == CommentaryTab) {
		verse = [defaults stringForKey: DefaultsCommentaryVersePosition];
		if([[PSModuleController defaultModuleController] primaryCommentary]) {
			valid = YES;
			mod = [[[PSModuleController defaultModuleController] primaryCommentary] name];
		}
//		historyName = @"commentaryHistory";
//		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else {
		ALog(@"\nWe don't know which tab we're on!  :(");
	}
	
	if(valid) {
		NSString *ref = [NSString stringWithFormat:@"%@:%@", [PSModuleController createRefString:[PSModuleController getCurrentBibleRef]], verse];
		
		NSArray *historyItem = [NSArray arrayWithObjects: ref, @"0"/*scroll*/, mod, [NSDate date], nil];
		
		if (!history) {
			history = [[NSMutableArray alloc] initWithObjects: nil];
			
			NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
			[prefs setObject: history forKey: PSHistoryName];
			
			[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
			[prefs release];
		} else {
		
			//check for duplicates:
			for (int ii = 0; ii < [history count]; ii++) {
				NSArray *existingItem = [history objectAtIndex:ii];
				NSString *existingRef = [existingItem objectAtIndex:0];
				if([ref isEqualToString:existingRef]) {
					//if the references are the same, 
					NSString *existingMod = nil;
					if([existingItem count] > 2) {
						existingMod = [existingItem objectAtIndex:2];
					}
					if(!existingMod || [mod isEqualToString:existingMod]) {
						//if the mods are the same, or it's an OLD history item without a mod, delete it
						[history removeObject:existingItem];
						break;
					}
				}
			}
		}
		
		[history insertObject: historyItem atIndex: 0];
		if([history count] >= PSHistoryMaxEntries) {
			[history removeLastObject];
		}
		
		[defaults setObject: history forKey: PSHistoryName];
		[defaults synchronize];
		
		// synchronize with iCloud as well, if available:
		Class cls = NSClassFromString(@"NSUbiquitousKeyValueStore");
		if(cls) {
			id kvStore = [cls defaultStore];
            [kvStore setArray:history forKey:PSHistoryName];
		}
	}
	if(history) {
		[history release];
		history = nil;
	}
	
	[pool release];
	
}

- (void)trashButtonPressed {
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"HistoryClearConfirmationTitle", @"Clear All History?") message: NSLocalizedString(@"HistoryClearConfirmationMessage", @"Are you sure?") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
	[alertView show];
	[alertView release];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	if (buttonIndex == 1) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: PSHistoryName];
		
		// synchronize with iCloud as well, if available:
		Class cls = NSClassFromString(@"NSUbiquitousKeyValueStore");
		if(cls) {
			id kvStore = [cls defaultStore];
            [kvStore removeObjectForKey:PSHistoryName];
			NSMutableArray *history = [[NSMutableArray alloc] initWithObjects: nil];
			[kvStore setArray:history forKey:PSHistoryName];
			[history release];
			history = nil;
		}
		
//		switch (listType) {
//			case BibleTab:
//				[[NSUserDefaults standardUserDefaults] removeObjectForKey: PS_HISTORY_NAME];
//				break;
//			case CommentaryTab:
//				[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"commentaryHistory"];
//				break;
//			default:
//				break;
//		}
		[self.tableView reloadData];
	} else {
		
	}
	[pool release];
}

- (void)removeHistoryItem:(NSInteger)historyIndex forTab:(ShownTab)tabForHistory {
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *history = [[defaults arrayForKey: PSHistoryName] mutableCopy];
//	NSString *historyName;
//	if(tabForHistory == BibleTab) {
//		historyName = PS_HISTORY_NAME;
//		history = [[defaults arrayForKey: historyName] mutableCopy];
//	} else if(tabForHistory == CommentaryTab) {
//		historyName = @"commentaryHistory";
//		history = [[defaults arrayForKey: historyName] mutableCopy];
//	} else {
//		return;
//	}
	[history removeObjectAtIndex:historyIndex];
	
	[defaults setObject: history forKey: PSHistoryName];
	[defaults synchronize];
	
	// synchronize with iCloud as well, if available:
	Class cls = NSClassFromString(@"NSUbiquitousKeyValueStore");
	if(cls) {
		id kvStore = [cls defaultStore];
		[kvStore setArray:history forKey:PSHistoryName];
	}

	if(history) {
		[history release];
		history = nil;
	}
	
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:historyIndex inSection:0];
	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey: PSHistoryName];
	if(history) {
		return [history count];
	}
//	switch (listType) {
//		case BibleTab:
//			history = [[NSUserDefaults standardUserDefaults] arrayForKey: PS_HISTORY_NAME];
//			if(history) {
//				return [history count];
//			} else {
//				return 0;
//			}
//			break;
//		case CommentaryTab:
//			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
//			if(history) {
//				return [history count];
//			} else {
//				return 0;
//			}
//			break;
//		default:
//			break;
//	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSString *theIdentifier = @"id-mod";
	
	// Try to recover a cell from the table view with the given identifier, this is for performance
	PSBookmarkTableViewCell *cell = (PSBookmarkTableViewCell*)[tableView dequeueReusableCellWithIdentifier: theIdentifier];
	
	// If no cell is available, create a new one using the given identifier - 
	if (!cell) {
		cell = [[[PSBookmarkTableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: theIdentifier] autorelease];
	}
	
	NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey: PSHistoryName];
//	switch (listType) {
//		case BibleTab:
//			history = [[NSUserDefaults standardUserDefaults] arrayForKey: PS_HISTORY_NAME];
//			break;
//		case CommentaryTab:
//			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
//			break;
//		default:
//			break;
//	}
	
	NSArray *obj = [history objectAtIndex: indexPath.row];
	cell.textLabel.text = [obj objectAtIndex: 0];
	if([obj count] > 2)
		cell.detailTextLabel.text = [obj objectAtIndex: 2];
	else
		cell.detailTextLabel.text = @"";
	if([obj count] > 3) {
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		
		NSString *dateString = [dateFormatter stringFromDate:[obj objectAtIndex: 3]];
		[dateFormatter release];
		dateFormatter = nil;
		cell.lastAccessedLabel.text = dateString;
	} else {
		cell.lastAccessedLabel.text = @"";
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor whiteColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.textColor = [UIColor blackColor];
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
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSArray *history;
	NSString *ref;
	//NSString *scroll;
	NSString *verse;
	NSString *mod;
	
	BOOL moduleIsCommentary = NO;
	history = [[NSUserDefaults standardUserDefaults] arrayForKey: PSHistoryName];
	ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
	verse = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 1];
	if([[history objectAtIndex: indexPath.row] count] > 2) {
		mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
		SwordModule *swordModule = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:mod];
		if(!swordModule) {
			mod = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastBible];
			//swordModule = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:mod];
		} else if(swordModule && (swordModule.type == commentary)) {
			moduleIsCommentary = YES;
		}
		if(moduleIsCommentary) {
			[[PSModuleController defaultModuleController] loadPrimaryCommentary: mod];
		} else {
			[[PSModuleController defaultModuleController] loadPrimaryBible: mod];
		}
	}
	[[NSUserDefaults standardUserDefaults] setObject: [PSModuleController createRefString:ref] forKey: DefaultsLastRef];
	if(moduleIsCommentary) {
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowCommentaryTab object:nil];
		[PSHistoryController addHistoryItem:CommentaryTab];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowBibleTab object:nil];
		[PSHistoryController addHistoryItem:BibleTab];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];

	
//	switch (listType) {
//		case BibleTab:
//			history = [[NSUserDefaults standardUserDefaults] arrayForKey: PS_HISTORY_NAME];
//			ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
//			verse = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 1];
//			//scroll = [[history objectAtIndex: indexPath.row] objectAtIndex: 1];
//			if([[history objectAtIndex: indexPath.row] count] > 2) {
//				mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
//				[[PSModuleController defaultModuleController] loadPrimaryBible: mod];
//			} else {
//				mod = nil;
//			}
//			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
//			[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
//			[[NSUserDefaults standardUserDefaults] synchronize];
//			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
//			[PSHistoryController addHistoryItem:BibleTab];
//			break;
//		case CommentaryTab:
//			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
//			ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
//			verse = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 1];
//			//scroll = [[history objectAtIndex: indexPath.row] objectAtIndex: 1];
//			if([[history objectAtIndex: indexPath.row] count] > 2) {
//				mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
//				[[PSModuleController defaultModuleController] loadPrimaryCommentary: mod];
//			} else {
//				mod = nil;
//			}
//			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
//			[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
//			[[NSUserDefaults standardUserDefaults] synchronize];
//			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
//			[PSHistoryController addHistoryItem:CommentaryTab];
//			break;
//		default:
//			break;
//	}
//	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];

	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[self removeHistoryItem:indexPath.row forTab:listType];
	}
	
}

+ (void)initialSynchronizeWithCloud:(NSArray*)cloudHistory withLocalHistory:(NSArray*)localHistory {
	
	NSMutableArray *history = [NSMutableArray arrayWithArray:localHistory];
	[history addObjectsFromArray:cloudHistory];
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dateAdded" ascending:NO];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[history sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];
	
	//check for duplicates:
	for (int ii = 0; ii < [history count]; ++ii) {
		
		PSHistoryItem *newItem = [history objectAtIndex:ii];
		NSString *ref = newItem.bibleReference;
		NSString *mod = newItem.moduleName;
		
		for (int jj = (ii+1); jj < [history count]; ++jj) {
			
			PSHistoryItem *existingItem = [history objectAtIndex:jj];
			NSString *existingRef = existingItem.bibleReference;
			if([ref isEqualToString:existingRef]) {
				//if the references are the same,
				NSString *existingMod = existingItem.moduleName;
				if([mod isEqualToString:existingMod]) {
					//if the mods are the same, or it's an OLD history item without a mod, delete it
					[history removeObjectAtIndex:jj];
					--jj;
				}
			}
		}
	}
	
	
	while([history count] >= PSHistoryMaxEntries) {
		[history removeLastObject];
	}
	
	NSArray *combinedHistory = [PSHistoryItem arrayArrayFromHistoryItems:history];
	
	[[NSUserDefaults standardUserDefaults] setObject: combinedHistory forKey: PSHistoryName];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHistoryChanged object:nil];
	
	if([PSHistoryItem arraysAreEqual:cloudHistory secondArray:history]) {
		// if our resulting history is the same as what's in the cloud, don't update the cloud version!
		return;
	}
	
	// synchronize with iCloud as well, if available:
	Class cls = NSClassFromString(@"NSUbiquitousKeyValueStore");
	if(cls) {
		id kvStore = [cls defaultStore];
		[kvStore setArray:combinedHistory forKey:PSHistoryName];
	}
}

+ (NSMutableArray*)synchronizeHistoryArray:(NSMutableArray*)firstArray withArray:(NSMutableArray*)secondArray {
	
	if(!firstArray || !secondArray || [firstArray count] == 0 || [secondArray count] == 0) {
		return nil;
	}
	NSUInteger capacity = ([firstArray count] > [secondArray count]) ? [secondArray count] : [firstArray count];
	NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:capacity];
	
	PSHistoryItem *firstArrayNewest = [firstArray objectAtIndex:0];
	PSHistoryItem *secondArrayNewest = [secondArray objectAtIndex:0];
	
	if([firstArrayNewest isEqualToHistoryItem:secondArrayNewest]) {
		DLog(@"\nhistoryArrays are now (?) equal");
		return ([firstArray count] > [secondArray count]) ? secondArray : firstArray;
	}
	
	switch([firstArrayNewest ageComparisonToHistoryItem:secondArrayNewest]) {
		case PSHistoryItemOlder:
			//firstArrayNewist is OLDER than secondArrayNewest
			[returnArray addObject:secondArrayNewest];
			[secondArray removeObjectAtIndex:0];
			[returnArray addObjectsFromArray:[PSHistoryController synchronizeHistoryArray:firstArray withArray:secondArray]];
			break;
		case PSHistoryItemNewer:
			[returnArray addObject:firstArrayNewest];
			[firstArray removeObjectAtIndex:0];
			[returnArray addObjectsFromArray:[PSHistoryController synchronizeHistoryArray:firstArray withArray:secondArray]];
			break;
		default:
			//items aren't equal but equal age! so add them both as a tie-breaker...
			DLog(@"tie-breaker!");
			[returnArray addObject:firstArrayNewest];
			[returnArray addObject:secondArrayNewest];
			[firstArray removeObjectAtIndex:0];
			[secondArray removeObjectAtIndex:0];
			[returnArray addObjectsFromArray:[PSHistoryController synchronizeHistoryArray:firstArray withArray:secondArray]];
			break;
	}
	
	return returnArray;

}

+ (void)synchronizeHistoryItemsFromCloud:(BOOL)initialSync {
	
	NSArray *cloudHistory = [PSHistoryItem parseHistoryArrayArray:[[NSUbiquitousKeyValueStore defaultStore] arrayForKey:PSHistoryName]];
	NSMutableArray *localHistory = [[[PSHistoryItem parseHistoryArrayArray:[[NSUserDefaults standardUserDefaults] arrayForKey: PSHistoryName]] mutableCopy] autorelease];
	NSMutableArray *cloudHistoryCopy = [[cloudHistory mutableCopy] autorelease];
	
	if([PSHistoryItem arraysAreEqual:cloudHistory secondArray:localHistory]) {
		DLog(@"\ninitial arrays are equal, don't need to do anything! :)");
		return;
	}
	
	NSMutableArray *history;
	
	if(initialSync) {
		[PSHistoryController initialSynchronizeWithCloud:cloudHistoryCopy withLocalHistory:localHistory];
		return;
	} else if(!cloudHistory || [cloudHistory count] == 0) {
		// we have deleted the history in the cloud & so locally delete it as well
		DLog(@"\ndeleting local history due to iCloud deletion");
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: PSHistoryName];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHistoryChanged object:nil];
		return;
	} else if(!localHistory || [localHistory count] == 0) {
		DLog(@"\nlocal history was blank, but we now need to update it from the changed iCloud version.");
		history = cloudHistoryCopy;
	} else {
		history = [PSHistoryController synchronizeHistoryArray:cloudHistoryCopy withArray:localHistory];
	}
	
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dateAdded" ascending:NO];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[history sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];
	
	//check for duplicates:
	for (int ii = 0; ii < [history count]; ++ii) {
		
		PSHistoryItem *newItem = [history objectAtIndex:ii];
		NSString *ref = newItem.bibleReference;
		NSString *mod = newItem.moduleName;
		
		for (int jj = (ii+1); jj < [history count]; ++jj) {
			
			PSHistoryItem *existingItem = [history objectAtIndex:jj];
			NSString *existingRef = existingItem.bibleReference;
			if([ref isEqualToString:existingRef]) {
				//if the references are the same,
				NSString *existingMod = existingItem.moduleName;
				if([mod isEqualToString:existingMod]) {
					//if the mods are the same, or it's an OLD history item without a mod, delete it
					[history removeObjectAtIndex:jj];
					--jj;
				}
			}
		}
	}


	while([history count] >= PSHistoryMaxEntries) {
		[history removeLastObject];
	}
		
	NSArray *combinedHistory = [PSHistoryItem arrayArrayFromHistoryItems:history];

	[[NSUserDefaults standardUserDefaults] setObject: combinedHistory forKey: PSHistoryName];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHistoryChanged object:nil];
	
	if([PSHistoryItem arraysAreEqual:cloudHistory secondArray:history]) {
		// if our resulting history is the same as what's in the cloud, don't update the cloud version!
		DLog(@"\nOur new local history now equals the iCloud version, so don't re-update the cloud copy :P");
		return;
	}

	// synchronize with iCloud as well, if available:
	Class cls = NSClassFromString(@"NSUbiquitousKeyValueStore");
	if(cls) {
		DLog(@"\nAfter our sync, we have a new history item & so we need to update the iCloud version as well...");
		id kvStore = [cls defaultStore];
		[kvStore setArray:combinedHistory forKey:PSHistoryName];
	}

}


@end
