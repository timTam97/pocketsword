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

@property (retain, readwrite) NSString *searchTerm;
@property (retain, readwrite) NSString *searchTermToDisplay;
@property (assign, readwrite) BOOL strongsSearch;
@property (assign, readwrite) BOOL fuzzySearch;
@property (assign, readwrite) PSSearchType searchType;
@property (assign, readwrite) PSSearchRange searchRange;
@property (retain, readwrite) NSString *bookName;
@property (retain, readwrite) NSMutableArray *results;
@property (retain, readwrite) NSArray *savedTablePosition;

- (id)initWithSearchTermToDisplay:(NSString*)sTerm strongs:(BOOL)strongs fuzzy:(BOOL)fuzzy type:(PSSearchType)sType range:(PSSearchRange)sRange book:(NSString*)bName;
- (id)initWithArray:(NSArray *)array;

- (NSArray *)searchHistoryItemArray;

@end
