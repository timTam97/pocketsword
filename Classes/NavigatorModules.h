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


@interface NavigatorModules : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet id table;
	IBOutlet id navigatorLeafView;
	NSArray *dataArray;
}

@property (retain, readwrite) NSArray *dataArray;

- (void)reloadTable;
- (void)dealloc;

@end
