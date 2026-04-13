//
//  PSWebView.h
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import <WebKit/WebKit.h>

@class PSWebView;

@protocol PSWebViewDelegate
- (void)topReloadTriggered:(PSWebView*)psWebView;
- (void)bottomReloadTriggered:(PSWebView*)psWebView;
- (void)scrollHappened:(PSWebView*)psWebView newOffsetY:(CGFloat)newOffsetY;
- (void)switchToFullscreen;
@optional
@end

@interface PSWebView : UIView <UIScrollViewDelegate>

@property (nonatomic, strong, readonly) WKWebView *wkWebView;
@property (nonatomic, weak) id<PSWebViewDelegate> psDelegate;
@property CGFloat topLength;
@property CGFloat bottomLength;
@property BOOL autoFullscreenMode;

// Forwarding methods to match UIWebView API used by callers
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (UIScrollView *)scrollView;
- (void)setDelegate:(id)delegate;  // WKNavigationDelegate
- (void)stringByEvaluatingJavaScriptFromString:(NSString *)script; // fire-and-forget wrapper

- (void)dataSourceDidFinishLoadingNewData;
- (void)setupRefreshViews:(CGFloat)top bottom:(CGFloat)bottom;
- (void)removeRefreshViews;

@end
