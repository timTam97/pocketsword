//
//  NavigatorModuleLanguages.h
//  PocketSword
//
//  Created by Nic Carter on 22/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSModuleType.h"
#import "NavigatorModules.h"

@interface NavigatorModuleLanguages : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet id table;
	IBOutlet id navigatorModules;
	PSModuleType *data;
	IBOutlet UITabBarController *tabController;
	//IBOutlet id navigationController;
	IBOutlet id moduleManager;
}

@property (retain, readwrite) PSModuleType *data;

- (void)viewWillAppear:(BOOL)animated;
- (void)reloadTable;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)dealloc;

@end
