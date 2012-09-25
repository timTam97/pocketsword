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

#import "HistoryController.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import "PSBookmarkTableViewCell.h"

@implementation HistoryController

- (id)init {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		UITabBarItem *tBI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory tag:0];
		self.tabBarItem = tBI;
		[tBI release];
	}
	return self;
}

- (IBAction)closeButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
}

- (void)setListType:(ShownTab)listT {
	listType = listT;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"CloseButtonTitle", @"Close") style: UIBarButtonItemStyleBordered target: self action: @selector(closeButtonPressed)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"HistoryClearButtonTitle", @"Clear") style: UIBarButtonItemStyleBordered target: self action: @selector(trashButtonPressed)] autorelease];
}

- (void)viewDidUnload {
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		historyListTable.backgroundColor = [UIColor blackColor];
	} else {
		historyListTable.backgroundColor = [UIColor whiteColor];
	}
	//[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:historyNavigationBar mainView:historyListTable useStatusBar:YES];
	if(listType == BibleTab) {
		self.navigationItem.title = NSLocalizedString(@"BibleHistoryTitle", @"Bible History");
	} else {
		self.navigationItem.title = NSLocalizedString(@"CommentaryHistoryTitle", @"Commentary History");
	}
	[historyListTable reloadData];
	if(([historyListTable numberOfSections] > 0) && [historyListTable numberOfRowsInSection: 0] > 0) {
		NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: 0];
		if(ip)
			[historyListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionTop animated:NO];
	}
}

//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:historyNavigationBar mainView:historyListTable fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
//}


- (void)addBibleHistoryItem {
	[HistoryController addHistoryItem: BibleTab];
}

- (void)addCommentaryHistoryItem {
	[HistoryController addHistoryItem: CommentaryTab];
}

// This should be called just AFTER:
//    "nextChapter".
//    or "prevChapter".
//    or navigation to a new ref from the refPicker.
//    or when the user selects a new module to view.
//    or when the user selects a bookmark.
//    or when the user selects a search result.
+ (void)addHistoryItem:(ShownTab)tabForHistory
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *verse;
	NSString *scroll;
	NSString *mod;
	NSMutableArray *history = nil;
	NSString *historyName;
	BOOL valid = NO;
	
	if(tabForHistory == BibleTab) {
		verse = [defaults stringForKey: DefaultsBibleVersePosition];
		scroll = [defaults stringForKey: @"bibleScrollPosition"];
		if([[PSModuleController defaultModuleController] primaryBible]) {
			valid = YES;
			mod = [[[PSModuleController defaultModuleController] primaryBible] name];
		}
		historyName = @"bibleHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else if(tabForHistory == CommentaryTab) {
		verse = [defaults stringForKey: DefaultsCommentaryVersePosition];
		scroll = [defaults stringForKey: @"commentaryScrollPosition"];
		if([[PSModuleController defaultModuleController] primaryCommentary]) {
			valid = YES;
			mod = [[[PSModuleController defaultModuleController] primaryCommentary] name];
		}
		historyName = @"commentaryHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else {
		ALog(@"\nWe don't know which tab we're on!  :(");
	}
	
	if(valid) {
		NSString *ref = [NSString stringWithFormat:@"%@:%@", [PSModuleController createRefString:[PSModuleController getCurrentBibleRef]], verse];
		
		NSArray *historyItem = [NSArray arrayWithObjects: ref, scroll, mod, [NSDate date], nil];
		
		if (!history) {
			history = [[NSMutableArray alloc] initWithObjects: nil];
			
			NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
			[prefs setObject: history forKey: historyName];
			
			[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
			[prefs release];
		}
		
		[history insertObject: historyItem atIndex: 0];
		//[historyItem release];
		if([history count] >= 50) {
			[history removeLastObject];
		}
		
		[defaults setObject: history forKey: historyName];
		[defaults synchronize];
	}
	if(history)
		[history release];
	
	[pool release];
	
}

- (IBAction)trashButtonPressed:(id)sender {
	switch (listType) {
		case BibleTab:
			[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"bibleHistory"];
			break;
		case CommentaryTab:
			[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"commentaryHistory"];
			break;
		default:
			break;
	}
	[historyListTable reloadData];
}

- (void)removeHistoryItem:(NSInteger)historyIndex forTab:(ShownTab)tabForHistory {
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *history;
	NSString *historyName;
	if(tabForHistory == BibleTab) {
		historyName = @"bibleHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else if(tabForHistory == CommentaryTab) {
		historyName = @"commentaryHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else {
		return;
	}
	[history removeObjectAtIndex:historyIndex];
	
//	NSInteger i = 0;
//	for(NSArray *historyItem in history) {
//		if([ref isEqualToString:[historyItem objectAtIndex:0]]) {
//			[history removeObjectAtIndex:i];
//			break;
//		}
//		i++;
//	}
	[defaults setObject: history forKey: historyName];
	[defaults synchronize];
	[history release];
	
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:historyIndex inSection:0];
	[historyListTable deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationMiddle];//UITableViewRowAnimationTop];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//	return @"";
//}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSArray *history;
	switch (listType) {
		case BibleTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bibleHistory"];
			if(history) {
				return [history count];
			} else {
				return 0;
			}
			break;
		case CommentaryTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
			if(history) {
				return [history count];
			} else {
				return 0;
			}
			break;
		default:
			break;
	}
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
	
	NSArray *history = nil;
	switch (listType) {
		case BibleTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bibleHistory"];
			break;
		case CommentaryTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
			break;
		default:
			break;
	}
	
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
	switch (listType) {
		case BibleTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bibleHistory"];
			ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
			verse = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 1];
			//scroll = [[history objectAtIndex: indexPath.row] objectAtIndex: 1];
			if([[history objectAtIndex: indexPath.row] count] > 2) {
				mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
				[[PSModuleController defaultModuleController] loadPrimaryBible: mod];
			} else {
				mod = nil;
			}
			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
			[[NSUserDefaults standardUserDefaults] synchronize];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: BibleTab];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
			[HistoryController addHistoryItem:BibleTab];
			break;
		case CommentaryTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
			ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
			verse = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 1];
			//scroll = [[history objectAtIndex: indexPath.row] objectAtIndex: 1];
			if([[history objectAtIndex: indexPath.row] count] > 2) {
				mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
				[[PSModuleController defaultModuleController] loadPrimaryCommentary: mod];
			} else {
				mod = nil;
			}
			//[[NSUserDefaults standardUserDefaults] setObject: scroll forKey: @"commentaryScrollPosition"];
			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
			[[NSUserDefaults standardUserDefaults] synchronize];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreScrollPosition];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
			[HistoryController addHistoryItem:CommentaryTab];
			//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: CommentaryTab];
			break;
		default:
			break;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
	//[[[PSModuleController defaultModuleController] viewController] toggleMultiList];

	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		//NSString *ref = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[self removeHistoryItem:indexPath.row forTab:listType];
		//[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationMiddle];//UITableViewRowAnimationTop];
	}
	
}



@end
