//
//  PSSearchHistoryItem.h
//  PocketSword
//
//  Created by Nic Carter on 1/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"

@interface PSSearchHistoryItem : NSObject {
	NSString *searchTerm;
	NSString *searchTermToDisplay;
	
	BOOL strongsSearch;
	BOOL fuzzySearch;
	PSSearchType searchType;
	PSSearchRange searchRange;
	NSString *bookName;// if searchRange == BookRange, we need to save which book we're interested in!
	
	NSMutableArray *results;
	NSArray *savedTablePosition;
}

@property (strong, readwrite) NSString *searchTerm;
@property (strong, readwrite) NSString *searchTermToDisplay;
@property (assign, readwrite) BOOL strongsSearch;
@property (assign, readwrite) BOOL fuzzySearch;
@property (assign, readwrite) PSSearchType searchType;
@property (assign, readwrite) PSSearchRange searchRange;
@property (strong, readwrite) NSString *bookName;
@property (strong, readwrite) NSMutableArray *results;
@property (strong, readwrite) NSArray *savedTablePosition;

- (id)initWithSearchTermToDisplay:(NSString*)sTerm strongs:(BOOL)strongs fuzzy:(BOOL)fuzzy type:(PSSearchType)sType range:(PSSearchRange)sRange book:(NSString*)bName;
- (id)initWithArray:(NSArray *)array;

- (NSArray *)searchHistoryItemArray;

@end
