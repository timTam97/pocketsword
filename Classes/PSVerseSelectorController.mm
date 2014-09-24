//
//  PSVerseSelectorController.mm
//  PocketSword
//
//  Created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSVerseSelectorController.h"
#import "globals.h"


@implementation PSVerseSelectorController

@synthesize book;
@synthesize chapter;

- (void)viewWillAppear:(BOOL)animated {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		self.tableView.backgroundColor = [UIColor blackColor];
	} else {
		self.tableView.backgroundColor = [UIColor whiteColor];
	}
	self.navigationItem.title = [NSString stringWithFormat:@"%@ %d", [book name], chapter];
    [super viewWillAppear:animated];
}

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

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
	int verses = [book verses:chapter];
	if(verses < 10)
		return nil;
	for(int i=1;i<=verses;i++) {
		[array addObject:[NSString stringWithFormat:@"%d", i]];
	}
	return array;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [book verses:chapter];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"RefSelectorVerseTitle", @"Verse"), (indexPath.section+1)];
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		cell.textLabel.textColor = [UIColor whiteColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
	}
	
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		cell.backgroundColor = [UIColor blackColor];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//[self dismissModalViewControllerAnimated:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleNavigation object:nil];
	NSMutableDictionary *bcvDict = [NSMutableDictionary dictionary];
	[bcvDict setObject:[book name] forKey:BookNameString];
	[bcvDict setObject:[NSString stringWithFormat:@"%d", chapter] forKey:ChapterString];
	[bcvDict setObject:[NSString stringWithFormat:@"%d", (indexPath.section+1)] forKey:VerseString];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationUpdateSelectedReference object:bcvDict];
}

- (void)dealloc {
	[book release];
    [super dealloc];
}

@end

