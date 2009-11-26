//
//  NavigatorLeafView.h
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ModuleManager.h"
#import "SwordModule.h"


@interface NavigatorLeafView : UIViewController <UINavigationBarDelegate> {
	IBOutlet UITabBarController *tabController;
	//IBOutlet id navigationController;
	IBOutlet id moduleManager;
	IBOutlet id detailsView;

	// Status view
	IBOutlet id statusController;
	IBOutlet id statusTitle;
	IBOutlet id statusText;
	IBOutlet id statusOverallText;
	IBOutlet id statusBar;
	IBOutlet id statusOverallBar;
	
	IBOutlet id moduleTable;//table of modules on the module tab.
	
	SwordModule *module;
}

@property (retain, readwrite) SwordModule *module;

- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;
- (void)showDownloadStatus;
- (void)runInstallation;
- (void)updateInstallationStatus;
- (void)hideOperationStatus;
- (void)dealloc;

@end
