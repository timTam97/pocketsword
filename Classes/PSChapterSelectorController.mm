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
#import "ViewController.h"

@implementation PSChapterSelectorController

@synthesize book;

int currentChapter;
BOOL needToScroll;

- (void)setBookAndInit:(SwordBook*)newBook {
	self.book = newBook;
	needToScroll = YES;
}

- (void)viewDidAppear:(BOOL)animated {
//	NSIndexPath *tableSelection = [chapterTable indexPathForSelectedRow];
//	if(tableSelection) {
//		[chapterTable deselectRowAtIndexPath:tableSelection animated:YES];
//	}
	if(needToScroll && (currentChapter > 0)) {
		NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: (currentChapter-1)];
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [book chapters];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	cell.textLabel.text = [NSString stringWithFormat:@"%@ %d", NSLocalizedString(@"RefSelectorChapterTitle", @"Chapter"), (indexPath.section+1)];
	if((indexPath.section+1) == currentChapter) {
		cell.textLabel.textColor = [UIColor blueColor];
	} else {
		cell.textLabel.textColor = [UIColor blackColor];
	}
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	PSVerseSelectorController *verseSelectorController = [[PSVerseSelectorController alloc] init];
	NSDictionary *proxyDict = [NSDictionary dictionaryWithObject:viewController forKey:@"viewController"];
	NSDictionary *optionsDict = [NSDictionary dictionaryWithObject:proxyDict forKey:UINibExternalObjects];
	[[NSBundle mainBundle] loadNibNamed:@"PSVerseSelectorController" owner:verseSelectorController options:optionsDict];
	verseSelectorController.book = book;
	verseSelectorController.chapter = indexPath.section+1;
	[self.navigationController pushViewController:verseSelectorController animated:YES];
	[verseSelectorController release];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	//jump to ch1, v1 of that book.
	//[ViewController hideModal:self.navigationController.view withTiming:0.3];
	[[viewController tabBarController] dismissModalViewControllerAnimated:YES];
	[viewController updateViewWithSelectedBookName:[book name] chapter:(indexPath.section+1) verse:1];
}

- (void)dealloc {
	[book release];
    [super dealloc];
}


@end

