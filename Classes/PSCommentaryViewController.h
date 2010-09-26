//
//  PSCommentaryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

//#import <UIKit/UIKit.h>


@interface PSCommentaryViewController : UIViewController <UIWebViewDelegate> {
	IBOutlet UITabBarItem				*commentaryTabBarItem;

	IBOutlet UIWebView *commentaryWebView;
	IBOutlet UIToolbar *commentaryToolbar;
	
	//IBOutlet id moduleManager;
	IBOutlet id viewController;
	//IBOutlet UIBarButtonItem *commentaryNavBtn;
	NSString *refToShow;
	NSString *jsToShow;
	BOOL isFullScreen;
	UIView *previousTabBarView;
}

@property (copy, readwrite) NSString *refToShow;
@property (copy, readwrite) NSString *jsToShow;
@property (readonly) BOOL isFullScreen;

- (void)toggleFullscreen;


@end
