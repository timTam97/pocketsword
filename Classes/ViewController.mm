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

#import "ViewController.h"
#import "PSIndexController.h"
#import "SearchWebView.h"
#import "HistoryController.h"
#import "NavigatorSources.h"
#import "PSModuleSelectorController.h"
#import "PSPreferencesController.h"
#import "PSBookmarksNavigatorController.h"
#import "PSBookmarks.h"

#define INFO_LANDSCAPE_HEIGHT 100.0
#define INFO_PORTRAIT_HEIGHT 160.0

@implementation ViewController

bool initialized = false;

//NSTimer *timer;
static NSString *lastRefAvailable = @"Revelation 22";
static NSString *firstRefAvailable = @"Genesis 1";

+ (void)setFirstRefAvailable:(NSString*)first
{
	if(firstRefAvailable)
		[firstRefAvailable release];
	firstRefAvailable = first;
	[firstRefAvailable retain];
}

+ (void)setLastRefAvailable:(NSString*)last
{
	if(lastRefAvailable)
		[lastRefAvailable release];
	lastRefAvailable = last;
	[lastRefAvailable retain];
}

- (void)awakeFromNib {
	[super awakeFromNib];

	if (!initialized) {
		toolbarLock = [[NSLock alloc] init];
		//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
		activityLoadingLabel.text = NSLocalizedString(@"ActivityLabelLoading", @"Loading...");
		aboutTabBarItem.title = NSLocalizedString(@"TabBarTitleAbout", @"About");
		
		//configure the Bible & commentary segmented controls.
		[bibleSegmentedControl setWidth: 50  forSegmentAtIndex:0];
		[bibleSegmentedControl setWidth: 78 forSegmentAtIndex:1];
		[bibleSegmentedControl setWidth: 50  forSegmentAtIndex:2];
		[bibleSegmentedControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
		
		[commentarySegmentedControl setWidth: 50  forSegmentAtIndex:0];//30
		[commentarySegmentedControl setWidth: 78 forSegmentAtIndex:1];//138
		[commentarySegmentedControl setWidth: 50  forSegmentAtIndex:2];//30
		[commentarySegmentedControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
		
		//VoiceOver hints:
		[self setVoiceOverForRefSegmentedControl];
		bibleSearchButton.accessibilityLabel = NSLocalizedString(@"VoiceOverHistoryAndSearchButton", @"");
		commentarySearchButton.accessibilityLabel = NSLocalizedString(@"VoiceOverHistoryAndSearchButton", @"");
		
		NSString *black = @"<html><body bgcolor=\"black\">@nbsp;</body></html>";
		[bibleWebView loadHTMLString: black baseURL: nil];
		[commentaryWebView loadHTMLString: black baseURL: nil];
				
		PSModuleController *moduleController = [PSModuleController defaultModuleController];
		
		NSString *lastRef = [PSModuleController getCurrentBibleRef];
		
		if ([PocketSwordAppDelegate sharedAppDelegate].urlToOpen == nil) {
			[self displayChapter:lastRef withPollingType:BibleViewPoll restoreType:RestoreScrollPosition];
		} else {
			[PocketSwordAppDelegate sharedAppDelegate].urlToOpen = nil;
			[self displayChapter:lastRef withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
		}
		
		if ([[[moduleController swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] count] == 0) {
			[self setTabTitle: @"PocketSword" ofTab:BibleTab];
			[bibleTitle setTitle: NSLocalizedString(@"None", @"None")];
			[self setEnabledBibleNextButton: NO];
			[self setEnabledBiblePreviousButton: NO];
		}
		if ([[[moduleController swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] count] == 0) {
			[self setTabTitle: @"PocketSword" ofTab:CommentaryTab];
			[commentaryTitle setTitle: NSLocalizedString(@"None", @"None")];
			[self setEnabledCommentaryNextButton: NO];
			[self setEnabledCommentaryPreviousButton: NO];
		}
		[self setBibleTitleViaNotification];
		[self setCommentaryTitleViaNotification];
		[self setDictionaryTitleViaNotification];
		
		tabController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
		tabController.moreNavigationController.topViewController.navigationItem.rightBarButtonItem = nil;
		tabController.delegate = self;
		
		//add our customized bookmarks tab:
		[PSBookmarks importBookmarksFromV2];
		PSBookmarksNavigatorController *bookmarksViewController = [[PSBookmarksNavigatorController alloc] initWithStyle:UITableViewStyleGrouped];
		UINavigationController *bookmarksTab = [[[UINavigationController alloc] initWithRootViewController:bookmarksViewController] retain];
		bookmarksTab.navigationBar.barStyle = UIBarStyleBlack;
		UITabBarItem *tbI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:0];
		bookmarksTab.tabBarItem = tbI;
		[tbI release];
		NSMutableArray *tabs = [tabController.viewControllers mutableCopy];
		[tabs insertObject:bookmarksTab atIndex:3];
		[tabController setViewControllers:tabs animated:NO];
		[tabs release];
		[bookmarksViewController release];
		[bookmarksTab release];
		
		tabController.customizableViewControllers = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter:) name:NotificationBibleSwipeRight object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter:) name:NotificationCommentarySwipeRight object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nextChapter:) name:NotificationBibleSwipeLeft object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nextChapter:) name:NotificationCommentarySwipeLeft object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayChapterWithDefaults) name:NotificationResetBibleAndCommentaryView object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayBibleChapter) name:NotificationRedisplayPrimaryBible object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplayCommentaryChapter) name:NotificationRedisplayPrimaryCommentary object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setBibleTitleViaNotification) name:NotificationNewPrimaryBible object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCommentaryTitleViaNotification) name:NotificationNewPrimaryCommentary object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setDictionaryTitleViaNotification) name:NotificationNewPrimaryDictionary object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleMultiList) name:NotificationToggleMultiList object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleModulesList:) name:NotificationToggleModuleList object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideInfo) name:NotificationHideInfoPane object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showInfoWithNotification:) name:NotificationShowInfoPane object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rotateInfo:) name:NotificationRotateInfoPane object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayBusyIndicatorViaNotification) name:NotificationDisplayBusyIndicator object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideBusyIndicator) name:NotificationHideBusyIndicator object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addModuleButtonPressed) name:NotificationShowDownloadsTab object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayCommentaryTabViaNotification) name:NotificationShowCommentaryTab object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayBibleTabViaNotification) name:NotificationShowBibleTab object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchToFullscreen) name:NotificationSwitchToFullscreen object:nil];
		//[pool release];
		initialized = true;
	}
	
}

- (void)switchToFullscreen {
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		[bibleTabController switchToFullscreen];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// commentary tab
		[commentaryTabController switchToFullscreen];
	}
}

- (void)setBibleTitleViaNotification {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	SwordModule *primaryBible = [[PSModuleController defaultModuleController] primaryBible];
	if(primaryBible) {
		int i = ([[primaryBible name] length] > 5) ? 5 : [[primaryBible name] length];
		NSString *newTitle = ([[primaryBible name] length] > i) ? [NSString stringWithFormat:@"%@..", [[primaryBible name] substringToIndex:i]] : [[primaryBible name] substringToIndex:i];
		[bibleTitle setTitle: newTitle];
	} else {
		[bibleTitle setTitle: NSLocalizedString(@"None", @"None")];
		[self setTabTitle: @"PocketSword" ofTab:BibleTab];
		[self setEnabledBibleNextButton: NO];
		[self setEnabledBiblePreviousButton: NO];
	}
	[pool release];
}

- (void)setCommentaryTitleViaNotification {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	SwordModule *primaryCommentary = [[PSModuleController defaultModuleController] primaryCommentary];
	if(primaryCommentary) {
		int i = ([[primaryCommentary name] length] > 5) ? 5 : [[primaryCommentary name] length];
		NSString *newTitle = ([[primaryCommentary name] length] > i) ? [NSString stringWithFormat:@"%@..", [[primaryCommentary name] substringToIndex:i]] : [[primaryCommentary name] substringToIndex:i];
		[commentaryTitle setTitle: newTitle];
	} else {
		[commentaryTitle setTitle: NSLocalizedString(@"None", @"None")];
		[self setTabTitle: @"PocketSword" ofTab:CommentaryTab];
		[self setEnabledCommentaryNextButton: NO];
		[self setEnabledCommentaryPreviousButton: NO];
	}
	[pool release];
}

- (void)setDictionaryTitleViaNotification {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	SwordModule *primaryDictionary = [[PSModuleController defaultModuleController] primaryDictionary];
	if(primaryDictionary) {
		NSString *newText = [primaryDictionary name];
		int i = ([newText length] > 8) ? 8 : [newText length];
		//but ".." is the equiv of another char, so if length <= 9, use the full name.  eg "Swe1917Of" should display full name.
		NSString *newTitle = ([newText length] <= 9) ? newText : [NSString stringWithFormat:@"%@..", [newText substringToIndex:i]];
		[dictionaryTitle setTitle: newTitle];
	} else {
		[dictionaryTitle setTitle: NSLocalizedString(@"None", @"None")];
	}
	[pool release];
}

//
// UIAlertView delegate method
//
//- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	
//	//DLog(@"Clicked button %d", buttonIndex);
//	if (buttonIndex == 1 && waitingForInstall) {
//		DLog(@"alertView: didDismissWithButtonIndex: -- waitingForInstall");
//		waitingForInstall = false;
//		[self performSelectorInBackground: @selector(runInstallation) withObject: nil];
//		
//		SEL method = @selector(updateInstallationStatus);
//		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
//		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
//		[invocation setTarget: self];
//		[invocation setSelector: method];
//		
//		timer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
//	}
//	
//	[pool release];
//}

- (void)setVoiceOverForRefSegmentedControl {
	int segmentCount = 0;
	//VoiceOver support for the prev & next buttons in the Bible tab
	for(UIView *segmentView in bibleSegmentedControl.subviews) {
		switch (segmentCount) {
			case 0:
				segmentView.accessibilityLabel = NSLocalizedString(@"VoiceOverPreviousChapterButton", @"");
				break;
			case 1:
				segmentView.accessibilityLabel = [bibleSegmentedControl titleForSegmentAtIndex:1];
				break;
			case 2:
				segmentView.accessibilityLabel = NSLocalizedString(@"VoiceOverNextChapterButton", @"");
				break;
			default:
				break;
		}
		segmentCount++;
	}
	segmentCount = 0;
	//VoiceOver support for the prev & next buttons in the commentary tab
	for(UIView *segmentView in commentarySegmentedControl.subviews) {
		switch (segmentCount) {
			case 0:
				segmentView.accessibilityLabel = NSLocalizedString(@"VoiceOverPreviousChapterButton", @"");
				break;
			case 1:
				segmentView.accessibilityLabel = [commentarySegmentedControl titleForSegmentAtIndex:1];
				break;
			case 2:
				segmentView.accessibilityLabel = NSLocalizedString(@"VoiceOverNextChapterButton", @"");
				break;
			default:
				break;
		}
		segmentCount++;
	}
}

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab
{
	[toolbarLock lock];
	NSString *titleToDisplay = [PSModuleController createTitleRefString:newTitle];
	
	if(tab == BibleTab) {
		[bibleSegmentedControl setTitle: titleToDisplay forSegmentAtIndex: 1];
	} else if(tab == CommentaryTab) {
		[commentarySegmentedControl setTitle: titleToDisplay forSegmentAtIndex: 1];
	}
	[self setVoiceOverForRefSegmentedControl];
	[toolbarLock unlock];
}

- (void)setEnabledBibleNextButton:(BOOL)enabled
{
	[bibleSegmentedControl setEnabled: enabled forSegmentAtIndex: 2];
}

- (void)setEnabledCommentaryNextButton:(BOOL)enabled
{
	[commentarySegmentedControl setEnabled: enabled forSegmentAtIndex: 2];
}

- (void)setEnabledBiblePreviousButton:(BOOL)enabled
{
	[bibleSegmentedControl setEnabled: enabled forSegmentAtIndex: 0];
}

- (void)setEnabledCommentaryPreviousButton:(BOOL)enabled
{
	[commentarySegmentedControl setEnabled: enabled forSegmentAtIndex: 0];
}

- (IBAction)segmentedControlAction:(id)sender
{
	UISegmentedControl *segControl = sender;
	switch (segControl.selectedSegmentIndex)
	{
		case 0:	// previous
		{
			[self prevChapter: sender];
			break;
		}
		case 1: // Ref
		{
			[self toggleNavigation];
			break;
		}
		case 2:	// next
		{
			[self nextChapter: sender];
			break;
		}
	}
}

//- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
//	tabBarController.moreNavigationController.navigationBar.topItem.rightBarButtonItem = nil;
//	DLog(@"\nRemoving Edit button");
//}

// Loads the next chapter into the Web View
- (IBAction)nextChapter:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];

	NSString *ref = [[PSModuleController defaultModuleController] setToNextChapter];
	if(!ref) {
		//rats...?
	} else if([bibleWebView isDescendantOfView:tabController.selectedViewController.view] || bibleTabController.isFullScreen) {
		// bible tab
		if(bibleTabController.isFullScreen) {
			[self displayTitle:ref];
		}
		[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreNoPosition];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
		[HistoryController addHistoryItem:BibleTab];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view] || commentaryTabController.isFullScreen) {
		// commentary tab
		if(commentaryTabController.isFullScreen) {
			[self displayTitle:ref];
		}
		[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreNoPosition];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
		[HistoryController addHistoryItem:CommentaryTab];
	} else {
		// weird & undefined
		[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreNoPosition];
	}
	
	[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	[pool release];
}

// Loads the previous chapter into the Web View
- (IBAction)prevChapter:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];

	NSString *ref = [[PSModuleController defaultModuleController] setToPreviousChapter];
	if(!ref) {
		//rats...?
	} else if([bibleWebView isDescendantOfView:tabController.selectedViewController.view] || bibleTabController.isFullScreen) {
		// bible tab
		if(bibleTabController.isFullScreen) {
			[self displayTitle:ref];
		}
		[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
		[HistoryController addHistoryItem:BibleTab];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view] || commentaryTabController.isFullScreen) {
		// commentary tab
		if(commentaryTabController.isFullScreen) {
			[self displayTitle:ref];
		}
		[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
		[HistoryController addHistoryItem:CommentaryTab];
	} else {
		// weird & undefined
		[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
	}
	
	[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	[pool release];
}

- (IBAction)toggleMultiList
{
//	[self highlightSearchTerm: @"and" forTab: BibleTab];
	
	if([multiListController.view superview]) {
	//if(multiListController) {
		[tabController dismissModalViewControllerAnimated:YES];
		//multiListController = nil;
	} else {
		//multiListController = [[PSMultiListController alloc] initWithNibName:@"PSMultiListController" bundle:nil];
		if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
			[historyController setListType: BibleTab];
		} else {
			[historyController setListType: CommentaryTab];
		}
		[tabController presentModalViewController:multiListController animated:YES];
	}
	
}

- (IBAction)toggleModulesList:(NSNotification *)notification {
	if(notification) {
		[self toggleModulesListAnimated:YES withModule:[notification object]];
	} else {
		[self toggleModulesListAnimated:YES withModule:nil];
	}
}

- (IBAction)toggleModulesListFromButton:(id)sender {
	[self toggleModulesListAnimated:YES withModule:nil];
}

- (void)toggleModulesListAnimated:(BOOL)animated withModule:(SwordModule *)swordModule {
	if(moduleSelectorViewController /*&& [((PSModuleSelectorController*)moduleSelectorViewController).view superview]*/) {
		[tabController dismissModalViewControllerAnimated:animated];
		moduleSelectorViewController = nil;
	} else {
		moduleSelectorViewController = [[[PSModuleSelectorController alloc] initWithNibName:@"PSModuleSelectorController" bundle:nil] autorelease];

		if(swordModule) {
			((PSModuleSelectorController*)moduleSelectorViewController).moduleToView = swordModule;
			[moduleSelectorViewController setListType: BibleTab];
		} else {
			((PSModuleSelectorController*)moduleSelectorViewController).moduleToView = nil;
			//set the module selector to use the correct module type.
			if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
				[moduleSelectorViewController setListType: BibleTab];
			} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
				[moduleSelectorViewController setListType: CommentaryTab];
			} else if([devotionalWebView isDescendantOfView:tabController.selectedViewController.view]) {
				[moduleSelectorViewController setListType: DevotionalTab];
			} else {
				[moduleSelectorViewController setListType: DictionaryTab];
			}
		}
		UINavigationController *modSelectorNavController = [[[UINavigationController alloc] initWithRootViewController:moduleSelectorViewController] autorelease];
		modSelectorNavController.navigationBarHidden = YES;
		[tabController presentModalViewController:modSelectorNavController animated:animated];
	}
}

- (UITabBarController *)tabBarController {
	return tabController;
}

- (IBAction)addModuleButtonPressed {
	[self setShownTabTo:DownloadsTab];
}

- (void)displayCommentaryTabViaNotification {
	[self setShownTabTo:CommentaryTab];//setShownTabTo:BibleTab
}

- (void)displayBibleTabViaNotification {
	[self setShownTabTo:BibleTab];
}

- (IBAction)toggleNavigation {
	//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL showingBibleTab = NO;
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		if(![[PSModuleController defaultModuleController] primaryBible])
		   return;
		else
		   showingBibleTab = YES;
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view] && !([[PSModuleController defaultModuleController] primaryCommentary])) {
		// commentary tab
		return;
	}
	[refSelectorController toggleNavigation];
	
	//[pool release];
}

// Loads the chapter selected from the picker into the Web View
//- (void)updateViewWithSelectedBook:(NSInteger)book chapter:(NSInteger)chapter verse:(NSInteger)verse {
//	NSString *bookName = [refSelectorController bookName:book];
//	[self updateViewWithSelectedBookName:bookName chapter:chapter verse:verse]; 
//}

- (void)updateViewWithSelectedBookName:(NSString*)bookNameString chapter:(NSInteger)chapter verse:(NSInteger)verse {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
	NSString *bookName = [NSString stringWithCString:lmgr->translate([bookNameString cStringUsingEncoding:NSUTF8StringEncoding], "en") encoding:NSUTF8StringEncoding];
	NSString *verseString = [NSString stringWithFormat:@"%d", verse];
	NSString *ref = [bookName stringByAppendingFormat: @" %d", chapter];
	PSModuleController *moduleController = [PSModuleController defaultModuleController];
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if([currentRef isEqualToString:ref]) {
		//we only need to move to the selected verse rather than reload the whole chapter
		NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", verseString];
		[bibleWebView stringByEvaluatingJavaScriptFromString:javascript];
		[commentaryWebView stringByEvaluatingJavaScriptFromString:javascript];
		if([moduleController primaryBible]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:BibleTab];
		}
		if([moduleController primaryCommentary]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:CommentaryTab];
		}
	} else {
		[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];
		
		if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
			// bible tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
			[HistoryController addHistoryItem:BibleTab];
		} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
			// commentary tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
			[HistoryController addHistoryItem:CommentaryTab];
		} else {
			//something tab???
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
		}
		[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	}
	
	[pool release];
}

- (void)dealloc {
	[toolbarLock release];
	[moduleSelectorViewController release];
	//[multiListController release];
    [super dealloc];
}

- (void)displayTitle:(NSString*)title {
	CGRect frame;
	UIInterfaceOrientation interfaceOrientation = tabController.interfaceOrientation;
	//NSString *ref = [PSModuleController getCurrentBibleRef];
	UILabel *label;
	label = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 50)];
	label.adjustsFontSizeToFitWidth = YES;
	label.text = [PSModuleController createRefString:title];
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.textAlignment = UITextAlignmentCenter;
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		frame = CGRectMake(130, 115, 220, 70);
	} else {// if(interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		frame = CGRectMake(50, 195, 220, 70);
	}
	
	if(refTitleSplashView) {
		//DLog(@"refTitleSplashView");
		//[self removeTitle:nil];
		[refTitleSplashView removeFromSuperview];
		refTitleSplashView = nil;
		[refTitleSplashTimer invalidate];
		refTitleSplashTimer = nil;
	}
	refTitleSplashView = [[UIView alloc] initWithFrame:frame];
	refTitleSplashView.backgroundColor = [UIColor blackColor];
	refTitleSplashView.alpha = 0.0;
	refTitleSplashView.layer.cornerRadius = 8;
	refTitleSplashView.layer.masksToBounds = YES;
	[refTitleSplashView addSubview:label];
	[label release];
	
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		refTitleSplashView.transform = CGAffineTransformIdentity;
		//refTitleSplashView.frame = CGRectMake(130, 115, 220, 70);
		refTitleSplashView.center = CGPointMake(160, 230);
		refTitleSplashView.transform = CGAffineTransformMakeRotation(3.0 * M_PI / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		refTitleSplashView.transform = CGAffineTransformIdentity;
		//refTitleSplashView.frame = CGRectMake(130, 115, 220, 70);
		refTitleSplashView.center = CGPointMake(160, 230);
		refTitleSplashView.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		refTitleSplashView.transform = CGAffineTransformIdentity;
		refTitleSplashView.transform = CGAffineTransformMakeRotation(2.0 * M_PI / 2.0);
		refTitleSplashView.frame = CGRectMake(50, 195, 220, 70);
	} else {// if(interfaceOrientation == UIInterfaceOrientationPortrait) {
		refTitleSplashView.transform = CGAffineTransformIdentity;
		refTitleSplashView.frame = CGRectMake(50, 195, 220, 70);
	}
	
	UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	[mainWindow addSubview:refTitleSplashView];

	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.5]; // animation duration in seconds
	[UIView setAnimationBeginsFromCurrentState:YES];
	refTitleSplashView.alpha = 0.7;
	[UIView commitAnimations];
	
	[refTitleSplashView release];
	refTitleSplashTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(removeTitle:) userInfo:nil repeats:NO];
	//[self performSelector:@selector(removeTitle) withObject:nil afterDelay:1.5];
}


- (void) removeTitleEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[refTitleSplashView removeFromSuperview];
	refTitleSplashView = nil;
}



- (void)removeTitle:(NSTimer*)theTimer {
	refTitleSplashTimer = nil;
	if(refTitleSplashView) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationDidStopSelector:@selector(removeTitleEnded:finished:context:)];
		refTitleSplashView.alpha = 0.0;
		[UIView commitAnimations];
	}
}

- (void)startAnimateChapterChange
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[toolbarLock lock];
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[bibleActivity startAnimating];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[commentaryActivity startAnimating];
	}
	[toolbarLock unlock];
	[pool release];
}

- (void)stopAnimateChapterChange
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[toolbarLock lock];
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[bibleActivity stopAnimating];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[commentaryActivity stopAnimating];
	}
	[toolbarLock unlock];
	[pool release];
}

- (void)redisplayChapterWithDefaults {
	NSString *ref = [PSModuleController getCurrentBibleRef];
	[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
}

- (void)redisplayBibleChapter {
	//[bibleTitle setTitle: NSLocalizedString(@"None", @"None")];
	[self redisplayChapter:BibleViewPoll restore:RestoreVersePosition];
}

- (void)redisplayCommentaryChapter {
	//[commentaryTitle setTitle: NSLocalizedString(@"None", @"None")];
	[self redisplayChapter:CommentaryViewPoll restore:RestoreVersePosition];
}

- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position {
	NSString *ref = [PSModuleController getCurrentBibleRef];
	[self displayChapter:ref withPollingType:pollingType restoreType:position];
}

- (void)displayChapter:(NSString *)ref withPollingType:(PollingType)polling restoreType:(RestorePositionType)position {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

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
				[commentaryJavascript appendFormat:@"scrollToVerse(%@);\n", versePosition];
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
			[bibleWebView loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
			//NSLog(@"%@", bText);
			commentaryTabController.refToShow = ref;
			commentaryTabController.jsToShow = commentaryJavascript;
		}
			break;
		case CommentaryViewPoll:
		{
			[commentaryJavascript appendString:@"startDetLocPoll();\n"];
			NSString *cText = [[PSModuleController defaultModuleController] getCommentaryChapter:ref withExtraJS:commentaryJavascript];
			[commentaryWebView loadHTMLString: cText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
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
	if([[PSModuleController defaultModuleController] primaryCommentary]) {
		[self setTabTitle: titleString ofTab:CommentaryTab];
	}
	
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if ([currentRef isEqualToString: lastRefAvailable]) {
		[self setEnabledBibleNextButton: NO];
		[self setEnabledBiblePreviousButton: YES];
		[self setEnabledCommentaryNextButton: NO];
		[self setEnabledCommentaryPreviousButton: YES];
	} else if ([currentRef isEqualToString: firstRefAvailable]) {
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
	
	[pool release];
}

// Use this to show the modal view (pops-up from the bottom)
// try a time of 0.7 to start with...
+ (void) showModal:(UIView*)modalView withTiming:(float)time
{
	UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	
	CGSize modalSize = modalView.bounds.size;
	//CGPoint middleCenter = modalView.center;
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGFloat width, height;
	CGPoint offScreenCenter, middleCenter;
	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if([UIApplication sharedApplication].statusBarHidden) {
		interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
	}
	if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		offScreenCenter = CGPointMake(offSize.height - (offSize.height * 1.5), offSize.height / 2.0);
		middleCenter = CGPointMake((modalSize.height / 2.0), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		offScreenCenter = CGPointMake((offSize.height * 1.5), offSize.height / 2.0);
		middleCenter = CGPointMake(offSize.width - (modalSize.height / 2.0), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height - (offSize.height * 1.5));
		middleCenter = CGPointMake(modalSize.width / 2.0, (modalSize.height / 2.0));
	} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
		width = offSize.width;
		height = offSize.height;
		offScreenCenter = CGPointMake(width / 2.0, height * 1.5);
		middleCenter = CGPointMake(modalSize.width / 2.0, height - (modalSize.height / 2.0));
	} else {
		ALog(@"ERROR");
	}
	modalView.center = offScreenCenter; // we start off-screen
	[mainWindow addSubview:modalView];
	
	// Show it with a transition effect
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:time]; // animation duration in seconds
	modalView.center = middleCenter;
	[UIView commitAnimations];
}

- (void) showInfoModal:(UIView*)modalView withTiming:(float)time
{
	UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	
	CGSize modalSize = modalView.bounds.size;
	//CGPoint middleCenter = modalView.center;
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGFloat width, height;
	CGPoint offScreenCenter, middleCenter;
	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if([UIApplication sharedApplication].statusBarHidden) {
		interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
		if(bibleTabController.isFullScreen) {
			interfaceOrientation = bibleTabController.interfaceOrientation;
		} else if(commentaryTabController.isFullScreen) {
			interfaceOrientation = commentaryTabController.interfaceOrientation;
		}
	}
	if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		offScreenCenter = CGPointMake(offSize.height - (offSize.height * 1.5), offSize.height / 2.0);
		middleCenter = CGPointMake((modalSize.height / 2.0), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		offScreenCenter = CGPointMake((offSize.height * 1.5), offSize.height / 2.0);
		middleCenter = CGPointMake(offSize.width - (modalSize.height / 2.0), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height - (offSize.height * 1.5));
		middleCenter = CGPointMake(modalSize.width / 2.0, (modalSize.height / 2.0));
	} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
		width = offSize.width;
		height = offSize.height;
		offScreenCenter = CGPointMake(width / 2.0, height * 1.5);
		middleCenter = CGPointMake(modalSize.width / 2.0, height - (modalSize.height / 2.0));
	} else {
		ALog(@"ERROR");
	}
	modalView.center = offScreenCenter; // we start off-screen
	[mainWindow addSubview:modalView];
	
	// Show it with a transition effect
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:time]; // animation duration in seconds
	modalView.center = middleCenter;
	[UIView commitAnimations];
}

// Use this to slide the semi-modal view back down.
+ (void) hideModal:(UIView*) modalView withTiming:(float)time
{
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if([UIApplication sharedApplication].statusBarHidden) {
		interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];;
	}
	//UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		offScreenCenter = CGPointMake(offSize.height - (offSize.height * 1.5), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		offScreenCenter = CGPointMake((offSize.height * 1.5), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height - (offSize.height * 1.5));
	}
	[UIView beginAnimations:nil context:modalView];
	[UIView setAnimationDuration:time];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDidStopSelector:@selector(hideModalEnded:finished:context:)];
	modalView.center = offScreenCenter;
	[UIView commitAnimations];
}

- (void) hideInfoModal:(UIView*) modalView withTiming:(float)time
{
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if([UIApplication sharedApplication].statusBarHidden) {
		interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];;
		if(bibleTabController.isFullScreen) {
			interfaceOrientation = bibleTabController.interfaceOrientation;
		} else if(commentaryTabController.isFullScreen) {
			interfaceOrientation = commentaryTabController.interfaceOrientation;
		}
	}
	//UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		offScreenCenter = CGPointMake(offSize.height - (offSize.height * 1.5), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		offScreenCenter = CGPointMake((offSize.height * 1.5), offSize.height / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height - (offSize.height * 1.5));
	}
	[UIView beginAnimations:nil context:modalView];
	[UIView setAnimationDuration:time];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDidStopSelector:@selector(hideInfoModalEnded:finished:context:)];
	modalView.center = offScreenCenter;
	[UIView commitAnimations];
}

+ (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	UIView* modalView = (UIView *)context;
	[modalView removeFromSuperview];
}

- (void) hideInfoModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	UIView* modalView = (UIView *)context;
	[modalView removeFromSuperview];
}

// Use this to slide the semi-modal view back down.
+ (void) hideModalAndRelease:(UIView*) modalView withTiming:(float)time
{
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
	[UIView beginAnimations:nil context:modalView];
	[UIView setAnimationDuration:time];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDidStopSelector:@selector(hideModalAndReleaseEnded:finished:context:)];
	modalView.center = offScreenCenter;
	[UIView commitAnimations];
}

+ (void) hideModalAndReleaseEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	UIView* modalView = (UIView *)context;
	[modalView removeFromSuperview];
	[modalView release];
}

- (void)displayBusyIndicatorViaNotification {
	[self performSelectorInBackground: @selector(displayBusyIndicator) withObject: nil];
}

- (void)displayBusyIndicator {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if([UIApplication sharedApplication].statusBarHidden) {
		interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];;
	}
	
	if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		activityLoadingLabel.transform = CGAffineTransformIdentity;
		activityLoadingLabel.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
		activityLoadingLabel.transform = CGAffineTransformIdentity;
		activityLoadingLabel.transform = CGAffineTransformMakeRotation(3.0 * M_PI / 2.0);
	} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
		activityLoadingLabel.transform = CGAffineTransformIdentity;
	} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		activityLoadingLabel.transform = CGAffineTransformIdentity;
		activityLoadingLabel.transform = CGAffineTransformMakeRotation(2.0 * M_PI / 2.0);
	}

	
	UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	[activityIndicator startAnimating];
	//[tabController presentModalViewController:activityController animated:NO];
	activityController.view.alpha = 0.0;
	[mainWindow addSubview:activityController.view];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	[UIView setAnimationDuration:0.3];
	activityController.view.alpha = 0.5;
	[UIView commitAnimations];
	
	[pool release];
}

- (void)_hideBusyIndicator {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	if (activityIndicator) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
		activityController.view.alpha = 0.0;
		[UIView commitAnimations];
		//[tabController dismissModalViewControllerAnimated:NO];
		//[activityIndicator stopAnimating];
	}
	
	[pool release];
}

- (void)hideBusyIndicator {
	[self _hideBusyIndicator];
	[self performSelector:@selector(_hideBusyIndicator) withObject:nil afterDelay:1];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[activityIndicator stopAnimating];
	[activityController.view removeFromSuperview];
}

- (void)highlightSearchTerm:(NSString*)term forTab:(ShownTab)tab {
	switch(tab) {
		case BibleTab:
			[bibleWebView highlightAllOccurencesOfString: term];
			break;
		case CommentaryTab:
			[commentaryWebView highlightAllOccurencesOfString: term];
			break;
	}
}

- (void)showInfoWithNotification:(NSNotification *)notification {
	if(notification) {
		[self showInfo:[notification object]];
	}
}

- (void)showInfo:(NSString *)infoString {
	if(![infoView superview]) {
		//need to show the info pane
		CGSize screen = [[UIScreen mainScreen] bounds].size;
		UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;//tabController.interfaceOrientation;
		if([UIApplication sharedApplication].statusBarHidden) {
			//we are in fullscreen mode in the Bible or Commentary tab.
			interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
			if(bibleTabController.isFullScreen) {
				interfaceOrientation = bibleTabController.interfaceOrientation;
			} else if(commentaryTabController.isFullScreen) {
				interfaceOrientation = commentaryTabController.interfaceOrientation;
			}
			//interfaceOrientation = tabController.interfaceOrientation;
//			if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
//				interfaceOrientation = UIInterfaceOrientationLandscapeRight;
//			if(interfaceOrientation == UIInterfaceOrientationLandscapeRight)
//				interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
		}
		if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
			infoView.transform = CGAffineTransformIdentity;
			infoView.frame = CGRectMake(0, 0, screen.height, INFO_LANDSCAPE_HEIGHT);
			infoView.transform = CGAffineTransformMakeRotation(3.0 * M_PI / 2.0);
		} else if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
			infoView.transform = CGAffineTransformIdentity;
			infoView.frame = CGRectMake(0, 0, screen.height, INFO_LANDSCAPE_HEIGHT);
			infoView.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
		} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
			infoView.transform = CGAffineTransformIdentity;
			infoView.frame = CGRectMake(0, 0, screen.width, INFO_PORTRAIT_HEIGHT);
		} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
			infoView.transform = CGAffineTransformIdentity;
			infoView.transform = CGAffineTransformMakeRotation(2.0 * M_PI / 2.0);
			infoView.frame = CGRectMake(0, 0, screen.width, INFO_PORTRAIT_HEIGHT);
		}
		[self showInfoModal: infoView withTiming: 0.3];
	}
//	NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsFontNamePreference];
//	[[NSUserDefaults standardUserDefaults] setObject:StrongsFontName forKey:DefaultsFontNamePreference];
//	[[NSUserDefaults standardUserDefaults] synchronize];

	//NSLog(@"%@", infoString);

	//NSString *htmlString = [PSModuleController createHTMLString: infoString usingPreferences:YES withJS: @"<script type=\"text/javascript\">\n<!--\n document.documentElement.style.webkitTouchCallout = \"none\";\n-->\n</script>" usingModuleForPreferences:blah];
	//NSString *htmlString = [PSModuleController createInfoHTMLString: infoString usingModuleForPreferences:blah];

//	[[NSUserDefaults standardUserDefaults] setObject:fontName forKey:DefaultsFontNamePreference];
//	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[infoWebView loadHTMLString: infoString baseURL: nil];
	
}

- (void)rotateInfo:(NSNotification *)notification {
	//DLog(@"rotateInfo");
	if([infoView superview]) {//only rotate if it's displayed!
		[UIView beginAnimations:@"rotateInfo" context:nil];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationDuration:0.3];
		
		CGSize screen = [[UIScreen mainScreen] bounds].size;
		UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;//tabController.interfaceOrientation;
		if([UIApplication sharedApplication].statusBarHidden) {
			//interfaceOrientation = tabController.interfaceOrientation;
			interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
		}
		CGFloat x,y;
		if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
			infoView.transform = CGAffineTransformIdentity;
			x = 0.5 * INFO_LANDSCAPE_HEIGHT - 20;
			y = (0.5 * screen.height) - (0.5 * INFO_LANDSCAPE_HEIGHT);
			infoView.frame = CGRectMake(x, y, screen.height, INFO_LANDSCAPE_HEIGHT);
			infoView.transform = CGAffineTransformMakeRotation(3.0 * M_PI / 2.0);
		} else if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
			infoView.transform = CGAffineTransformIdentity;
			x = 0.5 * INFO_LANDSCAPE_HEIGHT - 0.5 * screen.height;
			y = (0.5 * screen.height) - (0.5 * INFO_LANDSCAPE_HEIGHT);
			infoView.frame = CGRectMake(x, y, screen.height, INFO_LANDSCAPE_HEIGHT);
			infoView.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
		} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
			infoView.transform = CGAffineTransformIdentity;
			infoView.frame = CGRectMake(0, (screen.height - INFO_PORTRAIT_HEIGHT), screen.width, INFO_PORTRAIT_HEIGHT);
		} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
			infoView.transform = CGAffineTransformIdentity;
			infoView.frame = CGRectMake(0, 0, screen.width, INFO_PORTRAIT_HEIGHT);
			infoView.transform = CGAffineTransformMakeRotation(2.0 * M_PI / 2.0);
		}
		
		[UIView commitAnimations];
	}
}

- (IBAction)hideInfo {
	[self hideInfoModal: infoView withTiming: 0.3];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	//NSLog(@"  Info Pane: requestString: %@", [[request URL] absoluteString]);
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;
	
	if([[[request URL] scheme] isEqualToString:@"bible"]) {
		//our internal reference to say this is a Bible verse to display in the Bible tab
		if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
			//error checking, should always get here...
			[self setShownTabTo:BibleTab];
			[dictionaryViewController dismissModalViewControllerAnimated:YES];
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
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
			[HistoryController addHistoryItem:BibleTab];

			return NO;
		}
	}
	
	if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
		//
		// it's a dictionary entry to show.
		//
		NSString *mod = [rData objectForKey:ATTRTYPE_MODULE];
		
		SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
		if(swordDictionary) {
			entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];
			//DLog(@"\n%@ = %@\n", mod, entry);
		} else {
			entry = [NSString stringWithFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ %@</p>", mod, NSLocalizedString(@"ModuleNotInstalled", @"is not installed.")];
		}

		NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsFontNamePreference];
		[[NSUserDefaults standardUserDefaults] setObject:StrongsFontName forKey:DefaultsFontNamePreference];
		[[NSUserDefaults standardUserDefaults] synchronize];
		entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:mod];
		[[NSUserDefaults standardUserDefaults] setObject:fontName forKey:DefaultsFontNamePreference];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
	}
	
	if(entry) {
		[self showInfo: entry];
		load = NO;
	}
	
	[pool release];
	return load; // Return YES to make sure regular navigation works as expected.
	
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
		case DownloadsTab:
		{
			for(UIViewController *uivc in tabController.viewControllers) {
				if([uivc isKindOfClass:[NavigatorSources class]]) {
					tabController.selectedViewController = uivc;
					break;
				}
			}
		}
			break;
		case PreferencesTab:
		{
			for(UIViewController *uivc in tabController.viewControllers) {
				if([uivc isKindOfClass:[PSPreferencesController class]]) {
					tabController.selectedViewController = uivc;
					break;
				}
			}
		}
			break;
	}
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end

@implementation PSLoadingViewController

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}


@end

@implementation PSWebView

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFullscreenModePreference]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationSwitchToFullscreen object:nil];
	}
	[super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

@end