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
#import "DataController.h"
#import "NavigatorSources.h"

#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>
#include <filemgr.h>
#include <localemgr.h>

typedef enum {
    RestoreScrollPosition = 1,
    RestoreVersePosition = 2,
	RestoreNoPosition = 3
} RestorePositionType;

typedef enum {
	BibleViewPoll = 1,
	CommentaryViewPoll = 2,
	NoViewPoll = 3
} PollingType;

@interface ViewController : UIViewController <UITabBarControllerDelegate> {
	// Tab bar
	IBOutlet UITabBarController *tabController;
	
	// Read tab
	IBOutlet UIWebView *bibleWebView;
	IBOutlet UIBarButtonItem *bibleNavBtn;
	IBOutlet UIBarButtonItem *biblePrevBtn;
	IBOutlet UIBarButtonItem *bibleNextBtn;
	IBOutlet UIActivityIndicatorView *bibleActivity;
	IBOutlet UITabBarItem *bibleTabBarItem;
	IBOutlet UISegmentedControl *bibleSegmentedControl;
	IBOutlet UIBarButtonItem *bibleSearchButton;
	
	// Commentary tab
	IBOutlet UIWebView *commentaryWebView;
	IBOutlet UIBarButtonItem *commentaryNavBtn;
	IBOutlet UIBarButtonItem *commentaryPrevBtn;
	IBOutlet UIBarButtonItem *commentaryNextBtn;
	IBOutlet UIActivityIndicatorView *commentaryActivity;
	IBOutlet UITabBarItem *commentaryTabBarItem;
	IBOutlet UISegmentedControl *commentarySegmentedControl;
	IBOutlet UIBarButtonItem *commentarySearchButton;
	
	// Bible & Commentary tab
	IBOutlet UIPickerView *refSelector;
	IBOutlet UIView *refSelectorView;
	IBOutlet UIBarButtonItem *refSelectorTitle;
	
	IBOutlet UIView *modulesListView;
	IBOutlet UITableView *modulesListTable;
	IBOutlet UINavigationItem *modulesNavigationItem;
	
	// Module tab
	IBOutlet id moduleTable;
	IBOutlet id moduleEditBtn;
	IBOutlet UITabBarItem *moduleTabBarItem;
	IBOutlet UINavigationItem *moduleNavBar;
	
	// Search tab
	//IBOutlet id progressBar;
	//IBOutlet id resultsTable;
	
	// Bookmarks tab
	IBOutlet id bookmarksTable;
	IBOutlet id bookmarksEditBtn;
	IBOutlet UINavigationItem *bookmarksNavBar;
	
	// Preferences tab
	IBOutlet UITabBarItem *preferencesTabBarItem;
	
	// About tab
	IBOutlet UITabBarItem *aboutTabBarItem;
	
	// Status view
	IBOutlet id statusController;
	IBOutlet id statusTitle;
	IBOutlet id statusText;
	IBOutlet id statusOverallText;
	IBOutlet id statusBar;
	IBOutlet id statusOverallBar;
	
	// Busy Indicator
	IBOutlet UIViewController *activityController;
	IBOutlet UIActivityIndicatorView *activityIndicator;
	IBOutlet UILabel *activityLoadingLabel;
	
	IBOutlet id moduleManager;
	IBOutlet id dataController;
		
}

//- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
//- (void)confirmInstall:(NSString *)name;
- (void)updateInstallationStatus;
- (IBAction)nextChapter:(id)sender;
- (IBAction)prevChapter:(id)sender;
- (IBAction)toggleNavigation:(id)sender;
- (IBAction)updateViewWithSelectedChapter:(id)sender;
- (IBAction)toggleModuleTableEditing:(id)sender;
- (IBAction)toggleBookmarksTableEditing:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (IBAction)moveToModulesTab:(id)sender;

- (IBAction)toggleModulesList:(id)sender;

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab;
- (void)displayChapter:(NSString *)ref withPollingType:(PollingType)polling restoreType:(RestorePositionType)position;
- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position;

- (void) showModal:(UIView*)modalView withTiming:(float)time;
- (void) hideModal:(UIView*) modalView withTiming:(float)time;
- (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
- (void)displayBusyIndicator;
- (void)hideBusyIndicator;
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

- (void)setEnabledBibleNextButton:(BOOL)enabled;
- (void)setEnabledBiblePreviousButton:(BOOL)enabled;
- (void)setEnabledCommentaryNextButton:(BOOL)enabled;
- (void)setEnabledCommentaryPreviousButton:(BOOL)enabled;

@end
