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
//			NSLog(@"\nitem %d: refs: %@ = %@\nmods: %@ = %@\ndates: %@ = %@\n", i, firstHI.bibleReference, secondHI.bibleReference, firstHI.moduleName, secondHI.moduleName, firstHI.dateAdded, secondHI.dateAdded);
//			if(![firstHI.bibleReference isEqualToString:secondHI.bibleReference]) {
//				NSLog(@"refs not equal!");
//			} else if(![firstHI.moduleName isEqualToString:secondHI.moduleName]) {
//				NSLog(@"mods not equal!");
//			} else if(![firstHI.dateAdded isEqualToDate:secondHI.dateAdded]) {
//				NSLog(@"dates not equal!");
//			}
			return NO;
		}
	}
//	NSLog(@"\narrays ARE equal :P");
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

- (void)dealloc {
	self.bibleReference = nil;
	self.dateAdded = nil;
	self.scrollAmount = nil;
	self.moduleName = nil;
	[super dealloc];
}

@end
