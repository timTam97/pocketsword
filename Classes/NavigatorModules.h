//
//  NavigatorLevel3.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//


@class NavigatorLeafView;

@interface NavigatorModules : UITableViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	NSArray *dataArray;
}

@property (retain, readwrite) NSArray *dataArray;

- (void)reloadTable;
- (void)dealloc;

@end
