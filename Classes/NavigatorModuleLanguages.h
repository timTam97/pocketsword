//
//  NavigatorModuleLanguages.h
//  PocketSword
//
//  Created by Nic Carter on 22/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorSources.h"
@class NavigatorModules;

@interface NavigatorModuleLanguages : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet UITableView *table;
	IBOutlet NavigatorModules *navigatorModules;
	PSModuleType *data;
}

@property (retain, readwrite) PSModuleType *data;

- (void)reloadTable;
- (void)dealloc;

@end
