//
//  PSPreferencesController.m
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSPreferencesController.h"


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

- (void)viewWillDisappear:(BOOL)animated {
	if(requireReloadOfModuleViews) {
		[moduleManager displayBusyIndicator];
		[viewController redisplayChapter:NoViewPoll restore:RestoreScrollPosition];
		[moduleManager hideBusyIndicator];
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
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return 6;
			break;
		case 1:
			return 3;
			break;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return NSLocalizedString(@"PreferencesDisplayPreferencesTitle", @"Display Preferences");
			break;
		case 1:
			return NSLocalizedString(@"PreferencesDevicePreferencesTitle", @"Device Preferences");
			break;
	}
	return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch (indexPath.section) {
		case 0 :
			switch (indexPath.row) {
				case 0 :
				{
					return 45;
				}
					break;
				case 1 :
				{
					return 45;
				}
					break;
				case 2 :
				{
					return 45;
				}
					break;
				case 3 :
				{
					return 45;
				}
					break;
				case 4 :
				{
					return 45;
				}
					break;
				case 5 :
				{
					return 30;
				}
					break;
			}
			break;
		case 1 :
			switch (indexPath.row) {
				case 0 :
				{
					return 45;
				}
					break;
				case 1 :
				{
					return 45;
				}
					break;
				case 2 :
				{
					return 90;
				}
					break;
			}
			break;
	}
	return 50;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *CellIdentifier = [ NSString stringWithFormat: @"prefs-%d:%d", [ indexPath indexAtPosition: 0 ], [ indexPath indexAtPosition:1 ]];
	
    UITableViewCell *cell = [ tableView dequeueReusableCellWithIdentifier: CellIdentifier];
	
    if (cell == nil) {
		
        switch (indexPath.section) {
            case 0 :
                switch (indexPath.row) {
                    case 0 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISlider *fontSizeSlider = [ [ UISlider alloc ] initWithFrame: CGRectMake(170, 0, 125, 50) ];
						fontSizeSlider.minimumValue = 10.0;
						fontSizeSlider.maximumValue = 20.0;
						fontSizeSlider.tag = 0;
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
						//don't set the cellLabel here, we do it below
						//cell.textLabel.text = [NSString stringWithFormat:@"%@: %i", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size"), fontSize];
						[ fontSizeSlider release ];
					}
                        break;
					case 1 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *nightModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
						BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"];
						nightModeSwitch.on = nightMode;
						nightModeSwitch.tag = 1;
						[nightModeSwitch addTarget:self action:@selector(nightModeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: nightModeSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesNightModeTitle", @"Night Mode");
						[nightModeSwitch release];						
					}
						break;
					case 2 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *vplSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
						BOOL vpl = [[NSUserDefaults standardUserDefaults] boolForKey:@"vplPreference"];
						vplSwitch.on = vpl;
						vplSwitch.tag = 4;
						[vplSwitch addTarget:self action:@selector(vplChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: vplSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesVPLTitle", @"Verse Per Line");
						[vplSwitch release];						
					}
						break;
					case 3 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						cell.textLabel.text = NSLocalizedString(@"PreferencesFontTitle", @"Font");
						NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontNamePreference"];
						if(!font)
							font = @"Helvetica";
						cell.detailTextLabel.text = font;
						cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
					}
						break;
					case 4 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *redLetterModeSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];//x,y,width,height
						BOOL redLetterMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"redLetterPreference"];
						redLetterModeSwitch.on = redLetterMode;
						redLetterModeSwitch.tag = 2;
						[redLetterModeSwitch addTarget:self action:@selector(redLetterChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: redLetterModeSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesRedLetterTitle", @"Red Letter");
						[redLetterModeSwitch release];
					}
						break;
					case 5 :
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
			case 1:
				switch (indexPath.row) {
					case 0 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *insomniaSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
						BOOL insomniaMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"insomniaPreference"];
						insomniaSwitch.on = insomniaMode;
						insomniaSwitch.tag = 3;
						[insomniaSwitch addTarget:self action:@selector(insomniaModeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: insomniaSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesDisableAutoLockTitle", @"Disable auto-lock");
						[insomniaSwitch release];						
					}
						break;
					case 1 :
					{
						cell = [ [ [ UITableViewCell alloc ] initWithFrame: CGRectZero reuseIdentifier: CellIdentifier] autorelease ];
						cell.selectionStyle = UITableViewCellSelectionStyleNone;
						UISwitch *manualInstallSwitch = [ [ UISwitch alloc ] initWithFrame: CGRectMake(200, 10, 0, 0) ];
						BOOL manualInstallEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"moduleMaintainerModePreference"];
						manualInstallSwitch.on = manualInstallEnabled;
						manualInstallSwitch.tag = 3;
						[manualInstallSwitch addTarget:self action:@selector(moduleMaintainerModeChanged:) forControlEvents:UIControlEventValueChanged];
						[ cell addSubview: manualInstallSwitch ];
						cell.textLabel.text = NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"Module Maintainer Mode");
						cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:15.0];
						[manualInstallSwitch release];						
					}
						break;
					case 2 :
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
	
	//the font setting may have changed, so need to double check each time:
	if(indexPath.section == 0 && indexPath.row == 3) {
		NSString *font = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontNamePreference"];
		if(!font)
			font = @"Helvetica";
		cell.detailTextLabel.text = font;
	} else if(indexPath.section == 0 && indexPath.row == 0) {
		NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
		cell.textLabel.text = [NSString stringWithFormat:@"%@: %i", NSLocalizedString(@"PreferencesFontSizeTitle", @"Font Size"), fontSize];
	}
	return cell;				
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	//PSPreferencesFontTableViewController *fontTableViewController = [[PSPreferencesFontTableViewController alloc] initWithNibName:nil bundle:nil];
	//fontTableViewController.preferencesController = self;
	[tabController.moreNavigationController pushViewController:fontTableViewController animated:YES];
	//[fontTableViewController release];
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
