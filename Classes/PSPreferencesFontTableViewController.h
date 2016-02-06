//
//  PSPreferencesFontTableViewController.h
//  PocketSword
//
//  Created by Nic Carter on 9/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

@class PSBasePreferencesController;

@interface PSPreferencesFontTableViewController : UITableViewController {
	PSBasePreferencesController *__weak preferencesController;
	
	NSString *moduleName;

	NSArray *fontStrings;
}

@property (strong, readwrite) NSString *moduleName;
@property (weak, readwrite) PSBasePreferencesController *preferencesController;

@end
