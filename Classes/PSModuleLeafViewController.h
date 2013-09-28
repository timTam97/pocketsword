//
//  PSModuleLeafViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "SwordModule.h"
#import "PSModuleController.h"
#import "PSModulePreferencesController.h"
#import "PSModuleUnlockViewController.h"

@class PSModuleSelectorController;

@interface PSModuleLeafViewController : UIViewController {
	IBOutlet UIWebView						*infoWebView;

	IBOutlet PSModuleUnlockViewController	*unlockViewController;
	
	BOOL trashModule, askToUnlock;
}

//perhaps a tab with the version history in it?

- (void)displayInfoForModule:(SwordModule*)swordModule;

- (IBAction)closeLeaf:(id)sender;
- (IBAction)trashModule:(id)sender;

@end
