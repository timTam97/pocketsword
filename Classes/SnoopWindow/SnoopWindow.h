//
//  SnoopWindow.h
//  iPhoneIncubator
//
//  Originally Created by Nick Dalton on 9/25/09.
//	Majorly hacked for PocketSword.
//

#import <UIKit/UIKit.h>

@class PSBibleViewController;
@class PSCommentaryViewController;

@interface SnoopWindow : UIWindow {
	NSTimeInterval startTouchTime;
	CGPoint previousTouchPosition1, previousTouchPosition2;
	CGPoint startTouchPosition1, startTouchPosition2;
	//NSTimer *holdTimer;
	BOOL bibleEvent;
	//BOOL touchAndHold;
	BOOL movement;
	BOOL ignoreMovementEvents;
	
	PSBibleViewController *bibleViewController;
	PSCommentaryViewController *commentaryViewController;
}

@property (nonatomic, assign) PSBibleViewController *bibleViewController;
@property (nonatomic, assign) PSCommentaryViewController *commentaryViewController;

- (void)sendEvent:(UIEvent *)event;
- (void)setTouchAndHold:(NSTimer *)theTimer;

@end
