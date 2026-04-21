//
//  PSModuleDownloadItem.h
//  PocketSword
//
//  Created by Nic Carter on 29/05/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

#import "MBProgressHUD.h"

@class SwordModule;
@class SwordInstallSource;
@class PSModuleDownloadItem;

@protocol PSModuleDownloadDelegate <NSObject>
@required
- (void)moduleDownloaded:(PSModuleDownloadItem*)sender;
@end

@interface PSModuleDownloadItem : NSObject <MBProgressHUDDelegate> {

	id <PSModuleDownloadDelegate> __weak delegate;

	SwordModule *module;
	SwordInstallSource *sIS;
	UIView *viewForHUD; // if this is nil, when we are done we need to throw up a completion note on the window.
	BOOL downloadStarted;
	BOOL installingIndex;
	BOOL removingHUDViewInProgress;

    NSUInteger bti;
	MBProgressHUD *installModuleHUD;
	NSTimer *installModuleTimer;
}

@property (weak) id <PSModuleDownloadDelegate> delegate;
@property (readonly, assign) BOOL downloadStarted;

- (id)initWithModule:(SwordModule*)swordModule swordInstallSource:(SwordInstallSource*)swordInstallSource viewForHUD:(UIView*)view;
- (void)addViewForHUD:(UIView*)view;
- (void)removeViewForHUD;

- (void)startInstall;
- (NSString*)moduleName;

@end
