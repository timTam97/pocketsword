//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"
#import "MBProgressHUD.h"

@class PSModuleInfoViewController;
@class SwordModule;

@interface PSModuleSelectorController : UIViewController <MBProgressHUDDelegate, UITableViewDataSource, UITableViewDelegate> {
	ShownTab				listType;

	UITableView				*modulesListTable;
	UIToolbar				*modulesToolbar;
}

@property (assign) ShownTab listType;
@property (retain) UITableView *modulesListTable;
@property (retain) UIToolbar *modulesToolbar;

- (void)addButtonsToToolbar:(BOOL)animated;
- (void)addModuleButtonPressed;
- (void)dismissModuleSelector;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;


@end
