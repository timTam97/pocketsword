//
//  SwordInstallNavigationController.h
//  PocketSword
//
//  Created by Nic Carter on 8/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ModuleManager.h"
#import "NavigatorModuleTypes.h"
#import "NavigatorModules.h"
#import "PocketSwordAppDelegate.h"
#import "iPhoneHTTPServerDelegate.h"

@interface SwordInstallNavigationController : UIViewController  <UINavigationControllerDelegate, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {

	IBOutlet id table;
	IBOutlet id refreshButton;
	IBOutlet id moduleManager;
	IBOutlet id navigatorModuleTypes;
	IBOutlet UITabBarController *tabController;
	
	IBOutlet id viewController;
	
	IBOutlet iPhoneHTTPServerDelegate* manualInstallViewController;
	
}

- (id)viewController;

- (IBAction)manualAddModule:(id)sender;
- (void)viewWillAppear:(BOOL)animated;
- (void)addManualInstallButton;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)dealloc;
//- (void)navigationController:(UINavigationController *)navController willShowViewController:(UIViewController *)vController animated:(BOOL)animated;
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;

@end
