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

@interface PSWebView (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (float)tableViewHeight;
- (void)repositionRefreshHeaderView;
- (float)endOfTableView:(UIScrollView *)scrollView;

@end

#define PULL_THRESHOLD -130.0f

@implementation PSWebView

@synthesize reloading=_reloading, psDelegate;

- (void)removeRefreshViews {
	refreshFooterView.hidden = YES;
	refreshHeaderView.hidden = YES;
}

- (void)setupRefreshViews {
	[self dataSourceDidFinishLoadingNewData];
	NSString *heightString = [self stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"];
	cachedHeight = [heightString floatValue];

	//DLog(@"resetting cached height; now tis: %f", cachedHeight);
	
	UIScrollView* currentScrollView = nil;
    for (UIView* subView in self.subviews) {
        if ([[subView.class description] isEqualToString:@"UIScrollView"]) {
            currentScrollView = (UIScrollView*)subView;
            currentScrollView.delegate = self;
        }
    }
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		[currentScrollView setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
	} else {
		[currentScrollView setIndicatorStyle:UIScrollViewIndicatorStyleBlack];
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{	
	
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
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	BOOL reloadTriggered = NO;
	
	if (scrollView.contentOffset.y <= PULL_THRESHOLD && !_reloading && !refreshHeaderView.hidden) {
        _reloading = YES;
		[psDelegate topReloadTriggered];
        [refreshHeaderView setState:EGOOPullRefreshLoading];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        scrollView.contentInset = UIEdgeInsetsMake(80.0f, 0.0f, 0.0f, 0.0f);
        [UIView commitAnimations];
		reloadTriggered = YES;
	}
    
    if ([self endOfTableView:scrollView] <= PULL_THRESHOLD && !_reloading && !refreshFooterView.hidden) {
        _reloading = YES;
		[psDelegate bottomReloadTriggered];
        [refreshFooterView setState:EGOOPullRefreshLoading];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 80.0f, 0.0f);
        [UIView commitAnimations];
		reloadTriggered = YES;
	}

	if(!reloadTriggered) {
		if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFullscreenModePreference]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationSwitchToFullscreen object:nil];
		}
		[super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
	}
}

- (void)dataSourceDidFinishLoadingNewData {
	UIScrollView* currentScrollView;
    for (UIView* subView in self.subviews) {
        if ([[subView.class description] isEqualToString:@"UIScrollView"]) {
            currentScrollView = (UIScrollView*)subView;
        }
    }
	
	_reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	[currentScrollView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
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
    return [self tableViewHeight] - scrollView.bounds.size.height - scrollView.bounds.origin.y;
}

- (void)dealloc {
	refreshHeaderView = nil;
	refreshFooterView = nil;
    [super dealloc];
}

@end
