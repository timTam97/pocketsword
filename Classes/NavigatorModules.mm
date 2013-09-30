//
//  NavigatorLevel3.mm
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorModules.h"
#import "NavigatorLeafView.h"
#import "PSResizing.h"
#import "NavigatorSources.h"
#import "PSModuleController.h"
#import "SwordModule.h"
#import "SwordManager.h"

@implementation NavigatorModules

@synthesize dataArray;

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
//	NSMutableArray *modules = [self.dataArray mutableCopy];
//	BOOL resetArray = NO;
//	for(int i=0;i<[modules count];i++) {
//		if([[(SwordModule*)[modules objectAtIndex:i] name] isEqualToString:@"ESV"]) {
//			[modules removeObjectAtIndex: i];
//			resetArray = YES;
//			break;
//		}
//	}
//	if(resetArray)
//		self.dataArray = modules;
//	[modules release];
	[self.tableView reloadData];	// populate our table's data
	if(tableSelection) {
		[self.tableView selectRowAtIndexPath:tableSelection animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		[self.tableView deselectRowAtIndexPath:tableSelection animated:YES];
	}
}

- (void)reloadTable {
	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [dataArray count];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"lvl3-id"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"lvl3-id"] autorelease];
	}
	
	cell.textLabel.text = [(SwordModule*)[dataArray objectAtIndex:indexPath.row] name];
	cell.detailTextLabel.text = [(SwordModule*)[dataArray objectAtIndex:indexPath.row] descr];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	if ([[[PSModuleController defaultModuleController] swordManager] isModuleInstalled: cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor blueColor];
		cell.detailTextLabel.textColor = [UIColor blueColor];
	} else if([(SwordModule*)[dataArray objectAtIndex:indexPath.row] isLocked]) {
		cell.textLabel.textColor = [UIColor brownColor];
		cell.detailTextLabel.textColor = [UIColor brownColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.textColor = [UIColor blackColor];
	}
	
	return cell;
	
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NavigatorLeafView *leafView = [[NavigatorLeafView alloc] initWithNibName:nil bundle:nil];
	[leafView setModule:(SwordModule*)[dataArray objectAtIndex:indexPath.row]];
	[self.navigationController pushViewController:leafView animated:YES];
	[leafView release];
}


- (void)dealloc {
	[dataArray release];
	[super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

@end
