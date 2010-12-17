//
//  PSPreferencesFontTableViewController.h
//  PocketSword
//
//  Created by Nic Carter on 9/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//


@interface PSPreferencesFontTableViewController : UITableViewController {
	IBOutlet id preferencesController;
	IBOutlet UITableView *table;
	
	NSString *moduleName;
}

@property (retain, readwrite) NSString *moduleName;

@end
