//
//  PSPreferencesController.m
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBasePreferencesController.h"
#import "PSModulePreferencesController.h"
//#import "ViewController.h"
#import "PSModuleController.h"
#import "PSResizing.h"


@implementation PSModulePreferencesController

//BOOL requireReloadOfModuleView = NO;

- (void)viewDidLoad {
	[super viewDidLoad];
	//preferencesTabBarItem.title = NSLocalizedString(@"TabBarTitlePreferences", @"Preferences");
	//self.navigationItem.title = NSLocalizedString(@"PreferencesTitle", @"Preferences");
	fontSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(140.0, 2.0, 20.0, 42.0)];
	fontSizeLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	fontSizeLabel.textColor = [UIColor darkTextColor];
	fontSizeLabel.text = @"12";
	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:preferencesNavigationBar mainView:preferencesTable useStatusBar:YES];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:preferencesNavigationBar mainView:preferencesTable fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[preferencesTable reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
//	if(requireReloadOfModuleView) {
//		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
//	}
//	requireReloadOfModuleView = NO;
}

- (void)displayPrefsForModule:(SwordModule*)swordModule {
	//set title to the module name
	preferencesNavigationItem.title = [swordModule name];
	
	// init sections
	DisplaySection = ModuleSection = StrongsSection = MorphSection = LangSection = -1;
	Sections = 0;
	
	//init row totals
	DisplayRows = ModuleRows = StrongsRows = MorphRows = LangRows = 0;

	// init row indices
	FontDefaultsRow = FontSizeRow = FontNameRow = VPLRow = XrefRow = FootnotesRow = HeadingsRow = RedLetterRow = StrongsToggleRow = StrongsGreekRow = StrongsHebrewRow = MorphToggleRow = MorphGreekRow = LangGreekAccentsRow = LangHebrewPointsRow = LangHebrewCantillationRow = -1;
	
	// Display section:
	DisplaySection = Sections++;
	FontDefaultsRow = DisplayRows++;
	BOOL fontDefaults = GetBoolPrefForMod(DefaultsFontDefaultsPreference, preferencesNavigationItem.title);
	if(fontDefaults) {
		FontSizeRow = DisplayRows++;
		FontNameRow = DisplayRows++;
	}
	
	// Module section:
	//always show the VPL option.
	if([swordModule type] == bible) {
		VPLRow = ModuleRows++;
	}
	if([swordModule hasFeature: SWMOD_FEATURE_HEADINGS]) {
		HeadingsRow = ModuleRows++;
	}
	if([swordModule hasFeature: SWMOD_FEATURE_FOOTNOTES]) {
		FootnotesRow = ModuleRows++;
	}
	if([swordModule hasFeature: SWMOD_FEATURE_SCRIPTREF]) {
		XrefRow = ModuleRows++;
	}
	if([swordModule hasFeature: SWMOD_FEATURE_REDLETTERWORDS]) {
		RedLetterRow = ModuleRows++;
	}
	if(ModuleRows > 0) {
		ModuleSection = Sections++;
	}
	
	// Strongs section:
	if([swordModule hasFeature: SWMOD_FEATURE_STRONGS] || [swordModule hasFeature: SWMOD_CONF_FEATURE_STRONGS]) {
		StrongsToggleRow = StrongsRows++;
		//StrongsGreekRow = StrongsRows++;
		//StrongsHebrewRow = StrongsRows++;
		StrongsSection = Sections++;
	}
	
	// Morph section:
	if([swordModule hasFeature: SWMOD_FEATURE_MORPH]) {
		MorphToggleRow = MorphRows++;
		//MorphGreekRow = MorphRows++;
		MorphSection = Sections++;
	}
	
	// Lang section:
	if([swordModule hasFeature: SWMOD_FEATURE_GREEKACCENTS]) {
		LangGreekAccentsRow = LangRows++;
	}
	if([swordModule hasFeature: SWMOD_FEATURE_HEBREWPOINTS]) {
		LangHebrewPointsRow = LangRows++;
	}
	if([swordModule hasFeature: SWMOD_FEATURE_CANTILLATION]) {
		LangHebrewCantillationRow = LangRows++;
	}
	if(LangRows > 0) {
		LangSection = Sections++;
	}
	
	//	if([swordModule hasFeature: SWMOD_FEATURE_VARIANTS]) //not currently supported in PocketSword
	//		{}
	//	if([swordModule hasFeature: SWMOD_FEATURE_LEMMA])
	//		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsLemma", @"")];
	
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[fontSizeLabel release];
}

- (void)dealloc {
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[preferencesTable reloadData];
	//[preferencesTable reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, PREF__SECTIONS)] withRowAnimation:UITableViewRowAnimationFade];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return Sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(section == DisplaySection)
		return DisplayRows;
	else if(section == ModuleSection)
		return ModuleRows;
	else if(section == StrongsSection)
		return StrongsRows;
	else if(section == MorphSection)
		return MorphRows;
	else if(section == LangSection)
		return LangRows;
	else
		return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(section == DisplaySection)
		return NSLocalizedString(@"PreferencesDisplayPreferencesTitle", @"Display Preferences");
	else if(section == ModuleSection)
		return NSLocalizedString(@"PreferencesModulePreferencesTitle", @"Module Preferences");
	else if(section == StrongsSection)
		return NSLocalizedString(@"PreferencesStrongsPreferencesTitle", @"Strong's Preferences");
	else if(section == MorphSection)
		return NSLocalizedString(@"PreferencesMorphologyPreferencesTitle", @"Morphology Preferences");
	else if(section == LangSection)
		return NSLocalizedString(@"PreferencesOriginalLanguagePreferencesTitle", @"Original Language");
	else
		return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//	switch (indexPath.section) {
//		case DISPLAY_SECTION :
//			switch (indexPath.row) {
//				case FULLSCREEN_NOTE_ROW :
//					return 75;
//				default :
//					return 45;
//			}
//			break;
//		case MODULE_SECTION :
//			switch (indexPath.row) {
//				case RED_LETTER_NOTE_ROW :
//					return 38;
//				default :
//					return 45;
//			}
//			break;
//		case DEVICE_SECTION :
//			switch (indexPath.row) {
//				case MMM_NOTE_ROW :
//					return 110;
//				default :
//					return 45;
//			}
//			break;
//	}
	return 45;
}


// yes, this method is kinda out of control.  *sigh*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *CellIdentifierPlain = @"prefs-plain";
	static NSString *CellIdentifierStyled = @"prefs-styled";
	static NSString *CellIdentifierFS = @"prefs-fs";
	
    UITableViewCell *cell = nil;
	BOOL resetCell = YES;
	
	if(indexPath.section == DisplaySection) {
		if(indexPath.row == FontDefaultsRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
//				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
			}
		} else if(indexPath.row == FontSizeRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierFS];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierFS] autorelease];
//				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierFS] autorelease];
				
				[cell addSubview: fontSizeLabel];
			}
			//resetCell = NO;
		} else if(indexPath.row == FontNameRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierStyled];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifierStyled] autorelease];
			}
		}
	} else if(indexPath.section == ModuleSection) {
		if(indexPath.row == VPLRow || indexPath.row == XrefRow || indexPath.row == FootnotesRow || indexPath.row == HeadingsRow || indexPath.row == RedLetterRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
//				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
			}
		}
	} else if(indexPath.section == StrongsSection) {
		if(indexPath.row == StrongsToggleRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
//				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
			}
		} else if(indexPath.row == StrongsGreekRow || indexPath.row == StrongsHebrewRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierStyled];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifierStyled] autorelease];
			}
		}
	} else if(indexPath.section == MorphSection) {
		if(indexPath.row == MorphToggleRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
//				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
			}
		} else if(indexPath.row == MorphGreekRow /*|| indexPath.row == MORPH_H_ROW*/) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierStyled];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifierStyled] autorelease];
			}
		}
	} else if(indexPath.section == LangSection) {
		cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
		if(!cell) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
//			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
		}
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	//cell.textLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];//[UIFont systemFontOfSize:12.0];
	cell.textLabel.textColor = [UIColor darkTextColor];
	
	CGFloat xx = 0.0;
	BOOL deviceIsPad = [PSResizing iPad];
	UIInterfaceOrientation interfaceOrientation = self.navigationController.interfaceOrientation;
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		xx = 160.0;
		if(deviceIsPad) {
			xx += 95.0;
		}
	}
	if(deviceIsPad) {
		xx += 420.0;
	}
	
	if(resetCell) {
		for(UIView *subv in [cell subviews]) {
			if([subv isMemberOfClass:[UISlider class]] || [subv isMemberOfClass:[UISwitch class]]) {
				[subv removeFromSuperview];
			}
		}
	}
	
	if(indexPath.section == DisplaySection) {
		if(indexPath.row == FontDefaultsRow) {
			UISwitch *fontDefaultsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//vplSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL fontDefaults = GetBoolPrefForMod(DefaultsFontDefaultsPreference, preferencesNavigationItem.title);
			fontDefaultsSwitch.on = fontDefaults;
			//vplSwitch.tag = 4;
			[fontDefaultsSwitch addTarget:self action:@selector(fontDefaultsChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: fontDefaultsSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesFontDefaultTitle", @"Verse Per Line");
			[fontDefaultsSwitch release];						
		} else if(indexPath.row == FontSizeRow) {
			UISlider *fontSizeSlider = [ [ UISlider alloc ] initWithFrame: CGRectMake(xx+170, 0, 125, 50) ];
			//fontSizeSlider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			fontSizeSlider.minimumValue = 10.0;
			fontSizeSlider.maximumValue = 20.0;
			NSInteger fontSize = GetIntegerPrefForMod(DefaultsFontSizePreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
			if(fontSize != 0) {//defaults default to 0 if it's not previously set...
				fontSizeSlider.value = (float)fontSize;
			} else {
				fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
				if(fontSize != 0) {
					fontSizeSlider.value = (float)fontSize;
					SetIntegerPrefForMod(fontSize, DefaultsFontSizePreference, preferencesNavigationItem.title);
				} else {
					fontSizeSlider.value = 12.0;
					SetIntegerPrefForMod(12, DefaultsFontSizePreference, preferencesNavigationItem.title);
					[[NSUserDefaults standardUserDefaults] setInteger:12 forKey:DefaultsFontSizePreference];
					[[NSUserDefaults standardUserDefaults] synchronize];
				}
			}
			fontSizeSlider.continuous = YES;
			[fontSizeSlider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: fontSizeSlider ];
			[ fontSizeSlider release ];

			//NSInteger fontSize = GetIntegerPrefForMod(DefaultsFontSizePreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
			//cell.textLabel.text = [NSString stringWithFormat:@"%@: %i", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size"), fontSize];
			cell.textLabel.text = [NSString stringWithFormat:@"%@:", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size")];
			fontSizeLabel.text = [NSString stringWithFormat:@"%d", fontSize];
		} else if(indexPath.row == FontNameRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesFontTitle", @"Font");
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			NSString *font = GetStringPrefForMod(DefaultsFontNamePreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] stringForKey:DefaultsFontNamePreference];
			if(!font)
				font = PSDefaultFontName;
			cell.detailTextLabel.text = font;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		}
	} else if(indexPath.section == ModuleSection) {
		if(indexPath.row == VPLRow) {
			UISwitch *vplSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//vplSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL vpl = GetBoolPrefForMod(DefaultsVPLPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsVPLPreference];
			vplSwitch.on = vpl;
			//vplSwitch.tag = 4;
			[vplSwitch addTarget:self action:@selector(vplChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: vplSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesVPLTitle", @"Verse Per Line");
			[vplSwitch release];						
		} else if(indexPath.row == XrefRow) {
			UISwitch *xrefSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
			//xrefSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL xrefMode = GetBoolPrefForMod(DefaultsScriptRefsPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsScriptRefsPreference];
			xrefSwitch.on = xrefMode;
			[xrefSwitch addTarget:self action:@selector(xrefChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: xrefSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesCrossReferencesTitle", @"Cross-references");
			[xrefSwitch release];
		} else if(indexPath.row == FootnotesRow) {
			UISwitch *footnotesSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
			//footnotesSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL footnotesMode = GetBoolPrefForMod(DefaultsFootnotesPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFootnotesPreference];
			footnotesSwitch.on = footnotesMode;
			[footnotesSwitch addTarget:self action:@selector(footnotesChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: footnotesSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesFootnotesTitle", @"Footnotes");
			[footnotesSwitch release];
		} else if(indexPath.row == HeadingsRow) {
			UISwitch *headingsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
			//headingsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL headingsMode = GetBoolPrefForMod(DefaultsHeadingsPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHeadingsPreference];
			headingsSwitch.on = headingsMode;
			[headingsSwitch addTarget:self action:@selector(headingsChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: headingsSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesHeadingsTitle", @"Headings");
			[headingsSwitch release];
		} else if(indexPath.row == RedLetterRow) {
			UISwitch *redLetterModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
			//redLetterModeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL redLetterMode = GetBoolPrefForMod(DefaultsRedLetterPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsRedLetterPreference];
			redLetterModeSwitch.on = redLetterMode;
			//redLetterModeSwitch.tag = 2;
			[redLetterModeSwitch addTarget:self action:@selector(redLetterChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: redLetterModeSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterTitle", @"Red Letter");
			[redLetterModeSwitch release];
		}
	} else if(indexPath.section == StrongsSection) {
		if(indexPath.row == StrongsToggleRow) {
			UISwitch *strongsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//strongsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL displayStrongs = GetBoolPrefForMod(DefaultsStrongsPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsStrongsPreference];
			strongsSwitch.on = displayStrongs;
			//strongsSwitch.tag = 9;
			[strongsSwitch addTarget:self action:@selector(displayStrongsChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: strongsSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesDisplayTitle", @"Display");
			[strongsSwitch release];						
		} else if(indexPath.row == StrongsGreekRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			NSString *module = GetStringPrefForMod(DefaultsStrongsGreekModule, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsGreekModule];
			if(!module)
				module = NSLocalizedString(@"None", @"None");
			cell.detailTextLabel.text = module;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		} else if(indexPath.row == StrongsHebrewRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewModuleTitle", @"Hebrew module");
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			NSString *module = GetStringPrefForMod(DefaultsStrongsHebrewModule, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsHebrewModule];
			if(!module)
				module = NSLocalizedString(@"None", @"None");
			cell.detailTextLabel.text = module;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		}
	} else if(indexPath.section == MorphSection) {
		if(indexPath.row == MorphToggleRow) {
			UISwitch *morphSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//morphSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL displayMorph = GetBoolPrefForMod(DefaultsMorphPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsMorphPreference];
			morphSwitch.on = displayMorph;
			//morphSwitch.tag = 9;
			[morphSwitch addTarget:self action:@selector(displayMorphChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: morphSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesDisplayTitle", @"Display");
			[morphSwitch release];						
		} else if(indexPath.row == MorphGreekRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			NSString *module = GetStringPrefForMod(DefaultsMorphGreekModule, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] stringForKey:DefaultsMorphGreekModule];
			if(!module)
				module = NSLocalizedString(@"None", @"None");
			cell.detailTextLabel.text = module;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		}
//      else if(indexPath.row == MORPH_H_ROW)
//		{
//			cell.textLabel.text = NSLocalizedString(@"PreferencesStrongsHebrewTitle", @"Strong's Hebrew module");
//			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
//			asdf;
//		}
	} else if(indexPath.section == LangSection) {
		if(indexPath.row == LangGreekAccentsRow) {
			UISwitch *greekAccentsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//greekAccentsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL displayGreekAccents = GetBoolPrefForMod(DefaultsGreekAccentsPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsGreekAccentsPreference];
			greekAccentsSwitch.on = displayGreekAccents;
			//greekAccentsSwitch.tag = 9;
			[greekAccentsSwitch addTarget:self action:@selector(displayGreekAccentsChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: greekAccentsSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesGreekAccentsTitle", @"Greek Accents");
			[greekAccentsSwitch release];
		} else if(indexPath.row == LangHebrewPointsRow) {
			UISwitch *hvpSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//hvpSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL displayHVP = GetBoolPrefForMod(DefaultsHVPPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHVPPreference];
			hvpSwitch.on = displayHVP;
			//hvpSwitch.tag = 9;
			[hvpSwitch addTarget:self action:@selector(displayHVPChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: hvpSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesHVPTitle", @"Hebrew Vowel Points");
			cell.textLabel.font = [UIFont boldSystemFontOfSize:10.0];
			[hvpSwitch release];
		} else if(indexPath.row == LangHebrewCantillationRow)	{
			UISwitch *hebrewCantillationSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			//hebrewCantillationSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			BOOL displayHebrewCantillation = GetBoolPrefForMod(DefaultsHebrewCantillationPreference, preferencesNavigationItem.title);//[[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHebrewCantillationPreference];
			hebrewCantillationSwitch.on = displayHebrewCantillation;
			//hebrewCantillationSwitch.tag = 9;
			[hebrewCantillationSwitch addTarget:self action:@selector(displayHebrewCantillationChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: hebrewCantillationSwitch ];
			cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewCantillationTitle", @"Hebrew Cantillation");
			[hebrewCantillationSwitch release];						
		}
	}
		
	return cell;				
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == DisplaySection && indexPath.row == FontNameRow) {
		fontTableViewController.moduleName = preferencesNavigationItem.title;
		//fontTableViewController.moduleName = preferencesNavigationItem.title;
		[self presentModalViewController:fontTableViewController animated:YES];
		//[self.tabBarController.moreNavigationController pushViewController:fontTableViewController animated:YES];
	} else if(indexPath.section == StrongsSection) {
		if(indexPath.row == StrongsGreekRow) {
			//strongs greek
			//[moduleSelectorTableViewController setTableType: StrongsGreek];
			//[self.tabBarController.moreNavigationController pushViewController:moduleSelectorTableViewController animated:YES];
		} else if(indexPath.row == StrongsHebrewRow) {
			//strongs hebrew
			//[moduleSelectorTableViewController setTableType: StrongsHebrew];
			//[self.tabBarController.moreNavigationController pushViewController:moduleSelectorTableViewController animated:YES];
		}
	} else if(indexPath.section == MorphSection && indexPath.row == MorphGreekRow) {
		//greek morphology
		//[moduleSelectorTableViewController setTableType: MorphGreek];
		//[self.tabBarController.moreNavigationController pushViewController:moduleSelectorTableViewController animated:YES];
	}
}

- (void)hideFontTableView {
	//[tabController.moreNavigationController popViewControllerAnimated:YES];
	[self dismissModalViewControllerAnimated:YES];
}

- (void)fontDefaultsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsFontDefaultsPreference, preferencesNavigationItem.title);
	[[NSUserDefaults standardUserDefaults] synchronize];
	if(n) {
		// we now need to add the additional rows
		FontSizeRow = DisplayRows++;
		FontNameRow = DisplayRows++;
		NSIndexPath *rowOne = [NSIndexPath indexPathForRow:FontSizeRow inSection:DisplaySection];
		NSIndexPath *rowTwo = [NSIndexPath indexPathForRow:FontNameRow inSection:DisplaySection];
		NSArray *indexPaths = [NSArray arrayWithObjects:rowOne, rowTwo, nil];
		[preferencesTable insertRowsAtIndexPaths:indexPaths withRowAnimation: UITableViewRowAnimationTop];
	} else {
		NSIndexPath *rowOne = [NSIndexPath indexPathForRow:FontSizeRow inSection:DisplaySection];
		NSIndexPath *rowTwo = [NSIndexPath indexPathForRow:FontNameRow inSection:DisplaySection];
		NSArray *indexPaths = [NSArray arrayWithObjects:rowOne, rowTwo, nil];
		DisplayRows -= 2;
		FontSizeRow = -1;
		FontNameRow = -1;
		RemovePrefForMod(DefaultsFontSizePreference, preferencesNavigationItem.title);
		RemovePrefForMod(DefaultsFontNamePreference, preferencesNavigationItem.title);
		[preferencesTable deleteRowsAtIndexPaths:indexPaths withRowAnimation: UITableViewRowAnimationTop];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
	}
}

- (void)displayStrongsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsStrongsPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsStrongsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayMorphChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsMorphPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsMorphPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayGreekAccentsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsGreekAccentsPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsGreekAccentsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayHVPChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsHVPPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHVPPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayHebrewCantillationChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsHebrewCantillationPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHebrewCantillationPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)morphGreekModuleChanged:(NSString *)newModule {
	[[NSUserDefaults standardUserDefaults] setObject:newModule forKey:DefaultsMorphGreekModule];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[preferencesTable reloadData];
}

- (void)strongsGreekModuleChanged:(NSString *)newModule {
	[[NSUserDefaults standardUserDefaults] setObject:newModule forKey:DefaultsStrongsGreekModule];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[preferencesTable reloadData];
}

- (void)strongsHebrewModuleChanged:(NSString *)newModule {
	[[NSUserDefaults standardUserDefaults] setObject:newModule forKey:DefaultsStrongsHebrewModule];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[preferencesTable reloadData];
}

- (void)xrefChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsScriptRefsPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsScriptRefsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)footnotesChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsFootnotesPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsFootnotesPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)headingsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsHeadingsPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHeadingsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)fontSizeChanged:(UISlider *)sender {
	NSInteger f = [sender value];
	SetIntegerPrefForMod(f, DefaultsFontSizePreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setInteger:f forKey:DefaultsFontSizePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	//[preferencesTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:FONT_SIZE_ROW inSection:DISPLAY_SECTION]] withRowAnimation:UITableViewRowAnimationNone];
	//[preferencesTable reloadData];
	fontSizeLabel.text = [NSString stringWithFormat:@"%d", f];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)redLetterChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsRedLetterPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsRedLetterPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)vplChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsVPLPreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsVPLPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)fontNameChanged:(NSString *)newFont {
	SetObjectPrefForMod(newFont, DefaultsFontNamePreference, preferencesNavigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setObject:newFont forKey:DefaultsFontNamePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[preferencesTable reloadData];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

@end
