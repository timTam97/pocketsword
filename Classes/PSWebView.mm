//
//  PSWebView.m
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSWebView.h"
#import "globals.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import <cmath>

@interface PSWebView (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (float)tableViewHeight;
- (void)repositionRefreshHeaderView;
- (float)endOfTableView:(UIScrollView *)scrollView;

@end

#define PULL_THRESHOLD_IPAD -130.0f
#define PULL_THRESHOLD_IPHONE -65.0f


//[psDelegate bottomReloadTriggered:self];
//[psDelegate scrollHappened:self newOffsetY:currentOffsetY];
//if(!reloadTriggered) {
//    if(self.autoFullscreenMode) {
//        [psDelegate switchToFullscreen];
//    }
//}
//[psDelegate topReloadTriggered:self];




@implementation PSWebView

//@synthesize reloading=_reloading;
@synthesize psDelegate, topLength, bottomLength, autoFullscreenMode;


- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	CGFloat newOffY = scrollView.contentOffset.y + topLength;
	if(newOffY < 0) {
		newOffY = 0.0f;
	}
	if(std::abs(currentOffsetY - newOffY) > 2.0f) {
		// ignore tiny changes
		currentOffsetY = newOffY;
		//NSLog(@"new offset: %f (topLength: %f)", currentOffsetY, topLength);
		[psDelegate scrollHappened:self newOffsetY:currentOffsetY];
	}

	CGFloat PULL_THRESHOLD = PULL_THRESHOLD_IPHONE - topLength;
	if([PSResizing iPad]) {
		PULL_THRESHOLD = PULL_THRESHOLD_IPAD - topLength;
	}
	
	[super scrollViewDidScroll:scrollView];
//	if(self.autoFullscreenMode) {
//		// trigger switching to fullscreen.
//		//[psDelegate switchToFullscreen];
//	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	CGFloat PULL_THRESHOLD = PULL_THRESHOLD_IPHONE;
	if([PSResizing iPad]) {
		PULL_THRESHOLD = PULL_THRESHOLD_IPAD;
	}
	BOOL reloadTriggered = NO;
	
	if(!reloadTriggered) {
		if(self.autoFullscreenMode) {
			[psDelegate switchToFullscreen];
		}
		[super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
	}
}

- (void)dataSourceDidFinishLoadingNewData {
	UIScrollView* currentScrollView = nil;
    for (UIView* subView in self.subviews) {
        if ([subView respondsToSelector:@selector(scrollsToTop)]) {//scrollsToTop
			//if ([[subView.class description] isEqualToString:@"UIScrollView"]) {//scrollsToTop
			//DLog(@"subView that seems to work = %@", [subView.class description]);
            currentScrollView = (UIScrollView*)subView;
            [currentScrollView setDelegate:self];
        }
    }
	
	_reloading = NO;
	
	if([currentScrollView respondsToSelector:@selector(setContentInset:)]) {
		[UIView animateWithDuration:0.3 animations:^{
			[currentScrollView setContentInset:UIEdgeInsetsMake(topLength, 0.0f, bottomLength, 0.0f)];
			[currentScrollView setScrollIndicatorInsets:UIEdgeInsetsMake(topLength, 0.0f, bottomLength, 0.0f)];
		}];
	}
	
}

- (float)tableViewHeight {
	return cachedHeight;
}

- (float)endOfTableView:(UIScrollView *)scrollView {
	CGRect svBounds = scrollView.bounds;
	CGSize bSize = svBounds.size;
	CGPoint bOrigin = svBounds.origin;
    return [self tableViewHeight] - bSize.height - bOrigin.y;
}

@end
