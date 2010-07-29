//
//  PSCommentaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSCommentaryViewController.h"
#import "PSModuleController.h"


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
			[[NSUserDefaults standardUserDefaults] setObject: [components objectAtIndex:2] forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			//NSString *javascript = [NSString stringWithFormat:@"scrollToVerse(%@);", [components objectAtIndex:2]];
			//[bibleWebView stringByEvaluatingJavaScriptFromString:javascript];
			NSMutableString *ref = [NSMutableString stringWithString:[moduleManager getCurrentBibleRef]];
			[ref appendFormat:@":%@", [components objectAtIndex:2]];
			//[commentaryNavBtn setTitle: ref];
			[[moduleManager viewController] setTabTitle: [PSModuleController createRefString:ref] ofTab:CommentaryTab];
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
				entry = (NSString*)[[moduleManager primaryCommentary] attributeValueForEntryData:rData];
			} else if([[rData objectForKey:ATTRTYPE_TYPE] isEqualToString:@"x"]) {//x-reference
				NSArray *array = (NSArray*)[[moduleManager primaryCommentary] attributeValueForEntryData:rData];
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
			NSArray *array = (NSArray*)[[moduleManager primaryBible] attributeValueForEntryData:rData];
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
			[[moduleManager viewController] showInfo: entry];
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
