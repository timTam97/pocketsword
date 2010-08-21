//
//  PSBibleViewController.h
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

//#import <UIKit/UIKit.h>
//#import "PSBibleViewController.h"


@interface PSBibleViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate> {

	IBOutlet UITabBarItem				*bibleTabBarItem;
	
	IBOutlet UIWebView *bibleWebView;
	//IBOutlet UIWebView *commentaryWebView;
	
	//IBOutlet id moduleManager;
	IBOutlet id viewController;
	//IBOutlet UIBarButtonItem *bibleNavBtn;
	NSString *refToShow;
	NSString *jsToShow;
	NSString *tappedVerse;
}

@property (copy, readwrite) NSString *refToShow;
@property (copy, readwrite) NSString *jsToShow;
@property (copy, readwrite) NSString *tappedVerse;

@end
