//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleLeafViewController.h"
#import "SwordModule.h"

@interface PSModuleSelectorController : UIViewController <MBProgressHUDDelegate> {
	ShownTab listType;
	SwordModule *moduleToView;
	UITabBarController			*parentTabBarController;
	IBOutlet PSModuleLeafViewController *leafViewController;
	IBOutlet UITabBarController *leafTabBarController;

	IBOutlet UITableView		*modulesListTable;
	IBOutlet UINavigationItem	*modulesNavigationItem;
	IBOutlet UINavigationBar	*modulesNavigationBar;
	
	IBOutlet UIToolbar			*modulesToolbar;
	
//	BOOL reloadModuleViews;
}

@property (assign) ShownTab listType;
@property (retain, readwrite) SwordModule *moduleToView;
@property (assign) UITabBarController *parentTabBarController;
//@property (assign) BOOL reloadModuleViews;

- (void)addButtonsToToolbar:(BOOL)animated;
- (IBAction)addModuleButtonPressed;
- (IBAction)dismissModuleSelector;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;


@end
