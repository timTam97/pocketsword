//
//  PSModuleSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

@interface PSModuleSelectorController : NSObject {
	ShownTab listType;

	IBOutlet id moduleManager;
	IBOutlet id viewController;
}

@property (assign) ShownTab listType;

@end
