//
//  NavigatorLevel2.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "NavigatorSources.h"
#import "MBProgressHUD.h"

@class NavigatorModuleLanguages;

@interface NavigatorModuleTypes : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource, MBProgressHUDDelegate> {
	IBOutlet UITableView *table;
	IBOutlet NavigatorModuleLanguages *navigatorModuleLanguages;
	NSArray *dataArray;
	//IBOutlet NavigatorSources *navigatorSources;

    NSUInteger bti;
}
@property (retain, readwrite) NSArray *dataArray;

- (void)reloadTable;
- (IBAction)refreshDownloadSource:(id)sender;
- (IBAction)cancelRefreshDownloadSource;

- (void)dealloc;

@end
