//
//  NavigatorSources.h
//  PocketSword
//
//  Created by Nic Carter on 8/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "PSAddSourceViewController.h"

@interface NavigatorSources : UIViewController  <UINavigationControllerDelegate, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate> {

	IBOutlet id table;
	IBOutlet id refreshButton;
	//IBOutlet PSModuleController *moduleManager;
	IBOutlet id navigatorModuleTypes;
	IBOutlet UITabBarController *tabController;
	IBOutlet PSAddSourceViewController *addSourceViewController;
		
	IBOutlet id manualInstallViewController;
	
}

//@property (readonly) PSModuleController *moduleManager;
@property (readonly) UITabBarController *tabController;

- (IBAction)manualAddModule:(id)sender;
- (void)viewWillAppear:(BOOL)animated;
- (void)addManualInstallButton;
- (IBAction)editButtonPressed:(id)sender;
- (void)resetTableSelection;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)dealloc;
//- (void)navigationController:(UINavigationController *)navController willShowViewController:(UIViewController *)vController animated:(BOOL)animated;
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;

@end
