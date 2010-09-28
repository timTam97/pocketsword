//
//  PSBibleViewController.m
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBibleViewController.h"
//#import "SwordModule.h"
#import "PSModuleController.h"
//#import "ViewController.h"
#import "SwordDictionary.h"
#import "PSBookmarksViewController.h"


@implementation PSBibleViewController

@synthesize refToShow;
@synthesize jsToShow;
@synthesize tappedVerse;
@synthesize isFullScreen;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


- (void) viewDidLoad {
	[super viewDidLoad];
	isFullScreen = NO;
	bibleTabBarItem.title = NSLocalizedString(@"TabBarTitleBible", @"Bible");

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleFullscreen) name:NotificationBibleToggleFullscreen object:nil];
	
//	NSString *scrollPosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleScrollPosition"];
//	if(scrollPosition) {
//		NSString *script = [NSString stringWithFormat:@"window.scrollTo(0, %@);", scrollPosition];
//		[bibleWebView stringByEvaluatingJavaScriptFromString: script];
//	}
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	if(refToShow) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
		//[[PSModuleController defaultModuleController] displayBusyIndicator];
		NSString *bText = [[PSModuleController defaultModuleController] getBibleChapter:refToShow withExtraJS:[NSString stringWithFormat:@"%@\nstartDetLocPoll();\n", jsToShow]];
		[bibleWebView loadHTMLString: bText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		self.refToShow = nil;
		self.jsToShow = nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
		//[[PSModuleController defaultModuleController] hideBusyIndicator];
	}
	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
		bibleToolbar.frame = CGRectMake(0.0, 0.0, 480.0, 32.0);
		bibleWebView.frame = CGRectMake(0.0, 32.0, 480.0, 219.0);
	} else {
		bibleToolbar.frame = CGRectMake(0.0, 0.0, 320.0, 44.0);
		bibleWebView.frame = CGRectMake(0.0, 44.0, 320.0, 367.0);
	}
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if(isFullScreen)
		return;
	if(toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		bibleToolbar.frame = CGRectMake(0.0, 0.0, 320.0, 32.0);
		bibleWebView.frame = CGRectMake(0.0, 32.0, 320.0, 379.0);//367
	} else {
		bibleToolbar.frame = CGRectMake(0.0, 0.0, 480.0, 44.0);
		bibleWebView.frame = CGRectMake(0.0, 44.0, 480.0, 207.0);
	}
}


- (void)viewDidAppear:(BOOL)animated {
	[bibleWebView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
//	UIDeviceOrientation toInterfaceOrientation = [[UIDevice currentDevice] orientation];
//	if(toInterfaceOrientation == UIDeviceOrientationLandscapeLeft || toInterfaceOrientation == UIDeviceOrientationLandscapeRight) {
//		[self toggleFullscreen];
//	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[bibleWebView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
}

- (CGRect)getOrientationRect {
	CGFloat x,y,width,height;
	UIDeviceOrientation toInterfaceOrientation = [[UIDevice currentDevice] orientation];
	if(toInterfaceOrientation == UIDeviceOrientationLandscapeLeft || toInterfaceOrientation == UIDeviceOrientationLandscapeRight) {
		x = 0.0;
		y = 0.0;
		width = 480.0;
		height = 320.0;
	} else {
		x = 0.0;
		y = 0.0;
		width = 320.0;
		height = 480.0;
	}
	return CGRectMake(x, y, width, height);
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
    [bibleWebView removeFromSuperview];
    if(isFullScreen) {
		//previousTabBarView is an ivar to hang on to the original view...
        previousTabBarView = self.tabBarController.view;
        [self.tabBarController.view addSubview:bibleWebView];
		
        bibleWebView.frame = [self getOrientationRect];  //checks orientation to provide the correct rect
		
    } else {
		CGFloat startWidth = 320.0, startHeight = 480.0;
		UIDeviceOrientation toInterfaceOrientation = [[UIDevice currentDevice] orientation];
		if(toInterfaceOrientation == UIDeviceOrientationLandscapeLeft || toInterfaceOrientation == UIDeviceOrientationLandscapeRight) {
			startWidth = 480.0;
			startHeight = 320.0;
		}
		CGFloat bwvHeight = startHeight - bibleToolbar.frame.size.height - self.tabBarController.tabBar.frame.size.height;
		bibleWebView.frame = CGRectMake(0, bibleToolbar.frame.size.height, startWidth, bwvHeight);
        [self.view addSubview:bibleWebView];
        self.tabBarController.view = previousTabBarView;
    }
	
	if(!isFullScreen) {
		UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
		if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
			bibleToolbar.frame = CGRectMake(0.0, 0.0, 480.0, 32.0);
			bibleWebView.frame = CGRectMake(0.0, 32.0, 480.0, 239.0);
		} else {
			bibleToolbar.frame = CGRectMake(0.0, 0.0, 320.0, 44.0);
			bibleWebView.frame = CGRectMake(0.0, 44.0, 320.0, 387.0);
		}
	}
	
    [UIView commitAnimations];
}

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//	NSLog(@"BibleView will rotate");
//	[self toggleFullscreen];
//}

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
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:NotificationBibleToggleFullscreen];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	NSString *requestString = [[request URL] absoluteString];
	NSArray *components = [requestString componentsSeparatedByString:@":"];
	
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
			[sheet showInView:bibleWebView];
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
				entry = (NSString*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData];
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
				}
				[tmpEntry release];
			}
		}

		
		if(entry) {
			[viewController showInfo: entry];
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
		[PSBookmarksViewController addBookmarkForRef:[PSModuleController getCurrentBibleRef] withVerse:tappedVerse];
		self.tappedVerse = nil;
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"VerseContextualMenuCommentary", @"")]) {
		//[[NSUserDefaults standardUserDefaults] setObject: tappedVerse forKey: DefaultsCommentaryVersePosition];
		commentaryView.jsToShow = [NSString stringWithFormat:@"scrollToVerse(%@);\n", tappedVerse];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowCommentaryTab object:nil];
		self.tappedVerse = nil;
	}
}

- (void)dealloc {
    [super dealloc];
	self.refToShow = nil;
	self.jsToShow = nil;
	self.tappedVerse = nil;
}


@end
