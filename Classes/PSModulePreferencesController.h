//
//  PSPreferencesController.h
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "ViewController.h"
#import "PSModuleController.h"
//#import "PSPreferencesFontTableViewController.h"
#import "PSBasePreferencesController.h"

@interface PSModulePreferencesController : PSBasePreferencesController {
	
	IBOutlet UITabBarItem		*preferencesTabBarItem;
	IBOutlet UITableView		*preferencesTable;
	IBOutlet UINavigationBar	*preferencesNavigationBar;
	IBOutlet UINavigationItem	*preferencesNavigationItem;
	IBOutlet UIBarButtonItem	*closeButton;

	IBOutlet id fontTableViewController;
	IBOutlet id moduleSelectorTableViewController;
	
	UILabel *fontSizeLabel;

	//sections
	NSInteger DisplaySection, ModuleSection, StrongsSection, MorphSection, LangSection;
	NSInteger Sections;//total sections
	
	//rows in DISPLAY section
	NSInteger FontSizeRow, FontNameRow;
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

- (void)displayPrefsForModule:(SwordModule*)swordModule;

//- (void)displayStrongsChanged:(UISwitch *)sender;
//- (void)displayMorphChanged:(UISwitch *)sender;
//- (void)displayGreekAccentsChanged:(UISwitch *)sender;
//- (void)displayHVPChanged:(UISwitch *)sender;
//- (void)displayHebrewCantillationChanged:(UISwitch *)sender;
//- (void)morphGreekModuleChanged:(NSString *)newModule;
//- (void)strongsGreekModuleChanged:(NSString *)newModule;
//- (void)strongsHebrewModuleChanged:(NSString *)newModule;
//- (void)xrefChanged:(UISwitch *)sender;
//- (void)footnotesChanged:(UISwitch *)sender;
//- (void)fontSizeChanged:(UISlider *)sender;
//- (void)redLetterChanged:(UISwitch *)sender;
//- (void)fontNameChanged:(NSString *)newFont;

@end
