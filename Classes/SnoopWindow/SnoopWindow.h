//
//  SnoopWindow.h
//  iPhoneIncubator
//
//  Created by Nick Dalton on 9/25/09.
//  Copyright 360mind 2009. All rights reserved.
//
//

#import <UIKit/UIKit.h>

@interface SnoopWindow : UIWindow {
	NSTimeInterval startTouchTime;
	CGPoint previousTouchPosition1, previousTouchPosition2;
	CGPoint startTouchPosition1, startTouchPosition2;
	//NSTimer *holdTimer;
	BOOL bibleEvent;
	//BOOL touchAndHold;
	BOOL movement;
	
	IBOutlet UIWebView *bibleWebView;
	IBOutlet UIWebView *commentaryWebView;
}

@property (nonatomic, assign) UIWebView *bibleWebView;
@property (nonatomic, assign) UIWebView *commentaryWebView;
//@property (retain, readwrite) NSTimer *holdTimer;

- (void)sendEvent:(UIEvent *)event;
- (void)setTouchAndHold:(NSTimer *)theTimer;

@end
