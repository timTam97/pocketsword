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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger tag = [tableView tag];
	if (tag == HISTORY_LIST_TABLE) {
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
//	else if (tag == BOOKMARK_TABLE) {
//		NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
//		return [bookmarks count];
//	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger tag = [tableView tag];
	
	NSString *theIdentifier;
	
	if (tag == HISTORY_LIST_TABLE)
		theIdentifier = @"id-mod";
	else 
		theIdentifier = @"id-book";
	
	// Try to recover a cell from the table view with the given identifier, this is for performance
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: theIdentifier];
	
	// If no cell is available, create a new one using the given identifier - 
	if (cell == nil) {
		if (tag == HISTORY_LIST_TABLE)
			cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: theIdentifier] autorelease];
		else 
			cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: theIdentifier] autorelease];
	}
	
	if (tag == HISTORY_LIST_TABLE) {
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
//	else if (tag == BOOKMARK_TABLE) {
//		NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
//		cell.textLabel.text = [bookmarks objectAtIndex: indexPath.row];
//		// TODO:  add the first bit of the chapter to the detailLabel:
//		cell.detailTextLabel.text = @"";
//		return cell;
//	}
	
	
	cell.textLabel.text = @"";
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSInteger tag = [tableView tag];
	if (tag == HISTORY_LIST_TABLE) {
		NSArray *history;
		NSString *ref;
		NSString *scroll;
		NSString *mod;
		switch (listType) {
			case BibleTab:
				history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bibleHistory"];
				ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
				scroll = [[history objectAtIndex: indexPath.row] objectAtIndex: 1];
				if([[history objectAtIndex: indexPath.row] count] > 2) {
					mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
					[moduleManager loadPrimaryBible: mod];
				} else {
					mod = nil;
				}
				[[NSUserDefaults standardUserDefaults] setObject: scroll forKey: @"bibleScrollPosition"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				[[moduleManager viewController] displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreScrollPosition];
				[[moduleManager viewController] addHistoryItem: BibleTab];
				break;
			case CommentaryTab:
				history = [[NSUserDefaults standardUserDefaults] arrayForKey: @"commentaryHistory"];
				ref = [[[[history objectAtIndex: indexPath.row] objectAtIndex: 0] componentsSeparatedByString: @":"] objectAtIndex: 0];
				scroll = [[history objectAtIndex: indexPath.row] objectAtIndex: 1];
				if([[history objectAtIndex: indexPath.row] count] > 2) {
					mod = [[history objectAtIndex: indexPath.row] objectAtIndex: 2];
					[moduleManager loadPrimaryCommentary: mod];
				} else {
					mod = nil;
				}
				[[NSUserDefaults standardUserDefaults] setObject: scroll forKey: @"commentaryScrollPosition"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				[[moduleManager viewController] displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreScrollPosition];
				[[moduleManager viewController] addHistoryItem: CommentaryTab];
				break;
		}
		[[moduleManager viewController] toggleMultiList: nil];
	}
//	else if (tag == BOOKMARK_TABLE) {
//		[[moduleManager viewController] setShownTabTo:BibleTab];
//		if (![[[moduleManager swordManager] moduleNames] count] == 0) {
//			NSArray *fullRef = [[tableView cellForRowAtIndexPath: indexPath].textLabel.text componentsSeparatedByString: @":"];
//			NSString *ref = [fullRef objectAtIndex: 0];
//			NSString *verse = [fullRef objectAtIndex: 1];
//			if(verse) {
//				[[NSUserDefaults standardUserDefaults] setObject: verse forKey: @"bibleVersePosition"];
//				[[NSUserDefaults standardUserDefaults] synchronize];
//				[[moduleManager viewController] displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreVersePosition];
//			} else {
//				[[moduleManager viewController] displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreNoPosition];
//			}
//			[[moduleManager viewController] addHistoryItem: BibleTab];
//		}
//		
//		[tableView deselectRowAtIndexPath:indexPath animated:NO];
//		//[tabController setSelectedIndex: BIBLE_TAB];
//	}

	[pool release];
}

@end
