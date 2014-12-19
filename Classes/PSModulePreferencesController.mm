//
//  PSPreferencesController.m
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBasePreferencesController.h"
#import "PSModulePreferencesController.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import "SwordManager.h"

@implementation PSModulePreferencesController

@synthesize hackTableView, listType;

- (void)viewDidLoad {
	[super viewDidLoad];
	fontSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(140.0, 2.0, 20.0, 42.0)];
	fontSizeLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	fontSizeLabel.textColor = [UIColor darkTextColor];
	fontSizeLabel.text = @"12";
	fontSizeLabel.backgroundColor = [UIColor clearColor];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(hackTableView) {
		CGFloat topLength = 0;
		if([self respondsToSelector:@selector(topLayoutGuide)]) {
			topLength = [[self topLayoutGuide] length];
			if(topLength == 0.0f || topLength == 20.0f) {
				topLength += self.navigationController.navigationBar.frame.size.height;
			}
			self.tableView.contentSize = [[UIScreen mainScreen] bounds].size;
			[self.tableView setContentInset:UIEdgeInsetsMake(topLength, 0.0f, 0.0f, 0.0f)];
		}
	}
}

- (void)displayPrefsForModule:(SwordModule*)swordModule {
	//set title to the module name
	UITabBarItem *tbi = [[UITabBarItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ %@", [swordModule name], NSLocalizedString(@"TabBarTitlePreferences", @"")] image:[UIImage imageNamed:@"gear-24.png"] tag:101];
	self.tabBarItem = tbi;
	[tbi release];
	
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
	BOOL fontDefaults = GetBoolPrefForMod(DefaultsFontDefaultsPreference, swordModule.name);
	if(fontDefaults) {
		FontSizeRow = DisplayRows++;
		FontNameRow = DisplayRows++;
	}
	
	// Module section:
	//always show the VPL option for Bibles
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
//	if([swordModule hasFeature: SWMOD_FEATURE_VARIANTS]) {
//		not currently supported in PocketSword
//	}
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
	[super viewDidUnload];
}

- (void)dealloc {
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[self.tableView reloadData];
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
			}
		} else if(indexPath.row == FontSizeRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierFS];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierFS] autorelease];
				
				[cell addSubview: fontSizeLabel];
			}
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
			}
		}
	} else if(indexPath.section == StrongsSection) {
		if(indexPath.row == StrongsToggleRow) {
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
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
		}
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
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
		xx += 220.0;//was 420.0 before we moved this to the popover...
	}
	
	if(resetCell) {
		for(UIView *subv in [cell subviews]) {
			if([subv isMemberOfClass:[UISlider class]] || [subv isMemberOfClass:[UISwitch class]]) {
				[subv removeFromSuperview];
			}
		}
		cell.accessoryView = nil;
	}
	
	if(indexPath.section == DisplaySection) {
		
		if(indexPath.row == FontDefaultsRow) {
			UISwitch *fontDefaultsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL fontDefaults = GetBoolPrefForMod(DefaultsFontDefaultsPreference, self.tabBarController.navigationItem.title);
			fontDefaultsSwitch.on = fontDefaults;
			[fontDefaultsSwitch addTarget:self action:@selector(fontDefaultsChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: fontDefaultsSwitch ];
			cell.accessoryView = fontDefaultsSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesFontDefaultTitle", @"Verse Per Line");
			[fontDefaultsSwitch release];						
		} else if(indexPath.row == FontSizeRow) {
			UISlider *fontSizeSlider = [ [ UISlider alloc ] initWithFrame: CGRectMake(xx+170, 0, 125, 50) ];
			fontSizeSlider.minimumValue = 10.0;
			if([PSResizing iPad]) {
				fontSizeSlider.maximumValue = 36.0;
			} else {
				fontSizeSlider.maximumValue = 20.0;
			}
			NSInteger fontSize = GetIntegerPrefForMod(DefaultsFontSizePreference, self.tabBarController.navigationItem.title);
			if(fontSize != 0) {//defaults default to 0 if it's not previously set...
				fontSizeSlider.value = (float)fontSize;
			} else {
				fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
				if(fontSize != 0) {
					fontSizeSlider.value = (float)fontSize;
					SetIntegerPrefForMod(fontSize, DefaultsFontSizePreference, self.tabBarController.navigationItem.title);
				} else {
					fontSizeSlider.value = 12.0;
					SetIntegerPrefForMod(12, DefaultsFontSizePreference, self.tabBarController.navigationItem.title);
					[[NSUserDefaults standardUserDefaults] setInteger:12 forKey:DefaultsFontSizePreference];
					[[NSUserDefaults standardUserDefaults] synchronize];
				}
			}
			fontSizeSlider.continuous = YES;
			[fontSizeSlider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
			[ cell addSubview: fontSizeSlider ];
			[ fontSizeSlider release ];

			cell.textLabel.text = [NSString stringWithFormat:@"%@:", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size")];
			fontSizeLabel.text = [NSString stringWithFormat:@"%d", fontSize];
		} else if(indexPath.row == FontNameRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesFontTitle", @"Font");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			NSString *font = GetStringPrefForMod(DefaultsFontNamePreference, self.tabBarController.navigationItem.title);
			if(!font)
				font = PSDefaultFontName;
			cell.detailTextLabel.text = font;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		}
		
	} else if(indexPath.section == ModuleSection) {
		
		if(indexPath.row == VPLRow) {
			UISwitch *vplSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL vpl = GetBoolPrefForMod(DefaultsVPLPreference, self.tabBarController.navigationItem.title);
			vplSwitch.on = vpl;
			[vplSwitch addTarget:self action:@selector(vplChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: vplSwitch ];
			cell.accessoryView = vplSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesVPLTitle", @"Verse Per Line");
			[vplSwitch release];						
		} else if(indexPath.row == XrefRow) {
			UISwitch *xrefSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL xrefMode = GetBoolPrefForMod(DefaultsScriptRefsPreference, self.tabBarController.navigationItem.title);
			xrefSwitch.on = xrefMode;
			[xrefSwitch addTarget:self action:@selector(xrefChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: xrefSwitch ];
			cell.accessoryView = xrefSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesCrossReferencesTitle", @"Cross-references");
			[xrefSwitch release];
		} else if(indexPath.row == FootnotesRow) {
			UISwitch *footnotesSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL footnotesMode = GetBoolPrefForMod(DefaultsFootnotesPreference, self.tabBarController.navigationItem.title);
			footnotesSwitch.on = footnotesMode;
			[footnotesSwitch addTarget:self action:@selector(footnotesChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: footnotesSwitch ];
			cell.accessoryView = footnotesSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesFootnotesTitle", @"Footnotes");
			[footnotesSwitch release];
		} else if(indexPath.row == HeadingsRow) {
			UISwitch *headingsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL headingsMode = GetBoolPrefForMod(DefaultsHeadingsPreference, self.tabBarController.navigationItem.title);
			headingsSwitch.on = headingsMode;
			[headingsSwitch addTarget:self action:@selector(headingsChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: headingsSwitch ];
			cell.accessoryView = headingsSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesHeadingsTitle", @"Headings");
			[headingsSwitch release];
		} else if(indexPath.row == RedLetterRow) {
			UISwitch *redLetterModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL redLetterMode = GetBoolPrefForMod(DefaultsRedLetterPreference, self.tabBarController.navigationItem.title);
			redLetterModeSwitch.on = redLetterMode;
			[redLetterModeSwitch addTarget:self action:@selector(redLetterChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: redLetterModeSwitch ];
			cell.accessoryView = redLetterModeSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterTitle", @"Red Letter");
			[redLetterModeSwitch release];
		}
		
	} else if(indexPath.section == StrongsSection) {
		
		if(indexPath.row == StrongsToggleRow) {
			UISwitch *strongsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL displayStrongs = GetBoolPrefForMod(DefaultsStrongsPreference, self.tabBarController.navigationItem.title);
			strongsSwitch.on = displayStrongs;
			[strongsSwitch addTarget:self action:@selector(displayStrongsChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: strongsSwitch ];
			cell.accessoryView = strongsSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesDisplayTitle", @"Display");
			[strongsSwitch release];						
		} else if(indexPath.row == StrongsGreekRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			NSString *module = GetStringPrefForMod(DefaultsStrongsGreekModule, self.tabBarController.navigationItem.title);
			if(!module)
				module = NSLocalizedString(@"None", @"None");
			cell.detailTextLabel.text = module;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		} else if(indexPath.row == StrongsHebrewRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewModuleTitle", @"Hebrew module");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			NSString *module = GetStringPrefForMod(DefaultsStrongsHebrewModule, self.tabBarController.navigationItem.title);
			if(!module)
				module = NSLocalizedString(@"None", @"None");
			cell.detailTextLabel.text = module;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		}
		
	} else if(indexPath.section == MorphSection) {
		
		if(indexPath.row == MorphToggleRow) {
			UISwitch *morphSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL displayMorph = GetBoolPrefForMod(DefaultsMorphPreference, self.tabBarController.navigationItem.title);
			morphSwitch.on = displayMorph;
			[morphSwitch addTarget:self action:@selector(displayMorphChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: morphSwitch ];
			cell.accessoryView = morphSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesDisplayTitle", @"Display");
			[morphSwitch release];						
		} else if(indexPath.row == MorphGreekRow) {
			cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			NSString *module = GetStringPrefForMod(DefaultsMorphGreekModule, self.tabBarController.navigationItem.title);
			if(!module)
				module = NSLocalizedString(@"None", @"None");
			cell.detailTextLabel.text = module;
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
		}
//      else if(indexPath.row == MORPH_H_ROW)
//		{
//			cell.textLabel.text = NSLocalizedString(@"PreferencesStrongsHebrewTitle", @"Strong's Hebrew module");
//			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
//			asdf;
//		}
		
	} else if(indexPath.section == LangSection) {
		
		if(indexPath.row == LangGreekAccentsRow) {
			UISwitch *greekAccentsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL displayGreekAccents = GetBoolPrefForMod(DefaultsGreekAccentsPreference, self.tabBarController.navigationItem.title);
			greekAccentsSwitch.on = displayGreekAccents;
			[greekAccentsSwitch addTarget:self action:@selector(displayGreekAccentsChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: greekAccentsSwitch ];
			cell.accessoryView = greekAccentsSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesGreekAccentsTitle", @"Greek Accents");
			[greekAccentsSwitch release];
		} else if(indexPath.row == LangHebrewPointsRow) {
			UISwitch *hvpSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL displayHVP = GetBoolPrefForMod(DefaultsHVPPreference, self.tabBarController.navigationItem.title);
			hvpSwitch.on = displayHVP;
			[hvpSwitch addTarget:self action:@selector(displayHVPChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: hvpSwitch ];
			cell.accessoryView = hvpSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesHVPTitle", @"Hebrew Vowel Points");
			cell.textLabel.font = [UIFont boldSystemFontOfSize:10.0];
			[hvpSwitch release];
		} else if(indexPath.row == LangHebrewCantillationRow)	{
			UISwitch *hebrewCantillationSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
			BOOL displayHebrewCantillation = GetBoolPrefForMod(DefaultsHebrewCantillationPreference, self.tabBarController.navigationItem.title);
			hebrewCantillationSwitch.on = displayHebrewCantillation;
			[hebrewCantillationSwitch addTarget:self action:@selector(displayHebrewCantillationChanged:) forControlEvents:UIControlEventValueChanged];
			//[ cell addSubview: hebrewCantillationSwitch ];
			cell.accessoryView = hebrewCantillationSwitch;
			cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewCantillationTitle", @"Hebrew Cantillation");
			[hebrewCantillationSwitch release];						
		}
		
	}
		
	return cell;				
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == DisplaySection && indexPath.row == FontNameRow) {
		
		PSPreferencesFontTableViewController *fontTableViewController = [[PSPreferencesFontTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
		fontTableViewController.moduleName = self.tabBarController.navigationItem.title;
		fontTableViewController.preferencesController = self;
		[self.navigationController pushViewController:fontTableViewController animated:YES];
		//[self presentModalViewController:fontTableViewController animated:YES];
		[fontTableViewController release];
		
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
	[self.navigationController popViewControllerAnimated:YES];
	//[self dismissModalViewControllerAnimated:YES];
}

- (void)fontDefaultsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsFontDefaultsPreference, self.tabBarController.navigationItem.title);
	[[NSUserDefaults standardUserDefaults] synchronize];
	if(n) {
		// we now need to add the additional rows
		FontSizeRow = DisplayRows++;
		FontNameRow = DisplayRows++;
		NSIndexPath *rowOne = [NSIndexPath indexPathForRow:FontSizeRow inSection:DisplaySection];
		NSIndexPath *rowTwo = [NSIndexPath indexPathForRow:FontNameRow inSection:DisplaySection];
		NSArray *indexPaths = [NSArray arrayWithObjects:rowOne, rowTwo, nil];
		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation: UITableViewRowAnimationTop];
	} else {
		NSIndexPath *rowOne = [NSIndexPath indexPathForRow:FontSizeRow inSection:DisplaySection];
		NSIndexPath *rowTwo = [NSIndexPath indexPathForRow:FontNameRow inSection:DisplaySection];
		NSArray *indexPaths = [NSArray arrayWithObjects:rowOne, rowTwo, nil];
		DisplayRows -= 2;
		FontSizeRow = -1;
		FontNameRow = -1;
		RemovePrefForMod(DefaultsFontSizePreference, self.tabBarController.navigationItem.title);
		RemovePrefForMod(DefaultsFontNamePreference, self.tabBarController.navigationItem.title);
		[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation: UITableViewRowAnimationTop];
		[self redisplayFromButtonPress];
	}
}

- (void)displayStrongsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsStrongsPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsStrongsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)displayMorphChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsMorphPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsMorphPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)displayGreekAccentsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsGreekAccentsPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsGreekAccentsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)displayHVPChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsHVPPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHVPPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)displayHebrewCantillationChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsHebrewCantillationPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHebrewCantillationPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)morphGreekModuleChanged:(NSString *)newModule {
	[[NSUserDefaults standardUserDefaults] setObject:newModule forKey:DefaultsMorphGreekModule];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self.tableView reloadData];
}

- (void)strongsGreekModuleChanged:(NSString *)newModule {
	[[NSUserDefaults standardUserDefaults] setObject:newModule forKey:DefaultsStrongsGreekModule];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self.tableView reloadData];
}

- (void)strongsHebrewModuleChanged:(NSString *)newModule {
	[[NSUserDefaults standardUserDefaults] setObject:newModule forKey:DefaultsStrongsHebrewModule];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self.tableView reloadData];
}

- (void)xrefChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsScriptRefsPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsScriptRefsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)footnotesChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsFootnotesPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsFootnotesPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)headingsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsHeadingsPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHeadingsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)fontSizeChanged:(UISlider *)sender {
	NSInteger f = [sender value];
	SetIntegerPrefForMod(f, DefaultsFontSizePreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setInteger:f forKey:DefaultsFontSizePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	//[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:FONT_SIZE_ROW inSection:DISPLAY_SECTION]] withRowAnimation:UITableViewRowAnimationNone];
	//[self.tableView reloadData];
	fontSizeLabel.text = [NSString stringWithFormat:@"%d", f];
	[self redisplayFromButtonPress];
}

- (void)redLetterChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsRedLetterPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsRedLetterPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[self redisplayFromButtonPress];
}

- (void)vplChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	SetBoolPrefForMod(n, DefaultsVPLPreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsVPLPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self redisplayFromButtonPress];
}

- (void)fontNameChanged:(NSString *)newFont {
	SetObjectPrefForMod(newFont, DefaultsFontNamePreference, self.tabBarController.navigationItem.title);
	//[[NSUserDefaults standardUserDefaults] setObject:newFont forKey:DefaultsFontNamePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self.tableView reloadData];
	[self redisplayFromButtonPress];
}

- (void)redisplayFromButtonPress {
	switch (listType) {
		case BibleTab:
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			break;
		case CommentaryTab:
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			break;
		case DictionaryTab:
		case DevotionalTab:
		case DownloadsTab:
		case PreferencesTab:
			break;
	}
}

@end
