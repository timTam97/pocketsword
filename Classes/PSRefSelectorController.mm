//
//  PSRefSelectorController.mm
//  PocketSword
//
//  Created by Nic Carter on 3/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "PSRefSelectorController.h"
#import "SwordBook.h"
#import "PSModuleController.h"
#import "PSChapterSelectorController.h"
#import "PSResizing.h"

@implementation PSRefSelectorController

@synthesize refSelectorChapter;
@synthesize refSelectorBook;
@synthesize refSelectorBooks;
@synthesize refSelectorBooksIndex;
@synthesize currentlyViewedBookName;

- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetBooks:) name:NotificationRefSelectorResetBooks object:nil];
	if([self respondsToSelector:@selector(contentSizeForViewInPopover)]) {
		self.contentSizeForViewInPopover = CGSizeMake(540.0, 1100.0);
	}
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationRefSelectorResetBooks object:nil];
	[super viewDidUnload];
}

- (void)resetBooks:(NSNotification *)notification {
	self.refSelectorBooks = nil;
}

- (void)dealloc {
	[refSelectorBooks release];
	[refSelectorBooksIndex release];
//	[refToucherMiscScrollView release];
	[currentlyViewedBookName release];
	[super dealloc];
}

- (void)dismissNavigation {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleNavigation object:nil];
}

- (void)setupNavigation {
	[self updateRefSelectorBooks];
	[self.tableView reloadData];
	self.navigationItem.title = NSLocalizedString(@"RefSelectorBookTitle", @"Book");
	[self.navigationController popToRootViewControllerAnimated:NO];
	self.navigationItem.leftBarButtonItem = nil;
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		self.tableView.backgroundColor = [UIColor blackColor];
	} else {
		self.tableView.backgroundColor = [UIColor whiteColor];
	}
    if([PSResizing iPad]) {
        //the iPad doesn't want the cancel button
        return;
    }
	UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissNavigation)];
	self.navigationItem.leftBarButtonItem = cancel;
	[cancel release];
}

- (void)willShowNavigation {
	NSIndexPath *ip = nil;
	int bookCount = [refSelectorBooks count];
	for(int i=0;i<bookCount;i++) {
		if([currentlyViewedBookName isEqualToString:[((SwordBook*)[refSelectorBooks objectAtIndex:i]) name]]) {
			ip = [NSIndexPath indexPathForRow: 0 inSection: i];
		}
	}
	[self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

- (void)updateRefSelectorBooks {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *currentRefSystemName = [[[PSModuleController defaultModuleController] primaryBible] versification];
	if(!currentRefSystemName) //if there are no Bibles, fall back to the commentary versification
		currentRefSystemName = [[[PSModuleController defaultModuleController] primaryCommentary] versification];
	if(!currentRefSystemName)
		currentRefSystemName = @"KJV";//if no ref system, default to kjv
	const sword::VersificationMgr::System *refSystem = sword::VersificationMgr::getSystemVersificationMgr()->getVersificationSystem([currentRefSystemName cStringUsingEncoding:NSUTF8StringEncoding]);
	if(!refSystem) {
		refSystem = sword::VersificationMgr::getSystemVersificationMgr()->getVersificationSystem("KJV");
	}
	int numberOfBooks = refSystem->getBookCount();
	//refSelectorOTBookCount = refSystem->getBMAX()[0];
	NSMutableArray *books = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray *booksIndex = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray *booksFullIndex = [[[NSMutableArray alloc] init] autorelease];
	for(int i = 0; i < numberOfBooks; i++) {
		SwordBook *book = [[SwordBook alloc] initWithBook:refSystem->getBook(i)];
		[books addObject:book];
		if(![booksFullIndex containsObject:[book shortName]]) {
			[booksIndex addObject:[book shortName]];
		} else {
		}
		[booksFullIndex addObject:[book shortName]];
		[book release];
	}
	//NSLog(@"refSelector: %d books, %d refSelectorOTBookCount", numberOfBooks, refSelectorOTBookCount);
	NSString *currentBook = [PSModuleController getCurrentBibleRef];
	currentBook = [[currentBook componentsSeparatedByString:@":"] objectAtIndex:0];
	NSRange spaceRange = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
	if(spaceRange.location != NSNotFound) {
		currentBook = [currentBook substringToIndex: spaceRange.location];
	}

	[self setRefSelectorBooks:books];
	[self setRefSelectorBooksIndex:booksIndex];
	[self setCurrentlyViewedBookName:currentBook];

	//reset the picker.
	refSelectorBook = 0;
	refSelectorChapter = 1;

	[pool release];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [refSelectorBooks count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"] autorelease];
	}
	
	cell.textLabel.text = [self bookName:indexPath.section];
	if([currentlyViewedBookName isEqualToString:cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor blueColor];
	} else {
		if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
			cell.textLabel.textColor = [UIColor whiteColor];
		} else {
			cell.textLabel.textColor = [UIColor blackColor];
		}
	}
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	
	UIButton *jumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
	if([jumpButton respondsToSelector:@selector(tintColor)]) {
		jumpButton.frame = CGRectMake(0, 0, 60, 30);
		[jumpButton setTitle:@"1:1" forState:UIControlStateNormal];
		jumpButton.tag = (1000 + indexPath.section);
		[jumpButton addTarget:self action:@selector(accessoryButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		cell.accessoryView = jumpButton;
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		cell.backgroundColor = [UIColor blackColor];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	PSChapterSelectorController *chapterSelectorController = [[PSChapterSelectorController alloc] initWithStyle:UITableViewStylePlain];
	[chapterSelectorController setBookAndInit: [refSelectorBooks objectAtIndex:indexPath.section]];
	[self.navigationController pushViewController:chapterSelectorController animated:YES];
	//[refNavigationController pushViewController:chapterSelectorController animated:YES];
	[chapterSelectorController release];
}

- (void)jumpToVerseOne:(NSInteger)bookIndex {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleNavigation object:nil];
	NSMutableDictionary *bcvDict = [NSMutableDictionary dictionary];
	[bcvDict setObject:[[refSelectorBooks objectAtIndex:bookIndex] name] forKey:BookNameString];
	[bcvDict setObject:@"1" forKey:ChapterString];
	[bcvDict setObject:@"1" forKey:VerseString];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationUpdateSelectedReference object:bcvDict];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	//jump to ch1, v1 of that book.
	[self jumpToVerseOne:indexPath.section];
}

- (void)accessoryButtonPressed:(id)sender {
	NSInteger bookIndex = ((UIView*)sender).tag - 1000;
	[self jumpToVerseOne:bookIndex];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	return self.refSelectorBooksIndex;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	for(int i=0;i<[refSelectorBooks count];i++) {
		if([[self bookShortName:i] isEqualToString:[self.refSelectorBooksIndex objectAtIndex:index]])
			return i;
	}
	return 0;
}

- (NSString*)bookName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) name];
}

- (NSString*)bookShortName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) shortName];
}

- (NSString*)bookOSISName:(NSInteger)bookIndex {
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) osisName];
}

- (NSInteger)bookIndex:(NSString*)bookName {
	NSInteger ret = NSNotFound;
	for(int i = 0; i < [refSelectorBooks count]; i++) {
		if([[((SwordBook*)[refSelectorBooks objectAtIndex:i]) name] isEqualToString:bookName]) {
			//DLog(@"\nbookName: %@\nindex: %d", bookName, i);
			ret = i;
			break;
		}
	}
	return ret;
}

@end
