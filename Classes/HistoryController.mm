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

@implementation HistoryController


@synthesize listType;

- (void)viewDidLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addBibleHistoryItem) name:NotificationAddBibleHistoryItem object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addCommentaryHistoryItem) name:NotificationAddCommentaryHistoryItem object:nil];
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationAddBibleHistoryItem object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationAddCommentaryHistoryItem object:nil];
}

- (void)addBibleHistoryItem {
	[self addHistoryItem: BibleTab];
}

- (void)addCommentaryHistoryItem {
	[self addHistoryItem: CommentaryTab];
}

// This should be called just AFTER:
//    "nextChapter".
//    or "prevChapter".
//    or navigation to a new ref from the refPicker.
//    or when the user selects a new module to view.
//    or when the user selects a bookmark.
//    or when the user selects a search result.
- (void)addHistoryItem:(ShownTab)tabForHistory
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *verse;
	NSString *scroll;
	NSString *mod;
	NSMutableArray *history;
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
		NSString *ref = [NSString stringWithFormat:@"%@:%@", [PSModuleController createRefString:[[PSModuleController defaultModuleController] getCurrentBibleRef]], verse];
		
		NSArray *historyItem = [NSArray arrayWithObjects: ref, scroll, mod, nil];
		
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

- (void)removeHistoryItem:(NSString*)ref forTab:(ShownTab)tabForHistory {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
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
	
	for(NSArray *historyItem in history) {
		if([ref isEqualToString:[historyItem objectAtIndex:0]]) {
			[history removeObject:historyItem];
			break;
		}
	}
	[defaults setObject: history forKey: historyName];
	[defaults synchronize];
	[history release];
	
	[pool release];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSArray *history;
	switch (listType) {
		case BibleTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bibleHistory"];
			if(history)
				return [history count];
			else
				return 0;
			break;
		case CommentaryTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
			if(history)
				return [history count];
			else
				return 0;
			break;
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSString *theIdentifier = @"id-mod";
	
	// Try to recover a cell from the table view with the given identifier, this is for performance
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: theIdentifier];
	
	// If no cell is available, create a new one using the given identifier - 
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: theIdentifier] autorelease];
	}
	
	NSArray *history;
	switch (listType) {
		case BibleTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bibleHistory"];
			cell.textLabel.text = [[history objectAtIndex: indexPath.row] objectAtIndex: 0];
			if([[history objectAtIndex: indexPath.row] count] > 2)
				cell.detailTextLabel.text = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
			else
				cell.detailTextLabel.text = @"";
			cell.detailTextLabel.textAlignment = UITextAlignmentRight;
			break;
		case CommentaryTab:
			history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
			cell.textLabel.text = [[history objectAtIndex: indexPath.row] objectAtIndex: 0];
			if([[history objectAtIndex: indexPath.row] count] > 2)
				cell.detailTextLabel.text = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
			else
				cell.detailTextLabel.text = @"";
			cell.detailTextLabel.textAlignment = UITextAlignmentRight;
			break;
	}
	return cell;
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
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
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
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
			//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: CommentaryTab];
			break;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
	//[[[PSModuleController defaultModuleController] viewController] toggleMultiList];

	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *ref = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[self removeHistoryItem:ref forTab:listType];
		[tableView reloadData];
	}
	
}



@end
