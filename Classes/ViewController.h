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

#import "PSModuleController.h"
#import "PocketSwordAppDelegate.h"
#import "globals.h"
#import "PSDictionaryViewController.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"
#import "PSRefSelectorController.h"

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
	IBOutlet UIWebView					*bibleWebView;
	IBOutlet UIActivityIndicatorView	*bibleActivity;
	IBOutlet UITabBarItem				*bibleTabBarItem;
	IBOutlet UISegmentedControl			*bibleSegmentedControl;
	IBOutlet UIBarButtonItem			*bibleSearchButton;
	IBOutlet PSBibleViewController		*bibleTabController;
	
	// Commentary tab
	IBOutlet UIWebView					*commentaryWebView;
	IBOutlet UIActivityIndicatorView	*commentaryActivity;
	IBOutlet UITabBarItem				*commentaryTabBarItem;
	IBOutlet UISegmentedControl			*commentarySegmentedControl;
	IBOutlet UIBarButtonItem			*commentarySearchButton;
	IBOutlet PSCommentaryViewController *commentaryTabController;
	
	// Bible & Commentary tab
	IBOutlet PSRefSelectorController	*refSelectorController;
	IBOutlet UIPickerView				*refSelector;
	IBOutlet UIView						*infoView;
	IBOutlet UIWebView					*infoWebView;
	
	// MultiList
	IBOutlet UITabBarController *multiListController;
	//IBOutlet UIView				*modulesListView;
	IBOutlet id					moduleSelectorViewController;
	IBOutlet UITableView		*modulesListTable;
	IBOutlet UINavigationItem	*modulesNavigationItem;
	
	IBOutlet UIView				*historyListView;
	IBOutlet UITableView		*historyListTable;
	IBOutlet UINavigationItem	*historyNavigationItem;
	IBOutlet UIBarButtonItem	*historyCloseButton;
	
	// Dictionary tab
	IBOutlet UITabBarItem				*dictionaryTabBarItem;
	IBOutlet PSDictionaryViewController	*dictionaryViewController;
	IBOutlet UITabBarItem				*devotionalTabBarItem;
	IBOutlet UIWebView					*devotionalWebView;
	
	// Bookmarks tab
//	IBOutlet id bookmarksTable;
//	IBOutlet id bookmarksEditBtn;
//	IBOutlet UINavigationItem *bookmarksNavBar;
	
	// Preferences tab
	IBOutlet UITabBarItem *preferencesTabBarItem;
	
	// About tab
	IBOutlet UITabBarItem *aboutTabBarItem;
	
	// Status view
	IBOutlet UIViewController *statusController;
	IBOutlet UILabel *statusTitle;
	IBOutlet UILabel *statusText;
	IBOutlet UILabel *statusOverallText;
	IBOutlet UIProgressView *statusBar;
	IBOutlet UIProgressView *statusOverallBar;
	
	// Busy Indicator
	IBOutlet UIViewController *activityController;
	IBOutlet UIActivityIndicatorView *activityIndicator;
	IBOutlet UILabel *activityLoadingLabel;
	
	NSLock *toolbarLock;
	
	IBOutlet id moduleManager;
	IBOutlet id historyController;
		
}

+ (void)setFirstRefAvailable:(NSString*)first;
+ (void)setLastRefAvailable:(NSString*)last;

+ (void) showModal:(UIView*)modalView withTiming:(float)time;
+ (void) hideModal:(UIView*) modalView withTiming:(float)time;
+ (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
+ (void) hideModalAndRelease:(UIView*) modalView withTiming:(float)time;
+ (void) hideModalAndReleaseEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

//- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
//- (void)confirmInstall:(NSString *)name;
- (void)updateInstallationStatus;
- (void)updateIndexInstallationStatus:(NSString*)arg;
- (IBAction)nextChapter:(id)sender;
- (IBAction)prevChapter:(id)sender;
- (IBAction)toggleNavigation:(id)sender;
- (IBAction)updateViewWithSelectedChapter:(id)sender;
- (void)updateViewWithSelectedBook:(NSInteger)book chapter:(NSInteger)chapter verse:(NSInteger)verse;
- (void)updateViewWithSelectedBookName:(NSString*)bookNameString chapter:(NSInteger)chapter verse:(NSInteger)verse;
//- (IBAction)toggleModuleTableEditing:(id)sender;

- (void)addHistoryItem:(ShownTab)tabForHistory;
//- (IBAction)moveToModulesTab:(id)sender;

- (IBAction)toggleModulesList:(id)sender;
- (IBAction)toggleMultiList:(id)sender;

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab;
- (void)displayChapter:(NSString *)ref withPollingType:(PollingType)polling restoreType:(RestorePositionType)position;
- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position;

- (void)displayBusyIndicator;
- (void)hideBusyIndicator;
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

- (void)setEnabledBibleNextButton:(BOOL)enabled;
- (void)setEnabledBiblePreviousButton:(BOOL)enabled;
- (void)setEnabledCommentaryNextButton:(BOOL)enabled;
- (void)setEnabledCommentaryPreviousButton:(BOOL)enabled;

- (void)reloadModuleTable;
- (void)reloadDictionaryData;

- (void)showIndexStatus;
- (void)hideIndexStatus;
- (void)hideOperationStatus;

- (void)highlightSearchTerm:(NSString*)term forTab:(ShownTab)tab;

- (UITabBarController *)tabController;
//- (UIView *)modulesListView;
- (void)setShownTabTo:(ShownTab)tab;

- (void)showInfo:(NSString *)infoString;
- (IBAction)hideInfo:(id)sender;

@end
