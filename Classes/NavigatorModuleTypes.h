//
//  NavigatorLevel2.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "MBProgressHUD.h"

@class NavigatorModuleLanguages;

@interface NavigatorModuleTypes : UITableViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource, MBProgressHUDDelegate> {
	NSArray *dataArray;

    NSUInteger bti;
}
@property (retain, readwrite) NSArray *dataArray;

- (void)reloadTable;
- (void)refreshDownloadSource:(id)sender;
- (void)cancelRefreshDownloadSource;

- (void)dealloc;

@end
