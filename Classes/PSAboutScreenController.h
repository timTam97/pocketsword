//
//  PSAboutScreenController.h
//  PocketSword
//
//  Created by Nic Carter on 12/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface PSAboutScreenController : UIViewController <UIWebViewDelegate> {
	IBOutlet UIWebView *aboutWebView;
}

+ (NSString*)generateAboutHTML;
-(void)emailFeedback:(id)sender;
//- (IBAction)done:(id)sender;

@end
