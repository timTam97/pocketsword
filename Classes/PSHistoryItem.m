//
//  PSHistoryItem.m
//  PocketSword
//
//  Created by Nic Carter on 22/01/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

#import "PSHistoryItem.h"
#import "PSModuleController.h"

@implementation PSHistoryItem

@synthesize bibleReference, scrollAmount, dateAdded, moduleName;

+ (NSArray *)parseHistoryArrayArray:(NSArray*)arrays {
	if(!arrays)
		return nil;
	
	NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:[arrays count]];
	for(NSArray *item in arrays) {
		PSHistoryItem *historyItem = [[PSHistoryItem alloc] initWithArray:item];
		[returnArray addObject:historyItem];
		[historyItem release];
	}
	return returnArray;
}

+ (NSArray *)arrayArrayFromHistoryItems:(NSArray*)arrayOfHistoryItems {
	if(!arrayOfHistoryItems)
		return nil;
	
	NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:[arrayOfHistoryItems count]];
	for(PSHistoryItem *item in arrayOfHistoryItems) {
		[returnArray addObject:[item array]];
	}
	return returnArray;
}

+ (BOOL)arraysAreEqual:(NSArray*)firstArray secondArray:(NSArray*)secondArray {
	if([firstArray count] != [secondArray count])
		return NO;
	
	for(int i = 0; i < [firstArray count]; ++i) {
		PSHistoryItem *firstHI = [firstArray objectAtIndex:i];
		PSHistoryItem *secondHI = [secondArray objectAtIndex:i];
		if(![firstHI.bibleReference isEqualToString:secondHI.bibleReference] ||
		   ![firstHI.moduleName isEqualToString:secondHI.moduleName]) {
			return NO;
		}
	}
	return YES;
}

- (id)initWithReference:(NSString*)ref scrollAmount:(NSString*)scrollString moduleName:(NSString*)mod dateAdded:(NSDate*)da {
	self = [super init];
	if(self) {
		self.bibleReference = ref;
		self.scrollAmount = scrollString;
		self.moduleName = mod;
		self.dateAdded = da;
	}
	return self;
}

- (id)initWithArray:(NSArray*)historyArray {
	self = [super init];
	if(self) {
		if(historyArray && [historyArray count] >= 2) {
			self.bibleReference = [historyArray objectAtIndex:0];
			self.scrollAmount = [historyArray objectAtIndex:1];
			if([historyArray count] < 3) {
				self.moduleName = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsLastBible];
			} else {
				self.moduleName = [historyArray objectAtIndex:2];
			}
			if([historyArray count] < 4) {
				self.dateAdded = [NSDate distantPast];
				
			} else {
				self.dateAdded = [historyArray objectAtIndex:3];
			}
		} else {
			self.bibleReference = [PSModuleController getFirstRefAvailable];
			self.scrollAmount = @"0";
			self.moduleName = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsLastBible];
			self.dateAdded = [NSDate distantPast];
		}
	}
	return self;
}

- (NSArray *)array {
	return [NSArray arrayWithObjects: self.bibleReference, @"0"/*scroll*/, self.moduleName, self.dateAdded, nil];
}

- (BOOL)isEqualToHistoryItem:(PSHistoryItem*)otherHistoryItem {
	
	if(!otherHistoryItem)
		return NO;
	
	if([self.bibleReference isEqualToString:otherHistoryItem.bibleReference]
	   && [self.moduleName isEqualToString:otherHistoryItem.moduleName]
	   && [self.dateAdded isEqualToDate:otherHistoryItem.dateAdded])
		return YES;
	
	return NO;
}

// determines if self is older than otherHistoryItem
- (PSHistoryItemAge)ageComparisonToHistoryItem:(PSHistoryItem*)otherHistoryItem {
	
	if(!otherHistoryItem)
		return PSHistoryItemInvalidAge;
	
	NSTimeInterval timeInterval = [self.dateAdded timeIntervalSinceDate:otherHistoryItem.dateAdded];
	
	if(timeInterval < 0) {
		//self is before otherHistoryItem
		return PSHistoryItemOlder;
	} else if(timeInterval == 0) {
		//should be equal?
		return PSHistoryItemEqual;
	} else if(timeInterval > 0) {
		//self is after otherHistoryItem
		return PSHistoryItemNewer;
	}
	
	return PSHistoryItemInvalidAge;
}

- (void)dealloc {
	self.bibleReference = nil;
	self.dateAdded = nil;
	self.scrollAmount = nil;
	self.moduleName = nil;
	[super dealloc];
}

@end
