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

#import <UIKit/UIKit.h>
#import "ModuleManager.h"
#import "ViewController.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"

/*#define BOOKS [NSArray arrayWithObjects: @"Genesis", @"Exodus", @"Leviticus", @"Numbers", @"Deuteronomy", \
			@"Joshua", @"Judges", @"Ruth", @"1 Samuel", @"2 Samuel", @"1 Kings", @"2 Kings", @"1 Chronicles", \
			@"2 Chronicles", @"Ezra", @"Nehemiah", @"Esther", @"Job", @"Psalms", @"Proverbs", @"Ecclesiastes", \
			@"Song of Solomon", @"Isaiah", @"Jeremiah", @"Lamentations", @"Ezekiel", @"Daniel", @"Hosea", \
			@"Joel", @"Amos", @"Obadiah", @"Jonah", @"Micah", @"Nahum", @"Habakkuk", @"Zephaniah", @"Haggai", \
			@"Zechariah", @"Malachi", @"Matthew", @"Mark", @"Luke", @"John", @"Acts", @"Romans", @"1 Corinthians", \
			@"2 Corinthians", @"Galatians", @"Ephesians", @"Philippians", @"Colossians", @"1 Thessalonians", \
			@"2 Thessalonians", @"1 Timothy", @"2 Timothy", @"Titus", @"Philemon", @"Hebrews", @"James", @"1 Peter", \
			@"2 Peter", @"1 John", @"2 John", @"3 John", @"Jude", @"Revelation", nil]

#define CHAPTERS [NSArray arrayWithObjects: [NSNumber numberWithInteger: 50], [NSNumber numberWithInteger: 40], \
			[NSNumber numberWithInteger: 27], [NSNumber numberWithInteger: 36], [NSNumber numberWithInteger: 34], \
			[NSNumber numberWithInteger: 24], [NSNumber numberWithInteger: 21], [NSNumber numberWithInteger: 4], \
			[NSNumber numberWithInteger: 31], [NSNumber numberWithInteger: 24], [NSNumber numberWithInteger: 22], \
			[NSNumber numberWithInteger: 25], [NSNumber numberWithInteger: 29], [NSNumber numberWithInteger: 36], \
			[NSNumber numberWithInteger: 10], [NSNumber numberWithInteger: 13], [NSNumber numberWithInteger: 10], \
			[NSNumber numberWithInteger: 42], [NSNumber numberWithInteger: 150], [NSNumber numberWithInteger: 31], \
			[NSNumber numberWithInteger: 12], [NSNumber numberWithInteger: 8], [NSNumber numberWithInteger: 66], \
			[NSNumber numberWithInteger: 52], [NSNumber numberWithInteger: 5], [NSNumber numberWithInteger: 48], \
			[NSNumber numberWithInteger: 12], [NSNumber numberWithInteger: 14], [NSNumber numberWithInteger: 3], \
			[NSNumber numberWithInteger: 9], [NSNumber numberWithInteger: 1], [NSNumber numberWithInteger: 4], \
			[NSNumber numberWithInteger: 7], [NSNumber numberWithInteger: 3], [NSNumber numberWithInteger: 3], \
			[NSNumber numberWithInteger: 3], [NSNumber numberWithInteger: 2], [NSNumber numberWithInteger: 14], \
			[NSNumber numberWithInteger: 4], [NSNumber numberWithInteger: 28], [NSNumber numberWithInteger: 16], \
			[NSNumber numberWithInteger: 24], [NSNumber numberWithInteger: 21], [NSNumber numberWithInteger: 28], \
			[NSNumber numberWithInteger: 16], [NSNumber numberWithInteger: 16], [NSNumber numberWithInteger: 13], \
			[NSNumber numberWithInteger: 6], [NSNumber numberWithInteger: 6], [NSNumber numberWithInteger: 4], \
			[NSNumber numberWithInteger: 4], [NSNumber numberWithInteger: 5], [NSNumber numberWithInteger: 3], \
			[NSNumber numberWithInteger: 6], [NSNumber numberWithInteger: 4], [NSNumber numberWithInteger: 3], \
			[NSNumber numberWithInteger: 1], [NSNumber numberWithInteger: 13], [NSNumber numberWithInteger: 5], \
			[NSNumber numberWithInteger: 5], [NSNumber numberWithInteger: 3], [NSNumber numberWithInteger: 5], \
			[NSNumber numberWithInteger: 1], [NSNumber numberWithInteger: 1], [NSNumber numberWithInteger: 1], \
			[NSNumber numberWithInteger: 22], nil]*/

// we can add more to this enum as we're required to dynamically show those tabs
typedef enum {
    BibleTab = 1,
    CommentaryTab,
	ModuleTab
}ShownTab;


#define MODULE_TABLE		1
#define SEARCH_TABLE		2
//#define DOWNLOAD_TABLE	3
#define BOOKMARK_TABLE		4



@interface DataController : NSObject {
	IBOutlet id moduleTable;
	IBOutlet id resultsTable;
	IBOutlet id bookmarksTable;
	IBOutlet UITabBarController *tabController;
	IBOutlet id bibleNavBtn;
	IBOutlet PSBibleViewController *bibleTabController;
	IBOutlet PSCommentaryViewController *commentaryTabController;
	
	NSArray *refSelectorBooks;
	//NSInteger numChapters;
	NSInteger refSelectorBook;
	NSInteger refSelectorChapter;

	//NSInteger sourceInstallSourceView;
	//NSMutableArray *installedModuleGroups;
	
	IBOutlet id moduleManager;
	IBOutlet id viewController;
}

@property (assign) NSInteger refSelectorBook;
@property (assign) NSInteger refSelectorChapter;
@property (retain, readwrite) NSArray *refSelectorBooks;
//@property (assign) NSMutableArray *installedModuleGroups;
//@property (assign) NSInteger sourceInstallSourceView;

- (DataController *)init;
//- (void)performSearch:(NSString *)key;
- (void)addBookmark:(NSString *)ref;
- (void)removeBookmark:(NSString *)ref;
- (void)reloadModuleList;
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component;
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component;
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)dealloc;
- (void)setShownTabTo:(ShownTab)tab;
- (void)updateRefSelectorBooks;
- (NSString*)bookName:(NSInteger)bookIndex;
- (NSInteger)bookIndex:(NSString*)bookName;
//- (IBAction)updateDownloadManagerTableView;

@end
