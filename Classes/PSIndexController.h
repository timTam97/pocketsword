//
//  PSIndexController.h
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "SwordModule.h"
#import "MBProgressHUD.h"

@class PSSearchController;

@protocol PSIndexControllerDelegate <NSObject>
@required
// the delegate is responsible for dismissing the PSIndexController :P
- (void)indexInstalled:(BOOL)success;
@end

@interface PSIndexController : UIViewController <MBProgressHUDDelegate> {
	
	id <PSIndexControllerDelegate> delegate;

	//PSSearchController *searchController;

	NSMutableArray *files;
	
	NSMutableData *responseData;
	NSInteger responseDataExpectedLength;
	NSInteger responseDataCurrentLength;
	float installationProgress;
	NSString *moduleToInstall;
	MBProgressHUD *installHUD;
	
    NSUInteger bti;
}

@property (retain, readwrite) NSMutableArray *files;
@property (nonatomic, assign) id <PSIndexControllerDelegate> delegate;
@property (copy) NSString *moduleToInstall;

- (void)updateInstalledIndexListWithRemoteIndices;
- (void)updateInstalledIndexList;
- (void)installSearchIndexForModule;

@end
