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

@synthesize parentFolder, rgbHexString, bookmarkFolderBeingEdited;

#pragma mark -
#pragma mark Initialization

- (id)initWithParentFolder:(NSString*)folder bookmarkFolderToEdit:(PSBookmarkFolder*)bookmarkFolder {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.parentFolder = folder;
		self.bookmarkFolderBeingEdited = bookmarkFolder;
		if(bookmarkFolder) {
			self.rgbHexString = bookmarkFolder.rgbHexString;
		} else {
			self.rgbHexString = nil;
		}
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
	
    CGRect fieldFrames = CGRectMake(20,12,280,25);
    if([PSResizing iPad]) {
        //different frames for the iPad
        fieldFrames = CGRectMake(60,12,560,25);
    }
    
	nameTextField = [[UITextField alloc] initWithFrame:fieldFrames];
	[nameTextField setPlaceholder:@""];
	nameTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	nameTextField.delegate = self;
	nameTextField.keyboardType = UIKeyboardTypeDefault;
	nameTextField.returnKeyType = UIReturnKeyDone;
	if(self.bookmarkFolderBeingEdited) {
		nameTextField.text = bookmarkFolderBeingEdited.name;
		self.navigationItem.title = NSLocalizedString(@"BookmarksEditFolderTitle", @"Edit Folder");
	} else {
		self.navigationItem.title = NSLocalizedString(@"BookmarksAddFolderButton", @"Add Folder");
	}
}

- (void)saveButtonPressed {
	// check for a duplicate folder name:
	PSBookmarkFolder *parentFolderObject = [PSBookmarks getBookmarkFolderForFolderString:self.parentFolder];
	BOOL valid = YES;
	if(self.bookmarkFolderBeingEdited && [bookmarkFolderBeingEdited.name isEqualToString:nameTextField.text]) {
		//tis ok.
	} else {
		for(PSBookmarkFolder *childFolder in parentFolderObject.children) {
			if([childFolder.name isEqualToString:nameTextField.text]) {
				valid = NO;
				break;
			}
		}
	}
	if(!valid) {
		UIAlertView *av = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"BookmarksDuplicateFolderTitle", @"") message: NSLocalizedString(@"BookmarksDuplicateFolderMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
		[av show];
		[av release];
		return;
	}
	// check for an invalid folder name (ie: contains PSFolderSeparatorString):
	NSRange position = [nameTextField.text rangeOfString:PSFolderSeparatorString];
	if(position.location != NSNotFound) {
		UIAlertView *av = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"BookmarksInvalidFolderTitle", @"") message: NSLocalizedString(@"BookmarksInvalidFolderMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
		[av show];
		[av release];
		return;
	}
	
	if(self.bookmarkFolderBeingEdited) {
		// save the edited details of the bookmark folder.
		self.bookmarkFolderBeingEdited.name = nameTextField.text;
		self.bookmarkFolderBeingEdited.rgbHexString = self.rgbHexString;
		[PSBookmarks saveBookmarksToFile];
	} else {
		// add new folder to the bookmarks.
		PSBookmarkFolder *folder = [[PSBookmarkFolder alloc] initWithName:nameTextField.text dateAdded:[NSDate date] dateLastAccessed:[NSDate date] rgbHexString:rgbHexString children:nil];
		[PSBookmarks addBookmarkObject:folder withFolderString:self.parentFolder];
		[folder release];
	}
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
	if(self.bookmarkFolderBeingEdited) {
		return 3;
	} else {
		return 2;
	}
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
		case 2:
			return NSLocalizedString(@"BookmarksCreatedTitle", @"");
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
	} else if(indexPath.section == 2) {
		
		NSString *dateString = @"";
		if(self.bookmarkFolderBeingEdited) {
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			[dateFormatter setDateStyle:NSDateFormatterFullStyle];

			dateString = [dateFormatter stringFromDate:bookmarkFolderBeingEdited.dateAdded];
			[dateFormatter release];
			dateFormatter = nil;
		}
		cell.textLabel.text = dateString;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0) {
		[nameTextField becomeFirstResponder];
	} else if(indexPath.section == 1) {
		[nameTextField resignFirstResponder];
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
	[super viewDidUnload];
}


- (void)dealloc {
	self.parentFolder = nil;
	self.rgbHexString = nil;
	self.bookmarkFolderBeingEdited = nil;
    [super dealloc];
}


@end

