//
//  PSBookmarkFolderColourSelectorViewController.m
//  PocketSword
//
//  Created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

/* possible new colours (20130701)
 Blue: BBDDFF
 Brown: AA8866
 Green: BBFFBB
 Orange: FFCC99
 Pink: FFBBDD
 Purple: CCAAFF
 Red: FF7777 (1.0, 0.47, 0.47, 0.8)
 Turquoise: 99DDDD
 Yellow: FFFFCC (1.0, 1.0, 0.8, 0.8)
*/

#import "PSBookmarkFolderColourSelectorViewController.h"
#import "PSBookmarkFolder.h"
#import "PSResizing.h"

@implementation PSBookmarkFolderColourSelectorViewController

@synthesize delegate, currentSelectedColor, selectableColours;

#pragma mark -
#pragma mark Initialization

- (id)initWithColorString:(NSString*)rgbHexString delegate:(id)del {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.currentSelectedColor = rgbHexString;
		NSArray *colours = [[NSArray alloc] initWithObjects: [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0], 
							[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.8], // red
							[UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.8], // green
							[UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.8], // blue
							[UIColor colorWithRed:0.0 green:1.0 blue:1.0 alpha:0.8], // Turquoise
							[UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:0.8], // yellow
							[UIColor colorWithRed:1.0 green:0.0 blue:1.0 alpha:0.8], // pink
							[UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:0.8], // orange
							[UIColor colorWithRed:0.5 green:0.0 blue:0.5 alpha:0.8], // magenta?/purple
							[UIColor colorWithRed:0.6 green:0.4 blue:0.2 alpha:0.8], // brown
							nil];
		self.selectableColours = colours;
		[colours release];
		self.delegate = del;
		NSString *ourTitle = NSLocalizedString(@"BookmarksAddFolderHighlightColour", @"");
		if(([ourTitle length] > 0) && ([ourTitle characterAtIndex:([ourTitle length]-1)] == ':')) {
			ourTitle = [ourTitle substringToIndex:([ourTitle length] - 1)];
		}
		self.navigationItem.title = ourTitle;
	}
	return self;
}

#pragma mark -
#pragma mark View lifecycle

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
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

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
	if([[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]] isEqualToString:[PSBookmarkFolder hexStringFromColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0]]]) {
		cell.textLabel.text = NSLocalizedString(@"None", @"None");//[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]];
	} else {
		cell.textLabel.text = @"";//[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]];
	}
	
	if((!currentSelectedColor && indexPath.row == 0) || [[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]] isEqualToString:currentSelectedColor]) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.row != 0) {
		[delegate rgbHexColorStringDidChange:[PSBookmarkFolder hexStringFromColor:[selectableColours objectAtIndex:indexPath.row]]];
	} else {
		[delegate rgbHexColorStringDidChange:nil];
	}
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
	[super viewDidUnload];
}


- (void)dealloc {
	self.selectableColours = nil;
	self.currentSelectedColor = nil;
    [super dealloc];
}


@end

