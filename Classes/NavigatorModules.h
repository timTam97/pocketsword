//
//  NavigatorLevel3.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorSources.h"
#import "PSModuleController.h"
#import "SwordModule.h"

@class NavigatorLeafView;

@interface NavigatorModules : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet UITableView *table;
	IBOutlet NavigatorLeafView *navigatorLeafView;
	NSArray *dataArray;
}

@property (retain, readwrite) NSArray *dataArray;

- (void)reloadTable;
- (void)dealloc;

@end
