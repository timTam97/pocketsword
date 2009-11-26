//
//  NavigatorLevel3.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ModuleManager.h"
#import <Foundation/Foundation.h>
#import "NavigatorLeafView.h"
#import "SwordModule.h"


@interface NavigatorModules : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet id table;
	IBOutlet id navigatorLeafView;
	NSArray *dataArray;
	IBOutlet UITabBarController *tabController;
	//IBOutlet id navigationController;
	IBOutlet id moduleManager;
}

@property (retain, readwrite) NSArray *dataArray;

- (void)viewWillAppear:(BOOL)animated;
- (void)reloadTable;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)dealloc;

@end
