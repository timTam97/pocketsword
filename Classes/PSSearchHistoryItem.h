//
//  PSSearchHistoryItem.h
//  PocketSword
//
//  Created by Nic Carter on 1/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"

@interface PSSearchHistoryItem : NSObject {
	//NSString *searchTerm;
	NSString *searchTermToDisplay;
	
	BOOL strongsSearch;
	PSSearchType searchType;
	PSSearchRange searchRange;
	NSString *bookName;// if searchRange == BookRange, we need to save which book we're interested in!
	
	NSMutableArray *results;
	
}

@property (retain, readwrite) NSString *searchTermToDisplay;
@property (assign, readwrite) BOOL strongsSearch;
@property (assign, readwrite) PSSearchType searchType;
@property (assign, readwrite) PSSearchRange searchRange;
@property (retain, readwrite) NSString *bookName;
@property (retain, readwrite) NSMutableArray *results;

- (id)initWithSearchTerm:(NSString*)sTerm strongs:(BOOL)strongs type:(PSSearchType)sType range:(PSSearchRange)sRange book:(NSString*)bName;
- (NSArray *)searchHistoryItemArray;

@end
