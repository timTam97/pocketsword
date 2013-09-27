//
//  PSIndexController.h
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "MBProgressHUD.h"

@class PSIndexController;
@class SwordModule;

@protocol PSIndexControllerDelegate <NSObject>
@required
// the delegate is responsible for dismissing the PSIndexController :P
- (void)indexInstalled:(PSIndexController*)sender;
@end

@interface PSIndexController : NSObject <MBProgressHUDDelegate> {
	
	id <PSIndexControllerDelegate> delegate;

	NSMutableArray *files;
	
	NSMutableData *responseData;
	NSInteger responseDataExpectedLength;
	NSInteger responseDataCurrentLength;
	float installationProgress;
	NSString *moduleToInstall;
	MBProgressHUD *installHUD;
	
	UIView *viewForHUD;
	BOOL promptForDownload;
	BOOL removingHUDViewInProgress;
	
    NSUInteger bti;
}

@property (retain, readwrite) NSMutableArray *files;
@property (nonatomic, assign) id <PSIndexControllerDelegate> delegate;
@property (copy) NSString *moduleToInstall;

- (void)start:(BOOL)modal;

- (void)addViewForHUD:(UIView*)view;
- (void)removeViewForHUD;

- (void)retrieveRemoteIndexList;
- (void)checkForRemoteIndex;
- (void)installSearchIndexForModule;

@end
