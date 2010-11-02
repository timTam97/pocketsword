//
//  PSBibleViewController.h
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

//#import <UIKit/UIKit.h>
#import "PSCommentaryViewController.h"


@interface PSBibleViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate> {

	IBOutlet UITabBarItem				*bibleTabBarItem;
	IBOutlet UIToolbar *bibleToolbar;
	
	IBOutlet UIWebView *bibleWebView;
	IBOutlet PSCommentaryViewController *commentaryView;
	
	//IBOutlet id moduleManager;
	IBOutlet id viewController;
	//IBOutlet UIBarButtonItem *bibleNavBtn;
	NSString *refToShow;
	NSString *jsToShow;
	NSString *tappedVerse;
	BOOL isFullScreen;
	UIView *previousTabBarView;
}

@property (copy, readwrite) NSString *refToShow;
@property (copy, readwrite) NSString *jsToShow;
@property (copy, readwrite) NSString *tappedVerse;
@property (readonly) BOOL isFullScreen;

- (void)toggleFullscreen;
- (void)switchToFullscreen;
- (void)switchToNormalscreen;

@end
