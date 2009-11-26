//
//  SnoopWindow.m
//  iPhoneIncubator
//
//  Created by Nick Dalton on 9/25/09.
//  Copyright 360mind 2009. All rights reserved.
//
//

#import "SnoopWindow.h"

#import "globals.h"


#define SWIPE_DRAG_HORIZ_MIN 40
#define SWIPE_DRAG_VERT_MAX 40
#define ZOOM_DRAG_MIN 20


@implementation SnoopWindow

@synthesize bibleWebView;
@synthesize commentaryWebView;
@synthesize holdTimer;

#pragma mark -
#pragma mark Helper functions for generic math operations on CGPoints

CGFloat CGPointDot(CGPoint a,CGPoint b) {
	return a.x*b.x+a.y*b.y;
}

CGFloat CGPointLen(CGPoint a) {
	return sqrtf(a.x*a.x+a.y*a.y);
}

CGPoint CGPointSub(CGPoint a,CGPoint b) {
	CGPoint c = {a.x-b.x,a.y-b.y};
	return c;
}

CGFloat CGPointDist(CGPoint a,CGPoint b) {
	CGPoint c = CGPointSub(a,b);
	return CGPointLen(c);
}

CGPoint CGPointNorm(CGPoint a) {
	CGFloat m = sqrtf(a.x*a.x+a.y*a.y);
	CGPoint c;
	c.x = a.x/m;
	c.y = a.y/m;
	return c;
}

- (void)setTouchAndHold:(NSTimer *)theTimer
{
	DLog(@"Timer Fired");
	//touchAndHold = YES;
	//if(bibleEvent) {
	//	[bibleWebView becomeFirstResponder];
	//	CGRect drawRect = CGRectMake(startTouchPosition1.x, startTouchPosition1.y, 0, 0);
	//	UIMenuController *theMenu = [UIMenuController sharedMenuController];
	//	[theMenu setTargetRect:drawRect inView:bibleWebView];
	//	[theMenu setMenuVisible:YES animated:YES];
	//}
	
}

- (void)sendEvent:(UIEvent *)event {
	NSArray *allTouches = [[event allTouches] allObjects];
	UITouch *touch = [[event allTouches] anyObject];
	UIView *touchView = [touch view];
	
	if (touchView && ([touchView isDescendantOfView:bibleWebView] || [touchView isDescendantOfView:commentaryWebView])) {
		bibleEvent = [touchView isDescendantOfView:bibleWebView];

		
		//
		// touchesBegan
		//
		if (touch.phase==UITouchPhaseBegan) {
			//touchAndHold = NO;
			//movement = NO;
			if(holdTimer) {
				[holdTimer invalidate];
				self.holdTimer = nil;
			}
			self.holdTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(setTouchAndHold:) userInfo:nil repeats:NO];
			//[holdTimer retain];
			
			startTouchPosition1 = [touch locationInView:self];
			//startTouchPosition1 = [touch locationInView:touchView];
			startTouchTime = touch.timestamp;
			
			if ([[event allTouches] count] > 1) {
				startTouchPosition2 = [[allTouches objectAtIndex:1] locationInView:self];
				previousTouchPosition1 = startTouchPosition1;
				previousTouchPosition2 = startTouchPosition2;
			}
			//DLog(@"pos.x = %f && pos.y == %f", startTouchPosition1.x, startTouchPosition1.y);
		}
        
		//
		// touchesMoved
		//
		
		if (touch.phase==UITouchPhaseMoved) {
			if([holdTimer isValid]) {
				[holdTimer invalidate];
				self.holdTimer = nil;
			}
			//touchAndHold = NO;
			//movement = YES;
			//DLog(@"--- UITouchPhaseMoved ---");
			/*if ([[event allTouches] count] > 1) {
				CGPoint currentTouchPosition1 = [[allTouches objectAtIndex:0] locationInView:self];
				CGPoint currentTouchPosition2 = [[allTouches objectAtIndex:1] locationInView:self];

				CGFloat currentFingerDistance = CGPointDist(currentTouchPosition1, currentTouchPosition2);
				CGFloat previousFingerDistance = CGPointDist(previousTouchPosition1, previousTouchPosition2);
				if (fabs(currentFingerDistance - previousFingerDistance) > ZOOM_DRAG_MIN) {
					NSNumber *movedDistance = [NSNumber numberWithFloat:currentFingerDistance - previousFingerDistance];
					if (currentFingerDistance > previousFingerDistance) {
						DLog(@"zoom in");
						[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_ZOOM_IN object:movedDistance];
					} else {
						DLog(@"zoom out");
						[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_ZOOM_OUT object:movedDistance];
					}
				}
			}*/
		}

		
		//
		// touchesEnded
		///
		if (touch.phase==UITouchPhaseEnded) {
			if([holdTimer isValid]) {
				[holdTimer invalidate];
				self.holdTimer = nil;
			}
			CGPoint currentTouchPosition = [touch locationInView:self];
			//DLog(@"\nUITouchPhaseEnded: %f - %f = %f", touch.timestamp, startTouchTime, (touch.timestamp-startTouchTime));

			// Check if it's a swipe
			//DLog(@"%d %f %d %f time: %g",fabsf(startTouchPosition1.x - currentTouchPosition.x) >= SWIPE_DRAG_HORIZ_MIN ? 1 : 0,
			//	 fabsf(startTouchPosition1.y - currentTouchPosition.y),
			//	 fabsf(startTouchPosition1.x - currentTouchPosition.x) > fabsf(startTouchPosition1.y - currentTouchPosition.y)  ? 1 : 0, touch.timestamp - startTouchTime, touch.timestamp - startTouchTime);
			if (fabsf(startTouchPosition1.x - currentTouchPosition.x) >= SWIPE_DRAG_HORIZ_MIN &&
				fabsf(startTouchPosition1.y - currentTouchPosition.y) <= SWIPE_DRAG_VERT_MAX &&
				fabsf(startTouchPosition1.x - currentTouchPosition.x) > fabsf(startTouchPosition1.y - currentTouchPosition.y) &&
				touch.timestamp - startTouchTime < .7
				) {
				// It appears to be a swipe.
				if (startTouchPosition1.x < currentTouchPosition.x) {
					if(bibleEvent) {
						DLog(@"bible swipe right");
						//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBibleSwipeRight object:touch];
					} else {
						DLog(@"commentary swipe right");
						//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationCommentarySwipeRight object:touch];
					}
				} else {
					if(bibleEvent) {
						DLog(@"bible swipe left");
						//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBibleSwipeLeft object:touch];
					} else {
						DLog(@"commentary swipe left");
						//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationCommentarySwipeLeft object:touch];
					}
				}
			}/* else if(!movement && touchAndHold) {
				//a touchAndHold event - so we pass the event through to super.
				DLog(@"\nfound a touchAndHold event");
			} else if(movement) {
				DLog(@"\nfound a movement event");
			} else {
				//eat up the event;
				DLog(@"\neating an event");
				//startTouchPosition1 = CGPointMake(-1, -1);
				//return;
			}*/
			startTouchPosition1 = CGPointMake(-1, -1);
		}
	}

	[super sendEvent:event];
}

@end
