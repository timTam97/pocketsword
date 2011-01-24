//
//  PSBookmarksNavigatorController.m
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarksNavigatorController.h"
#import "PSBookmark.h"
#import "PSModuleController.h"
#import "HistoryController.h"
#import "PSBookmarkFolderAddViewController.h"
#import "PSBookmarks.h"


@implementation PSBookmarksNavigatorController

@synthesize bookmarkFolder, isAddingBookmark, parentFolders;

#pragma mark -
#pragma mark Initialization

- (id)initWithBookmarkFolder:(PSBookmarkFolder*)folder parentFolders:(NSString*)parentFoldersString isAddingBookmark:(BOOL)adding {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if(self) {
		self.bookmarkFolder = folder;
		isAddingBookmark = adding;
		self.editing = NO;
		parentFolders = [parentFoldersString copy];
		displayAddFolderRow = NO;
	}
	return self;
}

- (id)initWithStyle:(UITableViewStyle)style {
	self = [super initWithStyle:style];
	if(self) {
		self.bookmarkFolder = [PSBookmarks defaultBookmarks];
		isAddingBookmark = NO;
		self.editing = NO;
		parentFolders = nil;
		displayAddFolderRow = NO;
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
	UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonPressed)];
    self.navigationItem.rightBarButtonItem = editButton;
	[editButton release];
	if(bookmarkFolder) {
		self.navigationItem.title = bookmarkFolder.name;
	}
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	//[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:(self.navigationController).navigationBar mainView:self.tableView useStatusBar:YES];
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


- (void)editButtonPressed {
	displayAddFolderRow = NO;
	if(!self.editing) {
		displayAddFolderRow = YES;
		if(!self.isAddingBookmark) {
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
		} else {
			[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
		}
		[self setEditing:YES animated:YES];
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editButtonPressed)];
		[self.navigationItem setRightBarButtonItem:doneButton animated:YES];
		[doneButton release];
	} else {
		[self setEditing:NO animated:YES];
		if(!self.isAddingBookmark) {
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
		} else {
			[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
		}
		UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonPressed)];
		[self.navigationItem setRightBarButtonItem:editButton animated:YES];
		[editButton release];
	}
	//[self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)] withRowAnimation:UITableViewRowAnimationMiddle];
	//[self.tableView reloadData];
}
#pragma mark -
#pragma mark Table view data source

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if(indexPath.section == 0) {
		PSBookmarkObject *rowObject = (isAddingBookmark) ? [[bookmarkFolder folders] objectAtIndex:indexPath.row] : [bookmarkFolder.children objectAtIndex:indexPath.row];
		if(rowObject.folder) {
			cell.backgroundColor = [PSBookmarkFolder colorFromHexString:((PSBookmarkFolder*)rowObject).rgbHexString];
		} else {
			cell.backgroundColor = [UIColor whiteColor];
		}
	} else if(indexPath.section == 1) {
		cell.backgroundColor = [UIColor blueColor];
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
	if(displayAddFolderRow || self.isAddingBookmark) {
		return 2;
	} else {
		return 1;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
	if(section == 0) {
		if(isAddingBookmark) {
			return [[bookmarkFolder folders] count];
		} else {
			return [bookmarkFolder.children count];
		}
//	} else if(self.editing) {
//		return 1;
	} else if(isAddingBookmark || displayAddFolderRow) {
		return 1;//0;
	} else {
		return 0;
	}
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
	
	if(indexPath.section == 0) {
		PSBookmarkObject *rowObject = (isAddingBookmark) ? [[bookmarkFolder folders] objectAtIndex:indexPath.row] : [bookmarkFolder.children objectAtIndex:indexPath.row];
		cell.textLabel.text = rowObject.name;
		cell.showsReorderControl = YES;
		if(rowObject.folder) {
			//tis a folder
			cell.detailTextLabel.text = @"";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.imageView.image = [UIImage imageNamed:@""];
		} else {
			//tis a bookmark
			cell.detailTextLabel.text = ((PSBookmark*)rowObject).ref;
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.imageView.image = [UIImage imageNamed:@""];
		}
	} else if(indexPath.section == 1) {
		if(displayAddFolderRow) {
			//add folder row!
			cell.textLabel.text = @"Add Folder";
		} else {
			cell.textLabel.text = @"Add Bookmark here";
		}
	}
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if(section == 0 && !self.isAddingBookmark) {
		return @"To add a bookmark for a verse, tap on the verse number in the Bible tab and select 'Add Bookmark'";
	} else if(!displayAddFolderRow && section == 1 && self.isAddingBookmark) {
		return @"To add a folder, tap on the Edit button";
	} else {
		return nil;
	}
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0) {
		return UITableViewCellEditingStyleDelete;
	} else {
		return UITableViewCellEditingStyleInsert;
	}

}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
		PSBookmarkObject *rowObject = (isAddingBookmark) ? [[bookmarkFolder folders] objectAtIndex:indexPath.row] : [bookmarkFolder.children objectAtIndex:indexPath.row];
		if(rowObject.folder) {
			// TODO: display confirmation
			rowToDelete = [indexPath retain];
			[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"BookmarksConfirmDeleteFolderTitle", @"") message: [NSString stringWithFormat:NSLocalizedString(@"BookmarksConfirmDeleteFolderMessage", @""), rowObject.name] delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
		} else {
			[self deleteChildAtIndexPath:indexPath];
		}
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
		// create a new folder.
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
		PSBookmarkFolderAddViewController *favc = [[PSBookmarkFolderAddViewController alloc] initWithParentFolder:self.parentFolders];
		[self.navigationController pushViewController:favc animated:YES];
		[favc release];
		[self setEditing:NO];
    }   
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == 1) {
		//yup, delete the folder!
		[self deleteChildAtIndexPath:rowToDelete];
	}
	[rowToDelete release];
	rowToDelete = nil;
}

- (void)deleteChildAtIndexPath:(NSIndexPath *)indexPath {
	NSMutableArray *array = [bookmarkFolder.children mutableCopy];
	[array removeObjectAtIndex:indexPath.row];
	bookmarkFolder.children = array;
	[array release];
	[PSBookmarks saveBookmarksToFile];
	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationBookmarksChanged object:nil];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0)
		return YES;
	else
		return NO;
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
	NSMutableArray *kids = [bookmarkFolder.children mutableCopy];
	NSObject *obj = [kids objectAtIndex:fromIndexPath.row];
	[kids removeObjectAtIndex:fromIndexPath.row];
	[kids insertObject:obj atIndex:toIndexPath.row];
	bookmarkFolder.children = kids;
	[kids release];
	[PSBookmarks saveBookmarksToFile];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// tapping on the cell in section 1 will:
	if(indexPath.section == 1) {
		if(self.editing) {
			// add a folder
			//   This row won't actually be selectable while we're in editing mode, so we actually add a new folder in the commitEditingStyle: method, above.
		} else {
			// save the current folder structure & add a bookmark at this position
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBookmarkInFolder object:self.parentFolders];
		}
	} else {
		PSBookmarkObject *rowObject = (isAddingBookmark) ? [[bookmarkFolder folders] objectAtIndex:indexPath.row] : [bookmarkFolder.children objectAtIndex:indexPath.row];
		if(rowObject.folder) {
			// tapping on a folder navigates to that folder.
			NSString *pfs = rowObject.name;
			if(self.parentFolders) {
				pfs = [NSString stringWithFormat:@"%@%@%@", self.parentFolders, PSFolderSeparatorString, rowObject.name];
			}
			PSBookmarksNavigatorController *bnc = [[PSBookmarksNavigatorController alloc] initWithBookmarkFolder:(PSBookmarkFolder*)rowObject parentFolders:pfs isAddingBookmark:self.isAddingBookmark];
			[self.navigationController pushViewController:bnc animated:YES];
			[bnc release];
		} else {
			// tapping on a bookmark will open the bookmark.
			((PSBookmark*)rowObject).dateLastAccessed = [NSDate date];
			[PSBookmarks saveBookmarksToFile];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowBibleTab object:nil];
			if (![[[[PSModuleController defaultModuleController] swordManager] moduleNames] count] == 0) {
				NSArray *fullRef = [((PSBookmark*)rowObject).ref componentsSeparatedByString: @":"];
				NSString *ref = [fullRef objectAtIndex: 0];
				[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
				NSString *verse = [fullRef objectAtIndex: 1];
				if(verse) {
					[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
					[[NSUserDefaults standardUserDefaults] synchronize];
					[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
				} else {
					[[NSUserDefaults standardUserDefaults] setObject: @"1" forKey: DefaultsBibleVersePosition];
					[[NSUserDefaults standardUserDefaults] synchronize];
					[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
				}
				[HistoryController addHistoryItem:BibleTab];
			}
			
			[tableView deselectRowAtIndexPath:indexPath animated:NO];
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
}

- (void)dealloc {
	self.bookmarkFolder = nil;
	[parentFolders release];
    [super dealloc];
}


@end

