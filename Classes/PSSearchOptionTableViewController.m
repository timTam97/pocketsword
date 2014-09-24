//
//  PSSearchOptionTableViewController.m
//  PocketSword
//
//  Created by Nic Carter on 2/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSSearchOptionTableViewController.h"
//#import "PSModuleController.h"

@implementation PSSearchOptionTableViewController

@synthesize delegate, strongsSearch, fuzzySearch, searchType, searchRange, bookName;

#pragma mark -
#pragma mark Initialization

- (id)initWithTableType:(PSSearchOptionTableType)tType {
	self = [self init];
	if(self) {
		tableType = tType;
	}
	return self;
}

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        // Custom initialization.
		self.navigationItem.title = NSLocalizedString(@"SearchOptionsTitle", @"");
    }
    return self;
}



#pragma mark -
#pragma mark View lifecycle

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

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
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
	switch(tableType) {
		case PSSearchOptionTableTypeSelector:
			return SearchType_ROWS;
		case PSSearchOptionTableRangeSelector:
			return SearchRange_ROWS;
		case PSSearchOptionTableStrongsSelector:
			return SearchStrongs_ROWS;
		case PSSearchOptionTableFuzzySelector:
			return SearchFuzzy_ROWS;
	}
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch(tableType) {
		case PSSearchOptionTableTypeSelector:
			return NSLocalizedString(@"SearchTypeSectionHeader", @"");
		case PSSearchOptionTableRangeSelector:
			return NSLocalizedString(@"SearchRangeSectionHeader", @"");
		case PSSearchOptionTableStrongsSelector:
			return NSLocalizedString(@"SearchStrongsSectionHeader", @"");
		case PSSearchOptionTableFuzzySelector:
			return NSLocalizedString(@"SearchFuzzySectionHeader", @"");
	}
	return @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	switch(tableType) {
		case PSSearchOptionTableTypeSelector:
			return NSLocalizedString(@"SearchTypeSectionFooter", @"");
		case PSSearchOptionTableRangeSelector:
			return NSLocalizedString(@"SearchRangeSectionFooter", @"");
		case PSSearchOptionTableStrongsSelector:
			return NSLocalizedString(@"SearchStrongsSectionFooter", @"");
		case PSSearchOptionTableFuzzySelector:
			return NSLocalizedString(@"SearchFuzzySectionFooter", @"");
	}
	return @"";
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
	switch(tableType) {
		case PSSearchOptionTableTypeSelector:
		{
			switch(indexPath.row) {
				case SearchType_All:
					cell.textLabel.text = NSLocalizedString(@"SearchTypeAllRow", @"");
					if(self.searchType == AndSearch) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchType_Any:
					cell.textLabel.text = NSLocalizedString(@"SearchTypeAnyRow", @"");
					if(self.searchType == OrSearch) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchType_Exact:
					cell.textLabel.text = NSLocalizedString(@"SearchTypeExactRow", @"");
					if(self.searchType == ExactSearch) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
			}
		}
			break;
		case PSSearchOptionTableRangeSelector:
		{
			switch(indexPath.row) {
				case SearchRange_All:
					cell.textLabel.text = NSLocalizedString(@"SearchRangeAllRow", @"");
					if(self.searchRange == AllRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchRange_OT:
					cell.textLabel.text = NSLocalizedString(@"SearchRangeOTRow", @"");
					if(self.searchRange == OTRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchRange_NT:
					cell.textLabel.text = NSLocalizedString(@"SearchRangeNTRow", @"");
					if(self.searchRange == NTRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchRange_Book:
				{
					cell.textLabel.text = self.bookName;
					if(self.searchRange == BookRange) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
				}
					break;
			}
		}
			break;
		case PSSearchOptionTableStrongsSelector:
		{
			switch(indexPath.row) {
				case SearchStrongs_Off:
					cell.textLabel.text = NSLocalizedString(@"Off", @"");
					if(self.strongsSearch == NO) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchStrongs_On:
					cell.textLabel.text = NSLocalizedString(@"On", @"");
					if(self.strongsSearch == YES) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
			}
		}
			break;
		case PSSearchOptionTableFuzzySelector:
		{
			switch(indexPath.row) {
				case SearchFuzzy_Off:
					cell.textLabel.text = NSLocalizedString(@"Off", @"");
					if(self.fuzzySearch == NO) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
				case SearchFuzzy_On:
					cell.textLabel.text = NSLocalizedString(@"On", @"");
					if(self.fuzzySearch == YES) {
						cell.accessoryType = UITableViewCellAccessoryCheckmark;
					} else {
						cell.accessoryType = UITableViewCellAccessoryNone;
					}
					break;
			}
		}
			break;
	}
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	switch(tableType) {
		case PSSearchOptionTableTypeSelector:
		{
			switch(indexPath.row) {
				case SearchType_All:
					self.searchType = AndSearch;
					break;
				case SearchType_Any:
					self.searchType = OrSearch;
					break;
				case SearchType_Exact:
					self.searchType = ExactSearch;
					break;
			}
			[self.tableView reloadData];
			[delegate setSearchType:self.searchType];
			[[NSUserDefaults standardUserDefaults] setInteger:self.searchType forKey:DefaultsLastSearchType];
		}
			break;
		case PSSearchOptionTableRangeSelector:
		{
			switch(indexPath.row) {
				case SearchRange_All:
					self.searchRange = AllRange;
					break;
				case SearchRange_OT:
					self.searchRange = OTRange;
					break;
				case SearchRange_NT:
					self.searchRange = NTRange;
					break;
				case SearchRange_Book:
					self.searchRange = BookRange;
					break;
			}
			[self.tableView reloadData];
			[delegate setSearchRange:self.searchRange];
			[[NSUserDefaults standardUserDefaults] setInteger:self.searchRange forKey:DefaultsLastSearchRange];
		}
			break;
		case PSSearchOptionTableStrongsSelector:
		{
			switch(indexPath.row) {
				case SearchStrongs_Off:
					self.strongsSearch = NO;
					break;
				case SearchStrongs_On:
					self.strongsSearch = YES;
					break;
			}
			[self.tableView reloadData];
			[delegate setStrongsSearch:self.strongsSearch];
		}
			break;
		case PSSearchOptionTableFuzzySelector:
		{
			switch(indexPath.row) {
				case SearchFuzzy_Off:
					self.fuzzySearch = NO;
					break;
				case SearchFuzzy_On:
					self.fuzzySearch = YES;
					break;
			}
			[self.tableView reloadData];
			[delegate setFuzzySearch:self.fuzzySearch];
			[[NSUserDefaults standardUserDefaults] setBool:self.fuzzySearch forKey:DefaultsLastSearchFuzzy];
		}
			break;
	}
	
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
	[super viewDidUnload];
}


- (void)dealloc {
    [super dealloc];
}


@end

