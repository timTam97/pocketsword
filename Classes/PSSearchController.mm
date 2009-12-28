//
//  PSMultiListController.mm
//  PocketSword
//
//  Created by Nic Carter on 9/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSSearchController.h"
#import "PSIndexController.h"
#import "SwordModuleTextEntry.h"


@implementation PSSearchController

@synthesize results;

BOOL searchingEnabled;


- (void)viewDidAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	ShownTab tab = [dataController listType];
	BOOL showIndexController = NO;
	switch(tab) {
		case BibleTab:
			if(![[moduleManager primaryBible] hasSearchIndex])
				showIndexController = YES;
			break;
		case CommentaryTab:
			if(![[moduleManager primaryCommentary] hasSearchIndex])
				showIndexController = YES;
			break;
	}
	if(showIndexController) {
		PSIndexController *indexC = [[PSIndexController alloc] initWithNibName:@"IndexDownloader" bundle:nil];
		[indexC setModuleManager:moduleManager];
		[ViewController showModal:indexC.view withTiming:0.3];
	}
	[self refreshView];
}

- (void)refreshView {
	ShownTab tab = [dataController listType];
	searchingEnabled = NO;
	switch(tab) {
		case BibleTab:
			if([[moduleManager primaryBible] hasSearchIndex])
				searchingEnabled = YES;
			break;
		case CommentaryTab:
			if([[moduleManager primaryCommentary] hasSearchIndex])
				searchingEnabled = YES;
			break;
	}
	if(searchingEnabled) {
		//enable search
		[sBar setUserInteractionEnabled: YES];
	} else {
		//disable search
		[sBar setUserInteractionEnabled: NO];
	}
}

- (void)dealloc {
	self.results = nil;
    [super dealloc];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(results)
		return [results count];
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if(!searchingEnabled) {
		return @"No Search Index Installed";
	} else {
		if(results)
			return [NSString stringWithFormat: @"%d results", [results count]];
	}
	return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 65;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resultsCell"];
    UILabel *mainLabel, *secondLabel;

	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"resultsCell"] autorelease];
		mainLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20.0, 0.0, 320.0, 15.0)] autorelease];
        mainLabel.tag = 477;
        mainLabel.font = [UIFont boldSystemFontOfSize:14.0];
        mainLabel.textColor = [UIColor blackColor];
        mainLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;// | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:mainLabel];
		
        secondLabel = [[[UILabel alloc] initWithFrame:CGRectMake(5.0, 20.0, 310.0, 45.0)] autorelease];
        secondLabel.tag = 577;
        secondLabel.font = [UIFont systemFontOfSize:12.0];
		secondLabel.numberOfLines = 3;
		secondLabel.lineBreakMode = UILineBreakModeWordWrap;
        secondLabel.textColor = [UIColor darkGrayColor];
        secondLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;// | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:secondLabel];
		
	} else {
        mainLabel = (UILabel *)[cell.contentView viewWithTag:477];
        secondLabel = (UILabel *)[cell.contentView viewWithTag:577];
	}
	if(!((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text || [((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text isEqualToString: @""]) {
		ShownTab tab = [dataController listType];
		SwordModuleTextEntry *entry;
		switch(tab) {
			case BibleTab:
				entry = [[moduleManager primaryBible] textEntryForKey:[PSModuleController createRefString:((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key] textType:TextTypeStripped];
				break;
			case CommentaryTab:
				entry = [[moduleManager primaryCommentary] textEntryForKey:[PSModuleController createRefString:((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key] textType:TextTypeStripped];
				break;
		}
		[results replaceObjectAtIndex:indexPath.row withObject:entry];
	}
	mainLabel.text = ((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).key;
	NSMutableString *txt = [((SwordModuleTextEntry *)[results objectAtIndex: indexPath.row]).text mutableCopy];
	[txt replaceOccurrencesOfString:@"\n" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [txt length])];
	//NSLog(@"%@", txt);
	secondLabel.text = txt;
	[txt release];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//	if(downloadableShown && (indexPath.section == 1)) {
//		[self installSearchIndexForModule: (SwordModule*)[downloadableIndices objectAtIndex:indexPath.row]];
//	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[searchBar resignFirstResponder];
//	[self performSelectorOnMainThread: @selector(hideKeyboard) withObject: nil waitUntilDone: NO];
	[viewController performSelectorInBackground: @selector(displayBusyIndicator) withObject: nil];
	ShownTab tab = [dataController listType];
	self.results = nil;
	switch(tab) {
		case BibleTab:
			self.results = [[moduleManager primaryBible] search: [searchBar text]];
			break;
		case CommentaryTab:
			self.results = [[moduleManager primaryCommentary] search: [searchBar text]];
			break;
	}
	[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
	[resultsTable reloadData];
	[pool release];
}

//- (void)hideKeyboard {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	[sBar resignFirstResponder];
//	[pool release];
//}

- (IBAction)infoButtonPressed:(id)sender {
	
}

@end
