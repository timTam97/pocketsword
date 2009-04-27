/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2009 Ian Wagner

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

#import "DataController.h"


@implementation DataController
@synthesize installedModuleGroups;
@synthesize numChapters;

ListKey results;

- (DataController *)init {
	self = [super init];
	
	numChapters = [[CHAPTERS objectAtIndex: 0] intValue];
	
	return self;
}

// Search
- (void)performSearch:(NSString *)key {
	SWModule *primaryText = [moduleManager getPrimaryText];
	results = primaryText->Search([key UTF8String], -4);
	NSLog(@"Found %d results", results.Count());
	results.sort();
}

// Bookmark functions
- (void)addBookmark:(NSString *)ref {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks"] mutableCopy];
	
	if (bookmarks == nil) {
		bookmarks = [[NSMutableArray alloc] initWithObjects: nil];
		
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: bookmarks forKey: @"bookmarks"];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
	}
	
	// TODO: Check for duplicates?
	[bookmarks addObject: ref];
	
	[defaults setObject: bookmarks forKey: @"bookmarks"];
	[defaults synchronize];
	
	[bookmarksTable reloadData];
	[pool release];
}

- (void)removeBookmark:(NSString *)ref {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks"] mutableCopy];
	
	if (bookmarks == nil) { return; }
	
	for (NSUInteger i = 0; i < [bookmarks count]; ++i) {
		if ([[bookmarks objectAtIndex: i] isEqualToString: ref]) {
			[bookmarks removeObjectAtIndex: i];
		}
	}
	
	[defaults setObject: bookmarks forKey: @"bookmarks"];
	[defaults synchronize];
	
	[bookmarksTable reloadData];
	[pool release];
}

// Reloads the module list into the appropriate class-level arrays
- (void)reloadModuleList {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[moduleManager reload];
	
	[pool release];
}

//
// UIPickerView delegate and data source methods
//
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
	// One for chapter, one for verse. This may change in the future
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
	// We have 66 books and numChapters chapters. numChapters is updated when the book
	// changes to reflect the number of chapters in the book
	if (component == 0) {
		return 66;
	}
	else {
		return numChapters;
	}
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	if (component == 0) {
		return [BOOKS objectAtIndex: row];
	} else {
		return [NSString stringWithFormat: @"%d", row + 1];
	}
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
	if (component == 0) {
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
		// Update the picker to contain the appropriate number of chapters
		numChapters = [[CHAPTERS objectAtIndex: row] intValue];
		[pickerView reloadComponent: 1];
		
		[pool release];
	}
}

//
// UITableView delegate and data source methods
//
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	// Setup our module table data source
	// TODO: Make it work for other module types
	NSInteger tag = [tableView tag];
	if (tag == 1) {
		[self reloadModuleList];
		return [[moduleManager installedModules] count];
	}
	else if (tag == 3) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
			return 4;
		}
		else {
			return 2;
		}
	}
	else {
		return 1;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	// TODO: Add other section headers for other module types
	NSInteger tag = [tableView tag];
	if (tag == 1) {
		return [[[moduleManager installedModules] allKeys] objectAtIndex: section];
	}
	else if (tag == 2) {
		return [NSString stringWithFormat: @"Search Results (%d)", results.Count()];
	}
	else if (tag == 3) {
		if (section == 0) {
			return [NSString stringWithFormat: @"Bibles (%d)", [[moduleManager downloadableBibles] count]];
		}
		else if (section == 1) {
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
				return [NSString stringWithFormat: @"Beta Bibles (%d)", [[moduleManager betaBibles] count]];
			}
			return [NSString stringWithFormat: @"Commentaries (%d)", [[moduleManager downloadableZCommentaries] count]
				+ [[moduleManager downloadableRawCommentaries] count]];
		}
		else if (section == 2) {
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
				return [NSString stringWithFormat: @"Commentaries (%d)", [[moduleManager downloadableZCommentaries] count]
						+ [[moduleManager downloadableRawCommentaries] count]];;
			}
			return @"";
		}
		else if (section == 3) {
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
				return @"Beta Commentaries";
			}
			return @"";
		}
		else {
			return @"";
		}
	}
	else {
		return @"";
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	// TODO: Add mechanism for counting other module types
	NSInteger tag = [tableView tag];
	if (tag == 1) {
		NSString *sectionHeading = [[[moduleManager installedModules] allKeys] objectAtIndex: section];
		return [[[moduleManager installedModules] objectForKey: sectionHeading] count];
	}
	else if (tag == 2) {
		return results.Count();
	}
	else if (tag == 3) {
		if (section == 0) {
			return [[moduleManager downloadableBibles] count];
		}
		else if (section == 1) {
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"])  {
				return [[moduleManager betaBibles] count];
			}
			return [[moduleManager downloadableZCommentaries] count] + [[moduleManager downloadableRawCommentaries] count];
		}
		else if (section == 2) {
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"])  {
				return [[moduleManager downloadableZCommentaries] count] + [[moduleManager downloadableRawCommentaries] count];
			}
			return 0;
		}
	}
	else if (tag == 4) {
		NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks"];
		return [bookmarks count];
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger tag = [tableView tag];
	
	NSString *theIdentifier = [NSString stringWithFormat: @"id%d", [indexPath indexAtPosition: 1]];
	
	// Try to recover a cell from the table view with the given identifier, this is for performance
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: theIdentifier];
	
	// If no cell is available, create a new one using the given identifier
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame: CGRectZero reuseIdentifier: theIdentifier] autorelease];
	}
	
	if (tag == 1) {
		// Fill the cell
		// TODO: Break up the array of modules into subarrays for each module type
		//   whoose indices line up with the indexPath
		[self reloadModuleList];
		NSString *sectionHeading = [[[moduleManager installedModules] allKeys] objectAtIndex: [indexPath indexAtPosition: 0]];
		cell.text = [[[moduleManager installedModules] objectForKey: sectionHeading] objectAtIndex: [indexPath indexAtPosition: 1]];
		
		SWModule *primaryText = [moduleManager getPrimaryText];
		
		if (primaryText && [cell.text isEqualToString: [NSString stringWithUTF8String: primaryText->Name()]] ) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		return cell;
	}
	else if (tag == 2) {
		cell.text = [NSString stringWithUTF8String: results.getElement([indexPath indexAtPosition: 1])->getText()];
		return cell;
	}
	else if (tag == 3) {
		if ([indexPath indexAtPosition: 0] == 0) {
			cell.text = [[moduleManager downloadableBibles] objectAtIndex: [indexPath indexAtPosition: 1]];
		}
		else if ([indexPath indexAtPosition: 0] == 1 && [[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
			cell.text = [[moduleManager betaBibles] objectAtIndex: [indexPath indexAtPosition: 1]];
		}
		else if ([indexPath indexAtPosition: 0] == 1 && ![[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
			NSUInteger zCount = [[moduleManager downloadableZCommentaries] count];
			NSUInteger index = [indexPath indexAtPosition: 1];
			if (index >= zCount) {
				cell.text = [[moduleManager downloadableRawCommentaries] objectAtIndex: index - zCount];
			}
			else {
				cell.text = [[moduleManager downloadableZCommentaries] objectAtIndex: index];
			}
		}
		else if ([indexPath indexAtPosition: 0] == 2 && [[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
			NSUInteger zCount = [[moduleManager downloadableZCommentaries] count];
			NSUInteger index = [indexPath indexAtPosition: 1];
			if (index >= zCount) {
				cell.text = [[moduleManager downloadableRawCommentaries] objectAtIndex: index - zCount];
			}
			else {
				cell.text = [[moduleManager downloadableZCommentaries] objectAtIndex: index];
			}
		}
		return cell;
	}
	else if (tag == 4) {
		NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks"];
		cell.text = [bookmarks objectAtIndex: [indexPath indexAtPosition: 1]];
		return cell;
	}
	
	
	cell.text = @"";
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSInteger tag = [tableView tag];
	if (tag == 1) {
		// TODO: Make this whole function work with multiple module types
		NSString *ref;
		SWModule *primaryText = [moduleManager getPrimaryText];
		
		if (primaryText) {
			ref = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
		}
		else {
			ref = @"Genesis 1";
			[refPicker setTitle: @"Genesis 1"];
		}
		
		// Reload the list
		installedModuleGroups = [NSMutableArray arrayWithObjects: @"Bibles", nil];
		
		NSString *newModule = [[self tableView: tableView cellForRowAtIndexPath: indexPath] text];
		[moduleManager loadPrimaryText: newModule];
		[[NSUserDefaults standardUserDefaults] setObject: newModule forKey: @"lastModule"];
		
		NSString *text = [moduleManager getChapter: ref];
		[[viewController getTextView] loadHTMLString: text baseURL: nil];	// Get the chapter text
		
		// Update the module list to reflect the current translation
		[tableView reloadData];
		[tabController setSelectedIndex: 0];
	}
	else if (tag == 2 || tag == 4) {
		NSString *ref = [[[[tableView cellForRowAtIndexPath: indexPath] text] componentsSeparatedByString: @":"] objectAtIndex: 0];
		NSString *text = [moduleManager getChapter: ref];
		[[viewController getNavBtn] setTitle: ref];
		[[viewController getTextView] loadHTMLString: text baseURL: nil];	// Get the chapter text
		
		[tabController setSelectedIndex: 0];
	}
	else if (tag == 3) {
		NSString *name = [[tableView cellForRowAtIndexPath: indexPath] text];
		[viewController confirmInstall: name];
	}
	
	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSInteger tag = [tableView tag];
	
	if (tag == 1) {
		if (editingStyle == UITableViewCellEditingStyleDelete) {
			NSString *module = [tableView cellForRowAtIndexPath: indexPath].text;
			[moduleManager removeModule: module];
		}
	} else if (tag == 4) {
		if (editingStyle == UITableViewCellEditingStyleDelete) {
			NSString *ref = [tableView cellForRowAtIndexPath: indexPath].text;
			[self removeBookmark: ref];
		}
	}
	
	[pool release];
}

- (void)dealloc {
	[super dealloc];
}

@end
