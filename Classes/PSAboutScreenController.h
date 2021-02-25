//
//  PSAboutScreenController.h
//  PocketSword
//
//  Created by Nic Carter on 12/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import <MessageUI/MessageUI.h>
#import <WebKit/WebKit.h>


@interface PSAboutScreenController : UIViewController <WKNavigationDelegate, MFMailComposeViewControllerDelegate> {
	WKWebView *aboutWebView;
}

@property (strong) WKWebView *aboutWebView;

+ (NSString*)generateAboutHTML;
- (void)emailFeedback:(id)sender;

@end
