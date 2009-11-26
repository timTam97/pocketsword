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
#import <versemgr.h>
#import "SwordBook.h"

@implementation DataController


@synthesize refSelectorChapter;
@synthesize refSelectorBook;
@synthesize refSelectorBooks;
//@synthesize sourceInstallSourceView;
//@synthesize installedModuleGroups;

sword::ListKey results;

- (DataController *)init {
	self = [super init];
	
	refSelectorBook = 0;
	refSelectorChapter = 1;
	//numChapters = [[CHAPTERS objectAtIndex: 0] intValue];
	//sourceInstallSourceView = 0;
	
	// TODO: why are we calling this here?  Are we actually calling this twice at the app-start event?
	//[self reloadModuleList];
	return self;
}

/*
// Search
- (void)performSearch:(NSString *)key {
	sword::SWModule *primaryText = [moduleManager getPrimaryText];
	results = primaryText->Search([key UTF8String], -4);
	DLog(@"Found %d results", results.Count());
	results.sort();
}*/

// Bookmark functions
- (void)addBookmark:(NSString *)ref {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks2"] mutableCopy];
	
	if (bookmarks == nil) {
		bookmarks = [[NSMutableArray alloc] initWithObjects: nil];
		
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: bookmarks forKey: @"bookmarks2"];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
	}
	
	if(![bookmarks containsObject:ref])
		[bookmarks addObject: ref];
	
	[defaults setObject: bookmarks forKey: @"bookmarks2"];
	[defaults synchronize];
	[bookmarks release];
	
	[bookmarksTable reloadData];
	[pool release];
}

- (void)removeBookmark:(NSString *)ref {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks2"] mutableCopy];
	
	if (bookmarks == nil) { return; }
	
	for (NSUInteger i = 0; i < [bookmarks count]; ++i) {
		if ([[bookmarks objectAtIndex: i] isEqualToString: ref]) {
			[bookmarks removeObjectAtIndex: i];
		}
	}
	
	[defaults setObject: bookmarks forKey: @"bookmarks2"];
	[defaults synchronize];
	[bookmarks release];
	
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
	return 3;// One for book, one for chapter, one for verse.
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
	// We have 66 books and numChapters chapters. numChapters is updated when the book
	// changes to reflect the number of chapters in the book
	if (component == 0) {
		//return 66;
		return [refSelectorBooks count];
	}
	else if(component == 1) {
		//return numChapters;
		return [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) chapters];
	} else {
		return [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) verses:refSelectorChapter];
	}
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
	switch (component) {
		case 0 :
			return 180.0;
		case 1 :
			return 60.0;
		case 2 :
			return 60.0;
	}
	return 60.0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	if (component == 0) {
		//return [BOOKS objectAtIndex: row];
		return [((SwordBook*)[refSelectorBooks objectAtIndex:row]) name];
	} else {
		return [NSString stringWithFormat: @"%d", row + 1];
	}
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
	if (component == 0) {
		//DLog(@"picker selected Book row %d = %@", row, [((SwordBook*)[refSelectorBooks objectAtIndex:row]) name]);
		//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
		// Update the picker to contain the appropriate number of chapters
		//numChapters = [[CHAPTERS objectAtIndex: row] intValue];
		
		refSelectorBook = row;
		refSelectorChapter = 1;//reset to the top chapter
		[pickerView reloadComponent: 1];
		[pickerView selectRow: 0 inComponent: 1 animated: YES];
		[pickerView reloadComponent: 2];
		[pickerView selectRow: 0 inComponent: 2 animated: YES];
		
		//[pool release];
	} else if (component == 1) {
		//DLog(@"picker selected Chapter row %d = actual ch%d", row, (row+1));
		refSelectorChapter = row+1;
		[pickerView reloadComponent: 2];
		[pickerView selectRow: 0 inComponent: 2 animated: YES];
	}
}

//
// UITableView delegate and data source methods
//
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	// Setup our module table data source
	// TODO: Make it work for other module types
	NSInteger tag = [tableView tag];
	if (tag == MODULE_TABLE) {
		NSUInteger modCount = [[[moduleManager swordManager] moduleListByType] count];
		return modCount > 0 ? modCount : 1;
	}
	else {
		return 1;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	// TODO: Add other section headers for other module types
	NSInteger tag = [tableView tag];
	if (tag == MODULE_TABLE) {
		@try {
			NSUInteger modCount = [[[moduleManager swordManager] moduleListByType] count];
			if (modCount > 0) {
				return [[[[moduleManager swordManager] moduleListByType] objectAtIndex: section] moduleType];
			} else {
				return NSLocalizedString(@"NoModulesInstalled", @"");
			}
		}
		@catch (id except) {
			return NSLocalizedString(@"NoModulesInstalled", @"");
		}
	}
	else if (tag == SEARCH_TABLE) {
		return [NSString stringWithFormat: @"Search Results (%d)", results.Count()];
	}
	return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	// TODO: Add mechanism for counting other module types
	NSInteger tag = [tableView tag];
	if (tag == MODULE_TABLE) {
		@try {
			NSUInteger modCount = [[[moduleManager swordManager] moduleListByType] count];
			return (modCount > 0) ? [[[[[moduleManager swordManager] moduleListByType] objectAtIndex: section] moduleList] count] : 0;
		}
		@catch (id except) {
			return 0;
		}
	}
	else if (tag == SEARCH_TABLE) {
		return results.Count();
	}
	else if (tag == BOOKMARK_TABLE) {
		NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
		return [bookmarks count];
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger tag = [tableView tag];
	
	NSString *theIdentifier;
	
	if (tag == MODULE_TABLE)
		theIdentifier = @"id-mod";
	else 
		theIdentifier = @"id-book";
	
	// Try to recover a cell from the table view with the given identifier, this is for performance
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: theIdentifier];
	
	// If no cell is available, create a new one using the given identifier - 
	if (cell == nil) {
		if (tag == MODULE_TABLE)
			cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier: theIdentifier] autorelease];
		else 
			cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: theIdentifier] autorelease];
	}
	
	if (tag == MODULE_TABLE) {
		// Fill the cell
		try {
			int section = [indexPath section];
			int row = [indexPath row];
			cell.textLabel.text = [[[[[[moduleManager swordManager] moduleListByType] objectAtIndex: section] moduleList] objectAtIndex:row] name];
			cell.detailTextLabel.text = [[[[[[moduleManager swordManager] moduleListByType] objectAtIndex: section] moduleList] objectAtIndex:row] descr];
		} catch (...) {
			cell.textLabel.text = @"";
		}
		
		if ([moduleManager isLoaded:cell.textLabel.text]) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		return cell;
	}
	else if (tag == SEARCH_TABLE) {
		cell.textLabel.text = [NSString stringWithUTF8String: results.getElement([indexPath indexAtPosition: 1])->getText()];
		return cell;
	}
	else if (tag == BOOKMARK_TABLE) {
		NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
		cell.textLabel.text = [bookmarks objectAtIndex: indexPath.row];
		// TODO:  add the first bit of the chapter to the detailLabel:
		cell.detailTextLabel.text = @"";
		return cell;
	}
	
	
	cell.textLabel.text = @"";
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSInteger tag = [tableView tag];
	if (tag == MODULE_TABLE) {
		// TODO: Make this whole function work with multiple module types
		NSString *ref = [moduleManager getCurrentBibleRef];

		if (!ref) {
			ref = @"Genesis 1";
			[bibleNavBtn setTitle: @"Genesis 1"];
		}
		
		NSString *newModule = [self tableView: tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		if(([moduleManager primaryBible] && [newModule isEqualToString:[[moduleManager primaryBible] name]]) || ([moduleManager primaryCommentary] && [newModule isEqualToString:[[moduleManager primaryCommentary] name]])) {
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
			return;
		}
		SwordModule *mod = [[moduleManager swordManager] moduleWithName:newModule];
		BOOL bibleModule = ([[mod typeString] isEqualToString:SWMOD_CATEGORY_BIBLES]);
		if (bibleModule) {
			[moduleManager loadPrimaryBible: newModule];
			[[NSUserDefaults standardUserDefaults] setObject: newModule forKey: @"lastBible"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		else {
			[moduleManager loadPrimaryCommentary:newModule];
			[[NSUserDefaults standardUserDefaults] setObject: newModule forKey: @"lastCommentary"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		
		
		// Update the module list to reflect the current translation
		[tableView reloadData];
		if (bibleModule) {
			//[tabController setSelectedIndex: BIBLE_TAB];
			[self setShownTabTo:BibleTab];
			[viewController displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
		} else {
			//[tabController setSelectedIndex: COMMENTARY_TAB];
			[self setShownTabTo:CommentaryTab];
			[viewController displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
		}
	}
	else if (tag == SEARCH_TABLE || tag == BOOKMARK_TABLE) {
		[self setShownTabTo:BibleTab];
		if (![[[moduleManager swordManager] moduleNames] count] == 0) {
			NSArray *fullRef = [[tableView cellForRowAtIndexPath: indexPath].textLabel.text componentsSeparatedByString: @":"];
			NSString *ref = [fullRef objectAtIndex: 0];
			NSString *verse = [fullRef objectAtIndex: 1];
			if(verse) {
				[[NSUserDefaults standardUserDefaults] setObject: verse forKey: @"bibleVersePosition"];
				[[NSUserDefaults standardUserDefaults] synchronize];
				[viewController displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreVersePosition];
			} else {
				[viewController displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreNoPosition];
			}
		}
		
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
		//[tabController setSelectedIndex: BIBLE_TAB];
	}

	[pool release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSInteger tag = [tableView tag];
	
	if (tag == MODULE_TABLE) {
		if (editingStyle == UITableViewCellEditingStyleDelete) {
			NSString *module = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
			[moduleManager removeModule: module];
			//[moduleManager reload];
			//[moduleTable reloadData];
			
		}
	} else if (tag == BOOKMARK_TABLE) {
		if (editingStyle == UITableViewCellEditingStyleDelete) {
			NSString *ref = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
			[self removeBookmark: ref];
		}
	}
	
	[pool release];
}

- (void)dealloc {
	[refSelectorBooks release];
	[super dealloc];
}

- (void)setShownTabTo:(ShownTab)tab {
	switch(tab) {
		case BibleTab:
		{
			for(UIViewController* uivc in tabController.viewControllers) {
				if([uivc.view isDescendantOfView:bibleTabController.view]) {
					tabController.selectedViewController = uivc;
				}
			}
		}
			break;
		case CommentaryTab:
		{
			for(UIViewController* uivc in tabController.viewControllers) {
				if([uivc.view isDescendantOfView:commentaryTabController.view]) {
					tabController.selectedViewController = uivc;
				}
			}
		}
			break;
		case ModuleTab:
		{
			for(UIViewController* uivc in tabController.viewControllers) {
				if([moduleTable isDescendantOfView: uivc.view]) {
					tabController.selectedViewController = uivc;
				}
			}
		}
			break;
	}
}

- (void)updateRefSelectorBooks {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *currentRefSystemName = [[moduleManager primaryBible] versification];
	if(!currentRefSystemName) //if there are no Bibles, fall back to the commentary versification
		currentRefSystemName = [[moduleManager primaryCommentary] versification];
	const sword::VerseMgr::System *refSystem = sword::VerseMgr::getSystemVerseMgr()->getVersificationSystem([currentRefSystemName cStringUsingEncoding:NSUTF8StringEncoding]);
	int numberOfBooks = refSystem->getBookCount();
	NSMutableArray *books = [[[NSMutableArray alloc] init] autorelease];
	for(int i = 0; i < numberOfBooks; i++) {
		SwordBook *book = [[SwordBook alloc] initWithBook:refSystem->getBook(i)];
		[books addObject:book];
		//[books insertObject:book atIndex:i];
		[book release];
	}

	[self setRefSelectorBooks:books];
	//refSelectorBooks = books;
	//[refSelectorBooks retain];
	[pool release];
}

- (NSString*)bookName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) name];
}

- (NSInteger)bookIndex:(NSString*)bookName
{
	NSInteger ret = NSNotFound;
	for(int i = 0; i < [refSelectorBooks count]; i++) {
		if([[((SwordBook*)[refSelectorBooks objectAtIndex:i]) name] isEqualToString:bookName]) {
			//DLog(@"\nbookName: %@\nindex: %d", bookName, i);
			ret = i;
			break;
		}
	}
	return ret;
	//return [refSelectorBooks indexOfObject:bookName];
}

@end
