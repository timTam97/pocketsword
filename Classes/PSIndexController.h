//
//  PSIndexController.h
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSModuleController.h"

@interface PSIndexController : NSObject {
	PSModuleController *moduleManager;

	NSArray *downloadableIndices;
	NSArray *installedIndices;
	NSArray *noAvailableIndices;
	
}

@property (retain, readwrite) NSArray *downloadableIndices;
@property (retain, readwrite) NSArray *installedIndices;
@property (retain, readwrite) NSArray *noAvailableIndices;
@property (retain, readwrite) PSModuleController *moduleManager;

- (BOOL)updateInstalledIndexListWithRemoteIndices;
- (void)updateInstalledIndexList;


@end
