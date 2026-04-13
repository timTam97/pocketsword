//
//  PSPreferencesController.h
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBasePreferencesController.h"

@interface PSPreferencesController : PSBasePreferencesController {

	UILabel *fontSizeLabel;
}

- (void)strongsGreekModuleChanged:(NSString *)newModule;
- (void)strongsHebrewModuleChanged:(NSString *)newModule;
- (void)morphGreekModuleChanged:(NSString *)newModule;

@end
