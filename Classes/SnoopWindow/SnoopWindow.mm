//
//  SnoopWindow.m
//

#import "SnoopWindow.h"

#import "globals.h"
#import "PSModuleController.h"
#import "PSWebView.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"


#define SWIPE_DRAG_HORIZ_MIN 100
#define SWIPE_DRAG_VERT_MAX 40
#define ZOOM_DRAG_MIN 20
//#define MOVEMENT_LEEWAY 10


@implementation SnoopWindow

@synthesize bibleViewController, commentaryViewController;

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
	
	if(bibleEvent) {
		[bibleViewController toggleFullscreen];
	} else {
		[commentaryViewController toggleFullscreen];
	}
	
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
	//UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if([UIApplication sharedApplication].statusBarHidden) {
		interfaceOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
	}
	
	if (touchView && ([touchView isDescendantOfView:bibleViewController.webView] || [touchView isDescendantOfView:commentaryViewController.webView])) {
		bibleEvent = [touchView isDescendantOfView:bibleViewController.webView];

		
		//
		// touchesBegan
		//
		if (touch.phase==UITouchPhaseBegan) {
			//touchAndHold = NO;
			ignoreMovementEvents = NO;
			movement = NO;
//			if ([[event allTouches] count] > 1) {
//				if(holdTimer) {
//					[holdTimer invalidate];
//					self.holdTimer = nil;
//				}
//				self.holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(setTouchAndHold:) userInfo:nil repeats:NO];
//				//[holdTimer retain];
//			} else if([holdTimer isValid]) {
//				[holdTimer invalidate];
//				self.holdTimer = nil;
//			}
			
			startTouchPosition1 = [touch locationInView:self];
			if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
				//switch x & y if in landscape mode
				CGFloat dummyX = startTouchPosition1.x;
				startTouchPosition1.x = startTouchPosition1.y;
				startTouchPosition1.y = dummyX;
			}
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
//			if([holdTimer isValid]) {
//				[holdTimer invalidate];
//				self.holdTimer = nil;
//			}
			//touchAndHold = NO;
			movement = YES;
			//DLog(@"--- UITouchPhaseMoved ---");
			if(bibleEvent && !ignoreMovementEvents && ([[event allTouches] count] == 3)) {
				CGPoint currentTouchPosition = [touch locationInView:self];
				if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
					//switch x & y if in landscape mode
					CGFloat dummyX = currentTouchPosition.x;
					currentTouchPosition.x = currentTouchPosition.y;
					currentTouchPosition.y = dummyX;
				}
				BOOL reverseSwipe = NO;
				if(interfaceOrientation == UIInterfaceOrientationLandscapeRight || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
					reverseSwipe = YES;
				}
				if((!reverseSwipe && ((currentTouchPosition.y - startTouchPosition1.y) >= SWIPE_DRAG_HORIZ_MIN)) || 
				   (reverseSwipe && ((startTouchPosition1.y - currentTouchPosition.y) >= SWIPE_DRAG_HORIZ_MIN))) {
					ignoreMovementEvents = YES;
					//NSLog(@"%f %f", currentTouchPosition.y, startTouchPosition1.y);
					[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:[[PSModuleController defaultModuleController] primaryBible]];
				}
			}
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
//			if([holdTimer isValid]) {
//				[holdTimer invalidate];
//				self.holdTimer = nil;
//			}
			
			if (!movement && (bibleViewController.webView.autoFullscreenMode || ([[event allTouches] count] == 2))) {
				//DLog(@"toggle-fullscreen-tap");
				
				if(bibleEvent) {
					[bibleViewController toggleFullscreen];
				} else {
					[commentaryViewController toggleFullscreen];
				}
			} else if(!movement && bibleEvent && (!bibleViewController.webView.autoFullscreenMode && bibleViewController.isFullScreen)) {
				[bibleViewController switchToNormalscreen];
			} else if(!movement && !bibleEvent && (!commentaryViewController.webView.autoFullscreenMode && commentaryViewController.isFullScreen)) {
				[commentaryViewController switchToNormalscreen];
			}
			
			CGPoint currentTouchPosition = [touch locationInView:self];
			if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
				//switch x & y if in landscape mode
				CGFloat dummyX = currentTouchPosition.x;
				currentTouchPosition.x = currentTouchPosition.y;
				currentTouchPosition.y = dummyX;
			}
			BOOL reverseSwipe = NO;
			if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
				reverseSwipe = YES;
			}
			//DLog(@"\nUITouchPhaseEnded: %f - %f = %f", touch.timestamp, startTouchTime, (touch.timestamp-startTouchTime));

			// Check if it's a swipe
			//DLog(@"%d %f %d %f time: %g",fabsf(startTouchPosition1.x - currentTouchPosition.x) >= SWIPE_DRAG_HORIZ_MIN ? 1 : 0,
			//	 fabsf(startTouchPosition1.y - currentTouchPosition.y),
			//	 fabsf(startTouchPosition1.x - currentTouchPosition.x) > fabsf(startTouchPosition1.y - currentTouchPosition.y)  ? 1 : 0, touch.timestamp - startTouchTime, touch.timestamp - startTouchTime);
			if (([[event allTouches] count] == 1) &&fabsf(startTouchPosition1.x - currentTouchPosition.x) >= SWIPE_DRAG_HORIZ_MIN &&
				fabsf(startTouchPosition1.y - currentTouchPosition.y) <= SWIPE_DRAG_VERT_MAX &&
				fabsf(startTouchPosition1.x - currentTouchPosition.x) > fabsf(startTouchPosition1.y - currentTouchPosition.y) &&
				touch.timestamp - startTouchTime < .7
				) {
				// It appears to be a swipe.
				if ((startTouchPosition1.x < currentTouchPosition.x && !reverseSwipe) || (startTouchPosition1.x > currentTouchPosition.x && reverseSwipe)) {
					if(bibleEvent) {
						DLog(@"bible swipe right");
						[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBibleSwipeRight object:touch];
					} else {
						DLog(@"commentary swipe right");
						[[NSNotificationCenter defaultCenter] postNotificationName:NotificationCommentarySwipeRight object:touch];
					}
				} else {
					if(bibleEvent) {
						DLog(@"bible swipe left");
						[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBibleSwipeLeft object:touch];
					} else {
						DLog(@"commentary swipe left");
						[[NSNotificationCenter defaultCenter] postNotificationName:NotificationCommentarySwipeLeft object:touch];
					}
				}
			}
			
			/* else if(!movement && touchAndHold) {
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
