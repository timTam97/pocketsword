//
//  PSPreferencesController.m
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSPreferencesController.h"
#import "PSPreferencesModuleSelectorTableViewController.h"
#import "PSResizing.h"
#import "SwordManager.h"
#import "PSTabBarControllerDelegate.h"
#import "PSModuleController.h"
#import "PSAboutScreenController.h"
#import "PSModuleSelectorController.h"

//sections
#define DISPLAY_SECTION		0
#define MODULE_SECTION		4
#define STRONGS_SECTION		1
#define MORPH_SECTION		2
#define LANG_SECTION		44
#define DEVICE_SECTION		3
#define PREF__SECTIONS		5//total sections in table

//rows in DISPLAY section
#define FONT_SIZE_ROW		0
#define FONT_NAME_ROW		1
#define NIGHT_MODE_ROW		2
#define MOD_BLURB_ROW		3
#define DISPLAY__ROWS		4//total rows in section

//rows in the MODULE section
#define VPL_ROW				10
#define XREF_ROW			11
#define FOOTNOTES_ROW		22
#define HEADINGS_ROW		33
#define RED_LETTER_ROW		44
#define RED_LETTER_NOTE_ROW	0
#define MODULE__ROWS		1

//rows in STRONGS section
#define STRONGS_DISPLAY_ROW	-1
#define STRONGS_G_ROW		0
#define STRONGS_H_ROW		1
#define STRONGS__ROWS		2//total rows in section

//rows in MORPH section
#define MORPH_DISPLAY_ROW	-1
#define MORPH_G_ROW			0
#define MORPH__ROWS			1//total rows in section

//rows in LANG section
#define LANG_GREEKACC_ROW	0
#define LANG_HEBREWPTS_ROW	1
#define LANG_HEBREWCANT_ROW	2
#define LANG__ROWS			3//total rows in section

//rows in DEVICE section
#define INSOMNIA_ROW		0
#define ROTATION_LOCK_ROW	1
#define FULLSCREEN_MODE_ROW	2
#define FULLSCREEN_NOTE_ROW	3
#define MMM_ROW				4
#define MMM_NOTE_ROW		5
#define DEVICE__ROWS		6//total rows in section



@implementation PSPreferencesController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	//self.view.backgroundColor = [UIColor blackColor];
	self.navigationItem.title = NSLocalizedString(@"PreferencesTitle", @"Preferences");
	self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
	fontSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(140.0, 2.0, 20.0, 42.0)];
	fontSizeLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	fontSizeLabel.textColor = [UIColor darkTextColor];
	fontSizeLabel.backgroundColor = [UIColor clearColor];
	fontSizeLabel.text = @"12";
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
//	if(requireReloadOfModuleViews) {
//		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
//	}
//	requireReloadOfModuleViews = NO;
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
	return PREF__SECTIONS;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case DISPLAY_SECTION:
			return DISPLAY__ROWS;
		case MODULE_SECTION:
			//return [[[[PSModuleController defaultModuleController] swordManager] listModules] count];
			return MODULE__ROWS;
		case STRONGS_SECTION:
			return STRONGS__ROWS;
		case MORPH_SECTION:
			return MORPH__ROWS;
		case LANG_SECTION:
			return LANG__ROWS;
		case DEVICE_SECTION:
			return DEVICE__ROWS;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case DISPLAY_SECTION:
			return NSLocalizedString(@"PreferencesDisplayPreferencesTitle", @"Display Preferences");
		case MODULE_SECTION:
			return NSLocalizedString(@"PreferencesModulePreferencesTitle", @"Module Preferences");
		case STRONGS_SECTION:
			return NSLocalizedString(@"PreferencesStrongsPreferencesTitle", @"Strong's Preferences");
		case MORPH_SECTION:
			return NSLocalizedString(@"PreferencesMorphologyPreferencesTitle", @"Morphology Preferences");
		case LANG_SECTION:
			return NSLocalizedString(@"PreferencesOriginalLanguagePreferencesTitle", @"Original Language");
		case DEVICE_SECTION:
			return NSLocalizedString(@"PreferencesDevicePreferencesTitle", @"Device Preferences");
	}
	return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case MOD_BLURB_ROW:
					return 100;
				default :
					return 45;
			}
			break;
//		case MODULE_SECTION :
//			switch (indexPath.row) {
//				case RED_LETTER_NOTE_ROW :
//					return 110;//38;
//				default :
//					return 45;
//			}
//			break;
		case DEVICE_SECTION :
			switch (indexPath.row) {
				case FULLSCREEN_NOTE_ROW :
					return 75;
				case MMM_NOTE_ROW :
					return 110;
				default :
					return 45;
			}
			break;
	}
	return 45;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *CellIdentifierPlain = @"prefs-plain";
	static NSString *CellIdentifierStyled = @"prefs-styled";
	static NSString *CellIdentifierFS = @"prefs-fs";
	static NSString *CellIdenfifierSub = @"prefs-subtitle";
		
    UITableViewCell *cell = nil;
	BOOL resetCell = YES;
	CGFloat xx = 0.0;
	BOOL deviceIsPad = [PSResizing iPad];
	UIInterfaceOrientation interfaceOrientation = self.tabBarController.interfaceOrientation;
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		xx = 160.0;
		if(deviceIsPad) {
			xx += 95.0;
		}
	}
	if(deviceIsPad) {
		xx += 420.0;
	}
	
	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_SIZE_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierFS];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierFS] autorelease];
						CGFloat fssX = 170.0;
						if(deviceIsPad) {
							fssX = 135.0;
						}
						UISlider *fontSizeSlider = [[UISlider alloc] initWithFrame:CGRectMake(fssX, 0, 125, 50)];
						fontSizeSlider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
						fontSizeSlider.minimumValue = 10.0;
						if([PSResizing iPad]) {
							fontSizeSlider.maximumValue = 36.0;
						} else {
							fontSizeSlider.maximumValue = 20.0;
						}
						NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
						if(fontSize != 0) {//defaults default to 0 if it's not previously set...
							fontSizeSlider.value = (float)fontSize;
						} else {
							fontSizeSlider.value = 12.0;
							[[NSUserDefaults standardUserDefaults] setInteger:12 forKey:DefaultsFontSizePreference];
							[[NSUserDefaults standardUserDefaults] synchronize];
						}
						fontSizeSlider.continuous = YES;
						[fontSizeSlider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
						[cell addSubview:fontSizeSlider];
						[fontSizeSlider release];
						[cell addSubview:fontSizeLabel];
					}
					resetCell = NO;
				}
					break;
				case FONT_NAME_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierStyled];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifierStyled] autorelease];
					}
				}
					break;
				case NIGHT_MODE_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
					}
				}
					break;
				case MOD_BLURB_ROW:
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdenfifierSub];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdenfifierSub] autorelease];
					}
				}
					break;
			}
			break;
		case MODULE_SECTION :
			switch (indexPath.row) {
				case VPL_ROW :
				case XREF_ROW :
				case FOOTNOTES_ROW :
				case HEADINGS_ROW :
				case RED_LETTER_ROW :
				case RED_LETTER_NOTE_ROW :
				default :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdenfifierSub];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdenfifierSub] autorelease];
					}
				}
					break;
			}
			break;
		case STRONGS_SECTION :
			switch (indexPath.row) {
				case STRONGS_DISPLAY_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
					}
				}
					break;
				case STRONGS_G_ROW :
				case STRONGS_H_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierStyled];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifierStyled] autorelease];
					}
				}
					break;
			}
			break;
		case MORPH_SECTION :
			switch (indexPath.row) {
				case MORPH_DISPLAY_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
					}
				}
					break;
				case MORPH_G_ROW :
				//case MORPH_H_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierStyled];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifierStyled] autorelease];
					}
				}
					break;
			}
			break;
		case LANG_SECTION :
		case DEVICE_SECTION :
		{
			cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
			if(!cell) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierPlain] autorelease];
			}
		}
			break;
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];//[UIFont systemFontOfSize:[UIFont systemFontSize]];
	cell.textLabel.textColor = [UIColor darkTextColor];
	
	if(resetCell) {
		cell.accessoryView = nil;
		for(UIView *subv in [cell subviews]) {
			if([subv isMemberOfClass:[UISlider class]] || [subv isMemberOfClass:[UISwitch class]]) {
				[subv removeFromSuperview];
			}
		}
	}
	
	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_SIZE_ROW :
				{
				}
					break;
				case FONT_NAME_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesFontTitle", @"Font");
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.selectionStyle = UITableViewCellSelectionStyleBlue;
				}
					break;
				case NIGHT_MODE_ROW :
				{
					UISwitch *nightModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference];
					nightModeSwitch.on = nightMode;
					[nightModeSwitch addTarget:self action:@selector(nightModeChanged:) forControlEvents:UIControlEventValueChanged];
					cell.accessoryView = nightModeSwitch;
					//[ cell addSubview: nightModeSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesNightModeTitle", @"Night Mode");
					[nightModeSwitch release];						
				}
					break;
				case MOD_BLURB_ROW:
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesModuleSectionNote", @"");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 7;//2;
					cell.textLabel.textColor = [UIColor darkGrayColor];
					cell.textLabel.font = [UIFont systemFontOfSize:12.0];
					cell.detailTextLabel.text = @"";
				}
					break;
			}
			break;
		case MODULE_SECTION :
		{
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			// all Bibles are available for setting prefs:
			cell.textLabel.text = NSLocalizedString(@"PreferencesModulePreferencesTitle", @"Module Preferences");
			cell.detailTextLabel.text = nil;
//			cell.textLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] listModules] objectAtIndex:indexPath.row] name];
//			cell.detailTextLabel.text = [[[[[PSModuleController defaultModuleController] swordManager] listModules] objectAtIndex:indexPath.row] descr];
		}
			break;
//			switch (indexPath.row) {
//				case VPL_ROW :
//				{
//					UISwitch *vplSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
//					//vplSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
//					BOOL vpl = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsVPLPreference];
//					vplSwitch.on = vpl;
//					//vplSwitch.tag = 4;
//					[vplSwitch addTarget:self action:@selector(vplChanged:) forControlEvents:UIControlEventValueChanged];
//					[ cell addSubview: vplSwitch ];
//					cell.textLabel.text = NSLocalizedString(@"PreferencesVPLTitle", @"Verse Per Line");
//					[vplSwitch release];						
//				}
//					break;
//				case XREF_ROW :
//				{
//					UISwitch *xrefSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
//					//xrefSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
//					BOOL xrefMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsScriptRefsPreference];
//					xrefSwitch.on = xrefMode;
//					[xrefSwitch addTarget:self action:@selector(xrefChanged:) forControlEvents:UIControlEventValueChanged];
//					[ cell addSubview: xrefSwitch ];
//					cell.textLabel.text = NSLocalizedString(@"PreferencesCrossReferencesTitle", @"Cross-references");
//					[xrefSwitch release];
//				}
//					break;
//				case FOOTNOTES_ROW :
//				{
//					UISwitch *footnotesSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
//					//footnotesSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
//					BOOL footnotesMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFootnotesPreference];
//					footnotesSwitch.on = footnotesMode;
//					[footnotesSwitch addTarget:self action:@selector(footnotesChanged:) forControlEvents:UIControlEventValueChanged];
//					[ cell addSubview: footnotesSwitch ];
//					cell.textLabel.text = NSLocalizedString(@"PreferencesFootnotesTitle", @"Footnotes");
//					[footnotesSwitch release];
//				}
//					break;
//				case HEADINGS_ROW :
//				{
//					UISwitch *headingsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
//					//headingsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
//					BOOL headingsMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHeadingsPreference];
//					headingsSwitch.on = headingsMode;
//					[headingsSwitch addTarget:self action:@selector(headingsChanged:) forControlEvents:UIControlEventValueChanged];
//					[ cell addSubview: headingsSwitch ];
//					cell.textLabel.text = NSLocalizedString(@"PreferencesHeadingsTitle", @"Headings");
//					[headingsSwitch release];
//				}
//					break;
//				case RED_LETTER_ROW :
//				{
//					UISwitch *redLetterModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
//					//redLetterModeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
//					BOOL redLetterMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsRedLetterPreference];
//					redLetterModeSwitch.on = redLetterMode;
//					//redLetterModeSwitch.tag = 2;
//					[redLetterModeSwitch addTarget:self action:@selector(redLetterChanged:) forControlEvents:UIControlEventValueChanged];
//					[ cell addSubview: redLetterModeSwitch ];
//					cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterTitle", @"Red Letter");
//					[redLetterModeSwitch release];
//				}
//					break;
//				case RED_LETTER_NOTE_ROW :
//				{
//					//cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterNote", @"Note that Red Letter mode is only available in some modules");
//					cell.textLabel.text = NSLocalizedString(@"PreferencesModuleSectionNote", @"");
//					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
//					cell.textLabel.numberOfLines = 7;//2;
//					cell.textLabel.textColor = [UIColor darkGrayColor];
//					cell.textLabel.font = [UIFont systemFontOfSize:12.0];
//				}
//					break;
//			}
//			break;
		case STRONGS_SECTION :
			switch (indexPath.row) {
				case STRONGS_DISPLAY_ROW :
				{
					UISwitch *strongsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//strongsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayStrongs = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsStrongsPreference];
					strongsSwitch.on = displayStrongs;
					//strongsSwitch.tag = 9;
					[strongsSwitch addTarget:self action:@selector(displayStrongsChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: strongsSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesDisplayTitle", @"Display");
					[strongsSwitch release];						
				}
					break;
				case STRONGS_G_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.selectionStyle = UITableViewCellSelectionStyleBlue;
				}
					break;
				case STRONGS_H_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewModuleTitle", @"Hebrew module");
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.selectionStyle = UITableViewCellSelectionStyleBlue;
				}
					break;
			}
			break;
		case MORPH_SECTION :
			switch (indexPath.row) {
				case MORPH_DISPLAY_ROW :
				{
					UISwitch *morphSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//morphSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayMorph = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsMorphPreference];
					morphSwitch.on = displayMorph;
					//morphSwitch.tag = 9;
					[morphSwitch addTarget:self action:@selector(displayMorphChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: morphSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesDisplayTitle", @"Display");
					[morphSwitch release];						
				}
					break;
				case MORPH_G_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.selectionStyle = UITableViewCellSelectionStyleBlue;
				}
					break;
//                    case MORPH_H_ROW :
//					{
//						cell.textLabel.text = NSLocalizedString(@"PreferencesStrongsHebrewTitle", @"Strong's Hebrew module");
//						cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//						cell.selectionStyle = UITableViewCellSelectionStyleBlue;
//					}
//						break;
			}
			break;
		case LANG_SECTION:
			switch (indexPath.row) {
				case LANG_GREEKACC_ROW:
				{
					UISwitch *greekAccentsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//greekAccentsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayGreekAccents = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsGreekAccentsPreference];
					greekAccentsSwitch.on = displayGreekAccents;
					//greekAccentsSwitch.tag = 9;
					[greekAccentsSwitch addTarget:self action:@selector(displayGreekAccentsChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: greekAccentsSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesGreekAccentsTitle", @"Greek Accents");
					[greekAccentsSwitch release];
				}
					break;
				case LANG_HEBREWPTS_ROW:
				{
					UISwitch *hvpSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//hvpSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayHVP = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHVPPreference];
					hvpSwitch.on = displayHVP;
					//hvpSwitch.tag = 9;
					[hvpSwitch addTarget:self action:@selector(displayHVPChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: hvpSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesHVPTitle", @"Hebrew Vowel Points");
					cell.textLabel.font = [UIFont boldSystemFontOfSize:10.0];
					[hvpSwitch release];
				}
					break;
				case LANG_HEBREWCANT_ROW:
				{
					UISwitch *hebrewCantillationSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//hebrewCantillationSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayHebrewCantillation = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHebrewCantillationPreference];
					hebrewCantillationSwitch.on = displayHebrewCantillation;
					//hebrewCantillationSwitch.tag = 9;
					[hebrewCantillationSwitch addTarget:self action:@selector(displayHebrewCantillationChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: hebrewCantillationSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewCantillationTitle", @"Hebrew Cantillation");
					[hebrewCantillationSwitch release];						
				}
					break;
			}
			break;
		case DEVICE_SECTION:
			switch (indexPath.row) {
				case INSOMNIA_ROW :
				{
					UISwitch *insomniaSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//insomniaSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL insomniaMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsInsomniaPreference];
					insomniaSwitch.on = insomniaMode;
					//insomniaSwitch.tag = 3;
					[insomniaSwitch addTarget:self action:@selector(insomniaModeChanged:) forControlEvents:UIControlEventValueChanged];
					//[ cell addSubview: insomniaSwitch ];
					cell.accessoryView = insomniaSwitch;
					[insomniaSwitch release];						
					cell.textLabel.text = NSLocalizedString(@"PreferencesDisableAutoLockTitle", @"");
				}
					break;
				case ROTATION_LOCK_ROW :
				{
					UISwitch *rotationLockSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					int rotationLockPosition = [[NSUserDefaults standardUserDefaults] integerForKey:ROTATION_LOCK_POSITION];
					if(rotationLockPosition == RotationEnabled) {
						rotationLockSwitch.on = NO;
					} else {
						rotationLockSwitch.on = YES;
					}
					[rotationLockSwitch addTarget:self action:@selector(rotationLockChanged:) forControlEvents:UIControlEventValueChanged];
					//[ cell addSubview: rotationLockSwitch ];
					cell.accessoryView = rotationLockSwitch;
					[rotationLockSwitch release];						
					cell.textLabel.text = NSLocalizedString(@"PreferencesRotationLock", @"Rotation Lock");
				}
					break;
				case FULLSCREEN_MODE_ROW :
				{
					UISwitch *fullscreenModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//fullscreenModeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL fullscreenMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFullscreenModePreference];
					fullscreenModeSwitch.on = fullscreenMode;
					//nightModeSwitch.tag = 1;
					[fullscreenModeSwitch addTarget:self action:@selector(fullscreenModeChanged:) forControlEvents:UIControlEventValueChanged];
					//[ cell addSubview: fullscreenModeSwitch ];
					cell.accessoryView = fullscreenModeSwitch;
					[fullscreenModeSwitch release];						
					cell.textLabel.text = NSLocalizedString(@"PreferencesFullscreenModeTitle", @"Fullscreen Mode");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 2;
				}
					break;
				case FULLSCREEN_NOTE_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesFullscreenNote", @"With fullscreen mode disabled, you can still switch to and from fullscreen with a 2-finger tap in the Bible and Commentary tabs.");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 4;
					cell.textLabel.textColor = [UIColor darkGrayColor];
					cell.textLabel.font = [UIFont systemFontOfSize:12.0];
				}
					break;
				case MMM_ROW :
				{
					UISwitch *manualInstallSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					//manualInstallSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL manualInstallEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsModuleMaintainerModePreference];
					manualInstallSwitch.on = manualInstallEnabled;
					//manualInstallSwitch.tag = 3;
					[manualInstallSwitch addTarget:self action:@selector(moduleMaintainerModeChanged:) forControlEvents:UIControlEventValueChanged];
					//[ cell addSubview: manualInstallSwitch ];
					cell.accessoryView = manualInstallSwitch;
					[manualInstallSwitch release];
					cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"Module Maintainer Mode");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 2;
					cell.textLabel.font = [UIFont boldSystemFontOfSize:10.0];
				}
					break;
				case MMM_NOTE_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeNote", @"");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 7;
					cell.textLabel.font = [UIFont systemFontOfSize:12.0];
					cell.textLabel.textColor = [UIColor darkGrayColor];
				}
					break;
			}
			break;
	}
	
	// some of the cells can be changed from elsewhere, so we now need to set the text for some cell labels:
	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_SIZE_ROW :
				{
					NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
					//cell.textLabel.text = [NSString stringWithFormat:@"%@: %i", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size"), fontSize];
					cell.textLabel.text = [NSString stringWithFormat:@"%@:", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size")];
					fontSizeLabel.text = [NSString stringWithFormat:@"%d", fontSize];
				}
					break;
				case FONT_NAME_ROW:
				{
					NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsFontNamePreference];
					if(!font)
						font = PSDefaultFontName;
					cell.detailTextLabel.text = font;
					cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
				}
					break;
			}
			break;
		case STRONGS_SECTION:
			switch (indexPath.row) {
				case STRONGS_G_ROW:
				{
					NSString *module = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsGreekModule];
					if(!module)
						module = NSLocalizedString(@"None", @"None");
					cell.detailTextLabel.text = module;
					cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
				}
					break;
				case STRONGS_H_ROW:
				{
					NSString *module = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsHebrewModule];
					if(!module)
						module = NSLocalizedString(@"None", @"None");
					cell.detailTextLabel.text = module;
					cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
				}
					break;
			}
			break;
		case MORPH_SECTION:
			switch (indexPath.row) {
				case MORPH_G_ROW:
				{
					NSString *module = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsMorphGreekModule];
					if(!module)
						module = NSLocalizedString(@"None", @"None");
					cell.detailTextLabel.text = module;
					cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
				}
					break;
			}
			break;
	}
	
	return cell;				
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_NAME_ROW :
					PSPreferencesFontTableViewController *fontTableViewController = [[PSPreferencesFontTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
					fontTableViewController.moduleName = nil;
					fontTableViewController.preferencesController = self;
					[self.navigationController pushViewController:fontTableViewController animated:YES];
					[fontTableViewController release];
					break;
			}
			break;
		case STRONGS_SECTION:
			switch (indexPath.row) {
				case STRONGS_G_ROW:
				{
					//strongs greek
					PSPreferencesModuleSelectorTableViewController *moduleSelectorTableViewController = [[PSPreferencesModuleSelectorTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
					moduleSelectorTableViewController.preferencesController = self;
					[moduleSelectorTableViewController setTableType: StrongsGreek];
					[self.navigationController pushViewController:moduleSelectorTableViewController animated:YES];
					[moduleSelectorTableViewController release];
				}
					break;
				case STRONGS_H_ROW:
				{
					//strongs hebrew
					PSPreferencesModuleSelectorTableViewController *moduleSelectorTableViewController = [[PSPreferencesModuleSelectorTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
					moduleSelectorTableViewController.preferencesController = self;
					[moduleSelectorTableViewController setTableType: StrongsHebrew];
					[self.navigationController pushViewController:moduleSelectorTableViewController animated:YES];
					[moduleSelectorTableViewController release];
				}
					break;
			}
			break;
		case MORPH_SECTION:
			switch (indexPath.row) {
				case MORPH_G_ROW:
				{
					//greek morphology
					PSPreferencesModuleSelectorTableViewController *moduleSelectorTableViewController = [[PSPreferencesModuleSelectorTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
					moduleSelectorTableViewController.preferencesController = self;
					[moduleSelectorTableViewController setTableType: MorphGreek];
					[self.navigationController pushViewController:moduleSelectorTableViewController animated:YES];
					[moduleSelectorTableViewController release];
				}
					break;
			}
			break;
		case MODULE_SECTION:
		{
			PSModuleSelectorController *moduleSelectorViewController = [[[PSModuleSelectorController alloc] initWithNibName:nil bundle:nil] autorelease];
			[moduleSelectorViewController setListType:PreferencesTab];
			[self.navigationController pushViewController:moduleSelectorViewController animated:YES];
			//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:[[[[PSModuleController defaultModuleController] swordManager] listModules] objectAtIndex:indexPath.row]];
		}
			break;
	}
}

- (void)hideFontTableView {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)rotationLockChanged:(UISwitch *)sender {
	//BOOL n = [sender isOn];
	UIInterfaceOrientation interfaceOrientation = [self interfaceOrientation];
	//int rotationLockPosition = [[NSUserDefaults standardUserDefaults] integerForKey:ROTATION_LOCK_POSITION];
	
	if([sender isOn]) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight ? RotationLockedInLandscape : RotationLockedInPortrait)] forKey:ROTATION_LOCK_POSITION];
	} else {
		[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:RotationEnabled] forKey:ROTATION_LOCK_POSITION];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)fullscreenModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsFullscreenModePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)displayStrongsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsStrongsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayMorphChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsMorphPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayGreekAccentsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsGreekAccentsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayHVPChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHVPPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)displayHebrewCantillationChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHebrewCantillationPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
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
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsScriptRefsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)footnotesChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsFootnotesPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)headingsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsHeadingsPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)fontSizeChanged:(UISlider *)sender {
	NSInteger f = [sender value];
	[[NSUserDefaults standardUserDefaults] setInteger:f forKey:DefaultsFontSizePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	fontSizeLabel.text = [NSString stringWithFormat:@"%d", f];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)nightModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsNightModePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNightModeChanged object:nil];
}

- (void)redLetterChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsRedLetterPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)vplChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsVPLPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)fontNameChanged:(NSString *)newFont {
	[[NSUserDefaults standardUserDefaults] setObject:newFont forKey:DefaultsFontNamePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self.tableView reloadData];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
}

- (void)insomniaModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsInsomniaPreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[UIApplication sharedApplication].idleTimerDisabled = n;
}

- (void)moduleMaintainerModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:DefaultsModuleMaintainerModePreference];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationModuleMaintainerModeChanged object:nil];
}

@end
