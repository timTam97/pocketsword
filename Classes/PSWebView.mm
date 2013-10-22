//
//  PSWebView.m
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSWebView.h"
#import "globals.h"
#import "EGORefreshTableHeaderView.h"
#import "EGORefreshTableFooterView.h"
#import "PSModuleController.h"
#import "PSResizing.h"

#include <math.h>

@interface PSWebView (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (float)tableViewHeight;
- (void)repositionRefreshHeaderView;
- (float)endOfTableView:(UIScrollView *)scrollView;

@end

#define PULL_THRESHOLD_IPAD -130.0f
#define PULL_THRESHOLD_IPHONE -65.0f

@implementation PSWebView

//@synthesize reloading=_reloading;
@synthesize psDelegate, topLength, bottomLength, autoFullscreenMode;

- (void)removeRefreshViews {
	refreshFooterView.hidden = YES;
	refreshHeaderView.hidden = YES;
}

- (void)setupRefreshViews:(CGFloat)top bottom:(CGFloat)bottom {
	currentOffsetY = 0;
	
	self.topLength = top;
	self.bottomLength = bottom;
	
	if(!NSClassFromString(@"UIPopoverController")) {
		refreshFooterView = nil;
		refreshHeaderView = nil;
		// We're on iOS 3.1.3 or earlier and the refresh views don't seem to work, so disable them for the time being
		return;
	}
	
	[self dataSourceDidFinishLoadingNewData];
	
	UIScrollView* currentScrollView = nil;
    for (UIView* subView in self.subviews) {
        if ([subView respondsToSelector:@selector(scrollsToTop)]) {//scrollsToTop
        //if ([[subView.class description] isEqualToString:@"UIScrollView"]) {//scrollsToTop
			//DLog(@"subView that seems to work = %@", [subView.class description]);
            currentScrollView = (UIScrollView*)subView;
			if([currentScrollView respondsToSelector:@selector(setDelegate:)]) {
				[currentScrollView setDelegate:self];
			}
        }
    }
	
	if(!currentScrollView) {
		refreshFooterView = nil;
		refreshHeaderView = nil;
		ALog(@"cannot find the currentScrollView!");
		return;
	}
	
    NSString *jsCode = @"function documentHeight() {\n\
	var body = document.body,\n\
	html = document.documentElement;\n\
	\n\
	var height = Math.max(	body.scrollHeight, body.offsetHeight, \n\
	html.clientHeight, html.scrollHeight, html.offsetHeight );\n\
	return height;\n\
	}";
    [self stringByEvaluatingJavaScriptFromString:jsCode];
	
	//NSString *heightString = [self stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"];
	NSString *heightString = [self stringByEvaluatingJavaScriptFromString:@"documentHeight();"];
	float heightFromJS = [heightString floatValue];
	cachedHeight = 0.0f;
	if([currentScrollView respondsToSelector:@selector(contentSize)]) {
		cachedHeight = [currentScrollView contentSize].height;
	}
	if(heightFromJS > cachedHeight) {
		cachedHeight = heightFromJS;
	}
	
	//DLog(@"Bible tab: cached height now: %f", cachedHeight);
	
	if([currentScrollView respondsToSelector:@selector(setIndicatorStyle:)]) {
		if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
			[currentScrollView setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
		} else {
			[currentScrollView setIndicatorStyle:UIScrollViewIndicatorStyleBlack];
		}
	}
	
	[refreshHeaderView removeFromSuperview];
	refreshHeaderView = nil;
	[refreshFooterView removeFromSuperview];
	refreshFooterView = nil;
	CGFloat rectWidth = self.frame.size.width;
	
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.bounds.size.height, rectWidth, self.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[currentScrollView addSubview:refreshHeaderView];
	//currentScrollView.showsVerticalScrollIndicator = YES;
	[refreshHeaderView release];
    
	refreshFooterView = [[EGORefreshTableFooterView alloc] initWithFrame:CGRectMake(0.0f, [self tableViewHeight], rectWidth, 600.0f)];
	refreshFooterView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[currentScrollView addSubview:refreshFooterView];
	//currentScrollView.showsVerticalScrollIndicator = YES;
	[refreshFooterView release];

	NSString *currentRef = [PSModuleController getCurrentBibleRef];
	if ([currentRef isEqualToString: [PSModuleController getLastRefAvailable]]) {
		//DLog(@"last: %@", currentRef);
		refreshFooterView.hidden = YES;
	} else if([currentRef isEqualToString: [PSModuleController getFirstRefAvailable]]) {
		//DLog(@"first: %@", currentRef);
		refreshHeaderView.hidden = YES;
	} else {
		//DLog(@"not last or first: %@", currentRef);
	}

}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	CGFloat newOffY = scrollView.contentOffset.y + topLength;
	if(newOffY < 0) {
		newOffY = 0.0f;
	}
	if(fabsf(currentOffsetY - newOffY) > 2.0f) {
		// ignore tiny changes
		currentOffsetY = newOffY;
		//NSLog(@"new offset: %f (topLength: %f)", currentOffsetY, topLength);
		[psDelegate scrollHappened:self newOffsetY:currentOffsetY];
	}

	CGFloat PULL_THRESHOLD = PULL_THRESHOLD_IPHONE - topLength;
	if([PSResizing iPad]) {
		PULL_THRESHOLD = PULL_THRESHOLD_IPAD - topLength;
	}
	
	if (scrollView.isDragging) {
		if (refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > PULL_THRESHOLD && scrollView.contentOffset.y < 0.0f && !_reloading && !refreshHeaderView.hidden) {
			[refreshHeaderView setState:EGOOPullRefreshNormal];
		} else if (refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < PULL_THRESHOLD && !_reloading && !refreshHeaderView.hidden) {
			[refreshHeaderView setState:EGOOPullRefreshPulling];
		}
        
        float endOfTable = [self endOfTableView:scrollView];
        if (refreshFooterView.state == EGOOPullRefreshPulling && endOfTable < 0.0f && endOfTable > PULL_THRESHOLD && !_reloading && !refreshFooterView.hidden) {
			[refreshFooterView setState:EGOOPullRefreshNormal];
		} else if (refreshFooterView.state == EGOOPullRefreshNormal && endOfTable < PULL_THRESHOLD && !_reloading && !refreshFooterView.hidden) {
			[refreshFooterView setState:EGOOPullRefreshPulling];
		}
	}
	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
		[super scrollViewDidScroll:scrollView];
	}
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
	
	if (scrollView.contentOffset.y <= (PULL_THRESHOLD - topLength) && !_reloading && !refreshHeaderView.hidden) {
        _reloading = YES;
		[psDelegate topReloadTriggered:self];
        [refreshHeaderView setState:EGOOPullRefreshLoading];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        scrollView.contentInset = UIEdgeInsetsMake(80.0f, 0.0f, 0.0f, 0.0f);
        [UIView commitAnimations];
		reloadTriggered = YES;
	}
    
    if ([self endOfTableView:scrollView] <= (PULL_THRESHOLD - bottomLength) && !_reloading && !refreshFooterView.hidden) {
        _reloading = YES;
		[psDelegate bottomReloadTriggered:self];
        [refreshFooterView setState:EGOOPullRefreshLoading];
//        [UIView beginAnimations:nil context:NULL];
//        [UIView setAnimationDuration:0.2];
//        scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 80.0f, 0.0f);
//        [UIView commitAnimations];
		reloadTriggered = YES;
	}

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
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.3];
//		[currentScrollView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
		[currentScrollView setContentInset:UIEdgeInsetsMake(topLength, 0.0f, bottomLength, 0.0f)];
		[currentScrollView setScrollIndicatorInsets:UIEdgeInsetsMake(topLength, 0.0f, bottomLength, 0.0f)];
		//currentScrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
		[UIView commitAnimations];
	}
	
    if ([refreshHeaderView state] != EGOOPullRefreshNormal) {
        [refreshHeaderView setState:EGOOPullRefreshNormal];
        //[refreshHeaderView setCurrentDate];  //  should check if data reload was successful 
    }
    
    if ([refreshFooterView state] != EGOOPullRefreshNormal) {
        [refreshFooterView setState:EGOOPullRefreshNormal];
        //[refreshFooterView setCurrentDate];  //  should check if data reload was successful 
    }
}

- (float)tableViewHeight {
	return cachedHeight;
}

- (void)repositionRefreshHeaderView {
    refreshFooterView.center = CGPointMake(160.0f, [self tableViewHeight] + 300.0f);
}

- (float)endOfTableView:(UIScrollView *)scrollView {
	CGRect svBounds = scrollView.bounds;
	CGSize bSize = svBounds.size;
	CGPoint bOrigin = svBounds.origin;
    return [self tableViewHeight] - bSize.height - bOrigin.y;
}

- (void)dealloc {
	refreshHeaderView = nil;
	refreshFooterView = nil;
    [super dealloc];
}

@end
