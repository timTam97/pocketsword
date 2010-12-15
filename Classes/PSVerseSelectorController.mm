//
//  PSVerseSelectorController.mm
//  PocketSword
//
//  Created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSVerseSelectorController.h"
#import "ViewController.h"


@implementation PSVerseSelectorController

@synthesize book;
@synthesize chapter;

- (void)viewWillAppear:(BOOL)animated {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		verseTable.backgroundColor = [UIColor blackColor];
	} else {
		verseTable.backgroundColor = [UIColor whiteColor];
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
    
	cell.textLabel.text = [NSString stringWithFormat:@"%@ %d", NSLocalizedString(@"RefSelectorVerseTitle", @"Verse"), (indexPath.section+1)];
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
	//[ViewController hideModal:self.navigationController.view withTiming:0.3];
	[[viewController tabBarController] dismissModalViewControllerAnimated:YES];
	[viewController updateViewWithSelectedBookName:[book name] chapter:chapter verse:(indexPath.section+1)];
}

- (void)dealloc {
	[book release];
    [super dealloc];
}

@end

