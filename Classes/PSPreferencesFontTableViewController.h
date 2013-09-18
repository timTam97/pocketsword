//
//  PSPreferencesFontTableViewController.h
//  PocketSword
//
//  Created by Nic Carter on 9/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

@class PSBasePreferencesController;

@interface PSPreferencesFontTableViewController : UITableViewController {
	PSBasePreferencesController *preferencesController;
	
	NSString *moduleName;

	NSArray *fontStrings;
}

@property (retain, readwrite) NSString *moduleName;
@property (assign, readwrite) PSBasePreferencesController *preferencesController;

@end
