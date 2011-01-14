//
//  PSBookmarkFolderAddViewController.m
//  PocketSword
//
//  Created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolderAddViewController.h"
#import "PSBookmarkFolder.h"


@implementation PSBookmarkFolderAddViewController

@synthesize parentFolder, rgbHexString;

#pragma mark -
#pragma mark Initialization

- (id)initWithParentFolder:(NSString*)folder {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.parentFolder = folder;
		self.rgbHexString = nil;
	}
	return self;
}

#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];

	//self.navigationItem.rightBarButtonItem = save button;
	
	nameTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,12,260,25)];
	[nameTextField setPlaceholder:@""];
	nameTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	//nameTextField.delegate = self;
	nameTextField.keyboardType = UIKeyboardTypeDefault;
	nameTextField.returnKeyType = UIReturnKeyDone;
}

- (void)saveButtonPressed {
	
}

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
    return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 1;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return @"Folder Name:";
		case 1:
			return @"Highlight Colour:";
		default:
			break;
	}
	return @"";
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 1 && self.rgbHexString) {
		cell.backgroundColor = [PSBookmarkFolder colorFromHexString:rgbHexString];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *CellIdentifier = [NSString stringWithFormat:@"Cell-%d", indexPath.section];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		if(indexPath.section == 0) {
			[cell addSubview:nameTextField];
		}
    }
    
    // Configure the cell...
	if(indexPath.section == 0) {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	} else if(indexPath.section == 1) {
		if(self.rgbHexString) {
			cell.textLabel.text = @"";
		} else {
			cell.textLabel.text = NSLocalizedString(@"None", @"None");
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0) {
		[nameTextField becomeFirstResponder];
	} else {
		PSBookmarkFolderColourSelectorViewController *csvc = [[PSBookmarkFolderColourSelectorViewController alloc] initWithColorString:self.rgbHexString delegate:self];
		[self.navigationController pushViewController:csvc animated:YES];
		[csvc release];
	}
}

- (void)rgbHexColorStringDidChange:(NSString *)newColorHexString {
	self.rgbHexString = newColorHexString;
	[self.tableView reloadData];
	[self.navigationController popViewControllerAnimated:YES];
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
	[nameTextField release];
	nameTextField = nil;
}


- (void)dealloc {
    [super dealloc];
	self.parentFolder = nil;
	self.rgbHexString = nil;
}


@end

