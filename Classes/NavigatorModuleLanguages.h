//
//  NavigatorModuleLanguages.h
//  PocketSword
//
//  Created by Nic Carter on 22/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

@class NavigatorModules;
@class PSModuleType;

@interface NavigatorModuleLanguages : UITableViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	PSModuleType *data;
}

@property (retain, readwrite) PSModuleType *data;

- (void)reloadTable;
- (void)dealloc;

@end
