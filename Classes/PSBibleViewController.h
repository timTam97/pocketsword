//
//  PSBibleViewController.h
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

//#import <UIKit/UIKit.h>
//#import "PSBibleViewController.h"


@interface PSBibleViewController : UIViewController <UIWebViewDelegate> {
	IBOutlet UIWebView *bibleWebView;
	IBOutlet UIWebView *commentaryWebView;
	
	IBOutlet id moduleManager;
	IBOutlet UIBarButtonItem *bibleNavBtn;
}

@end
