//
//  PSPreferencesController.h
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ViewController.h"
#import "PSModuleController.h"
#import "PSAboutScreenController.h"
//#import "PSPreferencesFontTableViewController.h"


@interface PSPreferencesController : UIViewController {
	
	IBOutlet UITableView *preferencesTable;
	IBOutlet ViewController *viewController;
	IBOutlet PSModuleController *moduleManager;
	IBOutlet UITabBarController *tabController;
	IBOutlet id fontTableViewController;
	IBOutlet PSAboutScreenController *aboutScreenController;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)fontSizeChanged:(UISlider *)sender;
- (void)nightModeChanged:(UISwitch *)sender;
- (void)redLetterChanged:(UISwitch *)sender;
- (void)fontNameChanged:(NSString *)newFont;
- (void)insomniaModeChanged:(UISwitch *)sender;
- (void)moduleMaintainerModeChanged:(UISwitch *)sender;

//- (IBAction)infoButtonPressed:(id)sender;

@end
