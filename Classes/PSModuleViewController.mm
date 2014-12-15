//
//  PSBibleViewController.m
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleViewController.h"
#import "PSModuleController.h"
#import "PSTabBarControllerDelegate.h"
#import "SwordDictionary.h"
#import "PSBookmarkAddViewController.h"
#import "PSResizing.h"
#import "PSBookmarks.h"
#import "PSBookmark.h"
#import "PSCommentaryViewController.h"
#import "SwordManager.h"
#import "PSHistoryController.h"

@implementation PSModuleViewController

@synthesize refToShow, jsToShow, tappedVerse, isFullScreen, moduleButton, titleSegmentedControl, webView, versePositionArray;

- (id)init {
	self = [super init];
	if(self) {
		//tabType = BibleTab;
	}
	return self;
}

- (void)loadView {
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	
	PSWebView *wv = [[PSWebView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	wv.delegate = self;
	wv.psDelegate = self;
	wv.backgroundColor = [UIColor whiteColor];
	wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	NSString *html = @"<html><body bgcolor=\"white\">@nbsp;</body></html>";
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		html = @"<html><body bgcolor=\"black\">@nbsp;</body></html>";
		wv.backgroundColor = [UIColor blackColor];
	}
	[wv loadHTMLString: html baseURL: nil];
	[baseView addSubview:wv];
	self.webView = wv;
	[wv release];
	
	self.view = baseView;
	[baseView release];
	currentShownVerse = 1;
}

- (void)nightModeChanged {
	BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference];
	if(nightMode) {
		self.webView.backgroundColor = [UIColor blackColor];
	} else {
		self.webView.backgroundColor = [UIColor whiteColor];
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	switch(tabType) {
		case BibleTab:
		{
			UITabBarItem *tbi = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitleBible", @"Bible") image:[UIImage imageNamed:@"bible.png"] tag:10];
			self.tabBarItem = tbi;
			[tbi release];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setModuleNameViaNotification) name:NotificationNewPrimaryBible object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter) name:NotificationBibleSwipeRight object:nil];
		}
			break;
		case CommentaryTab:
		{
			UITabBarItem *tbi = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitleCommentary", @"Commentary") image:[UIImage imageNamed:@"commentary.png"] tag:10];
			self.tabBarItem = tbi;
			[tbi release];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setModuleNameViaNotification) name:NotificationNewPrimaryCommentary object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter) name:NotificationCommentarySwipeRight object:nil];
		}
			break;
		default:
			break;
	}
	
	UIImage *backImg = [UIImage imageNamed:@"back-white.png"];
	backImg.accessibilityLabel = NSLocalizedString(@"VoiceOverPreviousChapterButton", @"");
	UIImage *forwardImg = [UIImage imageNamed:@"forward-white.png"];
	forwardImg.accessibilityLabel = NSLocalizedString(@"VoiceOverNextChapterButton", @"");
	NSArray *segments = [NSArray arrayWithObjects:backImg, @"Gen 23:23", forwardImg, nil];
	UISegmentedControl *segControl = [[UISegmentedControl alloc] initWithItems:segments];
	segControl.segmentedControlStyle = UISegmentedControlStyleBar;
	segControl.momentary = YES;
	
	static CGFloat arrowWidth = 50.0;
	static CGFloat refWidth = /*([PSResizing iPad]) ? 138.0 :*/ 78.0;
	[segControl setWidth: arrowWidth  forSegmentAtIndex:0];
	[segControl setWidth: refWidth forSegmentAtIndex:1];
	[segControl setWidth: arrowWidth  forSegmentAtIndex:2];
	[segControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
	self.navigationItem.titleView = segControl;
	self.titleSegmentedControl = segControl;
	[segControl release];
	
	isFullScreen = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redoBookmarkHighlights) name:NotificationBookmarksChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nightModeChanged) name:NotificationNightModeChanged object:nil];
	finishedLoading = NO;
}

- (void)scrollToVerse:(NSInteger)verseNumber {
	CGFloat newYOffset = 0.0f;
	if(verseNumber > 1 && ([versePositionArray count] > verseNumber)) {
		newYOffset = [(NSNumber*)[versePositionArray objectAtIndex:(verseNumber-1)] floatValue];
		CGFloat topLength = 0;
		CGFloat bottomLength = 0;
		if([self respondsToSelector:@selector(topLayoutGuide)] && !self.isFullScreen) {
			topLength = [[self topLayoutGuide] length];
			bottomLength = [[self bottomLayoutGuide] length];
		}
		newYOffset -= topLength;
		if((newYOffset + webView.frame.size.height) > webView.scrollView.contentSize.height) {
			newYOffset = webView.scrollView.contentSize.height - webView.frame.size.height + bottomLength;
		}
		[self.webView.scrollView setContentOffset:CGPointMake(0, newYOffset) animated:NO];
		//[self.webView.scrollView scrollRectToVisible:CGRectMake(0, newYOffset, 2.0f, 2.0f) animated:NO];
		//[self.webView.scrollView setContentOffset:CGPointMake(0, newYOffset) animated:YES];
	}
}

- (void)scrollHappened:(PSWebView*)psWebView newOffsetY:(CGFloat)newOffsetY {
	//DLog(@"scrollHappened: %f", newOffsetY);
	if(!versePositionArray) {
		return;
	}
	NSInteger verseNumber = 0;
	for(; verseNumber < [versePositionArray count]; ++verseNumber) {
		if(newOffsetY < [(NSNumber*)[versePositionArray objectAtIndex:verseNumber] floatValue]) {
			break;
		}
	}
	if(verseNumber == 0) {
		verseNumber = 1;
	} else if(verseNumber == [versePositionArray count]) {
		--verseNumber;
	}
	if(verseNumber == currentShownVerse) {
		return;
	}
	currentShownVerse = verseNumber;
	//index 0 == verse 1, so we need to add one and then subtract 1, so the resulting verse is the number.
	//our method of updating the title bar & remembering our position.
	NSString *verseString = [NSString stringWithFormat:@"%d", verseNumber];
	if(tabType == BibleTab) {
		[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%d", (int)newOffsetY] forKey: @"bibleScrollPosition"];
		[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsBibleVersePosition];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%d", (int)newOffsetY] forKey: @"commentaryScrollPosition"];
		[[NSUserDefaults standardUserDefaults] setObject: verseString forKey: DefaultsCommentaryVersePosition];
	}
	//[[NSUserDefaults standardUserDefaults] synchronize];
	NSMutableString *ref = [NSMutableString stringWithString:[PSModuleController getCurrentBibleRef]];
	[ref appendFormat:@":%@", verseString];
	[self setTabTitle:[PSModuleController createRefString:ref]];
}

- (void)saveVersePositionArray:(NSArray*)verseArray {
	if(!verseArray) {
		return;
	} else if([verseArray count] == 0) {
		return;
	}
	NSMutableArray *mutVerseArray = [NSMutableArray arrayWithCapacity:[verseArray count]];
	// ignore the first element in the array, because it is "arraydump"
	// The rest of the array is the location of each verse.
	for(int i = 1; i < [verseArray count]; i++) {
		[mutVerseArray addObject:[NSNumber numberWithFloat:[(NSString*)[verseArray objectAtIndex:i] floatValue]]];
	}
	self.versePositionArray = mutVerseArray;
}

- (void)segmentedControlAction:(id)sender {
	
	UISegmentedControl *segControl = sender;
	switch (segControl.selectedSegmentIndex)
	{
		case 0:	// previous
		{
			[self prevChapter];
			break;
		}
		case 1: // Ref
		{
			[delegate toggleNavigation];
			break;
		}
		case 2:	// next
		{
			[self nextChapter];
			break;
		}
	}
	
}

// Loads the next chapter into the Web View
- (void)nextChapter {
	verseToShow = 0;
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if ([currentRef isEqualToString: [PSModuleController getLastRefAvailable]]) {
		return;
	}
		
	NSString *ref = [[PSModuleController defaultModuleController] setToNextChapter];
	if(!ref) {
		return;
	}
	
	if(isFullScreen) {
		[PSTabBarControllerDelegate displayTitle:ref];
	}

	switch(tabType) {
		case BibleTab:
		{
			[delegate displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreNoPosition];
			[PSHistoryController addHistoryItem:BibleTab];
		}
			break;
		case CommentaryTab:
		{
			[delegate displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreNoPosition];
			[PSHistoryController addHistoryItem:CommentaryTab];
		}
			break;
		default:
			break;
	}
	
}

// Loads the previous chapter into the Web View
- (void)prevChapter {
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if ([currentRef isEqualToString: [PSModuleController getFirstRefAvailable]]) {
		return;
	}
	
	NSString *ref = [[PSModuleController defaultModuleController] setToPreviousChapter];
	if(!ref) {
		return;
	}
	
	if(isFullScreen) {
		[PSTabBarControllerDelegate displayTitle:ref];
	}
		
	switch(tabType) {
		case BibleTab:
		{
			[delegate displayChapter:ref withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
			[PSHistoryController addHistoryItem:BibleTab];
		}
			break;
		case CommentaryTab:
		{
			[delegate displayChapter:ref withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
			[PSHistoryController addHistoryItem:CommentaryTab];
		}
			break;
		default:
			break;
	}
	
}

- (void)setEnabledNextButton:(BOOL)enabled {
	[titleSegmentedControl setEnabled: enabled forSegmentAtIndex: 2];
}

- (void)setEnabledPreviousButton:(BOOL)enabled {
	[titleSegmentedControl setEnabled: enabled forSegmentAtIndex: 0];
}

- (void)setTabTitle:(NSString*)title {
	NSString *titleToDisplay = [PSModuleController createTitleRefString:title];
	[titleSegmentedControl setTitle: titleToDisplay forSegmentAtIndex: 1];
	[PSModuleViewController setVoiceOverForRefSegmentedControlSubviews:titleSegmentedControl.subviews];
}

- (void)setModuleNameViaNotification {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	SwordModule *module;
	module = (tabType == BibleTab) ? [[PSModuleController defaultModuleController] primaryBible] : [[PSModuleController defaultModuleController] primaryCommentary];
	if(module) {
		int i = ([[module name] length] > 5) ? 5 : [[module name] length];
		NSString *newTitle = ([[module name] length] > i) ? [NSString stringWithFormat:@"%@..", [[module name] substringToIndex:i]] : [[module name] substringToIndex:i];
		[moduleButton setTitle: newTitle];
	} else {
		[moduleButton setTitle: NSLocalizedString(@"None", @"None")];
		[titleSegmentedControl setTitle: @"PocketSword" forSegmentAtIndex: 1];
		[self setEnabledNextButton: NO];
		[self setEnabledPreviousButton: NO];
	}
	[pool release];
}

- (PSTabBarControllerDelegate*)delegate {
	return delegate;
}

- (void)setDelegate:(PSTabBarControllerDelegate*)vc {

	UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"history.png"] style:UIBarButtonItemStyleBordered target:vc action:@selector(toggleMultiList:)];
	searchButton.accessibilityLabel = NSLocalizedString(@"VoiceOverHistoryAndSearchButton", @"");
	self.navigationItem.leftBarButtonItem = searchButton;
	[searchButton release];
	
	UIBarButtonItem *switchModuleButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"None" style:UIBarButtonItemStyleBordered target:vc action:@selector(toggleModulesListFromButton:)];
	self.navigationItem.rightBarButtonItem = switchModuleButtonItem;
	self.moduleButton = switchModuleButtonItem;
	[switchModuleButtonItem release];
	[self setModuleNameViaNotification];
	delegate = vc;
}

- (void)dealloc {
	self.refToShow = nil;
	self.jsToShow = nil;
	self.tappedVerse = nil;
	self.moduleButton = nil;
	self.titleSegmentedControl = nil;
	self.webView = nil;
    [super dealloc];
}

- (void)topReloadTriggered:(PSWebView*)psWebView {
	[self prevChapter];
}

- (void)bottomReloadTriggered:(PSWebView*)psWebView {
	[self nextChapter];
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewDidUnload];
}

- (void)setupWebViewRefreshViews {
	CGFloat topLength = 0;
	CGFloat bottomLength = 0;
	if([self respondsToSelector:@selector(topLayoutGuide)] && !self.isFullScreen) {
		topLength = [[self topLayoutGuide] length];
		bottomLength = [[self bottomLayoutGuide] length];
	}
	[webView setupRefreshViews:topLength bottom:bottomLength];
}

- (void)setVerseToShow:(NSInteger)verseNumber {
	verseToShow = verseNumber;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	//finishedLoading = NO;
	if(refToShow) {
		NSString *webText;
		if(tabType == BibleTab) {
			webText = [[PSModuleController defaultModuleController] getBibleChapter:refToShow withExtraJS:[NSString stringWithFormat:@"%@\nstartDetLocPoll();\n", jsToShow]];
		} else {
			webText = [[PSModuleController defaultModuleController] getCommentaryChapter:refToShow withExtraJS:[NSString stringWithFormat:@"%@\nstartDetLocPoll();\n", jsToShow]];
		}
		[webView loadHTMLString: webText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		self.refToShow = nil;
		self.jsToShow = nil;
	} else if(jsToShow) {
		NSString *jsString = [NSString stringWithFormat:@"%@; startDetLocPoll();", jsToShow];
		[webView stringByEvaluatingJavaScriptFromString:jsString];
		self.jsToShow = nil;
	} else if(verseToShow > 0) {
		// go there.
		[self scrollToVerse:verseToShow];
		//verseToShow = 0;
	} else {
		[webView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
	}
	if(!self.isFullScreen) {
		if(finishedLoading) {
			[self setupWebViewRefreshViews];
		}
	}
	if(finishedLoading) {
		CGFloat topLength = 0.0f;
		if([self respondsToSelector:@selector(topLayoutGuide)] && !self.isFullScreen) {
			topLength = [[self topLayoutGuide] length];
		}
		[self scrollHappened:webView newOffsetY:(self.webView.scrollView.contentOffset.y + topLength)];
	}
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFullscreenModePreference]) {
		webView.autoFullscreenMode = YES;
	} else {
		webView.autoFullscreenMode = NO;
	}
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
	NSString *verseKey = (tabType == BibleTab) ? DefaultsBibleVersePosition : DefaultsCommentaryVersePosition;
	self.jsToShow = [NSString stringWithFormat:@"scrollToVerse(%@);", [[NSUserDefaults standardUserDefaults] objectForKey:verseKey]];
	if(isFullScreen)
		return;
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
	if(finishedLoading) {
		[self setupWebViewRefreshViews];
	}
}

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
    //[[UIApplication sharedApplication] setStatusBarHidden:isFullScreen withAnimation:UIStatusBarAnimationSlide];
	[self setupWebViewRefreshViews];
	[webView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
}

- (void)toggleFullscreen {
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
    isFullScreen = !isFullScreen;
	[webView removeRefreshViews];
	
	//if(!isFullScreen) {
		[[UIApplication sharedApplication] setStatusBarHidden:isFullScreen withAnimation:UIStatusBarAnimationSlide];
	//}
	
    [UIView beginAnimations:@"fullscreen" context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	
	
    self.tabBarController.tabBar.alpha = (isFullScreen) ? 0 : 1;
	
    //resize webview to be full screen / normal
    [webView removeFromSuperview];
    if(isFullScreen) {
		//previousTabBarView is an ivar to hang on to the original view...
        previousTabBarView = self.tabBarController.view;
        [self.tabBarController.view addSubview:webView];
		
		CGFloat width  = [[UIScreen mainScreen] bounds].size.width;
		CGFloat height = [[UIScreen mainScreen] bounds].size.height;
		UIInterfaceOrientation uiio = (self.view.frame.size.width == (width * (width < height)) + (height * (width > height)))
			  ? UIInterfaceOrientationPortrait : UIInterfaceOrientationLandscapeLeft;
        webView.frame = [PSResizing getOrientationRect:uiio];
    } else {
        [self.view addSubview:webView];
        self.tabBarController.view = previousTabBarView;
    }
	
    [UIView commitAnimations];
	
}

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
	//[self highlightBookmarks];
	[self setupWebViewRefreshViews];
	finishedLoading = YES;
	if(verseToShow > 0) {
		[self scrollToVerse:verseToShow];
		verseToShow = 0;
	} else {
		CGFloat topLength = 0.0f;
		if([self respondsToSelector:@selector(topLayoutGuide)] && !self.isFullScreen) {
			topLength = [[self topLayoutGuide] length];
		}
		[self scrollHappened:webView newOffsetY:(self.webView.scrollView.contentOffset.y + topLength)];
	}
	
	//highlight search results
	// TODO: implement highlighting of search results
}

- (void)webViewDidStartLoad:(UIWebView *)wView {
	finishedLoading = NO;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	NSString *requestString = [[request URL] absoluteString];
	NSArray *components = [requestString componentsSeparatedByString:@":"];
//	NSString *moduleViewType = (tabType == BibleTab) ? @"BIBLE" : @"COMMENTARY";
//	DLog(@"\n%@: requestString: %@", moduleViewType, requestString);
	
	if ([components count] > 1 && [(NSString *)[components objectAtIndex:0] isEqualToString:@"pocketsword"]) {
		if([(NSString *)[components objectAtIndex:1] isEqualToString:@"currentverse"]) {
			//our method of updating the title bar & remembering our position.
			if(tabType == BibleTab) {
				[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:3] forKey: @"bibleScrollPosition"];
				[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:2] forKey: DefaultsBibleVersePosition];
			} else {
				[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:3] forKey: @"commentaryScrollPosition"];
				[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:2] forKey: DefaultsCommentaryVersePosition];
			}
			[[NSUserDefaults standardUserDefaults] synchronize];
			NSMutableString *ref = [NSMutableString stringWithString:[PSModuleController getCurrentBibleRef]];
			[ref appendFormat:@":%@", [components objectAtIndex:2]];
			[self setTabTitle:[PSModuleController createRefString:ref]];
		} else if([(NSString *)[components objectAtIndex:1] isEqualToString:@"versemenu"] && (tabType == BibleTab)) {
			// ONLY for BibleTab, not CommentaryTab...
			//bring up the contextual menu for a verse.
			self.tappedVerse = [components objectAtIndex:2];
			//DLog(@"    %@", tappedVerse);
			NSInteger tappedVerseInt = [tappedVerse integerValue];
			NSString *sheetTitle = [NSString stringWithFormat:NSLocalizedString(@"RefSelectorVerseTitle", @""), tappedVerseInt];
			UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"VerseContextualMenuAddBookmark", @""), NSLocalizedString(@"VerseContextualMenuCommentary", @""), nil];
			[sheet showFromTabBar:self.tabBarController.tabBar];
			// TODO: for iPad, use showFromRect:inView:animated: instead, after determining the rect of the verse number.
			[sheet release];
		}
		load = NO;
	} else if([(NSString *)[components objectAtIndex:0] isEqualToString:@"arraydump"]) {
		//DLog(@"\n%@: requestString: %@", moduleViewType, requestString);
		[self saveVersePositionArray:components];
	} else if([[[request URL] scheme] isEqualToString:@"sword"]) {
		//our internal reference to say this is a Bible verse to display in the Bible tab
		// This should only happen in the commentary tab & we allow it to "load" normally.
		DLog(@"\nCOMMENTARY: requestString: %@", requestString);
	} else {
		//NSLog(@"\nBIBLE: requestString: %@", requestString);
		NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
		NSString *entry = nil;
		
		if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showStrongs"]) {
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
			} else if(tabType == BibleTab) {
				// for the BibleTab only, allow a "search for all occurrences" link...
				NSString *strongsPrefix = @"G";
				if(hebrew)
					strongsPrefix = @"H";
				entry = [NSString stringWithFormat:@"%@<div style=\"text-align: right\"><a href=\"search://%@%@\">%@</a></div>", entry, strongsPrefix, [rData objectForKey:ATTRTYPE_VALUE], NSLocalizedString(@"StrongsSearchFindAll", @"")];
				//NSLog(@"%@", entry);
			}
			
			NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsFontNamePreference];
			if(!hebrew) {
				[[NSUserDefaults standardUserDefaults] setObject:PSGreekStrongsFontName forKey:DefaultsFontNamePreference];
			} else  {
				[[NSUserDefaults standardUserDefaults] setObject:PSHebrewStrongsFontName forKey:DefaultsFontNamePreference];
			}
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
				if(tabType == BibleTab) {
					entry = (NSString*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
					entry = [entry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
					entry = [entry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
					entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
				} else {
					entry = (NSString*)[[[PSModuleController defaultModuleController] primaryCommentary] attributeValueForEntryData:rData];
					entry = [entry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
					entry = [entry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
					entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryCommentary] name]];
				}
			} else if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"x"]) {//x-reference
				NSArray *array;
				if(tabType == BibleTab) {
					array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
				} else {
					array = (NSArray*)[[[PSModuleController defaultModuleController] primaryCommentary] attributeValueForEntryData:rData];
				}
				NSMutableString *tmpEntry = [@"" mutableCopy];
				for(NSDictionary *dict in array) {
					NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
					[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
					[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
				}
				if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
					entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
					entry = [entry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
					entry = [entry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
					entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
				}
				[tmpEntry release];
			}
		} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"] &&
				  tabType == CommentaryTab) {
			// ONLY for CommentaryTab as this is only a feature of Commentaries & dictionaries, etc.
			NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData cleanFeed:YES];
			NSMutableString *tmpEntry = [@"" mutableCopy];
			for(NSDictionary *dict in array) {
				NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
				[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
				[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
			}
			if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
				entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
				entry = [entry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
				entry = [entry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
				entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
			}
			[tmpEntry release];
		}

		
		if(entry) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];
			load = NO;
		}
	}
	
	[pool release];
	return load; // Return YES to make sure regular navigation works as expected.
	
}

+ (void)setVoiceOverForRefSegmentedControlSubviews:(NSArray *)subviews {
	for(UIView *segmentView in subviews) {
		if([segmentView.accessibilityLabel isEqualToString:@"forward-white.png"] ||
		   [segmentView.accessibilityLabel isEqualToString:NSLocalizedString(@"VoiceOverNextChapterButton", @"")]) {
			//forward button
			segmentView.accessibilityLabel = NSLocalizedString(@"VoiceOverNextChapterButton", @"");
		} else if([segmentView.accessibilityLabel isEqualToString:@"back-white.png"] ||
				  [segmentView.accessibilityLabel isEqualToString:NSLocalizedString(@"VoiceOverPreviousChapterButton", @"")]) {
			//backward button
			segmentView.accessibilityLabel = NSLocalizedString(@"VoiceOverPreviousChapterButton", @"");
		} else {
			//chapter title
			segmentView.accessibilityLabel = [PSModuleController getCurrentBibleRef];
		}
	}
}

@end
