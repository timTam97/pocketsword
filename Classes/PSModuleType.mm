//
//  PSModuleType.m
//  PocketSword
//
//  Created by Nic Carter on 7/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleType.h"
#import "PSLanguageCode.h"


@implementation PSModuleType

@synthesize moduleType;
@synthesize modules;
@synthesize moduleLanguages;
@synthesize moduleList;

-(id)initWithModules:(NSArray *)mods withModuleType:(NSString *)modType {
	if ((self = [super init]) == nil) {
		return nil;
	}
	[self setModules:mods];
	[self setModuleType:modType];
	return self;
}

-(NSArray*)getAvailableLanguages:(NSArray *)mods {
	NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:10];
	NSMutableArray *tmp = [[NSMutableArray alloc] initWithCapacity:10];
    
	for(SwordModule *mod in mods) {
		if(![tmp containsObject: [mod lang]]) {
			PSLanguageCode *lang = [[PSLanguageCode alloc] initWithCode:[mod lang]];
			NSString *langString = [NSString stringWithString:[mod lang]];
			[ret addObject:lang];
			[tmp addObject:langString];
		}
    }

    // sort
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"descr" ascending:YES];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[ret sortUsingDescriptors:sortDescriptors];
    
	NSArray *returnArray = [NSArray arrayWithArray:ret];
	return returnArray;
}

-(NSArray*)getModulesByLanguage:(NSString *)lang fromModuleArray:(NSArray *)mods {
	NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:10];
	for(SwordModule *mod in mods) {
		if([[mod lang] isEqualToString:lang]) {
			[ret addObject:mod];
		}
	}
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[ret sortUsingDescriptors:sortDescriptors];
	return ret;
}

- (void)setModules:(NSArray *)mods {
	NSMutableArray *modList = [[NSMutableArray alloc] initWithCapacity:10];
	//we accept a list of mods and need to create a list of mods per language.
	[self setModuleLanguages:[self getAvailableLanguages:mods]];
	for(PSLanguageCode *lang in moduleLanguages) {
		[modList addObject:[self getModulesByLanguage:lang.code fromModuleArray:mods]];
	}
	modules = modList;
	[self setModuleList:mods];
}

@end
