//
//  PSModuleLeafViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "SwordModule.h"
#import "PSModuleController.h"

@interface PSModuleLeafViewController : UIViewController {
	IBOutlet UIWebView *infoWebView;
	IBOutlet PSModuleController *moduleManager;
	IBOutlet UINavigationItem *navBar;
	IBOutlet UITableView *modulesListTable;
	
	IBOutlet UIBarButtonItem *closeButton;
}

//needs a UINavigationBar across the top with:
//	"close" button
//	"trash" button
//	module name as title

//UIWebView with the module info in it.

//perhaps a tab with the version history in it?

- (void)displayInfoForModule:(SwordModule*)swordModule;

- (IBAction)closeLeaf:(id)sender;
- (IBAction)trashModule:(id)sender;

@end
