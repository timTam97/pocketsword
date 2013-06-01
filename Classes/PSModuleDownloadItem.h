//
//  PSModuleDownloadItem.h
//  PocketSword
//
//  Created by Nic Carter on 29/05/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

#import "PSIndexController.h"

@class SwordModule;
@class SwordInstallSource;
@class PSModuleDownloadItem;

@protocol PSModuleDownloadDelegate <NSObject>
@required
// the delegate is responsible for dismissing the PSIndexController :P
- (void)moduleDownloaded:(PSModuleDownloadItem*)sender;
@end

@interface PSModuleDownloadItem : NSObject <PSIndexControllerDelegate, MBProgressHUDDelegate> {
	
	id <PSModuleDownloadDelegate> delegate;

	SwordModule *module;
	SwordInstallSource *sIS;
	UIView *viewForHUD; // if this is nil, when we are done we need to throw up a completion note on the window.
	BOOL downloadStarted;
	BOOL installingIndex;
	BOOL removingHUDViewInProgress;
	
    NSUInteger bti;
	PSIndexController *indexController;
	MBProgressHUD *installModuleHUD;
	NSTimer *installModuleTimer;
}

@property (assign) id <PSModuleDownloadDelegate> delegate;
@property (readonly, assign) BOOL downloadStarted;

- (id)initWithModule:(SwordModule*)swordModule swordInstallSource:(SwordInstallSource*)swordInstallSource viewForHUD:(UIView*)view;
- (void)addViewForHUD:(UIView*)view;
- (void)removeViewForHUD;

- (void)startInstall;
- (NSString*)moduleName;

@end
