//
//  PSBibleViewController.m
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBibleViewController.h"
#import "PSModuleController.h"
//#import "ViewController.h"
#import "SwordDictionary.h"
//#import "PSBasicBookmarksViewController.h"
#import "PSBookmarkAddViewController.h"
#import "PSResizing.h"
#import "PSBookmarks.h"
#import "PSBookmark.h"

@implementation PSBibleViewController

@synthesize refToShow;
@synthesize jsToShow;
@synthesize tappedVerse;
@synthesize isFullScreen;

//bool bib_initialised = false;

- (void) viewDidLoad {
	[super viewDidLoad];
	bibleTabBarItem.title = NSLocalizedString(@"TabBarTitleBible", @"Bible");
	isFullScreen = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleFullscreen) name:NotificationBibleToggleFullscreen object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redoBookmarkHighlights) name:NotificationBookmarksChanged object:nil];
	webView.psDelegate = self;
}

- (void)topReloadTriggered {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBibleSwipeRight object:nil];
}

- (void)bottomReloadTriggered {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBibleSwipeLeft object:nil];
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:NotificationBibleToggleFullscreen];
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:NotificationBookmarksChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	if(refToShow) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
		NSString *bText = [[PSModuleController defaultModuleController] getBibleChapter:refToShow withExtraJS:[NSString stringWithFormat:@"%@\nstartDetLocPoll();\n", jsToShow]];
		[webView loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		self.refToShow = nil;
		self.jsToShow = nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	} else {
		[webView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
	}
	if(!self.isFullScreen) {
		[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:bibleToolbar mainView:webView useStatusBar:YES];
	}
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
	self.jsToShow = [NSString stringWithFormat:@"scrollToVerse(%@);", [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsBibleVersePosition]];
	if(isFullScreen)
		return;
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:bibleToolbar mainView:webView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
	[webView removeRefreshViews];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
	NSString *js = nil;
	if(self.jsToShow) {
		js = [NSString stringWithFormat:@"resetArrays();%@startDetLocPoll();", self.jsToShow];
		self.jsToShow = nil;
	} else {
		js = [NSString stringWithFormat:@"resetArrays();startDetLocPoll();"];
	}
	[webView stringByEvaluatingJavaScriptFromString:js];
	[webView setupRefreshViews];
}

//- (void)viewDidAppear:(BOOL)animated {
//	DLog(@"");
//	[super viewDidAppear:animated];
//}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
}

- (void)switchToFullscreen {
	if(!isFullScreen)
		[self toggleFullscreen];
}

- (void)switchToNormalscreen {
	if(isFullScreen)
		[self toggleFullscreen];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    [[UIApplication sharedApplication] setStatusBarHidden:isFullScreen animated:YES];
	if(!isFullScreen) {
		[UIView beginAnimations:@"fullscreen2" context:nil];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationDuration:0.5];
		[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:bibleToolbar mainView:webView useStatusBar:NO];
		[UIView commitAnimations];
	}
	[webView setupRefreshViews];
	//NSString *posJS = [NSString stringWithFormat:@"scrollToPosition(%@);startDetLocPoll();", [[NSUserDefaults standardUserDefaults] objectForKey:@"bibleScrollPosition"]];
	//[webView stringByEvaluatingJavaScriptFromString:posJS];
	[webView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
	//webView.hidden = NO;
}

- (void)toggleFullscreen {
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
    isFullScreen = !isFullScreen;
	[webView removeRefreshViews];
	//webView.hidden = YES;
	//CGRect tmpFrame = CGRectMake(webView.frame.origin.x, webView.frame.origin.y, webView.frame.size.width, (webView.frame.size.height+400.0f));
	//webView.frame = tmpFrame;
	
	if(!isFullScreen)
		[[UIApplication sharedApplication] setStatusBarHidden:isFullScreen animated:YES];
	
    [UIView beginAnimations:@"fullscreen" context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	
	
    //move tab bar up/down
    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    int tabBarHeight = tabBarFrame.size.height;
    int offset = (isFullScreen) ? tabBarHeight : -1 * tabBarHeight;
    int tabBarY = tabBarFrame.origin.y + offset;
    tabBarFrame.origin.y = tabBarY;
    self.tabBarController.tabBar.frame = tabBarFrame;
    // and fade it in/out
    self.tabBarController.tabBar.alpha = (isFullScreen) ? 0 : 1;
	
    //resize webview to be full screen / normal
    [webView removeFromSuperview];
    if(isFullScreen) {
		//previousTabBarView is an ivar to hang on to the original view...
        previousTabBarView = self.tabBarController.view;
        [self.tabBarController.view addSubview:webView];
        webView.frame = [PSResizing getOrientationRect:self.tabBarController.interfaceOrientation];
    } else {
        [self.view addSubview:webView];
        self.tabBarController.view = previousTabBarView;
		//[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:bibleToolbar mainView:webView useStatusBar:NO];
    }
	
    [UIView commitAnimations];
	
	
}

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//	NSLog(@"BibleView will rotate");
//	[self toggleFullscreen];
//}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)highlightBookmarks {
	NSArray *shownBookmarks = [PSBookmarks getBookmarksForCurrentRef];
	if(shownBookmarks && [shownBookmarks count] > 0) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"HighlightBookmarks" ofType:@"js"];
		NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		[webView stringByEvaluatingJavaScriptFromString:jsCode];
		for(PSBookmark *bookmark in shownBookmarks) {
			if(bookmark.rgbHexString) {
				NSString *verse = [[bookmark.ref componentsSeparatedByString:@":"] objectAtIndex: 1];
				NSString *jsFunction = [NSString stringWithFormat:@"PS_HighlightVerseWithHexColour('%@','%@')", verse, [PSBookmarkFolder rgbStringFromHexString:bookmark.rgbHexString]];
				//DLog(@"%@", jsFunction);
				[webView stringByEvaluatingJavaScriptFromString:jsFunction];
			}
		}
	}
}

- (void)removeBookmarkHighlights {
	NSInteger verses = [[PSModuleController defaultModuleController].primaryBible getVerseMax];
	BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference];
	NSString *fontColor = (nightMode) ? @"white" : @"black";
	NSString *jsFunction = [NSString stringWithFormat:@"PS_RemoveHighlights('%d','%@')", verses, fontColor];
	[webView stringByEvaluatingJavaScriptFromString:jsFunction];
}

- (void)redoBookmarkHighlights {
	[self removeBookmarkHighlights];
	[self highlightBookmarks];
}

- (void)webViewDidFinishLoad:(UIWebView *)wView {
	
	//highlight bookmarked verses
	[self highlightBookmarks];
	[webView setupRefreshViews];
	
	//highlight search results
	// TODO: implement highlighting of search results
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	NSString *requestString = [[request URL] absoluteString];
	NSArray *components = [requestString componentsSeparatedByString:@":"];
	//DLog(@"\nBIBLE: requestString: %@", requestString);
	
	if ([components count] > 1 && [(NSString *)[components objectAtIndex:0] isEqualToString:@"pocketsword"]) {
		if([(NSString *)[components objectAtIndex:1] isEqualToString:@"currentverse"]) {
			//our method of updating the title bar & remembering our position.
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:3] forKey: @"bibleScrollPosition"];
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:2] forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			NSMutableString *ref = [NSMutableString stringWithString:[PSModuleController getCurrentBibleRef]];
			[ref appendFormat:@":%@", [components objectAtIndex:2]];
			[viewController setTabTitle: [PSModuleController createRefString:ref] ofTab:BibleTab];
		} else if([(NSString *)[components objectAtIndex:1] isEqualToString:@"versemenu"]) {
			//bring up the contextual menu for a verse.
			self.tappedVerse = [components objectAtIndex:2];
			//DLog(@"    %@", tappedVerse);
			NSString *sheetTitle = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"RefSelectorVerseTitle", @""), tappedVerse];
			UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"VerseContextualMenuAddBookmark", @""), NSLocalizedString(@"VerseContextualMenuCommentary", @""), nil];
			//[sheet showInView:webView];
			//[sheet showInView:self.tabBarController.view];
			[sheet showFromTabBar:self.tabBarController.tabBar];
		}
		load = NO;
	} else {
		//NSLog(@"\nBIBLE: requestString: %@", requestString);
		NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
		NSString *entry = nil;
		
		if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showStrongs"]) {//@"showStrongs"
			//
			// Strong's Numbers
			//
			NSString *mod = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsStrongsGreekModule];
			//NSLog(@"dataType = %@", [rData objectForKey:ATTRTYPE_TYPE]);
			BOOL hebrew = NO;
			if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"Hebrew"]) {
				mod = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsStrongsHebrewModule];
				hebrew = YES;
			}
			
			SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
			if(swordDictionary) {
				entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];
				//DLog(@"\n%@ = %@\n", mod, entry);
			}
			if(!entry) {
				if(hebrew)
					entry = NSLocalizedString(@"NoHebrewStrongsNumbersModuleInstalled", @"");
				else
					entry = NSLocalizedString(@"NoGreekStrongsNumbersModuleInstalled", @"");
			} else {
				NSString *strongsPrefix = @"G";
				if(hebrew)
					strongsPrefix = @"H";
				entry = [NSString stringWithFormat:@"%@<div style=\"text-align: right\"><a href=\"search://%@%@\">%@</a></div>", entry, strongsPrefix, [rData objectForKey:ATTRTYPE_VALUE], NSLocalizedString(@"StrongsSearchFindAll", @"")];
				//NSLog(@"%@", entry);
			}
			
			NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsFontNamePreference];
			[[NSUserDefaults standardUserDefaults] setObject:StrongsFontName forKey:DefaultsFontNamePreference];
			[[NSUserDefaults standardUserDefaults] synchronize];
			entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:mod];
			[[NSUserDefaults standardUserDefaults] setObject:fontName forKey:DefaultsFontNamePreference];
			[[NSUserDefaults standardUserDefaults] synchronize];
						
		} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showMorph"]) {
			//
			// Morphological Tags
			//		type hasPrefix: "robinson"		for Greek
			//		type isEqualToString: "Greek"	for Greek
			//		type hasPrefix: "strongMorph"	for Hebrew	???
			//
			// for the time being I'm going to test for "strongMorph" & show an error dialogue or otherwise use Greek.
			
			NSString *mod = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsMorphGreekModule];
			if([[rData objectForKey:ATTRTYPE_TYPE] hasPrefix:@"strongMorph"]) {
				entry = NSLocalizedString(@"MorphHebrewNotSupported", @"");
			} else {
				SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
				if(swordDictionary) {
					entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];
					//DLog(@"\n%@ = %@\n", mod, entry);
				}
				if(!entry) {
					entry = NSLocalizedString(@"NoMorphGreekModuleInstalled", @"");
				}
			}
			entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:mod];
			
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
				[tmpEntry release];
			}
		}

		
		if(entry) {
			[viewController showInfo: entry];
			//NSLog(@"%@", entry);
			load = NO;
		}
	}
	
	[pool release];
	return load; // Return YES to make sure regular navigation works as expected.
	
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSString *buttonPressedTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
	if([buttonPressedTitle isEqualToString:NSLocalizedString(@"VerseContextualMenuAddBookmark", @"")]) {
		//add a bookmark!
		//[PSBasicBookmarksViewController addBookmarkForRef:[PSModuleController getCurrentBibleRef] withVerse:tappedVerse];
		NSString *refToBookmark = [PSModuleController createRefString:[PSModuleController getCurrentBibleRef]];
		PSBookmarksAddTableViewController *tableViewController = [[PSBookmarksAddTableViewController alloc] initWithBookAndChapterRef:refToBookmark andVerse:tappedVerse];
		UINavigationController *containingNavigationController = [[UINavigationController alloc] initWithRootViewController:tableViewController];
		[tableViewController release];
		[self presentModalViewController:containingNavigationController animated:YES];
		[containingNavigationController release];

		//PSBookmarkAddViewController *bavc = [[PSBookmarkAddViewController alloc] initWithBookAndChapterRef:[PSModuleController getCurrentBibleRef] verse:tappedVerse];
//		[self presentModalViewController:bavc animated:YES];
//		[bavc release];
		
		self.tappedVerse = nil;
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"VerseContextualMenuCommentary", @"")]) {
		//[[NSUserDefaults standardUserDefaults] setObject: tappedVerse forKey: DefaultsCommentaryVersePosition];
		commentaryView.jsToShow = [NSString stringWithFormat:@"scrollToVerse(%@);\n", tappedVerse];
		BOOL fs = [self isFullScreen];
		if(fs) {
			[self toggleFullscreen];
			[commentaryView viewWillAppear:YES];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowCommentaryTab object:nil];
		if(fs) {
			[commentaryView toggleFullscreen];
		}
		self.tappedVerse = nil;
	}
}

- (void)dealloc {
	self.refToShow = nil;
	self.jsToShow = nil;
	self.tappedVerse = nil;
    [super dealloc];
}


@end
