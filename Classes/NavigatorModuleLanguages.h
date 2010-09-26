//
//  NavigatorModuleLanguages.h
//  PocketSword
//
//  Created by Nic Carter on 22/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorSources.h"

@interface NavigatorModuleLanguages : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet id table;
	IBOutlet id navigatorModules;
	PSModuleType *data;
	//IBOutlet UITabBarController *tabController;
	IBOutlet NavigatorSources *navigatorSources;
}

@property (retain, readwrite) PSModuleType *data;

- (void)reloadTable;
- (void)dealloc;

@end
