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
	CGSize screen = [PSResizing mainScreenBounds].size;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screen.width, screen.height)];
	baseView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.navigationItem.title = (self.entryTitle) ? entryTitle : @"";	
	
	WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, screen.width, screen.height) configuration:[[WKWebViewConfiguration alloc] init]];
	webView.navigationDelegate = self;
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	if(self.entryHTML) {
		[webView loadHTMLString: entryHTML baseURL: nil];
	}
	[baseView addSubview:webView];
	
	self.dictionaryDescriptionWebView = webView;
	
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	self.view = baseView;
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
	// scalesPageToFit not available on WKWebView; handled via viewport meta tag in HTML
}



//- (void)viewWillAppear:(BOOL)animated {
//    [super viewWillAppear:animated];
//	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:dictionaryDescriptionWebView useStatusBar:YES];
//}
//
//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:self.navigationController.navigationBar mainView:dictionaryDescriptionWebView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
//}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
	}];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}

- (void)webView:(WKWebView *)wv decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	@autoreleasepool {
		NSURLRequest *request = navigationAction.request;
		NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
		NSString *entry = nil;

		if(rData && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@"Bible"] && ![[rData objectForKey:ATTRTYPE_MODULE] isEqualToString:@""] && ![[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showImage"]) {
			NSString *mod = [rData objectForKey:ATTRTYPE_MODULE];

			SwordDictionary *swordDictionary = (SwordDictionary*)[[SwordManager defaultManager] moduleWithName: mod];
			if(swordDictionary) {
				entry = [swordDictionary entryForKey:[rData objectForKey:ATTRTYPE_VALUE]];
			} else {
				entry = [NSString stringWithFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ %@</p>", mod, NSLocalizedString(@"ModuleNotInstalled", @"is not installed.")];
			}
			NSString *t = [[rData objectForKey:ATTRTYPE_VALUE] stringByRemovingPercentEncoding];
			NSString *descr = [PSModuleController createInfoHTMLString: [NSString stringWithFormat: @"<div style=\"-webkit-text-size-adjust: none;\"><b>%@</b><br /><p>%@</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>", t, entry] usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryDictionary] name]];
			[self setDictionaryEntryTitle: t];
			[dictionaryDescriptionWebView loadHTMLString: descr baseURL: nil];

			decisionHandler(WKNavigationActionPolicyCancel);
			return;

		} else if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
			NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData cleanFeed:YES];
			NSMutableString *tmpEntry = [@"" mutableCopy];
			for(NSDictionary *dict in array) {
				NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
				[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
				[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
			}
			if(![tmpEntry isEqualToString:@""]) {
				entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
				entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
			}
		}

		if(entry) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];
			decisionHandler(WKNavigationActionPolicyCancel);
			return;
		}

		decisionHandler(WKNavigationActionPolicyAllow);
	}
}

@end

