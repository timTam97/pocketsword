//
//  PSWebView.h
//  PocketSword
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

@class EGORefreshTableHeaderView;
@class EGORefreshTableFooterView;

@protocol PSWebViewDelegate
- (void)topReloadTriggered;
- (void)bottomReloadTriggered;
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
}

@property (nonatomic, assign) id<PSWebViewDelegate> psDelegate;
//@property(assign,getter=isReloading) BOOL reloading;

- (void)dataSourceDidFinishLoadingNewData;
- (void)setupRefreshViews;
- (void)removeRefreshViews;

@end
