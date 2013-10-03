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

@property (retain) UIWebView *infoWebView;
@property (retain) SwordModule *swordModule;

//perhaps a tab with the version history in it?

- (void)displayInfoForModule:(SwordModule*)swordModule;

- (void)closeLeaf:(id)sender;
- (void)trashModule:(id)sender;

@end
