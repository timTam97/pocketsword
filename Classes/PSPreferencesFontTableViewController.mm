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

@synthesize moduleName;


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
					   //@"DB LCD Temp", 
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
					   //@"Zapfino", 
						//@"Snell Roundhand", 
						//@"Academy Engraved LET", 
						//@"Charis SIL", 
						//@"Padauk", 
						@"Code2000", 
						@"Gurmukhi MN", 
						@"Malayalam Sangam MN", 
						//@"Bradley Hand", 
						@"Kannada Sangam MN", 
						@"Bodoni 72", 
						@"Cochin", 
						@"Sinhala Sangam MN", 
						@"Hoefler Text", 
						@"Optima", 
						@"Gujarati Sangam MN", 
						@"Devanagari Sangam MN", 
						@"Kailasa", 
						@"Telugu Sangam MN",
						//@"Baskerville", 
						//@"Copperplate", 
						@"Bangla Sangam MN", 
						@"Tamil Sangam MN", 
						@"Gill Sans", 
						@"Oriya Sangam MN", 
					   nil] retain];
	}
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[table reloadData];
	NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsFontNamePreference];
	if(self.moduleName)
		font = GetStringPrefForMod(DefaultsFontNamePreference, moduleName);
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

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[fontStrings release];
	fontStrings = nil;
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
    static NSString *CellIdentifier = @"fontPreferencesTable";
    
	NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsFontNamePreference];
	if(self.moduleName)
		font = GetStringPrefForMod(DefaultsFontNamePreference, moduleName);
	if(!font)
		font = @"Helvetica";
	
    
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
	[(PSBasePreferencesController*)preferencesController fontNameChanged:[fontStrings objectAtIndex:indexPath.row]];
	[(PSBasePreferencesController*)preferencesController hideFontTableView];
	//[self.navigationController popViewControllerAnimated:YES];
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
	[fontStrings release];
	self.moduleName = nil;
    [super dealloc];
}


@end

