//
//  PSPreferencesController.m
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSPreferencesController.h"
#import "PSPreferencesModuleSelectorTableViewController.h"

//sections
#define DISPLAY_SECTION		0
#define MODULE_SECTION		1
#define STRONGS_SECTION		2
#define MORPH_SECTION		3
#define LANG_SECTION		4
#define DEVICE_SECTION		5
#define PREF__SECTIONS		6//total sections in table

//rows in DISPLAY section
#define FONT_SIZE_ROW		0
#define FONT_NAME_ROW		1
#define NIGHT_MODE_ROW		2
#define FULLSCREEN_MODE_ROW	3
#define FULLSCREEN_NOTE_ROW	4
#define DISPLAY__ROWS		5//total rows in section

//rows in the MODULE section
#define VPL_ROW				0
#define XREF_ROW			1
#define FOOTNOTES_ROW		2
#define HEADINGS_ROW		3
#define RED_LETTER_ROW		4
#define RED_LETTER_NOTE_ROW	5
#define MODULE__ROWS		6

//rows in STRONGS section
#define STRONGS_DISPLAY_ROW	0
#define STRONGS_G_ROW		1
#define STRONGS_H_ROW		2
#define STRONGS__ROWS		3//total rows in section

//rows in MORPH section
#define MORPH_DISPLAY_ROW	0
#define MORPH_G_ROW			1
#define MORPH__ROWS			2//total rows in section

//rows in LANG section
#define LANG_GREEKACC_ROW	0
#define LANG_HEBREWPTS_ROW	1
#define LANG_HEBREWCANT_ROW	2
#define LANG__ROWS			3//total rows in section

//rows in DEVICE section
#define INSOMNIA_ROW		0
#define MMM_ROW				1
#define MMM_NOTE_ROW		2
#define DEVICE__ROWS		3//total rows in section



@implementation PSPreferencesController

BOOL requireReloadOfModuleViews = NO;

- (void)viewDidLoad {
	[super viewDidLoad];
	preferencesTabBarItem.title = NSLocalizedString(@"TabBarTitlePreferences", @"Preferences");
	self.navigationItem.title = NSLocalizedString(@"PreferencesTitle", @"Preferences");
	fontSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(100.0, 2.0, 20.0, 42.0)];
	fontSizeLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	fontSizeLabel.textColor = [UIColor darkTextColor];
	fontSizeLabel.text = @"14";
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[preferencesTable reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if(requireReloadOfModuleViews) {
		//[[PSModuleController defaultModuleController] displayBusyIndicator];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
		//[[[PSModuleController defaultModuleController] viewController] redisplayChapter:NoViewPoll restore:RestoreVersePosition];
		//[[PSModuleController defaultModuleController] hideBusyIndicator];
	}
	requireReloadOfModuleViews = NO;
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

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
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[preferencesTable reloadData];
	//[preferencesTable reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, PREF__SECTIONS)] withRowAnimation:UITableViewRowAnimationFade];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return PREF__SECTIONS;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case DISPLAY_SECTION:
			return DISPLAY__ROWS;
		case MODULE_SECTION:
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
				case FULLSCREEN_NOTE_ROW :
					return 55;
				default :
					return 45;
			}
			break;
		case MODULE_SECTION :
			switch (indexPath.row) {
				case RED_LETTER_NOTE_ROW :
					return 38;
				default :
					return 45;
			}
			break;
		case DEVICE_SECTION :
			switch (indexPath.row) {
				case MMM_NOTE_ROW :
					return 98;
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
	
    UITableViewCell *cell;// = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
//	if(!cell) {
//		cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifierPlain] autorelease ];
//	}
	BOOL resetCell = YES;
	
	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_SIZE_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierFS];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierFS] autorelease];
						
						UISlider *fontSizeSlider = [ [ UISlider alloc ] initWithFrame: CGRectMake(170, 0, 125, 50) ];
						fontSizeSlider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
						fontSizeSlider.minimumValue = 10.0;
						fontSizeSlider.maximumValue = 20.0;
						NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
						if(fontSize != 0) {//defaults default to 0 if it's not previously set...
							fontSizeSlider.value = (float)fontSize;
						} else {
							fontSizeSlider.value = 14.0;
							[[NSUserDefaults standardUserDefaults] setInteger:14 forKey:@"fontSizePreference"];
							[[NSUserDefaults standardUserDefaults] synchronize];
						}
						fontSizeSlider.continuous = YES;
						[fontSizeSlider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: fontSizeSlider ];
						[ fontSizeSlider release ];
						[cell addSubview: fontSizeLabel];
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
				case FULLSCREEN_MODE_ROW :
				case FULLSCREEN_NOTE_ROW :
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
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
				{
					cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifierPlain];
					if(!cell) {
						cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
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
						cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
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
						cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
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
				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifierPlain] autorelease];
			}
		}
			break;
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	cell.textLabel.textColor = [UIColor darkTextColor];
	
	CGFloat xx = 0.0;
	UIInterfaceOrientation interfaceOrientation = tabController.interfaceOrientation;
	//UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	//if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		xx = 160.0;
	}
	
	if(resetCell) {
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
					cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
				}
					break;
				case NIGHT_MODE_ROW :
				{
					UISwitch *nightModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					nightModeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"];
					nightModeSwitch.on = nightMode;
					//nightModeSwitch.tag = 1;
					[nightModeSwitch addTarget:self action:@selector(nightModeChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: nightModeSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesNightModeTitle", @"Night Mode");
					[nightModeSwitch release];						
				}
					break;
				case FULLSCREEN_MODE_ROW :
				{
					UISwitch *fullscreenModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					fullscreenModeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL fullscreenMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"fullscreenModePreference"];
					fullscreenModeSwitch.on = fullscreenMode;
					//nightModeSwitch.tag = 1;
					[fullscreenModeSwitch addTarget:self action:@selector(fullscreenModeChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: fullscreenModeSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesFullscreenModeTitle", @"Fullscreen Mode");
					[fullscreenModeSwitch release];						
				}
					break;
				case FULLSCREEN_NOTE_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesFullscreenNote", @"With fullscreen mode disabled, you can still switch to and from fullscreen with a 2-finger tap in the Bible and Commentary tabs.");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 3;
					cell.textLabel.font = [UIFont systemFontOfSize:12.0];
					cell.textLabel.textColor = [UIColor darkGrayColor];
				}
					break;
			}
			break;
		case MODULE_SECTION :
			switch (indexPath.row) {
				case VPL_ROW :
				{
					UISwitch *vplSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					vplSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL vpl = [[NSUserDefaults standardUserDefaults] boolForKey:@"vplPreference"];
					vplSwitch.on = vpl;
					//vplSwitch.tag = 4;
					[vplSwitch addTarget:self action:@selector(vplChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: vplSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesVPLTitle", @"Verse Per Line");
					[vplSwitch release];						
				}
					break;
				case XREF_ROW :
				{
					UISwitch *xrefSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
					xrefSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL xrefMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"scriptRefsPreference"];
					xrefSwitch.on = xrefMode;
					[xrefSwitch addTarget:self action:@selector(xrefChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: xrefSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesCrossReferencesTitle", @"Cross-references");
					[xrefSwitch release];
				}
					break;
				case FOOTNOTES_ROW :
				{
					UISwitch *footnotesSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
					footnotesSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL footnotesMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"footnotesPreference"];
					footnotesSwitch.on = footnotesMode;
					[footnotesSwitch addTarget:self action:@selector(footnotesChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: footnotesSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesFootnotesTitle", @"Footnotes");
					[footnotesSwitch release];
				}
					break;
				case HEADINGS_ROW :
				{
					UISwitch *headingsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
					headingsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL headingsMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"headingsPreference"];
					headingsSwitch.on = headingsMode;
					[headingsSwitch addTarget:self action:@selector(headingsChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: headingsSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesHeadingsTitle", @"Headings");
					[headingsSwitch release];
				}
					break;
				case RED_LETTER_ROW :
				{
					UISwitch *redLetterModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];//x,y,width,height
					redLetterModeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL redLetterMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"redLetterPreference"];
					redLetterModeSwitch.on = redLetterMode;
					//redLetterModeSwitch.tag = 2;
					[redLetterModeSwitch addTarget:self action:@selector(redLetterChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: redLetterModeSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterTitle", @"Red Letter");
					[redLetterModeSwitch release];
				}
					break;
				case RED_LETTER_NOTE_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterNote", @"Note that Red Letter mode is only available in some modules");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 2;
					cell.textLabel.font = [UIFont systemFontOfSize:12.0];
					cell.textLabel.textColor = [UIColor darkGrayColor];
				}
					break;
			}
		case STRONGS_SECTION :
			switch (indexPath.row) {
				case STRONGS_DISPLAY_ROW :
				{
					UISwitch *strongsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					strongsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayStrongs = [[NSUserDefaults standardUserDefaults] boolForKey:@"strongsPreference"];
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
					cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
				}
					break;
				case STRONGS_H_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesHebrewModuleTitle", @"Hebrew module");
					cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
				}
					break;
			}
			break;
		case MORPH_SECTION :
			switch (indexPath.row) {
				case MORPH_DISPLAY_ROW :
				{
					UISwitch *morphSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					morphSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayMorph = [[NSUserDefaults standardUserDefaults] boolForKey:@"morphPreference"];
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
					cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
				}
					break;
//                    case MORPH_H_ROW :
//					{
//						cell.textLabel.text = NSLocalizedString(@"PreferencesStrongsHebrewTitle", @"Strong's Hebrew module");
//						cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
//					}
//						break;
			}
			break;
		case LANG_SECTION:
			switch (indexPath.row) {
				case LANG_GREEKACC_ROW:
				{
					UISwitch *greekAccentsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					greekAccentsSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayGreekAccents = [[NSUserDefaults standardUserDefaults] boolForKey:@"greekAccentsPreference"];
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
					hvpSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayHVP = [[NSUserDefaults standardUserDefaults] boolForKey:@"hvpPreference"];
					hvpSwitch.on = displayHVP;
					//hvpSwitch.tag = 9;
					[hvpSwitch addTarget:self action:@selector(displayHVPChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: hvpSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesHVPTitle", @"Hebrew Vowel Points");
					[hvpSwitch release];
				}
					break;
				case LANG_HEBREWCANT_ROW:
				{
					UISwitch *hebrewCantillationSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					hebrewCantillationSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL displayHebrewCantillation = [[NSUserDefaults standardUserDefaults] boolForKey:@"hebrewCantillationPreference"];
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
					insomniaSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL insomniaMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"insomniaPreference"];
					insomniaSwitch.on = insomniaMode;
					//insomniaSwitch.tag = 3;
					[insomniaSwitch addTarget:self action:@selector(insomniaModeChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: insomniaSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesDisableAutoLockTitle", @"Disable auto-lock");
					[insomniaSwitch release];						
				}
					break;
				case MMM_ROW :
				{
					UISwitch *manualInstallSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(xx+200, 10, 0, 0) ];
					manualInstallSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
					BOOL manualInstallEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"moduleMaintainerModePreference"];
					manualInstallSwitch.on = manualInstallEnabled;
					//manualInstallSwitch.tag = 3;
					[manualInstallSwitch addTarget:self action:@selector(moduleMaintainerModeChanged:) forControlEvents:UIControlEventValueChanged];
					[ cell addSubview: manualInstallSwitch ];
					cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"Module Maintainer Mode");
					//cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:15.0];
					[manualInstallSwitch release];						
				}
					break;
				case MMM_NOTE_ROW :
				{
					cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeNote", @"");
					cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
					cell.textLabel.numberOfLines = 6;
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
					NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
					//cell.textLabel.text = [NSString stringWithFormat:@"%@: %i", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size"), fontSize];
					cell.textLabel.text = [NSString stringWithFormat:@"%@:", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size")];
					fontSizeLabel.text = [NSString stringWithFormat:@"%d", fontSize];
				}
					break;
				case FONT_NAME_ROW:
				{
					NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontNamePreference"];
					if(!font)
						font = @"Helvetica";
					cell.detailTextLabel.text = font;
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
				}
					break;
				case STRONGS_H_ROW:
				{
					NSString *module = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsHebrewModule];
					if(!module)
						module = NSLocalizedString(@"None", @"None");
					cell.detailTextLabel.text = module;
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
				}
					break;
			}
			break;
	}
	
	return cell;				
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {

	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_NAME_ROW :
					[tabController.moreNavigationController pushViewController:fontTableViewController animated:YES];
					break;
			}
			break;
		case STRONGS_SECTION:
			switch (indexPath.row) {
				case STRONGS_G_ROW:
					//strongs greek
					[moduleSelectorTableViewController setTableType: StrongsGreek];
					[tabController.moreNavigationController pushViewController:moduleSelectorTableViewController animated:YES];
					break;
				case STRONGS_H_ROW:
					//strongs hebrew
					[moduleSelectorTableViewController setTableType: StrongsHebrew];
					[tabController.moreNavigationController pushViewController:moduleSelectorTableViewController animated:YES];
					break;
			}
			break;
		case MORPH_SECTION:
			switch (indexPath.row) {
				case MORPH_G_ROW:
					//greek morphology
					[moduleSelectorTableViewController setTableType: MorphGreek];
					[tabController.moreNavigationController pushViewController:moduleSelectorTableViewController animated:YES];
					break;
			}
			break;
	}
}

- (void)fullscreenModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"fullscreenModePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	//[[PSModuleController defaultModuleController] setPreferences];
	//requireReloadOfModuleViews = YES;
}

- (void)displayStrongsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"strongsPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayMorphChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"morphPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayGreekAccentsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"greekAccentsPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayHVPChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"hvpPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayHebrewCantillationChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"hebrewCantillationPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
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
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"scriptRefsPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)footnotesChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"footnotesPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)headingsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"headingsPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)fontSizeChanged:(UISlider *)sender {
	NSInteger f = [sender value];
	[[NSUserDefaults standardUserDefaults] setInteger:f forKey:@"fontSizePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	//[preferencesTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:FONT_SIZE_ROW inSection:DISPLAY_SECTION]] withRowAnimation:UITableViewRowAnimationNone];
	//[preferencesTable reloadData];
	fontSizeLabel.text = [NSString stringWithFormat:@"%d", f];
	requireReloadOfModuleViews = YES;
}

- (void)nightModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"nightModePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	requireReloadOfModuleViews = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNightModeChanged object:nil];
}

- (void)redLetterChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"redLetterPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[PSModuleController defaultModuleController] setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)vplChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"vplPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	requireReloadOfModuleViews = YES;
}

- (void)fontNameChanged:(NSString *)newFont {
	[[NSUserDefaults standardUserDefaults] setObject:newFont forKey:@"fontNamePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[preferencesTable reloadData];
	requireReloadOfModuleViews = YES;
}

- (void)insomniaModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"insomniaPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	UIApplication *thisApp = [UIApplication sharedApplication];
	thisApp.idleTimerDisabled = n;
}

- (void)moduleMaintainerModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"moduleMaintainerModePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ModuleMaintainerModeChanged" object:nil];
}

@end
