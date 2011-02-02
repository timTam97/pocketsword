//
//  PSSearchOptionTableViewController.h
//  PocketSword
//
//  Created by Nic Carter on 2/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"


typedef enum {
	PSSearchOptionTableTypeSelector = 1,
	PSSearchOptionTableRangeSelector,
	PSSearchOptionTableStrongsSelector,
	PSSearchOptionTableFuzzySelector
} PSSearchOptionTableType;

#define SearchType_All			0
#define SearchType_Any			1
#define SearchType_Exact		2
#define SearchType_ROWS			3

#define SearchRange_All			0
#define SearchRange_OT			1
#define SearchRange_NT			2
#define SearchRange_Book		3
#define SearchRange_ROWS		4

#define SearchStrongs_Off		0
#define SearchStrongs_On		1
#define SearchStrongs_ROWS		2

#define SearchFuzzy_Off			0
#define SearchFuzzy_On			1
#define SearchFuzzy_ROWS		2

@protocol PSSearchOptionsDelegate <NSObject>
@required
- (void)setSearchRange:(PSSearchRange)sRange;
- (void)setSearchType:(PSSearchType)sType;
- (void)setStrongsSearch:(BOOL)strongs;
- (void)setFuzzySearch:(BOOL)fuzzy;
@end

@interface PSSearchOptionTableViewController : UITableViewController {
	id <PSSearchOptionsDelegate> delegate;
	
	PSSearchOptionTableType tableType;
	PSSearchRange searchRange;
	PSSearchType searchType;
	BOOL strongsSearch;
	BOOL fuzzySearch;
	NSString *bookName;
}

@property (nonatomic, assign) id <PSSearchOptionsDelegate> delegate;
@property (assign, readwrite) BOOL strongsSearch;
@property (assign, readwrite) BOOL fuzzySearch;
@property (assign, readwrite) PSSearchType searchType;
@property (assign, readwrite) PSSearchRange searchRange;
@property (retain, readwrite) NSString *bookName;

- (id)initWithTableType:(PSSearchOptionTableType)tType;

@end
