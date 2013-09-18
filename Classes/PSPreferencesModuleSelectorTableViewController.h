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

@class PSPreferencesController;

@interface PSPreferencesModuleSelectorTableViewController : UITableViewController {
	PSPreferencesController *preferencesController;
	
	ModuleFeatureRequired tableType;
	NSArray *moduleList;
	NSString *currentModule;
	SEL moduleChanged;
}

@property (retain) NSArray *moduleList;
@property (retain) NSString *currentModule;
@property (assign, readwrite) PSPreferencesController *preferencesController;

- (void)setTableType:(ModuleFeatureRequired)feature;

@end
