//
//  PSModuleLeafViewController.h
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//


#import <WebKit/WebKit.h>

@class PSModuleSelectorController;
@class SwordModule;

@interface PSModuleInfoViewController : UIViewController {
	WKWebView *infoWebView;

	SwordModule *swordModule;

	BOOL askToUnlock;
}

@property (strong) WKWebView *infoWebView;
@property (strong) SwordModule *swordModule;

//perhaps a tab with the version history in it?

- (void)displayInfoForModule:(SwordModule*)swordModule;

- (void)closeLeaf:(id)sender;
- (void)trashModule:(id)sender;

@end
