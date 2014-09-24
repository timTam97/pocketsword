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

- (void)setBookAndInit:(SwordBook*)newBook {
	self.book = newBook;
	needToScroll = YES;
}

- (void)viewDidAppear:(BOOL)animated {
//	NSIndexPath *tableSelection = [tableView indexPathForSelectedRow];
//	if(tableSelection) {
//		[tableView deselectRowAtIndexPath:tableSelection animated:YES];
//	}
	if(needToScroll && (currentChapter > 0)) {
		NSIndexPath *ip = [NSIndexPath indexPathForRow: 0 inSection: (currentChapter-1)];
		[self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
		needToScroll = NO;
	}
	[super viewDidAppear:animated];
}


- (void)viewWillAppear:(BOOL)animated {
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		self.tableView.backgroundColor = [UIColor blackColor];
	} else {
		self.tableView.backgroundColor = [UIColor whiteColor];
	}
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
	[super viewDidUnload];
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
    
	cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"RefSelectorChapterTitle", @"Chapter"), (indexPath.section+1)];
	if((indexPath.section+1) == currentChapter) {
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
		NSString *buttonString = [NSString stringWithFormat:@"%d:1", (indexPath.section+1)];
		jumpButton.frame = CGRectMake(0, 0, 60, 30);
		[jumpButton setTitle:buttonString forState:UIControlStateNormal];
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
	PSVerseSelectorController *verseSelectorController = [[PSVerseSelectorController alloc] initWithStyle:UITableViewStylePlain];
	verseSelectorController.book = book;
	verseSelectorController.chapter = indexPath.section+1;
	[self.navigationController pushViewController:verseSelectorController animated:YES];
	[verseSelectorController release];
}

- (void)jumpToVerseOne:(NSInteger)chapterIndex {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleNavigation object:nil];
	NSMutableDictionary *bcvDict = [NSMutableDictionary dictionary];
	[bcvDict setObject:[book name] forKey:BookNameString];
	[bcvDict setObject:[NSString stringWithFormat:@"%d", (chapterIndex+1)] forKey:ChapterString];
	[bcvDict setObject:@"1" forKey:VerseString];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationUpdateSelectedReference object:bcvDict];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	//jump to v1 of that book & ch.
	[self jumpToVerseOne:indexPath.section];
}

- (void)accessoryButtonPressed:(id)sender {
	NSInteger chapterIndex = ((UIView*)sender).tag - 1000;
	[self jumpToVerseOne:chapterIndex];
}

- (void)dealloc {
	[book release];
    [super dealloc];
}


@end

