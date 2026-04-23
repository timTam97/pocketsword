//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"

@class SwordModule;

@interface PSModuleSelectorController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	ShownTab				listType;

	UITableView				*modulesListTable;
}

@property (assign) ShownTab listType;
@property (strong) UITableView *modulesListTable;

- (void)dismissModuleSelector;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;


@end
