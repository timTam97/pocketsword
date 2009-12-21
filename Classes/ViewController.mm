/*
	PocketSword - a frontend for viewing SWORD project modules on the iPhone and iPod Touch
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

#import "ViewController.h"
//#import <dlfcn.h> -- needed for the loadFonts() code, but it doesn't currently work!
#import "PSIndexController.h"


@implementation ViewController

//int percent;
bool initialized = false, waitingForInstall = false;

NSTimer *timer;
BOOL refSelectorShown = NO;
BOOL modulesListShown = NO;
BOOL multiListShown = NO;

 
//- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
//	[searchBar resignFirstResponder];
//}
//
//- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	
//	[searchBar resignFirstResponder];
//	
//	// Check if we have a lucene search framework
//	sword::SWModule *primaryText = [moduleManager getPrimaryText];
//	sword::SWBuf dir = primaryText->getConfigEntry("AbsoluteDataPath");
//	char ch = dir.c_str()[strlen(dir.c_str())-1];
//	if ((ch != '/') && (ch != '\\'))
//		dir.append('/');
//	dir.append("lucene");
//	char isIndexed = sword::FileMgr::existsFile(dir.c_str(), "segments");
//	if (isIndexed != 1) {
//		[[[UIAlertView alloc] initWithTitle: @"Error" message: @"You must download an index before you can search this module. Would you like to download it it now?"
//								   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
//		
//	}
//	[dataController performSearch: [searchBar text]];
//	[resultsTable reloadData];
//	[pool release];
//}
 
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
		desc = [NSString stringWithFormat: @"%@ files)", [desc substringToIndex: dataRange.location]];
	}
	//DLog(@"%@", desc);
	[statusOverallText setText: desc];
	
	//DLog(@"updateInstallationStatus: Progress: %f", progress);
	
	if (progress == 1.0) {
		[dataController reloadModuleList];
		[moduleTable reloadData];
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
		[dataController reloadModuleList];
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		[moduleTable reloadData];
		[[[UIAlertView alloc] initWithTitle: @"Error" message: @"A problem occurred during the installation."
								   delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil] show];		
	}
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
	
	[statusTitle setText: @"Index Download"];
	[statusText setText: @"Installing"];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	[navController setNavigationBarHidden: YES];
	
	[tabController presentModalViewController: navController animated: YES];
	
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
	if(tab == BibleTab) {
		//[bibleNavBtn setTitle: newTitle];
		[bibleSegmentedControl setTitle: newTitle forSegmentAtIndex: 1];
	} else if(tab == CommentaryTab) {
		//[commentaryNavBtn setTitle: newTitle];
		[commentarySegmentedControl setTitle: newTitle forSegmentAtIndex: 1];
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
		moduleTabBarItem.title = NSLocalizedString(@"TabBarTitleModules", @"Modules");
		preferencesTabBarItem.title = NSLocalizedString(@"TabBarTitlePreferences", @"Preferences");
		aboutTabBarItem.title = NSLocalizedString(@"TabBarTitleAbout", @"About");
		
		activityLoadingLabel.text = NSLocalizedString(@"ActivityLabelLoading", @"Loading...");
		// and the titles of each tab
		moduleNavBar.title = NSLocalizedString(@"ModulesTitle", @"Modules");
		bookmarksNavBar.title = NSLocalizedString(@"BookmarksTitle", @"Bookmarks");
		
		
		//configure the Bible & commentary segmented controls.
		[bibleSegmentedControl setWidth: 30  forSegmentAtIndex:0];
		[bibleSegmentedControl setWidth: 138 forSegmentAtIndex:1];
		[bibleSegmentedControl setWidth: 30  forSegmentAtIndex:2];
		[bibleSegmentedControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
		[commentarySegmentedControl setWidth: 30  forSegmentAtIndex:0];
		[commentarySegmentedControl setWidth: 138 forSegmentAtIndex:1];
		[commentarySegmentedControl setWidth: 30  forSegmentAtIndex:2];
		[commentarySegmentedControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
		
		NSString *black = @"<html><body bgcolor=\"black\">@nbsp;</body></html>";
		[bibleWebView loadHTMLString: black baseURL: nil];
		[commentaryWebView loadHTMLString: black baseURL: nil];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		
		NSString *lastRef = [defaults stringForKey: @"lastRef"];
		if (lastRef == nil) {
			[defaults setPersistentDomain: [NSDictionary dictionaryWithObject: @"Genesis 1" forKey: @"lastRef"] forName: [[NSBundle mainBundle] bundleIdentifier]];
			lastRef = @"Genesis 1";
		}
		
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
	//	PSIndexController *ic = [[PSIndexController alloc] init];
	//	ic.moduleManager = self;
	//	[ic updateInstalledIndexListWithRemoteIndices:nil];
	//	[ic installSearchIndexForModule: @"KJV"];
	
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
	if([moduleTable isDescendantOfView: viewController.view] && ([[[moduleManager swordManager] modulesForType:SWMOD_CATEGORY_BIBLES] count] > 0)) {
		NSArray *array = [[[[moduleManager swordManager] moduleListByType] objectAtIndex: 0] moduleList];
		int pos = 0;
		for(; pos < [array count]; pos++) {
			if([[[array objectAtIndex: pos] name] isEqualToString: [[moduleManager primaryBible] name]]) {
				break;
			}
		}
		if (pos < [array count]) {
			NSIndexPath *ip = [NSIndexPath indexPathForRow: pos inSection: 0];
			[moduleTable reloadData];
			if(ip)
				[moduleTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionMiddle animated:NO];
		}
	} //else if([tabController.moreNavigationController.view isDescendantOfView:viewController.view]) {
		//this is (hopefully) the root More controller.
		//NSLog(@"RAAAHHH!");
		//viewController.navigationItem.rightBarButtonItem = nil;
	//}
	
}

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
		if(ref)
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreNoPosition];
		[self addHistoryItem: BibleTab];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// commentary tab
		NSString *ref = [moduleManager setToNextChapter];
		if(ref)
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreNoPosition];
		[self addHistoryItem: CommentaryTab];
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
		if(ref)
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreNoPosition];
		[self addHistoryItem: BibleTab];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// commentary tab
		NSString *ref = [moduleManager setToPreviousChapter];
		if(ref)
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreNoPosition];
		[self addHistoryItem: CommentaryTab];
	} else {
		// weird & undefined
		NSString *ref = [moduleManager setToPreviousChapter];
		if(ref)
			[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreNoPosition];
	}
	
	[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	[pool release];
}

//- (IBAction)moveToModulesTab:(id)sender
//{
//	if(refSelectorShown) {
//		[self toggleNavigation:sender];
//	}
//	[dataController setShownTabTo: ModuleTab];
//}
//
- (IBAction)toggleMultiList:(id)sender
{
//	PSIndexController *indexC = [[PSIndexController alloc] initWithNibName:@"IndexDownloader" bundle:nil];
//	[indexC setModuleManager:moduleManager];
//	[self showModal:indexC.view withTiming:0.7];
	
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		[dataController setListType: BibleTab];
		historyNavigationItem.title = NSLocalizedString(@"BibleHistoryTitle", @"Bible History");
	} else {
		[dataController setListType: CommentaryTab];
		historyNavigationItem.title = NSLocalizedString(@"CommentaryHistoryTitle", @"Commentary History");
	}
	
	if(multiListShown) {
		//[self hideModal:historyListView withTiming:0.7];
		[self hideModal:multiListController.view withTiming:0.3];
		multiListShown = NO;
	} else {
		[historyListTable reloadData];
		NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: 0];
		if(ip)
			[historyListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionTop animated:NO];
		[self showModal:multiListController.view withTiming:0.3];
		multiListShown = YES;
	}
	
}

- (IBAction)toggleModulesList:(id)sender
{
	if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
		// bible tab
		[moduleSelector setListType: BibleTab];
	} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
		[moduleSelector setListType: CommentaryTab];
	} else {
		[moduleSelector setListType: DictionaryTab];
	}
	
	if(modulesListShown) {
		[self hideModal:modulesListView withTiming:0.3];
		modulesListShown = NO;
	} else {
		NSIndexPath *ip = nil;//default value
		if([moduleSelector listType] == BibleTab) {
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
		} else if([moduleSelector listType] == BibleTab) {
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
			
		} else {
		}
		[modulesListTable reloadData];
		if(ip)
			[modulesListTable scrollToRowAtIndexPath: ip atScrollPosition: UITableViewScrollPositionMiddle animated:NO];
		[self showModal:modulesListView withTiming:0.3];
		modulesListShown = YES;
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
	
	if(refSelectorShown) {
		//hide the refSelector
		[self hideModal:refSelectorView withTiming:0.3];
		refSelectorShown = NO;
		[dataController setRefSelectorBooks: nil];
	} else {
		//show the refSelector
		if(showingBibleTab) {
			[refSelectorTitle setTitle:[[moduleManager primaryBible] name]];
		} else {
			[refSelectorTitle setTitle:[[moduleManager primaryCommentary] name]];
		}
		[dataController updateRefSelectorBooks];
		[self showModal:refSelectorView withTiming:0.3];
		refSelectorShown = YES;

		NSRange range = [[moduleManager getCurrentBibleRef] rangeOfCharacterFromSet: [NSCharacterSet whitespaceCharacterSet] options: NSBackwardsSearch];
		NSUInteger book = [dataController bookIndex: [[moduleManager getCurrentBibleRef] substringToIndex: range.location]];
		int chapter = 1;
		sscanf([[[[moduleManager getCurrentBibleRef] componentsSeparatedByString: @" "] lastObject] UTF8String], "%d", &chapter);
		--chapter;
		if (book != NSNotFound) {
			[refSelector selectRow: book inComponent: 0 animated: YES];
			//[dataController pickerView: refSelector didSelectRow: book inComponent: 0];
			[dataController setRefSelectorBook: book];
			[refSelector reloadComponent:1];
		}
		[refSelector reloadAllComponents];
		[refSelector selectRow: chapter inComponent: 1 animated: YES];
		//[dataController pickerView: refSelector didSelectRow: chapter inComponent: 1];
		[dataController setRefSelectorChapter: chapter+1];
		[refSelector reloadComponent:2];
		int verse = 1;
		if(showingBibleTab) {
			NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleVersePosition"];
			verse = [versePosition intValue];
			if(verse == 0)
				verse++;
		} else {
			NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"commentaryVersePosition"];
			verse = [versePosition intValue];
			if(verse == 0)
				verse++;
		}
		verse--;
		[refSelector selectRow: verse inComponent: 2 animated: YES];
	}

	[pool release];
}

// Loads the chapter selected from the picker into the Web View
- (IBAction)updateViewWithSelectedChapter:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//[moduleManager getPrimaryText];//call this to set it if it's not set yet
	NSInteger book = [refSelector selectedRowInComponent: 0];
	
	sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
	
	NSString *bookName = [NSString stringWithCString:lmgr->translate([[dataController bookName:book] cStringUsingEncoding:NSUTF8StringEncoding], "en") encoding:NSUTF8StringEncoding];
	
	NSInteger chapter = [refSelector selectedRowInComponent: 1] + 1;
	NSInteger verse = [refSelector selectedRowInComponent: 2] + 1;
	NSString *verseString = [NSString stringWithFormat:@"%d", verse];
	//NSString *ref = [[BOOKS objectAtIndex: book] stringByAppendingFormat: @" %d", chapter];
	NSString *ref = [bookName stringByAppendingFormat: @" %d", chapter];
	NSString *currentRef = [moduleManager getCurrentBibleRef];
	if([currentRef isEqualToString:ref]) {
		//we only need to move to the selected verse rather than reload the whole chapter
		NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", verseString];
		[bibleWebView stringByEvaluatingJavaScriptFromString:javascript];
		[commentaryWebView stringByEvaluatingJavaScriptFromString:javascript];
		if([moduleManager primaryBible]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:BibleTab];
			//[bibleNavBtn setTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString]];
		}
		if([moduleManager primaryCommentary]) {
			[self setTabTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString] ofTab:CommentaryTab];
			//[commentaryNavBtn setTitle: [NSString stringWithFormat:@"%@:%@", ref, verseString]];
		}
	}
	else
	{
		[self performSelectorInBackground: @selector(startAnimateChapterChange) withObject: nil];
		
		if([bibleWebView isDescendantOfView:tabController.selectedViewController.view]) {
			// bible tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: @"bibleVersePosition"];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: @"commentaryVersePosition"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[self addHistoryItem: BibleTab];
		} else if([commentaryWebView isDescendantOfView:tabController.selectedViewController.view]) {
			// commentary tab
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: @"bibleVersePosition"];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: @"commentaryVersePosition"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[self addHistoryItem: CommentaryTab];
		} else {
			//something tab???
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: @"bibleVersePosition"];
			[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: @"commentaryVersePosition"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
		}
		[self performSelectorInBackground: @selector(stopAnimateChapterChange) withObject: nil];
	}

	[self toggleNavigation: sender];
	
	[pool release];
}

- (IBAction)toggleModuleTableEditing:(id)sender {
	if ([moduleTable isEditing]) {
		[moduleTable setEditing: NO animated: YES];
		[moduleEditBtn setTitle: NSLocalizedString(@"Edit", @"Edit")];
		[moduleEditBtn setStyle: UIBarButtonItemStyleBordered];
	}
	else {
		[moduleEditBtn setTitle: NSLocalizedString(@"Done", @"Done")];
		[moduleEditBtn setStyle: UIBarButtonItemStyleDone];
		[moduleTable setEditing: YES animated: YES];
	}
}

- (IBAction)toggleBookmarksTableEditing:(id)sender {
	if ([bookmarksTable isEditing]) {
		[bookmarksTable setEditing: NO animated: YES];
		[bookmarksEditBtn setTitle: NSLocalizedString(@"Edit", @"Edit")];
		[bookmarksEditBtn setStyle: UIBarButtonItemStyleBordered];
	}
	else {
		[bookmarksEditBtn setTitle: NSLocalizedString(@"Done", @"Done")];
		[bookmarksEditBtn setStyle: UIBarButtonItemStyleDone];
		[bookmarksTable setEditing: YES animated: YES];
	}
}

// This should be called just AFTER:
//    "nextChapter".
//    or "prevChapter".
//    or navigation to a new ref from the refPicker.
//    or when the user selects a new module to view.
//    or when the user selects a bookmark.
- (IBAction)addHistoryItem:(ShownTab)tabForHistory
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
		verse = [defaults stringForKey: @"bibleVersePosition"];
		scroll = [defaults stringForKey: @"bibleScrollPosition"];
		if([moduleManager primaryBible]) {
			valid = YES;
			mod = [[moduleManager primaryBible] name];
		}
		historyName = @"bibleHistory";
		history = [[defaults arrayForKey: historyName] mutableCopy];
	} else if(tabForHistory == CommentaryTab) {
		verse = [defaults stringForKey: @"commentaryVersePosition"];
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
		NSString *ref = [NSString stringWithFormat:@"%@:%@", [moduleManager getCurrentBibleRef], verse];
		
		NSArray *historyItem = [NSArray arrayWithObjects: ref, scroll, mod, nil];
		
		if (history == nil) {
			history = [[NSMutableArray alloc] initWithObjects: nil];
			
			NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
			[prefs setObject: history forKey: historyName];
			
			[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
			[prefs release];
		}
		
		[history insertObject: historyItem atIndex: 0];
		//[historyItem release];
		if([history count] >= 15) {
			[history removeLastObject];
		}
		
		[defaults setObject: history forKey: historyName];
		[defaults synchronize];
	}
	if(history)
		[history release];
	
	[pool release];
	
}

- (IBAction)addBookmark:(id)sender {
	NSString *verse = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleVersePosition"];
	[dataController addBookmark: [NSString stringWithFormat:@"%@:%@", [moduleManager getCurrentBibleRef], verse]];
}

- (void)getRemoteModuleList {
	[[moduleManager swordInstallManager] refreshAllInstallSources];
}

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

/*
// Toggles the download source picker display
- (IBAction)toggleDownloadSource:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	// downloadSourceBtn;
	// downloadSourceSelector;
	// downloadSourcesToolbar;
	[downloadSourceSelector setHidden: ![downloadSourceSelector isHidden]];
	[downloadSourcesToolbar setHidden: [downloadSourceSelector isHidden]];
	
	if (![downloadSourceSelector isHidden]) {
		
		DLog(@"Showing the DownloadSourcePicker");
		[downloadSourceSelector selectRow: [dataController sourceInstallSourceView] inComponent: 0 animated: YES];
		//[refSelector reloadAllComponents];
		
	}
	
	[pool release];
}

- (IBAction)refreshDownloadSourcesList:(id)sender {
	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = YES;
	
	[[moduleManager swordInstallManager] refreshMasterRemoteInstallSourceList];
	[[moduleManager swordInstallManager] refreshAllInstallSources];
	//now have to refresh the download sources picker.
	application.networkActivityIndicatorVisible = NO;
	[downloadSourceSelector reloadAllComponents];
}

- (IBAction)refreshDownloadSource:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	//[downloadableModulesTable reloadData];

	[self performSelectorInBackground: @selector(runRefreshDownloadSource) withObject: nil];
	
	SEL method = @selector(updateRefreshStatus);
	NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setTarget: self];
	[invocation setSelector: method];
	
	timer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];

	[pool release];
}

- (void)runRefreshDownloadSource {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[[moduleManager swordInstallManager] resetInstallationProgress];

	[self performSelectorInBackground: @selector(showRefreshStatus) withObject: nil];

	SwordInstallSource *is = [[[moduleManager swordInstallManager] installSourceList] objectAtIndex: [dataController sourceInstallSourceView]];

	[[moduleManager swordInstallManager] performSelectorInBackground: @selector(refreshInstallSource:) withObject:is];
	//[[moduleManager swordInstallManager] refreshInstallSource: is];
	
	[self updateRefreshStatus];
	
	[pool release];
}

- (void)showRefreshStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	//[statusTitle setText: NSLocalizedString(@"Module Download", @"Module Download")];
	[statusTitle setText: @"Refreshing Module Source"];
	[statusOverallText setText: @""];
	//[statusBar setHidden: YES];
	[statusOverallBar setHidden: YES];
	//SwordInstallSource *is = [[[moduleManager swordInstallManager] installSourceList] objectAtIndex: [dataController sourceInstallSourceView]];
	//NSString *sText = [NSString stringWithFormat: @"Source: %@", [is caption]];
	
	[statusText setText: @""];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	[navController setNavigationBarHidden: YES];
	
	[tabController presentModalViewController: navController animated: YES];
	
	[pool release];
}

- (void)updateRefreshStatus {
	PSStatusReporter *reporter = [moduleManager getInstallationProgress];
	BOOL failed = YES;
	float progress = reporter->fileProgress;
	[statusBar setProgress: reporter->fileProgress];
	//[statusOverallBar setProgress: reporter->overallProgress];
	//NSString *desc = [[NSString alloc] initWithCString: reporter->getDescription() encoding: [NSString defaultCStringEncoding]];
	//[statusOverallText setText: desc];
	//[desc release];
	
	//DLog(@"updateRefreshStatus: Progress: %f", progress);
	
	if (progress == 1.0) {
		//[statusOverallText setText: @"Done!"];
		[dataController reloadModuleList];
		[moduleTable reloadData];
		[downloadableModulesTable reloadData];
		//[moduleManager init]; -- not needed now that we're using SwordManager
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		//[NSThread sleepForTimeInterval: 1.0];
		//[statusBar setHidden: NO];
		
		failed = NO;
	}
	else if (progress == -1.0) {
		failed = YES;
	} else {
		failed = NO;
	}
	if (failed) {
		[dataController reloadModuleList];
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		[moduleTable reloadData];
		[[[UIAlertView alloc] initWithTitle: @"Error" message: @"A problem occurred during the installation."
								   delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil] show];		
	}
}*/

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
	switch(polling) {
		case BibleViewPoll:
			[bibleJavascript appendString:@"startDetLocPoll();\n"];
			break;
		case CommentaryViewPoll:
			[commentaryJavascript appendString:@"startDetLocPoll();\n"];
			break;
		case NoViewPoll:
		default:
			break;
	}
	NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleVersePosition"];
	switch(position) {
		case RestoreScrollPosition:
		{
			NSString *scrollPosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleScrollPosition"];
			if(scrollPosition) {
				[bibleJavascript appendFormat:@"scrollToPosition(%@);", scrollPosition];
			}
			scrollPosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"commentaryScrollPosition"];
			if(scrollPosition) {
				[commentaryJavascript appendFormat:@"scrollToPosition(%@);", scrollPosition];
			}
		}
			break;
		case RestoreVersePosition:
		{
			if(versePosition) {
				[bibleJavascript appendFormat:@"scrollToVerse(%@);", versePosition];
				[commentaryJavascript appendFormat:@"scrollToVerse(%@);", versePosition];
			}
		}
			break;
		case RestoreNoPosition:
		default:
			break;
	}
	
	NSString *bText = [moduleManager getBibleChapter:ref withExtraJS:bibleJavascript];
	NSString *cText = [moduleManager getCommentaryChapter:ref withExtraJS:commentaryJavascript];
	[bibleWebView loadHTMLString: bText baseURL: nil];	// Get the chapter text
	[commentaryWebView loadHTMLString: cText baseURL: nil];
	
	NSString *cVersePosition = @"1";
	if(versePosition) {
		cVersePosition = [NSString stringWithString:versePosition];
	} else {
		versePosition = @"1";
	}
	switch(position) {
		case RestoreScrollPosition:
		{
			cVersePosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"commentaryVersePosition"];
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
	
	
	NSString *titleString = [[[[ref stringByReplacingOccurrencesOfString: @"III " withString: @"3 "] 
								stringByReplacingOccurrencesOfString: @"II " withString: @"2 "] 
							   stringByReplacingOccurrencesOfString: @"I " withString: @"1 "] 
							  stringByReplacingOccurrencesOfString: @" of John " withString: @" "];
	if([moduleManager primaryBible]) {
		[self setTabTitle: [NSString stringWithFormat:@"%@:%@", titleString, versePosition] ofTab:BibleTab];
		//[bibleNavBtn setTitle: [NSString stringWithFormat:@"%@:%@", titleString, versePosition]];
	}
	if([moduleManager primaryCommentary]) {
		[self setTabTitle: [NSString stringWithFormat:@"%@:%@", titleString, versePosition] ofTab:CommentaryTab];
		//[commentaryNavBtn setTitle: [NSString stringWithFormat:@"%@:%@", titleString, cVersePosition]];
	}
	
	if ([[moduleManager getCurrentBibleRef] isEqualToString: @"Revelation 22"]) {
		[self setEnabledBibleNextButton: NO];
		[self setEnabledBiblePreviousButton: YES];
		[self setEnabledCommentaryNextButton: NO];
		[self setEnabledCommentaryPreviousButton: YES];
	} else if ([[moduleManager getCurrentBibleRef] isEqualToString: @"Genesis 1"]) {
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
- (void) showModal:(UIView*)modalView withTiming:(float)time
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
- (void) hideModal:(UIView*) modalView withTiming:(float)time
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

- (void) hideModalEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	UIView* modalView = (UIView *)context;
	[modalView removeFromSuperview];
	//[modalView release];
}

// Use this to slide the semi-modal view back down.
- (void) hideModalAndRelease:(UIView*) modalView withTiming:(float)time
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

- (void) hideModalAndReleaseEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
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
	[moduleTable reloadData];
}

- (void)reloadDictionaryData {
	[dictionaryViewController reloadDictionaryData:YES];
}

@end
