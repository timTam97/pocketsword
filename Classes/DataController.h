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
#import "PSModuleController.h"
#import "ViewController.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"
#import "globals.h"



#define MODULE_TABLE			1
#define SEARCH_TABLE			2
//#define DOWNLOAD_TABLE		3
#define BOOKMARK_TABLE			4

#define MODULES_LIST_TABLE		7
#define HISTORY_LIST_TABLE		8



@interface DataController : NSObject {
	IBOutlet id moduleTable;
	IBOutlet id resultsTable;
	IBOutlet id bookmarksTable;
	IBOutlet UITabBarController *tabController;
	//IBOutlet id bibleNavBtn;
	IBOutlet PSBibleViewController *bibleTabController;
	IBOutlet PSCommentaryViewController *commentaryTabController;
	
	NSArray *refSelectorBooks;
	//NSInteger numChapters;
	NSInteger refSelectorBook;
	NSInteger refSelectorChapter;
	ShownTab listType;

	//NSInteger sourceInstallSourceView;
	//NSMutableArray *installedModuleGroups;
	
	IBOutlet id moduleManager;
	IBOutlet id viewController;
}

@property (assign) NSInteger refSelectorBook;
@property (assign) NSInteger refSelectorChapter;
@property (retain, readwrite) NSArray *refSelectorBooks;
@property (assign) ShownTab listType;
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
- (NSString*)bookOSISName:(NSInteger)bookIndex;
- (NSInteger)bookIndex:(NSString*)bookName;
//- (IBAction)updateDownloadManagerTableView;

@end
