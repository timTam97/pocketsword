//
//  PSModuleLeafViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//


@class PSModuleSelectorController;
@class SwordModule;

@interface PSModuleInfoViewController : UIViewController {
	UIWebView *infoWebView;
	
	SwordModule *swordModule;
	
	BOOL trashModule, askToUnlock;
}

@property (strong) UIWebView *infoWebView;
@property (strong) SwordModule *swordModule;

//perhaps a tab with the version history in it?

- (void)displayInfoForModule:(SwordModule*)swordModule;

- (void)closeLeaf:(id)sender;
- (void)trashModule:(id)sender;

@end
