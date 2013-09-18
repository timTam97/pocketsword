//
//  PSPreferencesController.h
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "ViewController.h"
#import "PSModuleController.h"
#import "PSAboutScreenController.h"
#import "PSBasePreferencesController.h"

@interface PSPreferencesController : PSBasePreferencesController {
	
	IBOutlet UITabBarItem *preferencesTabBarItem;
	IBOutlet UITabBarController *tabController;
	IBOutlet id moduleSelectorTableViewController;
	
	UILabel *fontSizeLabel;
	IBOutlet UITableView *preferencesTableView;
}

//- (void)fullscreenModeChanged:(UISwitch *)sender;
//- (void)displayStrongsChanged:(UISwitch *)sender;
//- (void)displayMorphChanged:(UISwitch *)sender;
//- (void)displayGreekAccentsChanged:(UISwitch *)sender;
//- (void)displayHVPChanged:(UISwitch *)sender;
//- (void)displayHebrewCantillationChanged:(UISwitch *)sender;
//- (void)morphGreekModuleChanged:(NSString *)newModule;
//- (void)strongsGreekModuleChanged:(NSString *)newModule;
//- (void)strongsHebrewModuleChanged:(NSString *)newModule;
//- (void)xrefChanged:(UISwitch *)sender;
//- (void)footnotesChanged:(UISwitch *)sender;
//- (void)fontSizeChanged:(UISlider *)sender;
//- (void)nightModeChanged:(UISwitch *)sender;
//- (void)redLetterChanged:(UISwitch *)sender;
//- (void)fontNameChanged:(NSString *)newFont;
//- (void)insomniaModeChanged:(UISwitch *)sender;
//- (void)moduleMaintainerModeChanged:(UISwitch *)sender;

@end
