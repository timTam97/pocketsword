//
//  PSCommentaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSCommentaryViewController.h"
#import "PSModuleController.h"
#import "ViewController.h"


@implementation PSCommentaryViewController

@synthesize refToShow;
@synthesize jsToShow;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	if(refToShow) {
		NSString *cText = [moduleManager getCommentaryChapter:refToShow withExtraJS:[NSString stringWithFormat:@"%@\nstartDetLocPoll();\n", jsToShow]];
		[commentaryWebView loadHTMLString: cText baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		self.refToShow = nil;
		self.jsToShow = nil;
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[commentaryWebView stringByEvaluatingJavaScriptFromString:@"startDetLocPoll();"];
}


- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[commentaryWebView stringByEvaluatingJavaScriptFromString:@"stopDetLocPoll();"];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	NSString *requestString = [[request URL] absoluteString];
	//DLog(@"\nCOMMENTARY: requestString: %@", requestString);
	NSArray *components = [requestString componentsSeparatedByString:@":"];
	
	if ([components count] > 1 && [(NSString *)[components objectAtIndex:0] isEqualToString:@"pocketsword"]) {
		if([(NSString *)[components objectAtIndex:1] isEqualToString:@"currentverse"]) {
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:3] forKey: @"commentaryScrollPosition"];
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:2] forKey: @"commentaryVersePosition"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			//NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", [components objectAtIndex:2]];
			//[bibleWebView stringByEvaluatingJavaScriptFromString:javascript];
			NSMutableString *ref = [NSMutableString stringWithString:[moduleManager getCurrentBibleRef]];
			[ref appendFormat:@":%@", [components objectAtIndex:2]];
			//[commentaryNavBtn setTitle: ref];
			[viewController setTabTitle: [PSModuleController createRefString:ref] ofTab:CommentaryTab];
		}
		load = NO;
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
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
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
}


- (void)dealloc {
    [super dealloc];
	self.refToShow = nil;
	self.jsToShow = nil;
}


@end
