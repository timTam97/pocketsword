//
//  PSWebView.h
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

@class PSWebView;

@protocol PSWebViewDelegate
- (void)topReloadTriggered:(PSWebView*)psWebView;
- (void)bottomReloadTriggered:(PSWebView*)psWebView;
- (void)scrollHappened:(PSWebView*)psWebView newOffsetY:(CGFloat)newOffsetY;
- (void)switchToFullscreen;
@optional
@end

@interface PSWebView : UIWebView {
	id<PSWebViewDelegate> __weak psDelegate;

    BOOL _reloading;
    float cachedHeight;
	
	CGFloat topLength;
	CGFloat bottomLength;
	CGFloat currentOffsetY;
	
	BOOL autoFullscreenMode;
}

@property (nonatomic, weak) id<PSWebViewDelegate> psDelegate;
@property CGFloat topLength;
@property CGFloat bottomLength;
@property BOOL autoFullscreenMode;

- (void)dataSourceDidFinishLoadingNewData;
- (void)setupRefreshViews:(CGFloat)top bottom:(CGFloat)bottom;
- (void)removeRefreshViews;

@end
