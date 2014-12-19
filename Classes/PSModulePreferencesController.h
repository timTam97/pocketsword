//
//  PSPreferencesController.h
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "globals.h"
#import "PSBasePreferencesController.h"

@class PSModuleController;
@class SwordModule;

@interface PSModulePreferencesController : PSBasePreferencesController {
	
	UILabel		*fontSizeLabel;
	BOOL		hackTableView;
	ShownTab	listType;

	//sections
	NSInteger DisplaySection, ModuleSection, StrongsSection, MorphSection, LangSection;
	NSInteger Sections;//total sections
	
	//rows in DISPLAY section
	NSInteger FontDefaultsRow, FontSizeRow, FontNameRow;
	NSInteger DisplayRows;//total rows in section
	
	//rows in the MODULE section
	NSInteger VPLRow, XrefRow, FootnotesRow, HeadingsRow, RedLetterRow;
	NSInteger ModuleRows;//total rows in section
	
	//rows in STRONGS section
	NSInteger StrongsToggleRow, StrongsGreekRow, StrongsHebrewRow;
	NSInteger StrongsRows;//total rows in section
	
	//rows in MORPH section
	NSInteger MorphToggleRow, MorphGreekRow;
	NSInteger MorphRows;//total rows in section
	
	//rows in LANG section
	NSInteger LangGreekAccentsRow, LangHebrewPointsRow, LangHebrewCantillationRow;
	NSInteger LangRows;//total rows in section
}

@property BOOL hackTableView;
@property (assign) ShownTab listType;

- (void)displayPrefsForModule:(SwordModule*)swordModule;
- (void)redisplayFromButtonPress;

@end
