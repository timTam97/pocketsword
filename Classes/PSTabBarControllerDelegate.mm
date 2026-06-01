/*
	PocketSword - a frontend for viewing SWORD project modules on the iPhone and iPod Touch
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

#import <QuartzCore/QuartzCore.h>

#import "PSTabBarControllerDelegate.h"
#import "PocketSword-Swift.h"
#import "SearchWebView.h"
#import "PSHistoryController.h"
#import "PSModuleSelectorController.h"
#import "PSPreferencesController.h"
#import "PSBookmarksNavigatorController.h"
#import "SwordModule.h"
#import "PSModuleController.h"
#import "PocketSwordAppDelegate.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"
#import "PSRefSelectorController.h"
//#import "PSWebView.h"
#import "SwordManager.h"
#import "SwordDictionary.h"
#import "PSAboutScreenController.h"
#import "PSInfoPopupViewController.h"

@implementation PSTabBarControllerDelegate

@synthesize savedSearchHistoryItem, savedSearchResultsTab, bibleTabController, commentaryTabController, tabBarController;

- (id)init {
	self = [super init];
	if(self) {
		
		UITabBarController *tbc = [[UITabBarController alloc] init];
		tbc.delegate = self;
		self.tabBarController = tbc;

		[PSModuleController defaultModuleController];//init

		NSMutableArray *tabs = [NSMutableArray arrayWithCapacity:8];
		// Order of the tabs:
		// 00: Bible
		// 01: Commentary
		// 02: Dictionary
		// 03: Bookmarks
		// 04: Preferences
		// 05: About
		
		//add the Commentary Tab.
		PSCommentaryViewController *cvc = [[PSCommentaryViewController alloc] init];
		cvc.title = CommentaryTabTitleString;
		[cvc view];//load the view before we continue!
		[cvc setDelegate:self];
		UINavigationController *cTab = [[UINavigationController alloc] initWithRootViewController:cvc];
		[tabs insertObject:cTab atIndex:0];
		self.commentaryTabController = cvc;
		
		//add the Bible Tab.
		// Do this second because we need the commentary tab to initialise the Bible tab!
		PSBibleViewController *bvc = [[PSBibleViewController alloc] init];
		bvc.title = BibleTabTitleString;
		[bvc view];//load the view before we continue!
		[bvc setDelegate:self];
		bvc.commentaryView = commentaryTabController;
		UINavigationController *bTab = [[UINavigationController alloc] initWithRootViewController:bvc];
		[tabs insertObject:bTab atIndex:0];
		self.bibleTabController = bvc;
		
		//add the Dictionary Tab.
		PSDictionaryViewController *dictionaryViewController = [[PSDictionaryViewController alloc] initWithStyle:UITableViewStyleGrouped];
		dictionaryViewController.delegate = self;
		UINavigationController *dictionaryTab = [[UINavigationController alloc] initWithRootViewController:dictionaryViewController];
		UITabBarItem *dTBI = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitleDictionary", @"Dictionary") image:[UIImage imageNamed:@"dictionary.png"] tag:99];
		dictionaryTab.tabBarItem = dTBI;
		[tabs insertObject:dictionaryTab atIndex:2];
		
		//add the bookmarks tab.
		[PSBookmarks importBookmarksFromV2];
		PSBookmarksNavigatorController *bookmarksViewController = [[PSBookmarksNavigatorController alloc] initWithStyle:UITableViewStyleGrouped];
		UINavigationController *bookmarksTab = [[UINavigationController alloc] initWithRootViewController:bookmarksViewController];
		UITabBarItem *tbI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:0];
		bookmarksTab.tabBarItem = tbI;
		[tabs insertObject:bookmarksTab atIndex:3];
		
		//add the Preferences tab.
		PSPreferencesController *preferencesViewController = [[PSPreferencesController alloc] initWithStyle:UITableViewStyleGrouped];
		UITabBarItem *preferencesTabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitlePreferences", @"Preferences") image:[UIImage imageNamed:@"gear-24.png"] tag:9];
		if([PSResizing iPad]) {
			UINavigationController *preferencesIPadTab = [[UINavigationController alloc] initWithRootViewController:preferencesViewController];
			preferencesIPadTab.tabBarItem = preferencesTabBarItem;
			[tabs insertObject:preferencesIPadTab atIndex:4];
		} else {
			preferencesViewController.tabBarItem = preferencesTabBarItem;
			[tabs insertObject:preferencesViewController atIndex:4];
		}

		//add the About tab.
		PSAboutScreenController *aboutViewController = [[PSAboutScreenController alloc] init];
		UITabBarItem *aboutTBI = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitleAbout", @"About") image:[UIImage imageNamed:@"About.png"] tag:0];
		if([PSResizing iPad]) {
			UINavigationController *aboutIPadTab = [[UINavigationController alloc] initWithRootViewController:aboutViewController];
			aboutIPadTab.tabBarItem = aboutTBI;
			[tabs insertObject:aboutIPadTab atIndex:5];
		} else {
			aboutViewController.tabBarItem = aboutTBI;
			[tabs insertObject:aboutViewController atIndex:5];
		}
		
		[tabBarController setViewControllers:tabs animated:NO];
		tabs = nil;

		tabBarController.customizableViewControllers = nil;
		tabBarController.selectedIndex = 0;
		tabBarController.moreNavigationController.topViewController.navigationItem.rightBarButtonItem = nil;
		tabBarController.delegate = self;
		
				
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
		NSString *lastRef = [PSModuleController getCurrentBibleRef];
		
		if ([PocketSwordAppDelegate sharedAppDelegate].urlToOpen == nil) {
			[self displayChapter:lastRef withPollingType:BibleViewPoll restoreType:RestoreScrollPosition];
		} else {
			[PocketSwordAppDelegate sharedAppDelegate].urlToOpen = nil;
			[self displayChapter:lastRef withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
		}
				
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayChapterWithDefaults) name:NotificationResetBibleAndCommentaryView object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayBibleChapter) name:NotificationRedisplayPrimaryBible object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayCommentaryChapter) name:NotificationRedisplayPrimaryCommentary object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleMultiList) name:NotificationToggleMultiList object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleModulesList:) name:NotificationToggleModuleList object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleNavigation) name:NotificationToggleNavigation object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideInfo) name:NotificationHideInfoPane object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showInfoWithNotification:) name:NotificationShowInfoPane object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rotateInfo:) name:NotificationRotateInfoPane object:nil];
				
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayCommentaryTabViaNotification) name:NotificationShowCommentaryTab object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayBibleTabViaNotification) name:NotificationShowBibleTab object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateViewWithSelectedBookChapterVerse:) name:NotificationUpdateSelectedReference object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayBibleChapterAfterBookmarksChange) name:NotificationBookmarksChanged object:nil];

	}
	return self;
}

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab
{	
	if(tab == BibleTab) {
		[bibleTabController setTabTitle:newTitle];
	} else if(tab == CommentaryTab) {
		[commentaryTabController setTabTitle:newTitle];
	}
}

- (void)setEnabledBibleNextButton:(BOOL)enabled
{
	[bibleTabController setEnabledNextButton:enabled];
}

- (void)setEnabledBiblePreviousButton:(BOOL)enabled
{
	[bibleTabController setEnabledPreviousButton:enabled];
}

- (void)setEnabledCommentaryNextButton:(BOOL)enabled
{
	[commentaryTabController setEnabledNextButton:enabled];
}

- (void)setEnabledCommentaryPreviousButton:(BOOL)enabled
{
	[commentaryTabController setEnabledPreviousButton:enabled];
}

- (void)searchDidFinish:(PSSearchHistoryItem *)newSearchHistoryItem {
	if([[bibleTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
		self.savedSearchResultsTab = BibleTab;
	} else if([[bibleTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
		self.savedSearchResultsTab = CommentaryTab;
	}
	self.savedSearchHistoryItem = newSearchHistoryItem;
}

- (void)toggleMultiList:(id)sender {
	[self toggleMultiList];
}

- (void)toggleMultiList {
//	[self highlightSearchTerm: @"and" forTab: BibleTab];
	
	// Check the live view hierarchy, not just the ivar — swipe-to-dismiss
	// leaves the ivar set, which otherwise makes every alternate tap hit
	// the dismiss branch with nothing actually on screen.
	if(multiListController && multiListController.presentingViewController) {
		[tabBarController dismissViewControllerAnimated:YES completion:nil];
		multiListController = nil;
	} else {
		multiListController = [[UITabBarController alloc] init];
		PSHistoryController *historyController = [[PSHistoryController alloc] init];
		PSModuleSearchController *searchController = [[PSModuleSearchController alloc] init];
		UINavigationController *searchNavigationController = [[UINavigationController alloc] initWithRootViewController:searchController];
		searchNavigationController.title = NSLocalizedString(@"SearchTitle", @"");
		UINavigationController *historyNavigationController = [[UINavigationController alloc] initWithRootViewController:historyController];
		multiListController.delegate = searchController;
		searchController.delegate = self;
		NSArray* controllers = [NSArray arrayWithObjects:historyNavigationController, searchNavigationController, nil];
		multiListController.viewControllers = controllers;
		
		if([[bibleTabController webView] isDescendantOfView:tabBarController.selectedViewController.view] || bibleTabController.isFullScreen) {
			[historyController setListType:BibleTab];
			[searchController setListType:BibleTab];
			if(savedSearchResultsTab == BibleTab && savedSearchHistoryItem && savedSearchHistoryItem.results) {
				//restore the previous search term:
				[searchController setSearchHistoryItem:savedSearchHistoryItem];
				//[multiListController setSelectedViewController:searchNavigationController];
			} else if(savedSearchHistoryItem && (savedSearchHistoryItem.searchTerm || savedSearchHistoryItem.searchTermToDisplay.length > 0)) {
				// Strong's-popup-triggered searches arrive with only
				// searchTermToDisplay + strongsSearch set — the FTS5
				// expression is built later in setSearchHistoryItem:.
				[searchController setSearchHistoryItem:savedSearchHistoryItem];
				self.savedSearchHistoryItem = nil;
				[multiListController setSelectedViewController:searchNavigationController];
			}
		} else {
			[historyController setListType:CommentaryTab];
			[searchController setListType:CommentaryTab];
			if(savedSearchResultsTab == CommentaryTab && savedSearchHistoryItem && savedSearchHistoryItem.results) {
				//restore the previous search term:
				[searchController setSearchHistoryItem:savedSearchHistoryItem];
				//[multiListController setSelectedViewController:searchNavigationController];
			} else if(savedSearchHistoryItem && (savedSearchHistoryItem.searchTerm || savedSearchHistoryItem.searchTermToDisplay.length > 0)) {
				[searchController setSearchHistoryItem:savedSearchHistoryItem];
				self.savedSearchHistoryItem = nil;
				[multiListController setSelectedViewController:searchNavigationController];
			}
		}
		
		if([[NSUserDefaults standardUserDefaults] integerForKey:DefaultsLastMultiListTab] == SearchTab) {
			[multiListController setSelectedViewController:searchNavigationController];
		}
		[tabBarController presentViewController:multiListController animated:YES completion:nil];
	}
	
}

- (void)toggleModulesList:(NSNotification *)notification {
	if(notification) {
		[self toggleModulesListAnimated:YES withModule:[notification object] fromButton:nil];
	} else {
		[self toggleModulesListAnimated:YES withModule:nil fromButton:nil];
	}
}

- (void)toggleModulesListFromButton:(id)sender {
	[self toggleModulesListAnimated:YES withModule:nil fromButton:(id)sender];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
	if(moduleSelectorViewController) {
		moduleSelectorViewController = nil;
	}
	if(refNavigationController) {
		refSelectorController = nil;
		refNavigationController = nil;
	}
	if(infoPopupController &&
	   presentationController.presentedViewController == infoPopupController) {
		infoPopupController = nil;
	}
}

- (void)toggleModulesListAnimated:(BOOL)animated withModule:(SwordModule *)swordModule fromButton:(id)sender {
    BOOL iPad = [PSResizing iPad];
	if(moduleSelectorViewController || (tabBarController.presentedViewController != nil)) {
		[tabBarController dismissViewControllerAnimated:animated completion:nil];
		moduleSelectorViewController = nil;
	} else {
		moduleSelectorViewController = [[PSModuleSelectorController alloc] initWithNibName:nil bundle:nil];
		UINavigationController *modSelectorNavController = [[UINavigationController alloc] initWithRootViewController:moduleSelectorViewController];

		//set the module selector to use the correct module type.
		if([[commentaryTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
			[moduleSelectorViewController setListType:CommentaryTab];
		} else {
			[moduleSelectorViewController setListType:DictionaryTab];
		}

		if(iPad) {
			modSelectorNavController.modalPresentationStyle = UIModalPresentationPopover;
			modSelectorNavController.preferredContentSize = moduleSelectorViewController.preferredContentSize;
			if(sender) {
				modSelectorNavController.popoverPresentationController.barButtonItem = sender;
			} else {
				DLog(@"We should only be calling toggleModulesList with a sender now!");
				CGRect theSpot = CGRectMake(50, ([PSResizing mainScreenBounds].size.width-50), 10, 10);
				modSelectorNavController.popoverPresentationController.sourceView = tabBarController.view;
				modSelectorNavController.popoverPresentationController.sourceRect = theSpot;
			}
			modSelectorNavController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
			modSelectorNavController.popoverPresentationController.delegate = self;
			[tabBarController presentViewController:modSelectorNavController animated:animated completion:nil];
		} else {
			[tabBarController presentViewController:modSelectorNavController animated:animated completion:nil];
		}
	}
}

//- (UITabBarController *)tabBarController {
//	return tabBarController;
//}

- (void)displayCommentaryTabViaNotification {
	[self setShownTabTo:CommentaryTab];
}

- (void)displayBibleTabViaNotification {
	[self setShownTabTo:BibleTab];
}

- (void)toggleNavigation {
    BOOL iPad = [PSResizing iPad];
	if(refNavigationController || (tabBarController.presentedViewController != nil)) {
        [tabBarController dismissViewControllerAnimated:YES completion:nil];
		refSelectorController = nil;
		refNavigationController = nil;
	} else {
		if([[bibleTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
			// bible tab
			if(![[PSModuleController defaultModuleController] primaryBible]) {
                //no Bible selected, so ignore...
			   return;
            }
			refSelectorController = [[PSRefSelectorController alloc] initWithStyle:UITableViewStylePlain];
            [refSelectorController setupNavigation];
			refNavigationController = [[UINavigationController alloc] initWithRootViewController:refSelectorController];
            if(!iPad) {
                [refSelectorController willShowNavigation];
                [tabBarController presentViewController:refNavigationController animated:YES completion:nil];
            } else {
				refNavigationController.modalPresentationStyle = UIModalPresentationPopover;
				UIView *viewToPresentPopoverFrom = [bibleTabController titleSegmentedControl];
				CGRect rect = viewToPresentPopoverFrom.frame;
				rect.origin.x = 0;
				rect.origin.y = 0;
				refNavigationController.popoverPresentationController.sourceView = viewToPresentPopoverFrom;
				refNavigationController.popoverPresentationController.sourceRect = rect;
				refNavigationController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
				refNavigationController.popoverPresentationController.delegate = self;
                [refSelectorController willShowNavigation];
				[tabBarController presentViewController:refNavigationController animated:YES completion:nil];
            }
		} else if([[commentaryTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
			// commentary tab
            if(!([[PSModuleController defaultModuleController] primaryCommentary])) {
                //no Commentary selected, so ignore...
                return;
            }
			refSelectorController = [[PSRefSelectorController alloc] initWithStyle:UITableViewStylePlain];
            [refSelectorController setupNavigation];
			refNavigationController = [[UINavigationController alloc] initWithRootViewController:refSelectorController];
            if(!iPad) {
                [refSelectorController willShowNavigation];
                [tabBarController presentViewController:refNavigationController animated:YES completion:nil];
            } else {
				refNavigationController.modalPresentationStyle = UIModalPresentationPopover;
				UIView *viewToPresentPopoverFrom = [commentaryTabController titleSegmentedControl];
				CGRect rect = viewToPresentPopoverFrom.frame;
				rect.origin.x = 0;
				rect.origin.y = 0;
				refNavigationController.popoverPresentationController.sourceView = viewToPresentPopoverFrom;
				refNavigationController.popoverPresentationController.sourceRect = rect;
				refNavigationController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
				refNavigationController.popoverPresentationController.delegate = self;
                [refSelectorController willShowNavigation];
				[tabBarController presentViewController:refNavigationController animated:YES completion:nil];
            }
        }
	}
}

- (void)updateViewWithSelectedBookChapterVerse:(NSNotification *)notification {
	NSDictionary *bcv = nil;
	if(notification) {
		bcv = [notification object];
	}
	if(!bcv) return;
	
	NSString *bookNameString = [bcv objectForKey:BookNameString];
	NSInteger chapter = [(NSString*)[bcv objectForKey:ChapterString] integerValue];
	NSInteger verse = [(NSString*)[bcv objectForKey:VerseString] integerValue];
	[self updateViewWithSelectedBookName:bookNameString chapter:chapter verse:verse];
}

- (void)updateViewWithSelectedBookName:(NSString*)bookNameString chapter:(NSInteger)chapter verse:(NSInteger)verse {
	NSString *bookName = [SwordManager translateBookName:bookNameString];
	NSString *verseString = [NSString stringWithFormat:@"%ld", (long)verse];
	NSString *ref = [bookName stringByAppendingFormat: @" %ld", (long)chapter];
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if([currentRef isEqualToString:ref]) {
		//we only need to move to the selected verse rather than reload the whole chapter
		NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", verseString];
		[bibleTabController scrollToVerse:verse];
		[[bibleTabController webView] stringByEvaluatingJavaScriptFromString:javascript];
		[commentaryTabController scrollToVerse:verse];
		[[commentaryTabController webView] stringByEvaluatingJavaScriptFromString:javascript];
		if([moduleController primaryBible]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:BibleTab];
		}
		if([moduleController primaryCommentary]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:CommentaryTab];
		}
	} else {
		
		if([[bibleTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
			// bible tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
			[PSHistoryController addHistoryItem:BibleTab];
		} else if([[commentaryTabController webView] isDescendantOfView:tabBarController.selectedViewController.view]) {
			// commentary tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
			[PSHistoryController addHistoryItem:CommentaryTab];
		} else {
			//something tab???
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
		}
	}
}


+ (void)displayTitle:(NSString*)title {
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:[PSResizing keyWindow] animated:YES];
	hud.mode = MBProgressHUDModeText;
    hud.label.text = [PSModuleController createRefString:title];
	hud.removeFromSuperViewOnHide = YES;
	
	[hud hideAnimated:YES afterDelay:0.75];
}

- (void)redisplayChapterWithDefaults {
	NSString *ref = [PSModuleController getCurrentBibleRef];
	[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
}

- (void)redisplayBibleChapterAfterBookmarksChange {
	bibleTabController.refToShow = nil;
	bibleTabController.jsToShow = nil;
	[self redisplayChapter:BibleViewPoll restore:RestoreScrollPosition];
}

- (void)redisplayBibleChapter {
	bibleTabController.refToShow = nil;
	bibleTabController.jsToShow = nil;
	[self redisplayChapter:BibleViewPoll restore:RestoreVersePosition];
}

- (void)redisplayCommentaryChapter {
	//[commentaryTitle setTitle: NSLocalizedString(@"None", @"None")];
	commentaryTabController.refToShow = nil;
	commentaryTabController.jsToShow = nil;
	[self redisplayChapter:CommentaryViewPoll restore:RestoreVersePosition];
}

- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position {
	NSString *ref = [PSModuleController getCurrentBibleRef];
	[self displayChapter:ref withPollingType:pollingType restoreType:position];
}

- (void)displayChapter:(NSString *)ref withPollingType:(PollingType)polling restoreType:(RestorePositionType)position {
	NSMutableString *bibleJavascript = [NSMutableString stringWithString:@""];
	NSMutableString *commentaryJavascript = [NSMutableString stringWithString:@""];
	NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsBibleVersePosition];
	switch(position) {
		case RestoreScrollPosition:
		{
			NSString *scrollPosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleScrollPosition"];
			if(scrollPosition) {
				[bibleJavascript appendFormat:@"scrollToPosition(%@);\n", scrollPosition];
			}
			scrollPosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"commentaryScrollPosition"];
			if(scrollPosition) {
				[commentaryJavascript appendFormat:@"scrollToPosition(%@);\n", scrollPosition];
			}
		}
			break;
		case RestoreVersePosition:
		{
			if(versePosition) {
				[bibleJavascript appendFormat:@"scrollToVerse(%@);\n", versePosition];
				[bibleTabController setVerseToShow:[versePosition integerValue]];
			}
			versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsCommentaryVersePosition];
			if(versePosition) {
				[commentaryJavascript appendFormat:@"scrollToVerse(%@);\n", versePosition];
				[commentaryTabController setVerseToShow:[versePosition integerValue]];
			}
		}
			break;
		case RestoreNoPosition:
		default:
			break;
	}
	
	switch(polling) {
		case BibleViewPoll:
		{
			[bibleJavascript appendString:@"startDetLocPoll();\n"];
			NSString *bText = [[PSModuleController defaultModuleController] getBibleChapter:ref withExtraJS:bibleJavascript];
			[[bibleTabController webView] loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
			//NSLog(@"%@", bText);
			commentaryTabController.refToShow = ref;
			commentaryTabController.jsToShow = commentaryJavascript;
		}
			break;
		case CommentaryViewPoll:
		{
			[commentaryJavascript appendString:@"startDetLocPoll();\n"];
			NSString *cText = [[PSModuleController defaultModuleController] getCommentaryChapter:ref withExtraJS:commentaryJavascript];
			[[commentaryTabController webView] loadHTMLString: cText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
			//NSLog(@"%@", cText);
			bibleTabController.refToShow = ref;
			bibleTabController.jsToShow = bibleJavascript;
		}
			break;
		case NoViewPoll:
		default:
		{
			commentaryTabController.refToShow = ref;
			commentaryTabController.jsToShow = commentaryJavascript;
			bibleTabController.refToShow = ref;
			bibleTabController.jsToShow = bibleJavascript;
		}
			break;
	}

	NSString *cVersePosition = @"1";
	if(versePosition) {
		cVersePosition = [NSString stringWithString:versePosition];
	} else {
		versePosition = @"1";
	}
	switch(position) {
		case RestoreScrollPosition:
		{
			cVersePosition = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsCommentaryVersePosition];
			if(!cVersePosition)
				cVersePosition = @"1";
		}
			break;
		case RestoreVersePosition:
		{
		}
			break;
		case RestoreNoPosition:
		{
			versePosition = @"1";
			cVersePosition = @"1";
		}
		default:
			break;
	}
	
	NSString *titleString = [NSString stringWithFormat:@"%@:%@", [PSModuleController createRefString:ref], versePosition];
	if([[PSModuleController defaultModuleController] primaryBible]) {
		[self setTabTitle: titleString ofTab:BibleTab];
	}
	titleString = [NSString stringWithFormat:@"%@:%@", [PSModuleController createRefString:ref], cVersePosition];
	if([[PSModuleController defaultModuleController] primaryCommentary]) {
		[self setTabTitle: titleString ofTab:CommentaryTab];
	}
	
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if ([currentRef isEqualToString: [PSModuleController getLastRefAvailable]]) {
		[self setEnabledBibleNextButton: NO];
		[self setEnabledBiblePreviousButton: YES];
		[self setEnabledCommentaryNextButton: NO];
		[self setEnabledCommentaryPreviousButton: YES];
	} else if ([currentRef isEqualToString: [PSModuleController getFirstRefAvailable]]) {
		[self setEnabledBibleNextButton: YES];
		[self setEnabledBiblePreviousButton: NO];
		[self setEnabledCommentaryNextButton: YES];
		[self setEnabledCommentaryPreviousButton: NO];
	} else {
		[self setEnabledBibleNextButton: YES];
		[self setEnabledBiblePreviousButton: YES];
		[self setEnabledCommentaryNextButton: YES];
		[self setEnabledCommentaryPreviousButton: YES];
	}
}

- (void)highlightSearchTerm:(NSString*)term forTab:(ShownTab)tab {
	switch(tab) {
		case BibleTab:
			[[[bibleTabController webView] wkWebView] highlightAllOccurencesOfString:term completion:nil];
			break;
		case CommentaryTab:
			[[[commentaryTabController webView] wkWebView] highlightAllOccurencesOfString:term completion:nil];
			break;
        case DictionaryTab:
        case DevotionalTab:
        case PreferencesTab:
        default:
            break;
	}
}

- (void)showInfoWithNotification:(NSNotification *)notification {
	if(notification) {
		[self showInfo:[notification object]];
	}
}

- (void)showInfo:(NSString *)infoString {
	if(infoPopupController && infoPopupController.presentingViewController) {
		// Already on screen — just swap the HTML, don't re-present.
		[infoPopupController loadHTML:infoString];
		return;
	}

	PSInfoPopupViewController *popup = [[PSInfoPopupViewController alloc] init];
	// Force the view hierarchy to build so we can wire up the nav delegate
	// before presentation — WKWebView needs to exist before we assign it.
	[popup view];
	popup.webView.navigationDelegate = self;

	popup.modalPresentationStyle = UIModalPresentationPageSheet;
	popup.presentationController.delegate = self;

	UISheetPresentationController *sheet = popup.sheetPresentationController;
	if(sheet) {
		sheet.detents = @[
			[UISheetPresentationControllerDetent mediumDetent],
			[UISheetPresentationControllerDetent largeDetent],
		];
		sheet.prefersGrabberVisible = YES;
		// Dim the background at every detent — night-mode black-on-black
		// left the popup indistinguishable from the chapter.
		sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
	}

	self->infoPopupController = popup;
	[popup loadHTML:infoString];
	[tabBarController presentViewController:popup animated:YES completion:nil];
}

- (void)rotateInfo:(NSNotification *)notification {
	// The sheet presentation controller handles rotation natively; nothing
	// to do here. Kept as a no-op so existing NotificationRotateInfoPane
	// posts remain valid.
}

- (void)hideInfo {
	[self hideInfoWithCompletion:nil];
}

- (void)hideInfoWithCompletion:(void (^)(void))completion {
	if(!infoPopupController) {
		if(completion) completion();
		return;
	}
	PSInfoPopupViewController *popup = infoPopupController;
	infoPopupController = nil;
	[popup dismissViewControllerAnimated:YES completion:completion];
}

- (void)webView:(WKWebView *)wv decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	NSURLRequest *request = navigationAction.request;

	//NSLog(@"  Info Pane: requestString: %@", [[request URL] absoluteString]);
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;

	if([[[request URL] scheme] isEqualToString:@"bible"]) {
		//our internal reference to say this is a Bible verse to display in the Bible tab
		if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
			//error checking, should always get here...
			[self setShownTabTo:BibleTab];
			NSString *ref = [rData objectForKey:ATTRTYPE_VALUE];
			NSArray *comps = [ref componentsSeparatedByString:@":"];

			if([comps count] > 1) {
				//we have a verse
				[[NSUserDefaults standardUserDefaults] setObject: [comps objectAtIndex:1] forKey: DefaultsBibleVersePosition];
				[[NSUserDefaults standardUserDefaults] synchronize];
				ref = [comps objectAtIndex:0];//just the book & ch
				[self displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreVersePosition];
			} else {
				[self displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreNoPosition];
			}
			[PSHistoryController addHistoryItem:BibleTab];

			decisionHandler(WKNavigationActionPolicyCancel);
			return;
		}
	} else if([[[request URL] scheme] isEqualToString:@"search"]) {
		// Tapping a Strong's link routes here (e.g. search://H0430).
		// The FTS5 engine handles H0xxx/Hxxx equivalence internally, so
		// we no longer need to build `lemma:` expressions with || operators.
		NSString *strongsSearchTerm = [[request URL] host];
		self.savedSearchHistoryItem = nil;
		PSSearchHistoryItem *shi = [[PSSearchHistoryItem alloc] init];
		shi.searchTermToDisplay = strongsSearchTerm;
		shi.strongsSearch = YES;
		self.savedSearchHistoryItem = shi;
		// Chain the present on dismiss completion — presenting while the
		// popup is still mid-dismiss silently drops the second presentation,
		// leaving the search sheet unopened.
		__weak PSTabBarControllerDelegate *weakSelf = self;
		[self hideInfoWithCompletion:^{
			[weakSelf toggleMultiList];
		}];

		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}

	if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
		//
		// it's a Bible ref or dictionary entry to show.
		//
		NSString *mod = [rData objectForKey:ATTRTYPE_MODULE];
		BOOL isABibleRef = NO;
		if(mod) {
			SwordModule *modToUse = [[SwordManager defaultManager] moduleWithName:mod];
			if(!modToUse || modToUse.type == bible || modToUse.type == commentary) {
				isABibleRef = YES;
			} else {
				// Should be a dictionary entry:
				SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
				BOOL strongs = NO;
				BOOL greekStrongs = YES;
				if(swordDictionary) {
					entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];

					NSString *strongsSearchTerm = @"";
					if([swordDictionary hasFeature: SWMOD_CONF_FEATURE_GREEKDEF] && [swordDictionary hasFeature: SWMOD_CONF_FEATURE_HEBREWDEF]) {
						// should already have a prefix
						strongsSearchTerm = [rData objectForKey:ATTRTYPE_VALUE];
						strongs = YES;
					} else if([swordDictionary hasFeature: SWMOD_CONF_FEATURE_GREEKDEF]) {
						NSMutableString *greek = [[rData objectForKey:ATTRTYPE_VALUE] mutableCopy];
						while([greek characterAtIndex:0] == '0') {
							[greek deleteCharactersInRange:NSMakeRange(0, 1)];
						}
						strongsSearchTerm = [NSString stringWithFormat:@"G%@", greek];
						greek = nil;
						strongs = YES;
					} else if([swordDictionary hasFeature: SWMOD_CONF_FEATURE_HEBREWDEF]) {
						greekStrongs = NO;
						NSMutableString *hebrew = [[rData objectForKey:ATTRTYPE_VALUE] mutableCopy];
						while([hebrew characterAtIndex:0] == '0') {
							[hebrew deleteCharactersInRange:NSMakeRange(0, 1)];
						}
						strongsSearchTerm = [NSString stringWithFormat:@"H0%@", hebrew];
						hebrew = nil;
						strongs = YES;
					}
					if(strongs) {
						entry = [NSString stringWithFormat:@"%@<div style=\"text-align: right\"><a href=\"search://%@\">%@</a></div>", entry, strongsSearchTerm, NSLocalizedString(@"StrongsSearchFindAll", @"")];
					}
					//DLog(@"\n%@ = %@\n", mod, entry);
				} else {
					entry = [NSString stringWithFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ %@</p>", mod, NSLocalizedString(@"ModuleNotInstalled", @"is not installed.")];
				}

				NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsFontNamePreference];
				if(strongs && greekStrongs) {
					[[NSUserDefaults standardUserDefaults] setObject:PSGreekStrongsFontName forKey:DefaultsFontNamePreference];
				} else if(strongs && !greekStrongs) {
					[[NSUserDefaults standardUserDefaults] setObject:PSHebrewStrongsFontName forKey:DefaultsFontNamePreference];
				} else {
					[[NSUserDefaults standardUserDefaults] setObject:StrongsFontName forKey:DefaultsFontNamePreference];
				}
				[[NSUserDefaults standardUserDefaults] synchronize];
				entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:mod];
				[[NSUserDefaults standardUserDefaults] setObject:fontName forKey:DefaultsFontNamePreference];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
		} else {
			// Bible ref:
			isABibleRef = YES;
		}

		if(isABibleRef) {
			// handle ref:
			SwordModule *modToUse;
			if(mod && ![mod isEqualToString:@""]) {
				modToUse = [[SwordManager defaultManager] moduleWithName:mod];
			} else {
				modToUse = [[PSModuleController defaultModuleController] primaryBible];
			}
			if(mod && !modToUse) {
				entry = [NSString stringWithFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ %@</p>", mod, NSLocalizedString(@"ModuleNotInstalled", @"is not installed.")];
				entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:nil];
			} else {
				id attributeValue = [modToUse attributeValueForEntryData:rData cleanFeed:NO];
				if([attributeValue isMemberOfClass:[NSString class]]) {
					entry = [PSModuleController createInfoHTMLString: (NSString*)attributeValue usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
				} else if([attributeValue isKindOfClass:[NSArray class]]) {
					NSMutableString *tmpEntry = [@"" mutableCopy];
					for(NSDictionary *dict in (NSArray*)attributeValue) {
						NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
						[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
						[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
					}
					//DLog(@"\n%@\n", tmpEntry);
					if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
						entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
						entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[modToUse name]];
					}
				}
			}
		}

	} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showNote"]) {
		if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"n"]) {//footnote
			entry = (NSString*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
			entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
		} else if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"x"]) {//x-reference
			NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
			NSMutableString *tmpEntry = [@"" mutableCopy];
			for(NSDictionary *dict in array) {
				NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
				[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
				[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
			}
			if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
				entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
				entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
			}
		}
	}

	if(entry) {
		entry = [entry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
		entry = [entry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
		[self showInfo: entry];
		decisionHandler(WKNavigationActionPolicyCancel);
	} else {
		if(rData) {
			//DLog(@"\nempty entry && action = %@", [rData objectForKey:ATTRTYPE_ACTION]);
		} else {
			//DLog(@"rData is nil && entry is nil");
		}
		decisionHandler(WKNavigationActionPolicyAllow);
	}
}

- (void)setShownTabTo:(ShownTab)tab {
	switch(tab) {
		case BibleTab:
		{
			for(UIViewController* uivc in tabBarController.viewControllers) {
				if([uivc.title isEqualToString:BibleTabTitleString]) {
					tabBarController.selectedViewController = uivc;
				}
			}
		}
			break;
		case CommentaryTab:
		{
			for(UIViewController* uivc in tabBarController.viewControllers) {
				if([uivc.title isEqualToString:CommentaryTabTitleString]) {
					tabBarController.selectedViewController = uivc;
				}
			}
		}
			break;
		case PreferencesTab:
		{
			for(UIViewController *uivc in tabBarController.viewControllers) {
				if([uivc isKindOfClass:[PSPreferencesController class]]) {
					tabBarController.selectedViewController = uivc;
					break;
				}
			}
		}
			break;
        case DictionaryTab:
        case DevotionalTab:
        default:
            break;
	}
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

@end

@implementation PSLoadingViewController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}


@end
