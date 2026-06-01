//
//  PSWebView.mm
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSWebView.h"
#import "globals.h"
#import "PSModuleController.h"
#import "PocketSword-Swift.h"
#import <cmath>

@interface PSWebView (Private)

- (void)dataSourceDidFinishLoadingNewData;
- (float)tableViewHeight;
- (void)repositionRefreshHeaderView;
- (float)endOfTableView:(UIScrollView *)scrollView;

@end

#define PULL_THRESHOLD_IPAD -130.0f
#define PULL_THRESHOLD_IPHONE -65.0f

@implementation PSWebView {
	BOOL _reloading;
	float cachedHeight;
	CGFloat currentOffsetY;
}

@synthesize psDelegate, topLength, bottomLength, autoFullscreenMode;

#pragma mark - Initialisation

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
		_wkWebView = [[WKWebView alloc] initWithFrame:self.bounds configuration:config];
		_wkWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_wkWebView.scrollView.delegate = self;
		[self addSubview:_wkWebView];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self) {
		WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
		_wkWebView = [[WKWebView alloc] initWithFrame:self.bounds configuration:config];
		_wkWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_wkWebView.scrollView.delegate = self;
		[self addSubview:_wkWebView];
	}
	return self;
}

#pragma mark - Layout

- (void)layoutSubviews {
	[super layoutSubviews];
	_wkWebView.frame = self.bounds;
}

#pragma mark - Forwarding methods

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
	[_wkWebView loadHTMLString:string baseURL:baseURL];
}

- (UIScrollView *)scrollView {
	return _wkWebView.scrollView;
}

- (void)setDelegate:(id)delegate {
	_wkWebView.navigationDelegate = delegate;
}

- (void)stringByEvaluatingJavaScriptFromString:(NSString *)script {
	[_wkWebView evaluateJavaScript:script completionHandler:nil];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
	[super setBackgroundColor:backgroundColor];
	_wkWebView.backgroundColor = backgroundColor;
	_wkWebView.scrollView.backgroundColor = backgroundColor;
	if (@available(iOS 15.0, *)) {
		_wkWebView.underPageBackgroundColor = backgroundColor;
	}
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	CGFloat newOffY = scrollView.contentOffset.y + topLength;
	if (newOffY < 0) {
		newOffY = 0.0f;
	}
	if (std::abs(currentOffsetY - newOffY) > 2.0f) {
		// ignore tiny changes
		currentOffsetY = newOffY;
		[psDelegate scrollHappened:self newOffsetY:currentOffsetY];
	}

	CGFloat PULL_THRESHOLD = PULL_THRESHOLD_IPHONE - topLength;
	if ([PSResizing iPad]) {
		PULL_THRESHOLD = PULL_THRESHOLD_IPAD - topLength;
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	CGFloat PULL_THRESHOLD = PULL_THRESHOLD_IPHONE;
	if ([PSResizing iPad]) {
		PULL_THRESHOLD = PULL_THRESHOLD_IPAD;
	}
	BOOL reloadTriggered = NO;

	if (!reloadTriggered) {
		if (self.autoFullscreenMode) {
			[psDelegate switchToFullscreen];
		}
	}
}

#pragma mark - Refresh handling

- (void)setupRefreshViews:(CGFloat)top bottom:(CGFloat)bottom {
	self.topLength = top;
	self.bottomLength = bottom;
}

- (void)removeRefreshViews {
	self.topLength = 0.0f;
	self.bottomLength = 0.0f;
}

- (void)dataSourceDidFinishLoadingNewData {
	UIScrollView *currentScrollView = _wkWebView.scrollView;

	_reloading = NO;

	if ([currentScrollView respondsToSelector:@selector(setContentInset:)]) {
		[UIView animateWithDuration:0.3 animations:^{
			[currentScrollView setContentInset:UIEdgeInsetsMake(self->topLength, 0.0f, self->bottomLength, 0.0f)];
			[currentScrollView setScrollIndicatorInsets:UIEdgeInsetsMake(self->topLength, 0.0f, self->bottomLength, 0.0f)];
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
