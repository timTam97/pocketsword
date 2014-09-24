//
//  PSPreferencesFontTableViewController.m
//  PocketSword
//
//  Created by Nic Carter on 9/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSPreferencesFontTableViewController.h"
#import "PSPreferencesController.h"
#import "PSResizing.h"
#import "globals.h"

@implementation PSPreferencesFontTableViewController

@synthesize moduleName, preferencesController;

- (void)reloadFontStrings {
	if(!fontStrings) {
		fontStrings = [[NSArray arrayWithObjects: 
						//@"Zapfino", 
						//@"Snell Roundhand", 
						//@"Academy Engraved LET", 
						//@"Charis SIL", 
						//@"Padauk", 
						//@"DB LCD Temp", 
						//@"Marker Felt", 
						//@"Bradley Hand", 
						//@"Baskerville", 
						//@"Copperplate", 
					    @"American Typewriter", 
					    @"Arial", 
					    @"Courier", 
					    @"Helvetica Neue",
						@"HelveticaNeue-Light",
					    @"Times New Roman", 
						// specialist ones:
						@"Code2000",
						@"Gentium Plus",
						@"Ezra SIL",
						//the more weird ones....
					    @"AppleGothic",
					    @"Arial Hebrew",
					    @"Arial Rounded MT Bold", 
					    @"Arial Unicode MS", 
						@"Bangla Sangam MN", 
						@"Bodoni 72", 
						@"Cochin",
					    @"Courier New",
						@"Damascus",
						@"Devanagari Sangam MN",
					    @"Geeza Pro",
					    @"Georgia",
						@"Gill Sans",
						@"Gurmukhi MN", 
						@"Gujarati Sangam MN", 
						@"Heiti J",
						@"Heiti K", 
						@"Heiti SC", 
						@"Heiti TC", 
					    @"Helvetica",
						@"Hiragino Kaku Gothic ProN",
						@"Hoefler Text", 
						@"Kailasa", 
						@"Kannada Sangam MN", 
						@"Malayalam Sangam MN",
						@"Marion",
						@"Menlo",
						@"Optima", 
						@"Oriya Sangam MN", 
						@"Sinhala Sangam MN", 
						@"Tamil Sangam MN", 
						@"Telugu Sangam MN",
					    @"Thonburi",
					    @"Trebuchet MS",
					    @"Verdana",
					    nil] retain];
	}
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	self.navigationItem.title = NSLocalizedString(@"FontPreferenceTitle", @"Font");
	[self reloadFontStrings];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	if(!fontStrings) {
		[self reloadFontStrings];
	}
	[self.tableView reloadData];
	NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsFontNamePreference];
	if(self.moduleName)
		font = GetStringPrefForMod(DefaultsFontNamePreference, moduleName);
	if(!font)
		font = PSDefaultFontName;
	
	int pos = [fontStrings indexOfObject:font];
	NSIndexPath *ip = [NSIndexPath indexPathForRow:pos inSection:0];
	[self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
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
	[fontStrings release];
	fontStrings = nil;
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[fontStrings release];
	fontStrings = nil;
	[super viewDidUnload];
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
		font = PSDefaultFontName;
	
    
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
	[preferencesController fontNameChanged:[fontStrings objectAtIndex:indexPath.row]];
	[preferencesController hideFontTableView];
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

