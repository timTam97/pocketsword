//
//  PSBookmarkAddViewController.m
//  PocketSword
//
//  Created by Nic Carter on 10/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkAddViewController.h"
#import "globals.h"
#import "PSBookmarks.h"
#import "PSBookmarksNavigatorController.h"
#import "PSModuleController.h"
#import "PSResizing.h"

@implementation PSBookmarksAddTableViewController

@synthesize bookAndChapterRef, verse, folder, originalFolder, bookmarkBeingEdited;

#pragma mark -
#pragma mark Initialization

- (id)initWithBookAndChapterRef:(NSString*)ref andVerse:(NSString*)v {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.bookAndChapterRef = ref;
		self.verse = v;
		self.folder = nil;
		self.originalFolder = nil;
		self.bookmarkBeingEdited = nil;
	}
	return self;
}

- (id)initWithBookmarkToEdit:(PSBookmark*)bookmarkToEdit parentFolders:(NSString*)folders {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.bookAndChapterRef = nil;
		self.verse = nil;
		self.folder = folders;
		self.originalFolder = folders;
		self.bookmarkBeingEdited = bookmarkToEdit;
	}
	return self;
}

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization.
    }
    return self;
}
*/


#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];

    CGRect fieldFrames = CGRectMake(20,12,280,25);
    if([PSResizing iPad]) {
        //different frames for the iPad
        fieldFrames = CGRectMake(60,12,560,25);
    }
    
	descriptionTextField = [[UITextField alloc] initWithFrame:fieldFrames];
	[descriptionTextField setPlaceholder:@""];
	descriptionTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	descriptionTextField.delegate = self;
	descriptionTextField.keyboardType = UIKeyboardTypeDefault;
	descriptionTextField.returnKeyType = UIReturnKeyDone;
	if(self.bookmarkBeingEdited) {
		descriptionTextField.text = bookmarkBeingEdited.name;
	}
	
	UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveButtonPressed)];
	self.navigationItem.rightBarButtonItem = saveButton;
	[saveButton release];
	if(!self.bookmarkBeingEdited) {
		UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed)];
		self.navigationItem.leftBarButtonItem = cancelButton;
		[cancelButton release];
		self.navigationItem.title = NSLocalizedString(@"VerseContextualMenuAddBookmark", @"Add Bookmark");	
	} else {
		self.navigationItem.title = NSLocalizedString(@"BookmarkEditBookmarkTitle", @"Edit Bookmark");	
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(folderUpdated:) name:NotificationAddBookmarkInFolder object:nil];
}

- (void)cancelButtonPressed {
	// this button only exists if we're adding a bookmark, so it's ok to only do this.
	[self dismissModalViewControllerAnimated:YES];
}

- (void)saveButtonPressed {
	BOOL valid = YES;
	if(self.bookmarkBeingEdited && [bookmarkBeingEdited.name isEqualToString:descriptionTextField.text]) {
		//tis ok.
	} else {
		for(PSBookmarkFolder *childFolder in [PSBookmarks getBookmarkFolderForFolderString:self.folder].children) {
			if([childFolder.name isEqualToString:descriptionTextField.text]) {
				valid = NO;
				break;
			}
		}
	}
	if(!valid) {
		UIAlertView *av = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"BookmarksDuplicateBookmarkTitle", @"") message: NSLocalizedString(@"BookmarksDuplicateBookmarkMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
		[av show];
		[av release];
		return;
	}	
	
	if(self.bookmarkBeingEdited) {
		NSString *description = descriptionTextField.text;
		if([description isEqualToString:@""]) {
			description = bookmarkBeingEdited.ref;
		}
		PSBookmark *newBookmark = [[PSBookmark alloc] initWithName:description dateAdded:bookmarkBeingEdited.dateAdded dateLastAccessed:[NSDate date] bibleReference:bookmarkBeingEdited.ref];
		[PSBookmarks deleteBookmark:bookmarkBeingEdited.name fromFolderString:self.originalFolder];
		[PSBookmarks addBookmarkObject:newBookmark withFolderString:self.folder];
		[newBookmark release];
		
		NSArray *fullRef = [bookmarkBeingEdited.ref componentsSeparatedByString: @":"];
		NSString *ref = [fullRef objectAtIndex: 0];
		if([[PSModuleController createRefString:[PSModuleController getCurrentBibleRef]] isEqualToString:ref]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBookmarksChanged object:nil];
		}
		
		[self.navigationController popViewControllerAnimated:YES];
	} else {
		NSString *ref = [NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse];
		NSString *description = ref;
		if(descriptionTextField.text && ![descriptionTextField.text isEqualToString:@""]) {
			description = descriptionTextField.text;
		}
		[PSBookmarks addBookmarkWithRef:ref name:description folderString:folder];
		if([[PSModuleController createRefString:[PSModuleController getCurrentBibleRef]] isEqualToString:bookAndChapterRef]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBookmarksChanged object:nil];
		}
		[self dismissModalViewControllerAnimated:YES];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	[descriptionTextField becomeFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[self.tableView reloadData];
}

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

- (void)folderUpdated:(NSNotification *)notification
{
	//DLog(@"%@", [notification object]);
	self.folder = [notification object];
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
	[self.navigationController popToViewController:self animated:YES];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
	if(self.bookmarkBeingEdited) {
		return 5;
	} else {
		return 3;
	}
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 1;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return NSLocalizedString(@"BookmarksAddBookmarkVerseTitle", @"");
		case 1:
			return NSLocalizedString(@"BookmarksAddBookmarkDescriptionTitle", @"");
		case 2:
			return NSLocalizedString(@"BookmarksAddBookmarkFolderTitle", @"");
		case 3:
			return NSLocalizedString(@"BookmarksCreatedTitle", @"");
		case 4:
			return NSLocalizedString(@"BookmarksLastAccessedTitle", @"");
		default:
			break;
	}
	return @"";
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *CellIdentifier = [NSString stringWithFormat:@"Cell-%d", indexPath.section];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];//UITableViewCellStyleValue1
		if(indexPath.section == 1) {
			[cell addSubview:descriptionTextField];
		}
    }
    
    // Configure the cell...
	switch (indexPath.section) {
		case 0:
			if(self.bookmarkBeingEdited) {
				cell.textLabel.text = bookmarkBeingEdited.ref;
			} else {
				cell.textLabel.text = [NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse];
			}
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			break;
		case 1:
			if(self.bookmarkBeingEdited) {
				[descriptionTextField setPlaceholder:bookmarkBeingEdited.ref];
			} else {
				[descriptionTextField setPlaceholder:[NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse]];
			}
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			break;
		case 2:
			if(self.folder) {
				cell.textLabel.lineBreakMode = UILineBreakModeHeadTruncation;
				cell.textLabel.text = [folder stringByReplacingOccurrencesOfString:PSFolderSeparatorString withString:@"/"];
			} else {
				cell.textLabel.text = NSLocalizedString(@"BookmarksTitle", @"");
			}
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;
		case 3:
		{
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			[dateFormatter setDateStyle:NSDateFormatterFullStyle];
			
			cell.textLabel.text = [dateFormatter stringFromDate:bookmarkBeingEdited.dateAdded];
			[dateFormatter release];
			dateFormatter = nil;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
			break;
		case 4:
		{
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			[dateFormatter setDateStyle:NSDateFormatterFullStyle];
			
			cell.textLabel.text = [dateFormatter stringFromDate:bookmarkBeingEdited.dateLastAccessed];
			[dateFormatter release];
			dateFormatter = nil;
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
			break;
		default:
			break;
	}
    
    return cell;
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
        // Delete the row from the data source.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 1) {
		[descriptionTextField becomeFirstResponder];
	} else if(indexPath.section == 2) {
		if(!folder) {
			PSBookmarksNavigatorController *bnc = [[PSBookmarksNavigatorController alloc] initWithBookmarkFolder:[PSBookmarks defaultBookmarks] parentFolders:nil isAddingBookmark:YES];
			[self.navigationController pushViewController:bnc animated:YES];
			[bnc release];
		} else {
			NSArray *components = [folder componentsSeparatedByString:PSFolderSeparatorString];
			// push the root of our bookmarks:
			PSBookmarksNavigatorController *bnc = [[PSBookmarksNavigatorController alloc] initWithBookmarkFolder:[PSBookmarks defaultBookmarks] parentFolders:nil isAddingBookmark:YES];
			[self.navigationController pushViewController:bnc animated:NO];
			[bnc release];
			NSMutableString *currentFolder = [NSMutableString stringWithString:[components objectAtIndex:0]];
			for(int i=0; i<[components count];) {
				BOOL animate = NO;
				if(i == ([components count] - 1))
					animate = YES;
				bnc = [[PSBookmarksNavigatorController alloc] initWithBookmarkFolder:[PSBookmarks getBookmarkFolderForFolderString:currentFolder] parentFolders:currentFolder isAddingBookmark:YES];
				[self.navigationController pushViewController:bnc animated:animate];
				[bnc release];
				i++;
				if(i<[components count]) {
					[currentFolder appendFormat:@"%@%@", PSFolderSeparatorString, [components objectAtIndex:i]];
				}
			}
			self.folder = nil;//reset the folder to the root.
		}
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
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:NotificationAddBookmarkInFolder];
	[descriptionTextField release];
	descriptionTextField = nil;
	[super viewDidUnload];
}


- (void)dealloc {
	self.bookAndChapterRef = nil;
	self.verse = nil;
	self.folder = nil;
	self.originalFolder = nil;
	self.bookmarkBeingEdited = nil;
    [super dealloc];
}


@end

