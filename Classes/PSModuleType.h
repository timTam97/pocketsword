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

@property (retain, readwrite) NSString *moduleType;
@property (retain, readonly) NSArray *modules;
@property (retain, readwrite) NSArray *moduleLanguages;
@property (retain, readwrite) NSArray *moduleList;

- (id)initWithModules:(NSArray *)mods withModuleType:(NSString *)modType;
- (void)dealloc;
- (void)setModules:(NSArray *)mods;

@end
