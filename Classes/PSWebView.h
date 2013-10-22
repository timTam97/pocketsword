//
//  PSWebView.h
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

@class EGORefreshTableHeaderView;
@class EGORefreshTableFooterView;
@class PSWebView;

@protocol PSWebViewDelegate
- (void)topReloadTriggered:(PSWebView*)psWebView;
- (void)bottomReloadTriggered:(PSWebView*)psWebView;
- (void)scrollHappened:(PSWebView*)psWebView newOffsetY:(CGFloat)newOffsetY;
- (void)switchToFullscreen;
@optional
@end

@interface PSWebView : UIWebView {
	id<PSWebViewDelegate> psDelegate;

	EGORefreshTableHeaderView *refreshHeaderView;
    EGORefreshTableFooterView *refreshFooterView;
	
	//BOOL _reloadingHeader;
    //BOOL _reloadingFooter;
	BOOL _reloading;
    float cachedHeight;
	
	CGFloat topLength;
	CGFloat bottomLength;
	CGFloat currentOffsetY;
	
	BOOL autoFullscreenMode;
}

@property (nonatomic, assign) id<PSWebViewDelegate> psDelegate;
@property CGFloat topLength;
@property CGFloat bottomLength;
@property BOOL autoFullscreenMode;
//@property(assign,getter=isReloading) BOOL reloading;

- (void)dataSourceDidFinishLoadingNewData;
- (void)setupRefreshViews:(CGFloat)top bottom:(CGFloat)bottom;
- (void)removeRefreshViews;

@end
