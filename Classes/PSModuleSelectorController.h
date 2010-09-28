//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleLeafViewController.h"

@interface PSModuleSelectorController : UIViewController {
	ShownTab listType;
	IBOutlet PSModuleLeafViewController *leafViewController;

	IBOutlet UITableView		*modulesListTable;
	IBOutlet UINavigationItem	*modulesNavigationItem;
	IBOutlet UINavigationBar	*modulesNavigationBar;
}

@property (assign) ShownTab listType;

- (IBAction)addModuleButtonPressed;
- (IBAction)dismissModuleSelector;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;


@end
