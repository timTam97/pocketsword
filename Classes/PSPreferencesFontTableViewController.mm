//
//  PSPreferencesFontTableViewController.m
//  PocketSword
//
//  Created by Nic Carter on 9/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSPreferencesFontTableViewController.h"
#import "PSPreferencesController.h"


@implementation PSPreferencesFontTableViewController

//@synthesize preferencesController;

NSArray *fontStrings;


- (void)viewDidLoad {
    [super viewDidLoad];
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	self.navigationItem.title = NSLocalizedString(@"FontPreferenceTitle", @"Font");
	if(!fontStrings) {
		fontStrings = [[NSArray arrayWithObjects: 
					   @"American Typewriter", 
					   @"AppleGothic", 
					   @"Arial", 
					   @"Arial Hebrew", 
					   @"Arial Rounded MT Bold", 
					   @"Arial Unicode MS", 
					   @"Courier", 
					   @"Courier New", 
					   @"DB LCD Temp", 
					   @"Georgia", 
					   @"Geeza Pro", 
					   @"Heiti J", 
					   @"Heiti K", 
					   @"Heiti SC", 
					   @"Heiti TC", 
					   @"Helvetica",
					   @"Helvetica Neue", 
					   @"Hiragino Kaku Gothic ProN", 
					   //@"Marker Felt", 
					   @"Times New Roman", 
					   @"Thonburi", 
					   @"Trebuchet MS", 
					   @"Verdana", 
					   @"Zapfino", 
					   nil] retain];
	}
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[table reloadData];
	NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontNamePreference"];
	if(!font)
		font = @"Helvetica";
	
	int pos = [fontStrings indexOfObject:font];
	NSIndexPath *ip = [NSIndexPath indexPathForRow:pos inSection:0];
	[table scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

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

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [fontStrings count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontNamePreference"];
	if(!font)
		font = @"Helvetica";
	
    NSString *CellIdentifier = [NSString stringWithFormat:@"fontPreferencesTable-%d", indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
	cell.textLabel.text = [fontStrings objectAtIndex:indexPath.row];
	cell.textLabel.font = [UIFont fontWithName: [fontStrings objectAtIndex:indexPath.row] size:15.0];

	if([font isEqualToString:cell.textLabel.text])
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[(PSPreferencesController*)preferencesController fontNameChanged:[fontStrings objectAtIndex:indexPath.row]];
	[self.navigationController popViewControllerAnimated:YES];
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


- (void)dealloc {
    [super dealloc];
	[fontStrings release];
}


@end

