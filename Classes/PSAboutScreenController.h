//
//  PSAboutScreenController.h
//  PocketSword
//
//  Created by Nic Carter on 12/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import <MessageUI/MessageUI.h>


@interface PSAboutScreenController : UIViewController <UIWebViewDelegate, MFMailComposeViewControllerDelegate> {
	UIWebView *aboutWebView;
}

@property (retain) UIWebView *aboutWebView;

+ (NSString*)generateAboutHTML;
- (void)emailFeedback:(id)sender;

@end
