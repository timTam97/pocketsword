//
//  NavigatorModuleLanguages.mm
//  PocketSword
//
//  Created by Nic Carter on 22/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorSources.h"
#import "NavigatorModuleLanguages.h"
#import "NavigatorModules.h"
#import "PSResizing.h"
#import "PSModuleType.h"

@implementation NavigatorModuleLanguages

@synthesize data;

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:tableSelection animated:YES];
}

- (void)reloadTable {
	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [[data moduleLanguages] count];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return NSLocalizedString(@"ModuleLanguagesHeaderText", @"");
	//return @"";
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"lvl4-id"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"lvl4-id"] autorelease];
	}
	
	cell.textLabel.text = [[data.moduleLanguages objectAtIndex:indexPath.row] descr];
	//cell.detailTextLabel.text = [(SwordModule*)[dataArray objectAtIndex:indexPath.row] descr];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
	
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NavigatorModules *modulesList = [[NavigatorModules alloc] initWithStyle:UITableViewStyleGrouped];
	[modulesList setDataArray:[data.modules objectAtIndex:indexPath.row]];
	modulesList.title = [[data.moduleLanguages objectAtIndex:indexPath.row] descr];
	[modulesList reloadTable];
	[self.navigationController pushViewController:modulesList animated:YES];
	[modulesList release];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}


- (void)dealloc {
	[data release];
	[super dealloc];
}
@end
