//
//  PSPreferencesModuleSelectorTableViewController.h
//  PocketSword
//
//  Created by Nic Carter on 18/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

typedef enum {
	StrongsGreek = 0,
	StrongsHebrew,
	MorphGreek,
	MorphHebrew
} ModuleFeatureRequired;


@interface PSPreferencesModuleSelectorTableViewController : UITableViewController {
	IBOutlet id preferencesController;
	IBOutlet UITableView *table;
	
	ModuleFeatureRequired tableType;
	NSArray *moduleList;
	NSString *currentModule;
	SEL moduleChanged;
}

@property (retain) NSArray *moduleList;
@property (retain) NSString *currentModule;

- (void)setTableType:(ModuleFeatureRequired)feature;

@end
