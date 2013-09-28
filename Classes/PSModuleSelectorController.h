//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"
#import "MBProgressHUD.h"

@class PSModuleLeafViewController;
@class PSModulePreferencesController;
@class SwordModule;

@interface PSModuleSelectorController : UIViewController <MBProgressHUDDelegate, UITableViewDataSource, UITableViewDelegate> {
	ShownTab listType;
	UITabBarController			*parentTabBarController;
	IBOutlet PSModuleLeafViewController *leafViewController;
	IBOutlet PSModulePreferencesController *preferencesViewController;
	IBOutlet UITabBarController *leafTabBarController;

	IBOutlet UITableView		*modulesListTable;
	
	IBOutlet UIToolbar			*modulesToolbar;
	
//	BOOL reloadModuleViews;
}

@property (assign) ShownTab listType;
@property (assign) UITabBarController *parentTabBarController;
//@property (assign) BOOL reloadModuleViews;

- (void)addButtonsToToolbar:(BOOL)animated;
- (IBAction)addModuleButtonPressed;
- (IBAction)dismissModuleSelector;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;


@end
