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
#define STRONGS_SECTION		1
#define MORPH_SECTION		2
#define LANG_SECTION		3
#define DEVICE_SECTION		4
#define PREF__SECTIONS		5//total sections in table

//rows in DISPLAY section
#define FONT_SIZE_ROW		0
#define NIGHT_MODE_ROW		1
#define VPL_ROW				2
#define XREF_ROW			3
#define FOOTNOTES_ROW		4
#define FONT_NAME_ROW		5
#define RED_LETTER_ROW		6
#define RED_LETTER_NOTE_ROW	7
#define DISPLAY__ROWS		8//total rows in section

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

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
//- (void)viewWillAppear:(BOOL)animated {
- (void)viewDidLoad {
	[super viewDidLoad];

    //UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    //[infoButton addTarget:self action:@selector(infoButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    //UIBarButtonItem *iButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    //self.navigationItem.rightBarButtonItem = iButton;
    //[iButton release];
	self.navigationItem.title = NSLocalizedString(@"PreferencesTitle", @"Preferences");
}

- (void)viewWillAppear:(BOOL)animated {
	[preferencesTable reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
	if(requireReloadOfModuleViews) {
		//[moduleManager displayBusyIndicator];
		[viewController redisplayChapter:NoViewPoll restore:RestoreVersePosition];
		//[moduleManager hideBusyIndicator];
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
}


- (void)dealloc {
    [super dealloc];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return PREF__SECTIONS;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case DISPLAY_SECTION:
			return DISPLAY__ROWS;
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
	
	NSString *CellIdentifier = [NSString stringWithFormat: @"prefs-%d:%d", indexPath.section, indexPath.row];
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
	
	//if the cell hasn't been initialised yet, initialise here:
    if (!cell) {
		
        switch (indexPath.section) {
            case DISPLAY_SECTION :
                switch (indexPath.row) {
                    case FONT_SIZE_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISlider *fontSizeSlider = [ [ UISlider alloc ] initWithFrame: CGRectMake(170, 0, 125, 50) ];
						fontSizeSlider.minimumValue = 10.0;
						fontSizeSlider.maximumValue = 20.0;
						//fontSizeSlider.tag = 0;
						NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
						if(fontSize != 0) {//defaults default to 0 if it's not previously set...
							fontSizeSlider.value = (float)fontSize;
						} else {
							fontSizeSlider.value = 14.0;
							[[NSUserDefaults standardUserDefaults] setInteger:14 forKey:@"fontSizePreference"];
							[[NSUserDefaults standardUserDefaults] synchronize];
						}
						fontSizeSlider.continuous = NO;
						[fontSizeSlider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: fontSizeSlider ];
						[ fontSizeSlider release ];
					}
                        break;
					case NIGHT_MODE_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *nightModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
						BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"];
						nightModeSwitch.on = nightMode;
						//nightModeSwitch.tag = 1;
						[nightModeSwitch addTarget:self action:@selector(nightModeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: nightModeSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesNightModeTitle", @"Night Mode");
						[nightModeSwitch release];						
					}
						break;
					case VPL_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *vplSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *xrefSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];//x,y,width,height
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *footnotesSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];//x,y,width,height
						BOOL footnotesMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"footnotesPreference"];
						footnotesSwitch.on = footnotesMode;
						[footnotesSwitch addTarget:self action:@selector(footnotesChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: footnotesSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesFootnotesTitle", @"Footnotes");
						[footnotesSwitch release];
					}
						break;
					case FONT_NAME_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						cell.textLabel.text = NSLocalizedString(@"PreferencesFontTitle", @"Font");
						cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
					}
						break;
					case RED_LETTER_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *redLetterModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];//x,y,width,height
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterNote", @"Note that Red Letter mode is only available in some modules");
						cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
						cell.textLabel.numberOfLines = 2;
						cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0];
						cell.textLabel.textColor = [UIColor darkGrayColor];
					}
						break;
				}
				break;
            case STRONGS_SECTION :
                switch (indexPath.row) {
                    case STRONGS_DISPLAY_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *strongsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
						cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
					}
						break;
                    case STRONGS_H_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *morphSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						cell.textLabel.text = NSLocalizedString(@"PreferencesGreekModuleTitle", @"Greek module");
						cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
					}
						break;
//                    case MORPH_H_ROW :
//					{
//						cell = [ [ [ UITableViewCell alloc ] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: CellIdentifier] autorelease ];
//						cell.selectionStyle = UITableViewCellSelectionStyleNone;
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *greekAccentsSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *hvpSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *hebrewCantillationSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *insomniaSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
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
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *manualInstallSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
						BOOL manualInstallEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"moduleMaintainerModePreference"];
						manualInstallSwitch.on = manualInstallEnabled;
						//manualInstallSwitch.tag = 3;
						[manualInstallSwitch addTarget:self action:@selector(moduleMaintainerModeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: manualInstallSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"Module Maintainer Mode");
						cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:15.0];
						[manualInstallSwitch release];						
					}
						break;
					case MMM_NOTE_ROW :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeNote", @"");
						cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
						cell.textLabel.numberOfLines = 6;
						cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0];
						cell.textLabel.textColor = [UIColor darkGrayColor];
					}
						break;
				}
				break;
		}
	}
	
	// some of the cells can be changed from elsewhere, so we now need to set the text for some cell labels:
	switch (indexPath.section) {
		case DISPLAY_SECTION :
			switch (indexPath.row) {
				case FONT_SIZE_ROW :
				{
					NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
					cell.textLabel.text = [NSString stringWithFormat:@"%@: %i", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size"), fontSize];
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

- (void)displayStrongsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"strongsPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayMorphChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"morphPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayGreekAccentsChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"greekAccentsPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayHVPChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"hvpPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)displayHebrewCantillationChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"hebrewCantillationPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
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
	[moduleManager setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)footnotesChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"footnotesPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
	requireReloadOfModuleViews = YES;
}

- (void)fontSizeChanged:(UISlider *)sender {
	NSInteger f = [sender value];
	[[NSUserDefaults standardUserDefaults] setInteger:f forKey:@"fontSizePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[preferencesTable reloadData];
	requireReloadOfModuleViews = YES;
}

- (void)nightModeChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"nightModePreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	requireReloadOfModuleViews = YES;
}

- (void)redLetterChanged:(UISwitch *)sender {
	BOOL n = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:n forKey:@"redLetterPreference"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[moduleManager setPreferences];
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
