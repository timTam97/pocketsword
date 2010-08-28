//
//  PSBookmarksViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 19/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarksViewController.h"

#import "PSModuleController.h"
#import "globals.h"

@implementation PSBookmarksViewController


#pragma mark -
#pragma mark Initialization

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if ((self = [super initWithStyle:style])) {
    }
    return self;
}
*/


#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
	
	bookmarksNavBar.title = NSLocalizedString(@"BookmarksTitle", @"Bookmarks");
	UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(toggleBookmarksTableEditing:)];
	bookmarksNavBar.leftBarButtonItem = btn;
	[btn release];
}



- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[bookmarksTable reloadData];
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
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (IBAction)toggleBookmarksTableEditing:(id)sender {
	if ([bookmarksTable isEditing]) {
		[bookmarksTable setEditing: NO animated: YES];
		UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(toggleBookmarksTableEditing:)];
		//self.navigationItem.leftBarButtonItem = btn;
		bookmarksNavBar.leftBarButtonItem = btn;
		[btn release];
	}
	else {
		[bookmarksTable setEditing: YES animated: YES];
		UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(toggleBookmarksTableEditing:)];
		bookmarksNavBar.leftBarButtonItem = btn;
		//self.navigationItem.leftBarButtonItem = btn;
		[btn release];
	}
}

+ (void)addBookmarkForRef:(NSString*)bookAndChapterRef withVerse:(NSString*)verse {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *ref = [NSString stringWithFormat:@"%@:%@", bookAndChapterRef, verse];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks2"] mutableCopy];
	
	if (!bookmarks) {
		bookmarks = [[NSMutableArray alloc] initWithObjects: nil];
		
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: bookmarks forKey: @"bookmarks2"];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
	}
	NSString *refToAdd = [PSModuleController createRefString:ref];
	if(![bookmarks containsObject: refToAdd])
		[bookmarks addObject: refToAdd];
	
	[defaults setObject: bookmarks forKey: @"bookmarks2"];
	[defaults synchronize];
	[bookmarks release];
	[pool release];
}

- (IBAction)addBookmark:(id)sender {
	if(![PSModuleController defaultModuleController].primaryBible && ![PSModuleController defaultModuleController].primaryCommentary) {
		//can't add a bookmark for the currently viewed verse!
		return;
	}
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *verse = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsBibleVersePosition];
	NSString *ref = [NSString stringWithFormat:@"%@:%@", [PSModuleController getCurrentBibleRef], verse];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks2"] mutableCopy];
	
	if (!bookmarks) {
		bookmarks = [[NSMutableArray alloc] initWithObjects: nil];
		
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: bookmarks forKey: @"bookmarks2"];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
	}
	NSString *refToAdd = [PSModuleController createRefString:ref];
	if(![bookmarks containsObject: refToAdd])
		[bookmarks addObject: refToAdd];
	
	[defaults setObject: bookmarks forKey: @"bookmarks2"];
	[defaults synchronize];
	[bookmarks release];
	
	[bookmarksTable reloadData];
	[pool release];
}

- (void)removeBookmark:(NSString *)ref {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *bookmarks = [[defaults arrayForKey: @"bookmarks2"] mutableCopy];
	
	if(!bookmarks)
		return;
	
	for(NSUInteger i = 0; i < [bookmarks count]; ++i) {
		if ([[bookmarks objectAtIndex: i] isEqualToString: ref]) {
			[bookmarks removeObjectAtIndex: i];
		}
	}
	
	[defaults setObject: bookmarks forKey: @"bookmarks2"];
	[defaults synchronize];
	[bookmarks release];
	
	[bookmarksTable reloadData];
	[pool release];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
	return [bookmarks count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *theIdentifier = @"id-book";

    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:theIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:theIdentifier] autorelease];
    }
    
	NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
	cell.textLabel.text = [bookmarks objectAtIndex: indexPath.row];
	// TODO:  add the first bit of the chapter to the detailLabel:
	cell.detailTextLabel.text = @"";    
    return cell;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *ref = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[self removeBookmark: ref];
	}
	
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


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[viewController setShownTabTo:BibleTab];
	if (![[[[PSModuleController defaultModuleController] swordManager] moduleNames] count] == 0) {
		NSArray *fullRef = [[tableView cellForRowAtIndexPath: indexPath].textLabel.text componentsSeparatedByString: @":"];
		NSString *ref = [fullRef objectAtIndex: 0];
		[[NSUserDefaults standardUserDefaults] setObject: ref forKey: DefaultsLastRef];
		NSString *verse = [fullRef objectAtIndex: 1];
		if(verse) {
			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreVersePosition];
		} else {
			[[NSUserDefaults standardUserDefaults] setObject: @"1" forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			//[[[PSModuleController defaultModuleController] viewController] displayChapter: ref withPollingType: BibleViewPoll restoreType: RestoreNoPosition];
		}
		//[[[PSModuleController defaultModuleController] viewController] addHistoryItem: BibleTab];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
		//[HistoryController addHistoryItem:BibleTab];
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end

