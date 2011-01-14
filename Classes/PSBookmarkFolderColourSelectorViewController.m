//
//  PSBookmarkFolderColourSelectorViewController.m
//  PocketSword
//
//  Created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolderColourSelectorViewController.h"
#import "PSBookmarkFolder.h"

@implementation PSBookmarkFolderColourSelectorViewController

@synthesize delegate;

#pragma mark -
#pragma mark Initialization

- (id)initWithColorString:(NSString*)rgbHexString delegate:(id)del {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		currentSelectedColor = rgbHexString;
		selectableColours = [[NSArray alloc] initWithObjects: [UIColor whiteColor], 
							 [UIColor redColor], [UIColor greenColor], [UIColor blueColor], [UIColor cyanColor],
							 [UIColor yellowColor], [UIColor magentaColor], [UIColor orangeColor], [UIColor purpleColor],
							 [UIColor brownColor], nil];
		self.delegate = del;
	}
	return self;
}

#pragma mark -
#pragma mark View lifecycle

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
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
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [selectableColours count];
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	cell.backgroundColor = [selectableColours objectAtIndex:indexPath.row];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
	if([[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]] isEqualToString:[PSBookmarkFolder hexStringFromColor:[UIColor whiteColor]]]) {
		cell.textLabel.text = NSLocalizedString(@"None", @"None");
	} else {
		cell.textLabel.text = @"";
	}
	
	if([[selectableColours objectAtIndex:indexPath.row] isEqualToString:currentSelectedColor]) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[delegate rgbHexColorStringDidChange:[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]]];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
	[selectableColours release];
}


@end

