//
//  PSPreferencesModuleSelectorTableViewController.m
//  PocketSword
//
//  Created by Nic Carter on 18/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "PSPreferencesModuleSelectorTableViewController.h"
#import "PSPreferencesController.h"
#import "PSResizing.h"
#import "SwordManager.h"
#import "globals.h"

@implementation PSPreferencesModuleSelectorTableViewController

@synthesize moduleList;
@synthesize currentModule, preferencesController;

- (void)setTableType:(ModuleFeatureRequired)feature {
	tableType = feature;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	switch(tableType) {
		case StrongsGreek:
			self.moduleList = [[SwordManager defaultManager] modulesForFeature: @"GreekDef"];
			self.currentModule = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsGreekModule];
			if(!currentModule)
				self.currentModule = NSLocalizedString(@"None", @"None");
			self.navigationItem.title = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
			moduleChanged = @selector(strongsGreekModuleChanged:);
			[self.tableView reloadData];
			break;
		case StrongsHebrew:
			self.moduleList = [[SwordManager defaultManager] modulesForFeature: @"HebrewDef"];
			self.currentModule = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsHebrewModule];
			if(!currentModule)
				self.currentModule = NSLocalizedString(@"None", @"None");
			self.navigationItem.title = NSLocalizedString(@"PreferencesHebrewModuleTitle", @"Hebrew module");
			moduleChanged = @selector(strongsHebrewModuleChanged:);
			[self.tableView reloadData];
			break;
		case MorphGreek:
			self.moduleList = [[SwordManager defaultManager] modulesForFeature: @"GreekParse"];
			self.currentModule = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsMorphGreekModule];
			if(!currentModule)
				self.currentModule = NSLocalizedString(@"None", @"None");
			self.navigationItem.title = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
			moduleChanged = @selector(morphGreekModuleChanged:);
			[self.tableView reloadData];
			break;
		default:
			break;
//		case MorphHebrew:
//			self.moduleList = [[SwordManager defaultManager] modulesForFeature: @"HebrewParse"];
//			moduleChanged = @selector(strongsGreekModuleChanged:);
//			self.navigationItem.title = @"Hebrew Morphological lexicon:";
//			[table reloadData];
//			break;
	}
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[super viewDidUnload];
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(moduleList)
		return ([moduleList count] + 1);
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch(tableType) {
		case StrongsGreek:
			return NSLocalizedString(@"PreferencesGreekStrongsLexiconTitle", @"Greek Strong's lexicon");
		case StrongsHebrew:
			return NSLocalizedString(@"PreferencesHebrewStrongsLexiconTitle", @"Hebrew Strong's lexicon");
		case MorphGreek:
			return NSLocalizedString(@"PreferencesGreekMorphLexiconTitle", @"Greek Morphological lexicon");
		case MorphHebrew:
			return @"";
	}
	return @"";
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Set up the cell...
	if(indexPath.row == 0) {
		cell.textLabel.text = NSLocalizedString(@"None", @"None");
		cell.detailTextLabel.text = @"";
	} else {
		cell.textLabel.text = [[moduleList objectAtIndex: (indexPath.row - 1)] name];
		cell.detailTextLabel.text = [[moduleList objectAtIndex: (indexPath.row - 1)] descr];
	}
	if([cell.textLabel.text isEqualToString:currentModule])
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryType = UITableViewCellAccessoryNone;
		
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *mod = nil;
	if(indexPath.row == 0) {
		mod = NSLocalizedString(@"None", @"None");
	} else {
		mod = [[moduleList objectAtIndex: (indexPath.row - 1)] name];
	}

	[preferencesController performSelector:moduleChanged withObject: mod];
	[self.navigationController popViewControllerAnimated:YES];
}


- (void)dealloc {
	self.moduleList = nil;
	self.currentModule = nil;
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}


@end

