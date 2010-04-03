//
//  PSCommentaryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

//#import <UIKit/UIKit.h>


@interface PSCommentaryViewController : UIViewController <UIWebViewDelegate> {
	IBOutlet UIWebView *bibleWebView;
	IBOutlet UIWebView *commentaryWebView;
	
	IBOutlet id moduleManager;
	IBOutlet UIBarButtonItem *commentaryNavBtn;
	NSString *refToShow;
	NSString *jsToShow;
}

@property (copy, readwrite) NSString *refToShow;
@property (copy, readwrite) NSString *jsToShow;


@end
