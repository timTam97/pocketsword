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

	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *ref = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[[moduleManager viewController] removeHistoryItem:ref forTab:listType];
		[tableView reloadData];
	}
	
}



@end
