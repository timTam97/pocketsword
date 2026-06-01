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
#import "PocketSword-Swift.h"
#import "PSCommentaryViewController.h"
#import "PSBibleViewController.h"
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
	CGRect screenBounds = [PSResizing mainScreenBounds];
	CGFloat viewWidth = screenBounds.size.width;
	CGFloat viewHeight = screenBounds.size.height;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	
	PSWebView *wv = [[PSWebView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	wv.delegate = self;
	wv.psDelegate = self;
	wv.backgroundColor = [UIColor systemBackgroundColor];
	wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[wv loadHTMLString:@"<html><body>&nbsp;</body></html>" baseURL:nil];
	[baseView addSubview:wv];
	self.webView = wv;

	self.view = baseView;
	currentShownVerse = 1;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	switch(tabType) {
		case BibleTab:
		{
			UITabBarItem *tbi = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitleBible", @"Bible") image:[UIImage imageNamed:@"bible.png"] tag:10];
			self.tabBarItem = tbi;
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setModuleNameViaNotification) name:NotificationNewPrimaryBible object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prevChapter) name:NotificationBibleSwipeRight object:nil];
		}
			break;
		case CommentaryTab:
		{
			UITabBarItem *tbi = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"TabBarTitleCommentary", @"Commentary") image:[UIImage imageNamed:@"commentary.png"] tag:10];
			self.tabBarItem = tbi;
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
	segControl.momentary = YES;
	
	static CGFloat arrowWidth = 50.0;
	static CGFloat refWidth = /*([PSResizing iPad]) ? 138.0 :*/ 78.0;
	[segControl setWidth: arrowWidth  forSegmentAtIndex:0];
	[segControl setWidth: refWidth forSegmentAtIndex:1];
	[segControl setWidth: arrowWidth  forSegmentAtIndex:2];
	[segControl addTarget: self action: @selector(segmentedControlAction:) forControlEvents: UIControlEventValueChanged];
	self.navigationItem.titleView = segControl;
	self.titleSegmentedControl = segControl;
	
	isFullScreen = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redoBookmarkHighlights) name:NotificationBookmarksChanged object:nil];
	finishedLoading = NO;
}

- (void)scrollToVerse:(NSInteger)verseNumber {
	CGFloat newYOffset = 0.0f;
	if(verseNumber > 1 && ([versePositionArray count] > verseNumber)) {
		newYOffset = [(NSNumber*)[versePositionArray objectAtIndex:(verseNumber-1)] floatValue];
		CGFloat topLength = 0;
		CGFloat bottomLength = 0;
		if(!self.isFullScreen) {
			topLength = self.view.safeAreaInsets.top;
			bottomLength = self.view.safeAreaInsets.bottom;
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
	NSString *verseString = [NSString stringWithFormat:@"%d", (int)verseNumber];
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
	@autoreleasepool {
		if(tabType == BibleTab) {
			[self rebuildBibleSettingsMenu];
			return;
		}
		SwordModule *module = [[PSModuleController defaultModuleController] primaryCommentary];
		if(module) {
			NSUInteger i = ([[module name] length] > 5) ? 5 : [[module name] length];
			NSString *newTitle = ([[module name] length] > i) ? [NSString stringWithFormat:@"%@..", [[module name] substringToIndex:i]] : [[module name] substringToIndex:i];
			[moduleButton setTitle: newTitle];
		} else {
			[moduleButton setTitle: NSLocalizedString(@"None", @"None")];
			[titleSegmentedControl setTitle: @"PocketSword" forSegmentAtIndex: 1];
			[self setEnabledNextButton: NO];
			[self setEnabledPreviousButton: NO];
		}
	}
}

- (void)rebuildBibleSettingsMenu {
	SwordModule *bible = [[PSModuleController defaultModuleController] primaryBible];
	NSString *modName = [bible name];
	if(!modName) {
		self.moduleButton.menu = nil;
		return;
	}

	__weak PSModuleViewController *weakSelf = self;
	NSMutableArray<UIMenuElement *> *topLevel = [NSMutableArray array];

	BOOL hasStrongs = [bible hasFeature:SWMOD_FEATURE_STRONGS] || [bible hasFeature:SWMOD_CONF_FEATURE_STRONGS];
	if(hasStrongs) {
		UIAction *strongsToggle = [UIAction
			actionWithTitle:NSLocalizedString(@"PreferencesStrongsPreferencesTitle", @"Strong's Numbers")
					  image:nil
				 identifier:@"bible.strongs"
					handler:^(UIAction *a) {
						NSString *mName = [[[PSModuleController defaultModuleController] primaryBible] name];
						BOOL current = GetBoolPrefForMod(DefaultsStrongsPreference, mName);
						SetBoolPrefForMod(!current, DefaultsStrongsPreference, mName);
						[[NSUserDefaults standardUserDefaults] synchronize];
						[[PSModuleController defaultModuleController] setPreferences];
						[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
						[weakSelf rebuildBibleSettingsMenu];
					}];
		strongsToggle.state = GetBoolPrefForMod(DefaultsStrongsPreference, modName) ? UIMenuElementStateOn : UIMenuElementStateOff;
		[topLevel addObject:[UIMenu menuWithTitle:@""
											image:nil
									   identifier:@"bible.strongsGroup"
										  options:UIMenuOptionsDisplayInline
										 children:@[strongsToggle]]];
	}

	UIAction *vplToggle = [UIAction
		actionWithTitle:NSLocalizedString(@"PreferencesVPLTitle", @"Verse Per Line")
				  image:nil
			 identifier:@"bible.vpl"
				handler:^(UIAction *a) {
					NSString *mName = [[[PSModuleController defaultModuleController] primaryBible] name];
					BOOL current = GetBoolPrefForMod(DefaultsVPLPreference, mName);
					SetBoolPrefForMod(!current, DefaultsVPLPreference, mName);
					[[NSUserDefaults standardUserDefaults] synchronize];
					[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
					[weakSelf rebuildBibleSettingsMenu];
				}];
	vplToggle.state = GetBoolPrefForMod(DefaultsVPLPreference, modName) ? UIMenuElementStateOn : UIMenuElementStateOff;
	[topLevel addObject:[UIMenu menuWithTitle:@""
										image:nil
								   identifier:@"bible.vplGroup"
									  options:UIMenuOptionsDisplayInline
									 children:@[vplToggle]]];

	self.moduleButton.menu = [UIMenu menuWithTitle:@"" children:topLevel];
}

- (PSTabBarControllerDelegate*)delegate {
	return delegate;
}

- (void)setDelegate:(PSTabBarControllerDelegate*)vc {

	UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"history.png"] style:UIBarButtonItemStylePlain target:vc action:@selector(toggleMultiList:)];
	searchButton.accessibilityLabel = NSLocalizedString(@"VoiceOverHistoryAndSearchButton", @"");
	self.navigationItem.leftBarButtonItem = searchButton;

	UIBarButtonItem *rightButton;
	if(tabType == BibleTab) {
		rightButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"textformat"]
													   style:UIBarButtonItemStylePlain
													  target:nil
													  action:nil];
		self.moduleButton = rightButton;
		[self rebuildBibleSettingsMenu];
	} else {
		rightButton = [[UIBarButtonItem alloc] initWithTitle:@"None"
													   style:UIBarButtonItemStylePlain
													  target:vc
													  action:@selector(toggleModulesListFromButton:)];
		self.moduleButton = rightButton;
		[self setModuleNameViaNotification];
	}
	self.navigationItem.rightBarButtonItem = rightButton;
	delegate = vc;
}


- (void)topReloadTriggered:(PSWebView*)psWebView {
	[self prevChapter];
}

- (void)bottomReloadTriggered:(PSWebView*)psWebView {
	[self nextChapter];
}

- (void)setupWebViewRefreshViews {
	CGFloat topLength = 0;
	CGFloat bottomLength = 0;
	if(!self.isFullScreen) {
		topLength = self.view.safeAreaInsets.top;
		bottomLength = self.view.safeAreaInsets.bottom;
	}
	[webView setupRefreshViews:topLength bottom:bottomLength];
}

- (void)setVerseToShow:(NSInteger)verseNumber {
	verseToShow = verseNumber;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

	UINavigationBarAppearance *transparentAppearance = [[UINavigationBarAppearance alloc] init];
	[transparentAppearance configureWithTransparentBackground];
	self.navigationController.navigationBar.standardAppearance = transparentAppearance;
	self.navigationController.navigationBar.scrollEdgeAppearance = transparentAppearance;

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
		if(!self.isFullScreen) {
			topLength = self.view.safeAreaInsets.top;
		}
		[self scrollHappened:webView newOffsetY:(self.webView.scrollView.contentOffset.y + topLength)];
	}
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFullscreenModePreference]) {
		webView.autoFullscreenMode = YES;
	} else {
		webView.autoFullscreenMode = NO;
	}
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
	NSString *verseKey = (tabType == BibleTab) ? DefaultsBibleVersePosition : DefaultsCommentaryVersePosition;
	self.jsToShow = [NSString stringWithFormat:@"scrollToVerse(%@);", [[NSUserDefaults standardUserDefaults] objectForKey:verseKey]];
	if(!isFullScreen) {
		[webView removeRefreshViews];
	}
	[coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
		NSString *js = nil;
		if(self.jsToShow) {
			js = [NSString stringWithFormat:@"resetArrays();%@startDetLocPoll();", self.jsToShow];
			self.jsToShow = nil;
		} else {
			js = [NSString stringWithFormat:@"resetArrays();startDetLocPoll();"];
		}
		[self->webView stringByEvaluatingJavaScriptFromString:js];
		if(self->finishedLoading) {
			[self setupWebViewRefreshViews];
		}
	}];
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

- (BOOL)prefersStatusBarHidden {
	return isFullScreen;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
	return UIStatusBarAnimationSlide;
}

- (void)toggleFullscreen {
	[webView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
    isFullScreen = !isFullScreen;
	[webView removeRefreshViews];

	[self setNeedsStatusBarAppearanceUpdate];

    //resize webview to be full screen / normal
    [webView removeFromSuperview];
    if(isFullScreen) {
		//previousTabBarView is an ivar to hang on to the original view...
        previousTabBarView = self.tabBarController.view;
        [self.tabBarController.view addSubview:webView];
        webView.frame = [PSResizing getOrientationRect:UIInterfaceOrientationPortrait];
    } else {
        [self.view addSubview:webView];
        self.tabBarController.view = previousTabBarView;
    }

	[UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
		self.tabBarController.tabBar.alpha = (self->isFullScreen) ? 0 : 1;
	} completion:^(BOOL finished) {
		[self setupWebViewRefreshViews];
		[self->webView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
	}];
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
	NSString *jsFunction = [NSString stringWithFormat:@"PS_RemoveHighlights('%d')", (int)verses];
	[webView stringByEvaluatingJavaScriptFromString:jsFunction];
}

- (void)redoBookmarkHighlights {
	[self removeBookmarkHighlights];
	[self highlightBookmarks];
}

- (void)webView:(WKWebView *)wv didFinishNavigation:(WKNavigation *)navigation {

	//highlight bookmarked verses
	//[self highlightBookmarks];
	[self setupWebViewRefreshViews];
	finishedLoading = YES;
	if(verseToShow > 0) {
		[self scrollToVerse:verseToShow];
		verseToShow = 0;
	} else {
		CGFloat topLength = 0.0f;
		if(!self.isFullScreen) {
			topLength = self.view.safeAreaInsets.top;
		}
		[self scrollHappened:webView newOffsetY:(self.webView.scrollView.contentOffset.y + topLength)];
	}

	//highlight search results
	// TODO: implement highlighting of search results
}

- (void)webView:(WKWebView *)wv didStartProvisionalNavigation:(WKNavigation *)navigation {
	finishedLoading = NO;
}

- (void)webView:(WKWebView *)wv decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	@autoreleasepool {
		NSURLRequest *request = navigationAction.request;
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
				UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:sheetTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];
				[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"VerseContextualMenuAddBookmark", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
					//add a bookmark!
					NSString *refToBookmark = [PSModuleController createRefString:[PSModuleController getCurrentBibleRef]];
					PSBookmarksAddTableViewController *tableViewController = [[PSBookmarksAddTableViewController alloc] initWithBookAndChapterRef:refToBookmark andVerse:self->tappedVerse];
					UINavigationController *containingNavigationController = [[UINavigationController alloc] initWithRootViewController:tableViewController];
					[self presentViewController:containingNavigationController animated:YES completion:nil];
					self.tappedVerse = nil;
				}]];
				[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"VerseContextualMenuCommentary", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
					//switch to the equivalent commentary entry.
					PSCommentaryViewController *commView = ((PSBibleViewController *)self).commentaryView;
					[commView setVerseToShow:[self->tappedVerse integerValue]];
					BOOL fs = [self isFullScreen];
					if(fs) {
						[self toggleFullscreen];
						[commView viewWillAppear:YES];
					}
					[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowCommentaryTab object:nil];
					if(fs) {
						[commView toggleFullscreen];
					}
					self.tappedVerse = nil;
				}]];
				[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil]];
				// TODO: for iPad, use popoverPresentationController.sourceView/sourceRect instead.
				[self presentViewController:actionSheet animated:YES completion:nil];
			}
			decisionHandler(WKNavigationActionPolicyCancel);
			return;
		} else if([(NSString *)[components objectAtIndex:0] isEqualToString:@"arraydump"]) {
			//DLog(@"\n%@: requestString: %@", moduleViewType, requestString);
			[self saveVersePositionArray:components];
			decisionHandler(WKNavigationActionPolicyCancel);
			return;
		} else if([[[request URL] scheme] isEqualToString:@"sword"]) {
			//our internal reference to say this is a Bible verse to display in the Bible tab
			// This should only happen in the commentary tab & we allow it to "load" normally.
			DLog(@"\nCOMMENTARY: requestString: %@", requestString);
			decisionHandler(WKNavigationActionPolicyAllow);
			return;
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
			}


			if(entry) {
				[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];
				decisionHandler(WKNavigationActionPolicyCancel);
				return;
			}
		}

		decisionHandler(WKNavigationActionPolicyAllow);
	}
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
