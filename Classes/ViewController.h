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

#import "SwordModule.h"
#import "PSModuleController.h"
#import "PocketSwordAppDelegate.h"
#import "globals.h"
#import "PSDictionaryViewController.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"
#import "PSRefSelectorController.h"
//#import "PSMultiListController.h"

#ifdef __cplusplus
#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>
#include <filemgr.h>
#include <localemgr.h>
#endif

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

@interface PSWebView : UIWebView {}
@end

@interface ViewController : NSObject <UITabBarControllerDelegate> {
	// Tab bar
	IBOutlet UITabBarController *tabController;
	
	// Bible tab
	IBOutlet PSWebView					*bibleWebView;
	IBOutlet UIActivityIndicatorView	*bibleActivity;
	IBOutlet UISegmentedControl			*bibleSegmentedControl;
	IBOutlet UIBarButtonItem			*bibleSearchButton;
	IBOutlet PSBibleViewController		*bibleTabController;
	IBOutlet UIBarButtonItem			*bibleTitle;
	
	// Commentary tab
	IBOutlet PSWebView					*commentaryWebView;
	IBOutlet UIActivityIndicatorView	*commentaryActivity;
	IBOutlet UISegmentedControl			*commentarySegmentedControl;
	IBOutlet UIBarButtonItem			*commentarySearchButton;
	IBOutlet PSCommentaryViewController *commentaryTabController;
	IBOutlet UIBarButtonItem			*commentaryTitle;
	
	// Bible & Commentary tab
	IBOutlet PSRefSelectorController	*refSelectorController;
	IBOutlet UIView						*infoView;
	IBOutlet UIWebView					*infoWebView;
	UIView								*refTitleSplashView;
	NSTimer								*refTitleSplashTimer;

	// MultiList
	UITabBarController					*multiListController;

	id									moduleSelectorViewController;
	
	// Dictionary tab
	IBOutlet PSDictionaryViewController	*dictionaryViewController;
	IBOutlet UIBarButtonItem			*dictionaryTitle;
	
	// Devotional tab
	IBOutlet UIWebView					*devotionalWebView;
	
	// Bookmarks tab
//	IBOutlet id							bookmarksTable;
//	IBOutlet id							bookmarksEditBtn;
//	IBOutlet UINavigationItem			*bookmarksNavBar;
	
	// Preferences tab
	
	// About tab
	IBOutlet UITabBarItem				*aboutTabBarItem;
	
	// Busy Indicator
	IBOutlet UIViewController			*activityController;
	IBOutlet UIActivityIndicatorView	*activityIndicator;
	IBOutlet UILabel					*activityLoadingLabel;
	
	NSLock								*toolbarLock;
	
}

+ (void)setFirstRefAvailable:(NSString*)first;
+ (void)setLastRefAvailable:(NSString*)last;

+ (void) showModal:(UIView*)modalView withTiming:(float)time;
+ (void) hideModal:(UIView*) modalView withTiming:(float)time;
+ (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
+ (void) hideModalAndRelease:(UIView*) modalView withTiming:(float)time;
+ (void) hideModalAndReleaseEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

- (void)setVoiceOverForRefSegmentedControl;
- (void)setBibleTitleViaNotification;
- (void)setCommentaryTitleViaNotification;
- (void)setDictionaryTitleViaNotification;

//- (void)updateInstallationStatus;
//- (void)updateIndexInstallationStatus:(NSString*)arg;//needed, move to PSIndexController
//- (void)showIndexStatus;//needed, move to PSIndexController
//- (void)hideIndexStatus;//needed, move to PSIndexController
//- (void)hideOperationStatus;

- (void)displayTitle:(NSString*)title;
- (void)removeTitle:(NSTimer*)theTimer;
- (IBAction)nextChapter:(id)sender;
- (IBAction)prevChapter:(id)sender;
- (IBAction)toggleNavigation;
//- (IBAction)updateViewWithSelectedChapter:(id)sender;
//- (void)updateViewWithSelectedBook:(NSInteger)book chapter:(NSInteger)chapter verse:(NSInteger)verse;
- (void)updateViewWithSelectedBookName:(NSString*)bookNameString chapter:(NSInteger)chapter verse:(NSInteger)verse;

- (void)toggleModulesListAnimated:(BOOL)animated withModule:(SwordModule *)swordModule;
//- (IBAction)toggleModulesList;
- (IBAction)toggleModulesList:(NSNotification *)notification;
- (IBAction)toggleModulesListFromButton:(id)sender;
- (IBAction)toggleMultiList;
- (UITabBarController *)tabBarController;
- (IBAction)addModuleButtonPressed;

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab;
- (void)displayChapter:(NSString *)ref withPollingType:(PollingType)polling restoreType:(RestorePositionType)position;
- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position;
- (void)redisplayChapterWithDefaults;
- (void)redisplayBibleChapter;
- (void)redisplayCommentaryChapter;

- (void)displayBusyIndicator;
- (void)hideBusyIndicator;
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

- (void)setEnabledBibleNextButton:(BOOL)enabled;
- (void)setEnabledBiblePreviousButton:(BOOL)enabled;
- (void)setEnabledCommentaryNextButton:(BOOL)enabled;
- (void)setEnabledCommentaryPreviousButton:(BOOL)enabled;

//- (void)reloadModuleTable;

- (void)highlightSearchTerm:(NSString*)term forTab:(ShownTab)tab;

- (void)setShownTabTo:(ShownTab)tab;

- (void)showInfoWithNotification:(NSNotification *)notification;
- (void)showInfo:(NSString *)infoString;
- (void)rotateInfo:(NSNotification *)notification;
- (IBAction)hideInfo;
- (void) showInfoModal:(UIView*)modalView withTiming:(float)time;
- (void) hideInfoModal:(UIView*) modalView withTiming:(float)time;
- (void) hideInfoModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

@end

@interface PSLoadingViewController : UIViewController {
	
}

@end
