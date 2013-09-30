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

#import "globals.h"
#import "PSSearchController.h"
#import "PSDictionaryViewController.h"

#ifdef __cplusplus
#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>
#include <filemgr.h>
#include <localemgr.h>
#endif

@class PSWebView;//remove after the commentary tab is pulled from the XIB.

@class PSModuleSelectorController;
@class Swordmodule;
@class PSBibleViewController;
@class PSCommentaryViewController;
@class PSRefSelectorController;

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

@interface ViewController : NSObject <UITabBarControllerDelegate, PSSearchControllerDelegate, UIPopoverControllerDelegate, UIWebViewDelegate, PSDictionaryViewControllerDelegate> {
	// Tab bar
	IBOutlet UITabBarController *tabController;
    IBOutlet UIWindow *window;
	
	// Bible tab
	PSBibleViewController				*bibleTabController;
	
	// Commentary tab
	IBOutlet PSWebView					*commentaryWebView;
	IBOutlet UISegmentedControl			*commentarySegmentedControl;
    IBOutlet UIBarButtonItem            *commentaryRefButton;
	IBOutlet PSCommentaryViewController *commentaryTabController;
	IBOutlet UIBarButtonItem			*commentaryTitle;
	
	// Bible & Commentary tab
	PSRefSelectorController				*refSelectorController;
	UINavigationController				*refNavigationController;
	UIView								*refTitleSplashView;
	NSTimer								*refTitleSplashTimer;
    UIPopoverController					*popoverController;
	
	// infoView
	UIView								*infoView;
	UIWebView							*infoWebView;
	

	// MultiList
	UITabBarController					*multiListController;

	PSModuleSelectorController			*moduleSelectorViewController;
	
	// Devotional tab
	IBOutlet UIWebView					*devotionalWebView;
	IBOutlet UIBarButtonItem			*devotionalTitle;
	
	// Bookmarks tab
	
	// Preferences tab
	
	// About tab
	IBOutlet UITabBarItem				*aboutTabBarItem;
		
	PSSearchHistoryItem					*savedSearchHistoryItem;
	ShownTab							savedSearchResultsTab;
}

@property (retain, readwrite) PSSearchHistoryItem *savedSearchHistoryItem;
@property (assign, readwrite) ShownTab			 savedSearchResultsTab;
@property (retain) PSBibleViewController *bibleTabController;

+ (void) showModal:(UIView*)modalView withTiming:(float)time;
+ (void) hideModal:(UIView*) modalView withTiming:(float)time;
+ (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
+ (void) hideModalAndRelease:(UIView*) modalView withTiming:(float)time;
+ (void) hideModalAndReleaseEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;

+ (void)setVoiceOverForRefSegmentedControlSubviews:(NSArray *)subviews;
+ (void)displayTitle:(NSString*)title;

- (void)setVoiceOverForRefSegmentedControl;
- (void)setCommentaryTitleViaNotification;

- (void)nightModeChanged;

- (void)nextChapter;
- (void)prevChapter;
- (IBAction)toggleNavigation;
//- (IBAction)updateViewWithSelectedChapter:(id)sender;
//- (void)updateViewWithSelectedBook:(NSInteger)book chapter:(NSInteger)chapter verse:(NSInteger)verse;
- (void)updateViewWithSelectedBookChapterVerse:(NSNotification *)notification;
- (void)updateViewWithSelectedBookName:(NSString*)bookNameString chapter:(NSInteger)chapter verse:(NSInteger)verse;

- (void)toggleModulesListAnimated:(BOOL)animated withModule:(SwordModule *)swordModule fromButton:(id)sender;
//- (IBAction)toggleModulesList;
- (IBAction)toggleModulesList:(NSNotification *)notification;
- (IBAction)toggleModulesListFromButton:(id)sender;
- (void)toggleMultiList:(id)sender;
- (IBAction)toggleMultiList;
- (UITabBarController *)tabBarController;
- (IBAction)addModuleButtonPressed;

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab;
- (void)displayChapter:(NSString *)ref withPollingType:(PollingType)polling restoreType:(RestorePositionType)position;
- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position;
- (void)redisplayChapterWithDefaults;
- (void)redisplayBibleChapter;
- (void)redisplayCommentaryChapter;
- (void)redisplayBibleChapterAfterBookmarksChange;

//- (void)displayBusyIndicator;
//- (void)displayBusyIndicatorViaNotification;
//- (void)hideBusyIndicator;

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

- (void)segmentedControlAction:(id)sender;
- (void)displayCommentaryTabViaNotification;
- (void)displayBibleTabViaNotification;

@end

@interface PSLoadingViewController : UIViewController {
	
}

@end
