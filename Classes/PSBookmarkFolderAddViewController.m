//
//  PSBookmarkFolderAddViewController.m
//  PocketSword
//
//  Created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolderAddViewController.h"
#import "PSBookmarkFolder.h"
#import "PSBookmarks.h"
#import "globals.h"
#import "PSResizing.h"

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
	
	UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveButtonPressed)];
	self.navigationItem.rightBarButtonItem = saveButton;
	[saveButton release];
	
	nameTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,12,260,25)];
	[nameTextField setPlaceholder:@""];
	nameTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	nameTextField.delegate = self;
	nameTextField.keyboardType = UIKeyboardTypeDefault;
	nameTextField.returnKeyType = UIReturnKeyDone;
}

- (void)saveButtonPressed {
	// check for a duplicate folder name:
	PSBookmarkFolder *parentFolderObject = [PSBookmarks getBookmarkFolderForFolderString:self.parentFolder];
	BOOL valid = YES;
	for(PSBookmarkFolder *childFolder in parentFolderObject.children) {
		if([childFolder.name isEqualToString:nameTextField.text]) {
			valid = NO;
			break;
		}
	}
	if(!valid) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"BookmarksDuplicateFolderTitle", @"") message: NSLocalizedString(@"BookmarksDuplicateFolderMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil] show];
		return;
	}
	// check for an invalid folder name (ie: contains PSFolderSeparatorString):
	NSRange position = [nameTextField.text rangeOfString:PSFolderSeparatorString];
	if(position.location != NSNotFound) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"BookmarksInvalidFolderTitle", @"") message: NSLocalizedString(@"BookmarksInvalidFolderMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil] show];
		return;
	}
	
	PSBookmarkFolder *folder = [[PSBookmarkFolder alloc] initWithName:nameTextField.text dateAdded:[NSDate date] dateLastAccessed:[NSDate date] rgbHexString:rgbHexString children:nil];
	[PSBookmarks addBookmarkObject:folder withFolderString:self.parentFolder];
	[folder release];
	[self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	[nameTextField becomeFirstResponder];
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

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
			return NSLocalizedString(@"BookmarksAddFolderFolderName", @"");
		case 1:
			return NSLocalizedString(@"BookmarksAddFolderHighlightColour", @"");
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
	self.parentFolder = nil;
	self.rgbHexString = nil;
    [super dealloc];
}


@end

