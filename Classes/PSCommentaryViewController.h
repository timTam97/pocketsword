//
//  PSCommentaryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSWebView.h"

@interface PSCommentaryViewController : UIViewController <UIWebViewDelegate, PSWebViewDelegate> {
	IBOutlet UITabBarItem				*commentaryTabBarItem;

	IBOutlet UIWebView *webView;
	IBOutlet UIToolbar *toolbar;
	
	IBOutlet id viewController;
	NSString *refToShow;
	NSString *jsToShow;
	BOOL isFullScreen;
	UIView *previousTabBarView;
}

@property (copy, readwrite) NSString *refToShow;
@property (copy, readwrite) NSString *jsToShow;
@property (readonly) BOOL isFullScreen;

- (void)toggleFullscreen;
- (void)switchToFullscreen;
- (void)switchToNormalscreen;

@end
