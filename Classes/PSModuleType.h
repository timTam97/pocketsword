//
//  PSModuleType.h
//  PocketSword
//
//  Created by Nic Carter on 7/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "SwordModule.h"


@interface PSModuleType : NSObject {
	NSArray *modules;
	NSString *moduleType;
	NSArray *moduleLanguages;
	NSArray *moduleList;
}

@property (strong, readwrite) NSString *moduleType;
@property (strong, readonly) NSArray *modules;
@property (strong, readwrite) NSArray *moduleLanguages;
@property (strong, readwrite) NSArray *moduleList;

- (id)initWithModules:(NSArray *)mods withModuleType:(NSString *)modType;
- (void)setModules:(NSArray *)mods;

@end
