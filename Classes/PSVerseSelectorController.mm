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
	self.tableView.backgroundColor = [UIColor systemBackgroundColor];
	self.navigationItem.title = [NSString stringWithFormat:@"%@ %d", [book name], (int)chapter];
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

#pragma mark Table view methods

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	NSMutableArray *array = [[NSMutableArray alloc] init];
	int verses = (int)[book verses:chapter];
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
	cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"RefSelectorVerseTitle", @"Verse"), (indexPath.section+1)];
	cell.textLabel.textColor = [UIColor labelColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	cell.backgroundColor = [UIColor systemBackgroundColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//[self dismissModalViewControllerAnimated:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleNavigation object:nil];
	NSMutableDictionary *bcvDict = [NSMutableDictionary dictionary];
	[bcvDict setObject:[book name] forKey:BookNameString];
	[bcvDict setObject:[NSString stringWithFormat:@"%d", (int)chapter] forKey:ChapterString];
	[bcvDict setObject:[NSString stringWithFormat:@"%d", (int)(indexPath.section+1)] forKey:VerseString];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationUpdateSelectedReference object:bcvDict];
}


@end

