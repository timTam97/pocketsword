//
//  PSChapterSelectorController.m
//  PocketSword
//
//  Created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSChapterSelectorController.h"
#import "PSVerseSelectorController.h"
#import "globals.h"

@implementation PSChapterSelectorController

@synthesize book;

int currentChapter;
BOOL needToScroll;

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

/*
- (void)viewDidLoad {
	[super viewDidLoad];
	// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
	// self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

- (void)setBookAndInit:(SwordBook*)newBook {
	self.book = newBook;
	needToScroll = YES;
}

- (void)viewDidAppear:(BOOL)animated {
//	NSIndexPath *tableSelection = [chapterTable indexPathForSelectedRow];
//	if(tableSelection) {
//		[chapterTable deselectRowAtIndexPath:tableSelection animated:YES];
//	}
	if(needToScroll) {
		NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: currentChapter];
		[chapterTable scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
		needToScroll = NO;
	}

	
	[super viewDidAppear:animated];
}


- (void)viewWillAppear:(BOOL)animated {
	self.navigationItem.title = [book name];//[NSString stringWithFormat:@"%@ %@", [book name], NSLocalizedString(@"RefSelectorChapterTitle", @"Chapter")];
	NSString *currentBook = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastRef];
	currentBook = [[currentBook componentsSeparatedByString:@":"] objectAtIndex:0];
	NSRange spaceRange = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
	if(spaceRange.location != NSNotFound) {
		currentChapter = [[currentBook substringFromIndex:spaceRange.location] intValue];
		currentBook = [currentBook substringToIndex: spaceRange.location];
	}
	if(![[book name] isEqualToString:currentBook])
		currentChapter = 0;
	
    [super viewWillAppear:animated];
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

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


#pragma mark - Table view methods

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
	int chapters = [book chapters];
	if(chapters < 10)
		return nil;
	for(int i=1;i<=chapters;i++) {
		[array addObject:[NSString stringWithFormat:@"%d", i]];
	}
	return array;
}

//- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
//	for(int i=0;i<[refSelectorBooks count];i++) {
//		if([[self bookShortName:i] isEqualToString:[self.refSelectorBooksIndex objectAtIndex:index]])
//			return i;
//	}
//	return 0;
//}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [book chapters];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Set up the cell...
	cell.textLabel.text = [NSString stringWithFormat:@"%@ %d", NSLocalizedString(@"RefSelectorChapterTitle", @"Chapter"), (indexPath.section+1)];
	if((indexPath.section+1) == currentChapter) {
		cell.textLabel.textColor = [UIColor blueColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
	}
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//PSVerseSelectorController *verseSelectorController = [[PSVerseSelectorController alloc] initWithNibName:@"PSVerseSelectorController" bundle:nil];
	PSVerseSelectorController *verseSelectorController = [[PSVerseSelectorController alloc] init];
	NSDictionary *proxyDict = [NSDictionary dictionaryWithObject:viewController forKey:@"viewController"];
	NSDictionary *optionsDict = [NSDictionary dictionaryWithObject:proxyDict forKey:UINibExternalObjects];
	[[NSBundle mainBundle] loadNibNamed:@"PSVerseSelectorController" owner:verseSelectorController options:optionsDict];
	verseSelectorController.book = book;
	verseSelectorController.chapter = indexPath.section+1;
	[self.navigationController pushViewController:verseSelectorController animated:YES];
	[verseSelectorController release];
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
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
	[book release];
    [super dealloc];
}


@end

