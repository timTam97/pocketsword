//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "ViewController.h"
#import "PSModuleLeafViewController.h"

@interface PSModuleSelectorController : NSObject {
	ShownTab listType;
	IBOutlet PSModuleLeafViewController *leafViewController;

	IBOutlet id moduleManager;
	IBOutlet id viewController;
}

@property (assign) ShownTab listType;

@end
