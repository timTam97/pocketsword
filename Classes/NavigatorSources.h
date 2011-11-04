//
//  NavigatorSources.h
//  PocketSword
//
//  Created by Nic Carter on 8/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "PSAddSourceViewController.h"

@class NavigatorModuleTypes;

@interface NavigatorSources : UIViewController  <UINavigationControllerDelegate, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate> {

	IBOutlet id table;
	IBOutlet id refreshButton;
	//IBOutlet PSModuleController *moduleManager;
	IBOutlet NavigatorModuleTypes *navigatorModuleTypes;
	IBOutlet UITabBarController *tabController;
	IBOutlet PSAddSourceViewController *addSourceViewController;
		
	IBOutlet id manualInstallViewController;
	BOOL mmmMenuDisplayed;
}

//@property (readonly) PSModuleController *moduleManager;
@property (readonly) UITabBarController *tabController;

- (IBAction)manualAddModule:(id)sender;
- (void)addManualInstallButton;
- (IBAction)editButtonPressed:(id)sender;
- (void)resetTableSelection;

@end

@interface PSStatusController : UIViewController {}
@end