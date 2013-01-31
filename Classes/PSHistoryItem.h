//
//  PSHistoryItem.h
//  PocketSword
//
//  Created by Nic Carter on 22/01/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"

typedef enum {
	PSHistoryItemOlder = 0,
	PSHistoryItemEqual,
	PSHistoryItemNewer,
	PSHistoryItemInvalidAge
} PSHistoryItemAge;

@interface PSHistoryItem : NSObject {

	NSString *bibleReference;
	NSString *scrollAmount;
	NSString *moduleName;
	NSDate *dateAdded;
}

@property (retain, readwrite) NSString *bibleReference;
@property (retain, readwrite) NSString *scrollAmount;
@property (retain, readwrite) NSString *moduleName;
@property (retain, readwrite) NSDate *dateAdded;

- (id)initWithReference:(NSString*)ref scrollAmount:(NSString*)scrollString moduleName:(NSString*)mod dateAdded:(NSDate*)da;
- (id)initWithArray:(NSArray*)historyArray;
- (NSArray *)array;
- (BOOL)isEqualToHistoryItem:(PSHistoryItem*)otherHistoryItem;
// determines if self is older than otherHistoryItem
- (PSHistoryItemAge)ageComparisonToHistoryItem:(PSHistoryItem*)otherHistoryItem;

+ (NSArray *)parseHistoryArrayArray:(NSArray*)arrays;
+ (NSArray *)arrayArrayFromHistoryItems:(NSArray*)arrayOfHistoryItems;
+ (BOOL)arraysAreEqual:(NSArray*)firstArray secondArray:(NSArray*)secondArray;

@end
