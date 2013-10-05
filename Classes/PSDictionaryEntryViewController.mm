//
//  PSDictionaryEntryViewController.m
//  PocketSword
//
//  Created by Nic Carter on 27/09/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

#import "PSDictionaryEntryViewController.h"
#import "PSResizing.h"
#import "PSModuleController.h"
#import "globals.h"
#import "SwordManager.h"
#import "SwordDictionary.h"

@interface PSDictionaryEntryViewController ()

@end

@implementation PSDictionaryEntryViewController

@synthesize entryHTML, entryTitle, dictionaryDescriptionWebView;

- (void)loadView {
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screen.width, screen.height)];
	baseView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.navigationItem.title = (self.entryTitle) ? entryTitle : @"";	
	
	UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, screen.width, screen.height)];
	webView.delegate = self;
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	if(self.entryHTML) {
		[webView loadHTMLString: entryHTML baseURL: nil];
	}
	[baseView addSubview:webView];
	
	self.dictionaryDescriptionWebView = webView;
	[webView release];
	
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	self.view = baseView;
	[baseView release];
}

- (void)setDictionaryEntryTitle:(NSString*)title {
	if([title length] > 20) {
		title = [NSString stringWithFormat: @"%@...", [title substringToIndex: 20]];
	}
	self.entryTitle = title;
	self.navigationItem.title = title;
}

- (void)setDictionaryEntryText:(NSString*)entry {
	self.entryHTML = entry;
	[dictionaryDescriptionWebView loadHTMLString: entry baseURL: nil];
}

- (void)setScalesPageToFit:(BOOL)scalesPageToFit {
	dictionaryDescriptionWebView.scalesPageToFit = scalesPageToFit;
}

- (void)viewDidUnload {
	[super viewDidUnload];
}

- (void)dealloc {
	self.dictionaryDescriptionWebView = nil;
	self.entryHTML = nil;
	self.entryTitle = nil;
	[super dealloc];
}

//- (void)viewWillAppear:(BOOL)animated {
//    [super viewWillAppear:animated];
//	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:dictionaryDescriptionWebView useStatusBar:YES];
//}
//
//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:dictionaryDescriptionWebView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
//}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	//NSLog(@"\nDictionaryDescription: requestString: %@", [[request URL] absoluteString]);
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;
	
	if(rData && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@"Bible"] && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@""] && ![[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showImage"]) {
		//
		// it's a dictionary entry to show. (&& it's not a link on an image.)
		//
		NSString *mod = [rData objectForKey:ATTRTYPE_MODULE];
		
		SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
		if(swordDictionary) {
			entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];
			//DLog(@"\n%@ = %@\n", mod, entry);
		} else {
			entry = [NSString stringWithFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ %@</p>", mod, NSLocalizedString(@"ModuleNotInstalled", @"is not installed.")];
		}
		NSString *t = [[rData objectForKey:ATTRTYPE_VALUE] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString *descr = [PSModuleController createInfoHTMLString: [NSString stringWithFormat: @"<div style=\"-webkit-text-size-adjust: none;\"><b>%@</b><br /><p>%@</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>", t, entry] usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryDictionary] name]];
		[self setDictionaryEntryTitle: t];
		[dictionaryDescriptionWebView loadHTMLString: descr baseURL: nil];
		
		entry = nil;
		load = NO;
		
	} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
		NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData cleanFeed:YES];
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
	
	if(entry) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];
		
		load = NO;
	}
	
	
	[pool release];
	return load;
}

@end

