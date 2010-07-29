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

#import "ViewController.h"
//#import <dlfcn.h> -- needed for the loadFonts() code, but it doesn't currently work!
#import "PSIndexController.h"
#import "SearchWebView.h"
#import "HistoryController.h"
#import "NavigatorSources.h"


@implementation ViewController

//int percent;
bool initialized = false, waitingForInstall = false;

NSTimer *timer;
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

- (void)showDownloadStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[statusTitle setText: NSLocalizedString(@"Module Download", @"Module Download")];
	[statusOverallText setText: @""];
	NSString *sText = [NSString stringWithFormat: @"%@", NSLocalizedString(@"Installing", @"Installing")] ;
	
	[statusOverallBar setHidden: NO];
	[statusText setText: sText];
	[statusText setLineBreakMode: UILineBreakModeWordWrap];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	[navController setNavigationBarHidden: YES];
	
	[tabController presentModalViewController: navController animated: YES];
	
	[pool release];
}

/*- (void)runInstallation {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[[moduleManager swordInstallManager] resetInstallationProgress];
	
	[self performSelectorInBackground: @selector(showDownloadStatus) withObject: nil];
	
	[moduleManager setCurrentInstallSource:[[[moduleManager swordInstallManager] installSourceList] objectAtIndex: installModuleInstallSource]];
	[moduleManager performSelectorInBackground: @selector(installModule:) withObject: installModule];
	[self updateInstallationStatus];
	
	[pool release];
}*/

- (void)updateInstallationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	PSStatusReporter *reporter = [moduleManager getInstallationProgress];
	BOOL failed = YES;
	float progress = reporter->overallProgress;
	[statusBar setProgress: reporter->fileProgress];
	[statusOverallBar setProgress: reporter->overallProgress];
	NSString *desc = [[[NSString alloc] initWithCString: reporter->getDescription() encoding: [NSString defaultCStringEncoding]] autorelease];
	//DLog(@"%@", desc);
	NSRange dataRange = [desc rangeOfString: @")"];
	if(dataRange.location != NSNotFound) {
		desc = [NSString stringWithFormat: @"%@ %@)", [desc substringToIndex: dataRange.location], NSLocalizedString(@"files", @"files")];
	}
	//DLog(@"%@", desc);
	[statusOverallText setText: desc];
	
	//DLog(@"updateInstallationStatus: Progress: %f", progress);
	
	if (progress == 1.0) {
		[moduleManager reload];
		//[moduleTable reloadData];
		//[downloadableModulesTable reloadData];
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		failed = NO;
	}
	else if (progress == -1.0) {
		failed = YES;
	} else {
		failed = NO;
	}
	if (failed) {
		[moduleManager reload];
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		//[moduleTable reloadData];
		[[[UIAlertView alloc] initWithTitle: @"Error" message: @"A problem occurred during the installation."
								   delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil] show];		
	}
	[pool release];
}

- (void)hideIndexStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[ViewController hideModal: statusController.view withTiming:0.3];
	[statusText setText: @""];
	[statusOverallText setText: @""];
	[statusBar setProgress: 0.0];
	[statusOverallBar setProgress: 0.0];
	[pool release];
}

- (void)hideOperationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[tabController dismissModalViewControllerAnimated: YES];
	[timer invalidate];
	
	[statusText setText: @""];
	[statusOverallText setText: @""];
	[statusBar setProgress: 0.0];
	[statusOverallBar setProgress: 0.0];
	[pool release];
}

- (void)installIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[self performSelectorInBackground: @selector(showDownloadStatus) withObject: nil];
	
	[moduleManager performSelectorInBackground: @selector(installSearchIndex) withObject: nil];
	[self updateInstallationStatus];
	
	[pool release];
}

- (void)showIndexStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[statusTitle setText: NSLocalizedString(@"IndexDownloadTitle", @"Index Download")]; 
	[statusText setText: @""];
	[statusOverallBar setHidden: YES];
	//UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	//[navController setNavigationBarHidden: YES];
	
	//[tabController presentModalViewController: navController animated: YES];
	[ViewController showModal: statusController.view withTiming:0.3];
	
	[pool release];
}

- (void)updateIndexInstallationStatus:(NSString*)arg {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	//[statusBar setProgress: reporter->fileProgress];
	float p = [arg floatValue];
	[statusBar setProgress: p];
	[pool release];
}

//
// UIAlertView delegate method
//
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//DLog(@"Clicked button %d", buttonIndex);
	if (buttonIndex == 1 && waitingForInstall) {
		DLog(@"alertView: didDismissWithButtonIndex: -- waitingForInstall");
		waitingForInstall = false;
		[self performSelectorInBackground: @selector(runInstallation) withObject: nil];
		
		SEL method = @selector(updateInstallationStatus);
		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
		[invocation setTarget: self];
		[invocation setSelector: method];
		
		timer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
	}
	else if (buttonIndex == 1) {
		DLog(@"alertView: didDismissWithButtonIndex: -- installIndex??!!??");
		//percent = 0;
		[self performSelectorInBackground: @selector(installIndex) withObject: nil];
		
		SEL method = @selector(updateInstallationStatus);
		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
		[invocation setTarget: self];
		[invocation setSelector: method];
		
		timer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
	}
	
	[pool release];
}

- (void)setTabTitle:(NSString *)newTitle ofTab:(ShownTab)tab
{
	[toolbarLock lock];
	NSString *titleToDisplay = [PSModuleController createTitleRefString:newTitle];
	
	if(tab == BibleTab) {
		//[bibleNavBtn setTitle: newTitle];
		[bibleSegmentedControl setTitle: titleToDisplay forSegmentAtIndex: 1];
	} else if(tab == CommentaryTab) {
		//[commentaryNavBtn setTitle: newTitle];
		[commentarySegmentedControl setTitle: titleToDisplay forSegmentAtIndex: 1];
	}
	[toolbarLock unlock];
}

- (void)setEnabledBibleNextButton:(BOOL)enabled
{
	[bibleSegmentedControl setEnabled: enabled forSegmentAtIndex: 2];
	//[bibleNextBtn setEnabled: enabled];
}

- (void)setEnabledCommentaryNextButton:(BOOL)enabled
{
	[commentarySegmentedControl setEnabled: enabled forSegmentAtIndex: 2];
	//[commentaryNextBtn setEnabled: enabled];
}

- (void)setEnabledBiblePreviousButton:(BOOL)enabled
{
	[bibleSegmentedControl setEnabled: enabled forSegmentAtIndex: 0];
	//[biblePrevBtn setEnabled: enabled];
}

- (void)setEnabledCommentaryPreviousButton:(BOOL)enabled
{
	[commentarySegmentedControl setEnabled: enabled forSegmentAtIndex: 0];
	//[commentaryPrevBtn setEnabled: enabled];
}

- (IBAction)segmentedControlAction:(id)sender
{
	UISegmentedControl *segControl = sender;
	switch (segControl.selectedSegmentIndex)
	{
		case 0:	// previous
		{
			//
			[self prevChapter: sender];
			break;
		}
		case 1: // Ref
		{
			[self toggleNavigation: sender];
			break;
		}
		case 2:	// next
		{
			[self nextChapter: sender];
			break;
		}
	}
}

- (void)awakeFromNib {
	if (!initialized) {
		toolbarLock = [[NSLock alloc] init];
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		//localize the tab bar titles
		bibleTabBarItem.title = NSLocalizedString(@"TabBarTitleBible", @"Bible");
		commentaryTabBarItem.title = NSLocalizedString(@"TabBarTitleCommentary", @"Commentary");
		dictionaryTabBarItem.title = NSLocalizedString(@"TabBarTitleDictionary", @"Dictionary");
		preferencesTabBarItem.title = NSLocalizedString(@"TabBarTitlePreferences", @"Preferences");
		aboutTabBarItem.title = NSLocalizedString(@"TabBarTitleAbout", @"About");
		devotionalTabBarItem.title = NSLocalizedString(@"TabBarTitleDevotional", @"Devotional");
		
		activityLoadingLabel.text = NSLocalizedString(@"ActivityLabelLoading", @"Loading...");
		// and the titles of each tab
		historyCloseButton.title = NSLocalizedString(@"CloseButtonTitle", @"Close");
		
		//configure the Bible & commentary segmented controls.
		[bibleSegmentedControl setWidth: 50  forSegmentAtIndex:0];
		[bibleSegmentedControl setWidth: 78 forSegmentAtIndex:1];
		[bibleSegmentedControl setWidth: 50  forSegmentAtIndex:2];
		[bibleSegmentedControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
		[commentarySegmentedControl setWidth: 50  forSegmentAtIndex:0];//30
		[commentarySegmentedControl setWidth: 78 forSegmentAtIndex:1];//138
		[commentarySegmentedControl setWidth: 50  forSegmentAtIndex:2];//30
		[commentarySegmentedControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
		
		NSString *black = @"<html><body bgcolor=\"black\">@nbsp;</body></html>";
		[bibleWebView loadHTMLString: black baseURL: nil];
		[commentaryWebView loadHTMLString: black baseURL: nil];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		NSString *lastRef = [moduleManager getCurrentBibleRef];
		
		[self displayChapter:lastRef withPollingType:BibleViewPoll restoreType:RestoreScrollPosition];
		
		if ([[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] count] == 0) {
			[self setTabTitle: @"PocketSword" ofTab:BibleTab];
			//[bibleNavBtn setTitle: @"PocketSword"];
		}
		if ([[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES] count] == 0) {
			[self setTabTitle: @"PocketSword" ofTab:CommentaryTab];
			//[commentaryNavBtn setTitle: @"PocketSword"];
		}
		
		if ([defaults boolForKey: @"insomniaPreference"]) {
			UIApplication *thisApp = [UIApplication sharedApplication];
			thisApp.idleTimerDisabled = YES;
		}
		tabController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
		tabController.delegate = self;
		tabController.customizableViewControllers = nil;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter:) name:NotificationBibleSwipeRight object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter:) name:NotificationCommentarySwipeRight object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nextChapter:) name:NotificationBibleSwipeLeft object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nextChapter:) name:NotificationCommentarySwipeLeft object:nil];

		[pool release];
		initialized = true;
	}
	
}

//- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
//	tabBarController.moreNavigationController.navigationBar.topItem.rightBarButtonItem = nil;
//	DLog(@"\nRemoving Edit button");
//}

// Loads the next chapter into the Web View
- (IBAction)nextChapter:(id)sender {
//	if (([[bibleNavBtn title] isEqualToString: @"PocketSword"] && [[commentaryNavBtn title] isEqualToString: @"PocketSword"]) || [[moduleManager getCurrentBibleRef] isEqualToString: @"Revelation 22"]) {
//		return;
//	}
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];
	
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		NSString *ref = [moduleManager setToNextChapter];
		if(ref) {
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreNoPosition];
			[self addHistoryItem: BibleTab];
		}
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// commentary tab
		NSString *ref = [moduleManager setToNextChapter];
		if(ref) {
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreNoPosition];
			[self addHistoryItem: CommentaryTab];
		}
	} else {
		// weird & undefined
		NSString *ref = [moduleManager setToNextChapter];
		if(ref)
			[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreNoPosition];
	}
	
	[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	[pool release];
}

// Loads the previous chapter into the Web View
- (IBAction)prevChapter:(id)sender {
//	if (([[bibleNavBtn title] isEqualToString: @"PocketSword"] && [[commentaryNavBtn title] isEqualToString: @"PocketSword"]) || [[moduleManager getCurrentBibleRef] isEqualToString: @"Genesis 1"]) {
//		return;
//	}
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];
	
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		NSString *ref = [moduleManager setToPreviousChapter];
		if(ref) {
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[self addHistoryItem: BibleTab];
		}
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// commentary tab
		NSString *ref = [moduleManager setToPreviousChapter];
		if(ref) {
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[self addHistoryItem: CommentaryTab];
		}
	} else {
		// weird & undefined
		NSString *ref = [moduleManager setToPreviousChapter];
		if(ref)
			[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
	}
	
	[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	[pool release];
}

- (IBAction)toggleMultiList:(id)sender
{
//	[self highlightSearchTerm: @"and" forTab: BibleTab];
	
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		[historyController setListType: BibleTab];
		historyNavigationItem.title = NSLocalizedString(@"BibleHistoryTitle", @"Bible History");
	} else {
		[historyController setListType: CommentaryTab];
		historyNavigationItem.title = NSLocalizedString(@"CommentaryHistoryTitle", @"Commentary History");
	}
	
	//if(multiListShown) {
	if([multiListController.view superview]) {
		[tabController dismissModalViewControllerAnimated:YES];
		//[ViewController hideModal:multiListController.view withTiming:0.3];
		//multiListShown = NO;
	} else {
		[historyListTable reloadData];
		if(([historyListTable numberOfSections] > 0) && [historyListTable numberOfRowsInSection: 0] > 0) {
			NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: 0];
			if(ip)
				[historyListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionTop animated:NO];
		}
		//[ViewController showModal:multiListController.view withTiming:0.3];
		[tabController presentModalViewController:multiListController animated:YES];
		//multiListShown = YES;
	}
	
}

- (IBAction)toggleModulesList:(id)sender
{
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		[moduleSelectorViewController setListType: BibleTab];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[moduleSelectorViewController setListType: CommentaryTab];
	} else if([devotionalWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[moduleSelectorViewController setListType: DevotionalTab];
	} else {
		[moduleSelectorViewController setListType: DictionaryTab];
	}
	
	//if(modulesListShown) {
	if([[moduleSelectorViewController view] superview]) {
		//[ViewController hideModal:modulesListView withTiming:0.3];
		//modulesListShown = NO;
		[tabController dismissModalViewControllerAnimated:YES];
//		if([devotionalWebView isDescendantOfView:tabController.selectedViewController.view]) {
//			devotionalWebView.frame = CGRectMake(0, 44, 320, 367);
//		}
	} else {
		NSIndexPath *ip = nil;//default value
		if([moduleSelectorViewController listType] == BibleTab) {
			[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_BIBLES, @"")];
			NSArray *array = [[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_BIBLES];
			int pos = 0;
			for(; pos < [array count]; pos++) {
				if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleManager primaryBible] name]]) {
					break;
				}
			}
			if (pos < [array count]) {
				ip = [NSIndexPath indexPathForRow: pos inSection: 0];
			}			
		} else if([moduleSelectorViewController listType] == CommentaryTab) {
			[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_COMMENTARIES, @"")];
			NSArray *array = [[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_COMMENTARIES];
			int pos = 0;
			for(; pos < [array count]; pos++) {
				if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleManager primaryCommentary] name]]) {
					break;
				}
			}
			if (pos < [array count]) {
				ip = [NSIndexPath indexPathForRow: pos inSection: 0];
			}
		} else if([moduleSelectorViewController listType] == DevotionalTab) {
			[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_DAILYDEVS, @"")];
			NSArray *array = [[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_DAILYDEVS];
			int pos = 0;
			for(; pos < [array count]; pos++) {
				if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleManager primaryDevotional] name]]) {
					break;
				}
			}
			if (pos < [array count]) {
				ip = [NSIndexPath indexPathForRow: pos inSection: 0];
			}
		} else {
			[modulesNavigationItem setTitle: NSLocalizedString(SWMOD_CATEGORY_DICTIONARIES, @"")];
			NSArray *array = [[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_DICTIONARIES];
			int pos = 0;
			for(; pos < [array count]; pos++) {
				if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleManager primaryDictionary] name]]) {
					break;
				}
			}
			if (pos < [array count]) {
				ip = [NSIndexPath indexPathForRow: pos inSection: 0];
			}			
		}
		[modulesListTable reloadData];
		if(ip)
			[modulesListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionMiddle animated:NO];
		//[ViewController showModal:modulesListView withTiming:0.3];
		[tabController presentModalViewController:moduleSelectorViewController animated:YES];
		//modulesListShown = YES;
	}
}

- (IBAction)addModuleButtonPressed {
	[self toggleModulesList:nil];
	for(UIViewController *uivc in tabController.viewControllers) {
		if([uivc isKindOfClass:[NavigatorSources class]]) {
			tabController.selectedViewController = uivc;
			break;
		}
	}
}

// Toggles the reference picker display
- (IBAction)toggleNavigation:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL showingBibleTab = NO;
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		if(![moduleManager primaryBible])
		   return;
		else
		   showingBibleTab = YES;
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view] && !([moduleManager primaryCommentary])) {
		// commentary tab
		return;
	}
//	ShownTab shownTab = (showingBibleTab) ? BibleTab : CommentaryTab;
	[refSelectorController toggleNavigation/*:shownTab*/];
	
	[pool release];
}

- (IBAction)updateViewWithSelectedChapter:(id)sender {
	NSInteger book = [refSelector selectedRowInComponent: 0];
	NSInteger chapter = [refSelector selectedRowInComponent: 1] + 1;
	NSInteger verse = [refSelector selectedRowInComponent: 2] + 1;

	[self toggleNavigation: nil];
	[self updateViewWithSelectedBook:book chapter:chapter verse:verse];
}

// Loads the chapter selected from the picker into the Web View
- (void)updateViewWithSelectedBook:(NSInteger)book chapter:(NSInteger)chapter verse:(NSInteger)verse {
	
	NSString *bookName = [refSelectorController bookName:book];
	[self updateViewWithSelectedBookName:bookName chapter:chapter verse:verse]; 
	
}

- (void)updateViewWithSelectedBookName:(NSString*)bookNameString chapter:(NSInteger)chapter verse:(NSInteger)verse {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
	NSString *bookName = [NSString stringWithCString:lmgr->translate([bookNameString cStringUsingEncoding:NSUTF8StringEncoding], "en") encoding:NSUTF8StringEncoding];
	NSString *verseString = [NSString stringWithFormat:@"%d", verse];
	NSString *ref = [bookName stringByAppendingFormat: @" %d", chapter];
	NSString *currentRef = [moduleManager getCurrentBibleRef];
	if([currentRef isEqualToString:ref]) {
		//we only need to move to the selected verse rather than reload the whole chapter
		NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", verseString];
		[bibleWebView stringByEvaluatingJavaScriptFromString:javascript];
		[commentaryWebView stringByEvaluatingJavaScriptFromString:javascript];
		if([moduleManager primaryBible]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:BibleTab];
		}
		if([moduleManager primaryCommentary]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:CommentaryTab];
		}
	}
	else
	{
		[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];
		
		if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
			// bible tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[self addHistoryItem: BibleTab];
		} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
			// commentary tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[self addHistoryItem: CommentaryTab];
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

// This should be called just AFTER:
//    "nextChapter".
//    or "prevChapter".
//    or navigation to a new ref from the refPicker.
//    or when the user selects a new module to view.
//    or when the user selects a bookmark.
//    or when the user selects a search result.
- (void)addHistoryItem:(ShownTab)tabForHistory
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *verse;
	NSString *scroll;
	NSString *mod;
	NSMutableArray *history;
	NSString *historyName;
	BOOL valid = NO;
	
	if(tabForHistory == BibleTab) {
		verse = [defaults stringForKey: DefaultsBibleVersePosition];
		scroll = [defaults stringForKey: @"bibleScrollPosition"];
		if([moduleManager primaryBible]) {
			valid = YES;
			mod = [[moduleManager primaryBible] name];
		}
		historyName = @"bibleHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else if(tabForHistory == CommentaryTab) {
		verse = [defaults stringForKey: DefaultsCommentaryVersePosition];
		scroll = [defaults stringForKey: @"commentaryScrollPosition"];
		if([moduleManager primaryCommentary]) {
			valid = YES;
			mod = [[moduleManager primaryCommentary] name];
		}
		historyName = @"commentaryHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else {
		ALog(@"\nWe don't know which tab we're on!  :(");
	}
	
	if(valid) {
		NSString *ref = [NSString stringWithFormat:@"%@:%@", [PSModuleController createRefString:[moduleManager getCurrentBibleRef]], verse];
		
		NSArray *historyItem = [NSArray arrayWithObjects: ref, scroll, mod, nil];
		
		if (!history) {
			history = [[NSMutableArray alloc] initWithObjects: nil];
			
			NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
			[prefs setObject: history forKey: historyName];
			
			[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
			[prefs release];
		}
		
		[history insertObject: historyItem atIndex: 0];
		//[historyItem release];
		if([history count] >= 50) {
			[history removeLastObject];
		}
		
		[defaults setObject: history forKey: historyName];
		[defaults synchronize];
	}
	if(history)
		[history release];
	
	[pool release];
	
}

- (void)removeHistoryItem:(NSString*)ref forTab:(ShownTab)tabForHistory {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *history;
	NSString *historyName;
	if(tabForHistory == BibleTab) {
		historyName = @"bibleHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else if(tabForHistory == CommentaryTab) {
		historyName = @"commentaryHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else {
		return;
	}
	
	for(NSArray *historyItem in history) {
		if([ref isEqualToString:[historyItem objectAtIndex:0]]) {
			[history removeObject:historyItem];
			break;
		}
	}
	[defaults setObject: history forKey: historyName];
	[defaults synchronize];
	[history release];
	
	[pool release];
}

//- (void)getRemoteModuleList {
//	[[moduleManager swordInstallManager] refreshAllInstallSources];
//}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	//[bibleWebView reload];
	DLog(@"Rotating");
	//NSString *text = [bibleWebView stringByEvaluatingJavaScriptFromString:@"document.documentElement.textContent"];
	//[bibleWebView loadHTMLString: @"foo" baseURL: nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	
}


- (void)dealloc {
	[toolbarLock release];
    [super dealloc];
}

- (void)startAnimateChapterChange
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[toolbarLock lock];
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
//		[bibleSearchButton setEnabled: NO];
		[bibleActivity startAnimating];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
//		[commentarySearchButton setEnabled: NO];
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
//		[bibleSearchButton setEnabled: YES];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[commentaryActivity stopAnimating];
//		[commentarySearchButton setEnabled: YES];
	}
	[toolbarLock unlock];
	[pool release];
}

- (void)redisplayChapter:(PollingType)pollingType restore:(RestorePositionType)position {
	NSString *ref = [moduleManager getCurrentBibleRef];
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
			NSString *bText = [moduleManager getBibleChapter:ref withExtraJS:bibleJavascript];
			[bibleWebView loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
			//NSLog(@"%@", bText);
			commentaryTabController.refToShow = ref;
			commentaryTabController.jsToShow = commentaryJavascript;
		}
			break;
		case CommentaryViewPoll:
		{
			[commentaryJavascript appendString:@"startDetLocPoll();\n"];
			NSString *cText = [moduleManager getCommentaryChapter:ref withExtraJS:commentaryJavascript];
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
//			NSString *bText = [moduleManager getBibleChapter:ref withExtraJS:bibleJavascript];
//			NSString *cText = [moduleManager getCommentaryChapter:ref withExtraJS:commentaryJavascript];
//			[bibleWebView loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];	// Get the chapter text
//			[commentaryWebView loadHTMLString: cText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		}
			break;
	}

//	NSString *bText = [moduleManager getBibleChapter:ref withExtraJS:bibleJavascript];
//	[bibleWebView loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
//	NSString *cText = [moduleManager getCommentaryChapter:ref withExtraJS:commentaryJavascript];
//	[commentaryWebView loadHTMLString: cText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
	
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
	
	
	NSString *titleString = [PSModuleController createRefString:ref];
	if([moduleManager primaryBible]) {
		[self setTabTitle: [NSString stringWithFormat:@"%@:%@", titleString, versePosition] ofTab:BibleTab];
	}
	if([moduleManager primaryCommentary]) {
		[self setTabTitle: [NSString stringWithFormat:@"%@:%@", titleString, versePosition] ofTab:CommentaryTab];
	}
	
	if ([[moduleManager getCurrentBibleRef] isEqualToString: lastRefAvailable]) {
		[self setEnabledBibleNextButton: NO];
		[self setEnabledBiblePreviousButton: YES];
		[self setEnabledCommentaryNextButton: NO];
		[self setEnabledCommentaryPreviousButton: YES];
	} else if ([[moduleManager getCurrentBibleRef] isEqualToString: firstRefAvailable]) {
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
	//if we don't have any modules of that type, disable the buttons.
	if(![moduleManager primaryBible]) {
		[self setEnabledBibleNextButton: NO];
		[self setEnabledBiblePreviousButton: NO];
	}
	if(![moduleManager primaryCommentary]) {
		[self setEnabledCommentaryNextButton: NO];
		[self setEnabledCommentaryPreviousButton: NO];
	}
	
	[pool release];
}

/*NSUInteger loadFonts()
{
	NSUInteger newFontCount = 0;
	NSBundle *frameworkBundle = [NSBundle bundleWithIdentifier:@"com.apple.GraphicsServices"];
	const char *frameworkPath = [[frameworkBundle executablePath] UTF8String];
	if (frameworkPath) {
		void *graphicsServices = dlopen(frameworkPath, RTLD_NOLOAD | RTLD_LAZY);
		if (graphicsServices) {
			BOOL (*GSFontAddFromFile)(const char *) = dlsym(graphicsServices, "GSFontAddFromFile");
			if (GSFontAddFromFile)
				for (NSString *fontFile in [[NSBundle mainBundle] pathsForResourcesOfType:@"ttf" inDirectory:nil])
					newFontCount += GSFontAddFromFile([fontFile UTF8String]);
		}
	}
	return newFontCount;
}*/

// Use this to show the modal view (pops-up from the bottom)
// try a time of 0.7 to start with...
+ (void) showModal:(UIView*)modalView withTiming:(float)time
{
	UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	
	CGSize modalSize = modalView.bounds.size;
	//CGPoint middleCenter = modalView.center;
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGPoint middleCenter = CGPointMake(modalSize.width / 2.0, offSize.height - (modalSize.height / 2.0));
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
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
	[UIView beginAnimations:nil context:modalView];
	[UIView setAnimationDuration:time];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(hideModalEnded:finished:context:)];
	modalView.center = offScreenCenter;
	[UIView commitAnimations];
}

+ (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	UIView* modalView = (UIView *)context;
	[modalView removeFromSuperview];
	//[modalView release];
}

// Use this to slide the semi-modal view back down.
+ (void) hideModalAndRelease:(UIView*) modalView withTiming:(float)time
{
	CGSize offSize = [UIScreen mainScreen].bounds.size;
	CGPoint offScreenCenter = CGPointMake(offSize.width / 2.0, offSize.height * 1.5);
	[UIView beginAnimations:nil context:modalView];
	[UIView setAnimationDuration:time];
	[UIView setAnimationDelegate:self];
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

- (void)displayBusyIndicator {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	[activityIndicator startAnimating];
	activityController.view.alpha = 0.0;
	[mainWindow addSubview:activityController.view];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	[UIView setAnimationDuration:0.3];
	activityController.view.alpha = 0.5;
	[UIView commitAnimations];
	
	[pool release];
}

- (void)hideBusyIndicator {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	if (activityIndicator) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
		activityController.view.alpha = 0.0;
		[UIView commitAnimations];
	}
	
	[pool release];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[activityIndicator stopAnimating];
	[activityController.view removeFromSuperview];
}

- (void)reloadModuleTable {
	[modulesListTable reloadData];
}

- (void)reloadDictionaryData {
	[dictionaryViewController reloadDictionaryData:YES];
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

- (UITabBarController *)tabController {
	return tabController;
}

//- (UIView *)modulesListView {
//	return modulesListView;
//}
//
- (void)showInfo:(NSString *)infoString {
	if(![infoView superview]) {
		//need to show the info pane
		[ViewController showModal: infoView withTiming: 0.3];
	}
	NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"fontNamePreference"];
	[[NSUserDefaults standardUserDefaults] setObject:StrongsFontName forKey:@"fontNamePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	NSString *htmlString = [PSModuleController createHTMLString: infoString withJS: @"<script type=\"text/javascript\">\n<!--\n document.documentElement.style.webkitTouchCallout = \"none\";\n-->\n</script>"];

	[[NSUserDefaults standardUserDefaults] setObject:fontName forKey:@"fontNamePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[infoWebView loadHTMLString: htmlString baseURL: nil];
	
	//NSLog(@"%@", infoString);
}

- (IBAction)hideInfo:(id)sender {
	[ViewController hideModal: infoView withTiming: 0.3];
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
			[self addHistoryItem: BibleTab];

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
	}
}

@end
