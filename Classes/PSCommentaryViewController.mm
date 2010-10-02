//
//  PSCommentaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSCommentaryViewController.h"
#import "PSModuleController.h"

#import "PSResizing.h"


@implementation PSCommentaryViewController

@synthesize refToShow;
@synthesize jsToShow;
@synthesize isFullScreen;

bool comm_initialised = false;

- (void)viewDidLoad {
	[super viewDidLoad];
	commentaryTabBarItem.title = NSLocalizedString(@"TabBarTitleCommentary", @"Commentary");
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleFullscreen) name:NotificationCommentaryToggleFullscreen object:nil];
}

- (void)awakeFromNib {
	[super awakeFromNib];
	if(!comm_initialised) {
		isFullScreen = NO;
		comm_initialised = true;
	}
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	if(refToShow) {
		NSString *cText = [[PSModuleController defaultModuleController] getCommentaryChapter:refToShow withExtraJS:[NSString stringWithFormat:@"%@\nstartDetLocPoll();\n", jsToShow]];
		[commentaryWebView loadHTMLString: cText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		self.refToShow = nil;
		self.jsToShow = nil;
	} else if(jsToShow) {
		[commentaryWebView stringByEvaluatingJavaScriptFromString:jsToShow];
		self.jsToShow = nil;
	}
	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:commentaryToolbar mainView:commentaryWebView useStatusBar:YES];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if(isFullScreen)
		return;
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:commentaryToolbar mainView:commentaryWebView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[commentaryWebView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
//	UIDeviceOrientation toInterfaceOrientation = [[UIDevice currentDevice] orientation];
//	if(toInterfaceOrientation == UIDeviceOrientationLandscapeLeft || toInterfaceOrientation == UIDeviceOrientationLandscapeRight) {
//		[self toggleFullscreen];
//	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[commentaryWebView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
}

- (void)toggleFullscreen {
    isFullScreen = !isFullScreen;
	
    [[UIApplication sharedApplication] setStatusBarHidden:isFullScreen animated:YES];
	
    [UIView beginAnimations:@"fullscreen" context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.3];
	
    //move tab bar up/down
    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    int tabBarHeight = tabBarFrame.size.height;
    int offset = isFullScreen ? tabBarHeight : -1 * tabBarHeight;
    int tabBarY = tabBarFrame.origin.y + offset;
    tabBarFrame.origin.y = tabBarY;
    self.tabBarController.tabBar.frame = tabBarFrame;
	
    //fade it in/out
    self.tabBarController.tabBar.alpha = isFullScreen ? 0 : 1;
	
    //resize webview to be full screen / normal
    [commentaryWebView removeFromSuperview];
    if(isFullScreen) {
		//previousTabBarView is an ivar to hang on to the original view...
        previousTabBarView = self.tabBarController.view;
        [self.tabBarController.view addSubview:commentaryWebView];
		
        commentaryWebView.frame = [PSResizing getOrientationRect];  //checks orientation to provide the correct rect
		
    } else {
		[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:commentaryToolbar mainView:commentaryWebView useStatusBar:NO];
        [self.view addSubview:commentaryWebView];
        self.tabBarController.view = previousTabBarView;
    }
	
    [UIView commitAnimations];
}

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//	[self toggleFullscreen];
//}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	NSString *requestString = [[request URL] absoluteString];
	//DLog(@"\nCOMMENTARY: requestString: %@", requestString);
	NSArray *components = [requestString componentsSeparatedByString:@":"];
	
	if ([components count] > 1 && [(NSString *)[components objectAtIndex:0] isEqualToString:@"pocketsword"]) {
		if([(NSString *)[components objectAtIndex:1] isEqualToString:@"currentverse"]) {
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:3] forKey: @"commentaryScrollPosition"];
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:2] forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			//NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", [components objectAtIndex:2]];
			//[bibleWebView stringByEvaluatingJavaScriptFromString:javascript];
			NSMutableString *ref = [NSMutableString stringWithString:[PSModuleController getCurrentBibleRef]];
			[ref appendFormat:@":%@", [components objectAtIndex:2]];
			//[commentaryNavBtn setTitle: ref];
			[viewController setTabTitle: [PSModuleController createRefString:ref] ofTab:CommentaryTab];
		}
		load = NO;
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
			}
			
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
			
		} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showNote"]) {
			if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"n"]) {//footnote
				entry = (NSString*)[[[PSModuleController defaultModuleController] primaryCommentary] attributeValueForEntryData:rData];
			} else if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"x"]) {//x-reference
				NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryCommentary] attributeValueForEntryData:rData];
				NSMutableString *tmpEntry = [@"" mutableCopy];
				for(NSDictionary *dict in array) {
					[tmpEntry appendFormat:@"<b>%@:</b> ", [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]]];
					[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
				}
				if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
					entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
				}
				[tmpEntry release];
			}
		} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
			BOOL strongs = [[NSUserDefaults standardUserDefaults] boolForKey:@"strongsPreference"];
			BOOL morphs = [[NSUserDefaults standardUserDefaults] boolForKey:@"morphPreference"];
			SwordManager *swordManager = [SwordManager defaultManager];
			[swordManager setGlobalOption: SW_OPTION_STRONGS value: SW_OFF ];
			[swordManager setGlobalOption: SW_OPTION_MORPHS value: SW_OFF ];
			NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
			[swordManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
			[swordManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
			NSMutableString *tmpEntry = [@"" mutableCopy];
			for(NSDictionary *dict in array) {
				NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
				[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
				[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
			}
			if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
				entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
			}
			[tmpEntry release];
		}
		
		if(entry) {
			[viewController showInfo: entry];
			load = NO;
		}
	}
	
	[pool release];
	return load; // Return YES to make sure regular navigation works as expected.
	
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:NotificationCommentaryToggleFullscreen];
}


- (void)dealloc {
    [super dealloc];
	self.refToShow = nil;
	self.jsToShow = nil;
}


@end
