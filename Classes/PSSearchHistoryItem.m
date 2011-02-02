//
//  PSSearchHistoryItem.m
//  PocketSword
//
//  Created by Nic Carter on 1/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSSearchHistoryItem.h"


@implementation PSSearchHistoryItem

@synthesize searchTerm, searchTermToDisplay, strongsSearch, searchType, searchRange, bookName, results, savedTablePosition;

- (id)init {
	self = [super init];
	if(self) {
		self.searchTerm = nil;
		self.searchTermToDisplay = nil;
		self.strongsSearch = NO;
		self.searchType = AndSearch;
		self.searchRange = AllRange;
		self.bookName = nil;
		self.results = nil;
		self.savedTablePosition = nil;
	}
	return self;
}

- (id)initWithSearchTermToDisplay:(NSString*)sTerm strongs:(BOOL)strongs type:(PSSearchType)sType range:(PSSearchRange)sRange book:(NSString*)bName {
	self = [self init];
	if(self) {
		self.searchTermToDisplay = sTerm;
		self.strongsSearch = strongs;
		self.searchType = sType;
		self.searchRange = sRange;
		self.bookName = bName;
	}
	return self;
}

- (id)initWithArray:(NSArray *)array {
	self = [self init];
	if(self && array) {
		if([array count] > 0) {
			self.searchTermToDisplay = [array objectAtIndex:0];
		} else {
			self.searchTermToDisplay = nil;
		}
		if([array count] > 1) {
			self.strongsSearch = [(NSString*)[array objectAtIndex:1] boolValue];
		}
		if([array count] > 2) {
			self.searchType = (PSSearchType)[(NSString*)[array objectAtIndex:2] intValue];
		}
		if([array count] > 3) {
			self.searchRange = (PSSearchRange)[(NSString*)[array objectAtIndex:3] intValue];
		}
		if([array count] > 4) {
			self.bookName = [array objectAtIndex:4];
		} else {
			self.bookName = nil;
		}
	}
	return self;
}

- (void)dealloc {
	self.searchTermToDisplay = nil;
	self.bookName = nil;
	self.results = nil;
	[super dealloc];
}

- (NSArray *)searchHistoryItemArray {
	NSString *strongs = (strongsSearch) ? @"Y" : @"N";
	NSString *sType = [NSString stringWithFormat:@"%d", searchType];
	NSString *sRange = [NSString stringWithFormat:@"%d", searchRange];
	return [NSArray arrayWithObjects:searchTermToDisplay, strongs, sType, sRange, bookName, nil];
}

@end
