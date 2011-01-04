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

@interface PSModuleLeafViewController : UIViewController {
	IBOutlet UIWebView			*infoWebView;
	IBOutlet UINavigationItem	*infoNavItem;
	IBOutlet UINavigationBar	*infoNavBar;
	IBOutlet UITabBarItem		*preferencesTabBarItem;
	IBOutlet PSModulePreferencesController *prefController;

	IBOutlet UIBarButtonItem			*closeButton;
	IBOutlet id moduleSelectorController;
	IBOutlet PSModuleUnlockViewController *unlockViewController;
	
	BOOL trashModule, askToUnlock;
}

//needs a UINavigationBar across the top with:
//	"close" button
//	"trash" button
//	module name as title

//UIWebView with the module info in it.

//perhaps a tab with the version history in it?

//- (void)viewWillAppear;
//- (void)viewDidAppear;

- (void)displayInfoForModule:(SwordModule*)swordModule;

- (IBAction)closeLeaf:(id)sender;
- (IBAction)trashModule:(id)sender;

@end
