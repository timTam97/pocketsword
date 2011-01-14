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

@implementation PSBookmarkAddViewController

@synthesize bookAndChapterRef, verse;

- (id)initWithBookAndChapterRef:(NSString*)ref verse:(NSString*)v {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		self.bookAndChapterRef = ref;
		self.verse = v;
	}
	return self;
}

- (void)loadView {
	tableViewController = [[[PSBookmarksAddTableViewController alloc] initWithBookAndChapterRef:bookAndChapterRef andVerse:verse] retain];
	containingNavigationController = [[[UINavigationController alloc] initWithRootViewController:tableViewController] retain];
	self.view = containingNavigationController.view;
}

- (void)viewDidUnload {
	[super viewDidUnload];
	[tableViewController release];
	tableViewController = nil;
	[containingNavigationController release];
	containingNavigationController = nil;
}

- (void)dealloc {
	[super dealloc];
	[tableViewController release];
	[containingNavigationController release];
	self.bookAndChapterRef = nil;
	self.verse = nil;
}


@end

@implementation PSBookmarksAddTableViewController

@synthesize bookAndChapterRef, verse, folder;

#pragma mark -
#pragma mark Initialization

- (id)initWithBookAndChapterRef:(NSString*)ref andVerse:(NSString*)v {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.bookAndChapterRef = ref;
		self.verse = v;
		self.folder = nil;
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

	descriptionTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,12,260,25)];
	[descriptionTextField setPlaceholder:@""];
	descriptionTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	//descriptionTextField.delegate = self;
	descriptionTextField.keyboardType = UIKeyboardTypeDefault;
	descriptionTextField.returnKeyType = UIReturnKeyDone;
	
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveButtonPressed)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed)];
	self.navigationItem.title = NSLocalizedString(@"VerseContextualMenuAddBookmark", @"Add Bookmark");	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(folderUpdated:) name:NotificationAddBookmarkInFolder object:nil];
}

- (void)cancelButtonPressed {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)saveButtonPressed {
	NSString *ref = [NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse];
	NSString *description = ref;
	if(![descriptionTextField.text isEqualToString:@""]) {
		description = descriptionTextField.text;
	}
	[PSBookmarks addBookmarkWithRef:ref name:description folderString:folder];
	[self dismissModalViewControllerAnimated:YES];
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
	DLog(@"%@", [notification object]);
	self.folder = [notification object];
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
	[self.navigationController popToViewController:self animated:YES];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 3;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 1;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return @"Verse";
		case 1:
			return @"Description";
		case 2:
			return @"Folder";
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
			cell.textLabel.text = [NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			break;
		case 1:
			[descriptionTextField setPlaceholder:[NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse]];
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


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 1) {
		[descriptionTextField becomeFirstResponder];
	} else if(indexPath.section == 2) {
		PSBookmarksNavigatorController *bnc = [[PSBookmarksNavigatorController alloc] initWithBookmarkFolder:[PSBookmarks getBookmarkFolderForFolderString:folder] parentFolders:folder isAddingBookmark:YES];
		[self.navigationController pushViewController:bnc animated:YES];
		[bnc release];
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
}


- (void)dealloc {
    [super dealloc];
	self.bookAndChapterRef = nil;
	self.verse = nil;
	self.folder = nil;
}


@end

