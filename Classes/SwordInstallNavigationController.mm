//
//  SwordInstallNavigationController.m
//  PocketSword
//
//  Created by Nic Carter on 8/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SwordInstallNavigationController.h"


@implementation SwordInstallNavigationController

// displaying the Install Sources

- (id)viewController {
	return viewController;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.navigationItem.title = NSLocalizedString(@"InstallSourcesTitle", @"Sources");
	[self addManualInstallButton];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addManualInstallButton) name:@"ModuleMaintainerModeChanged" object:nil];
}

- (void)addManualInstallButton {
	BOOL manualInstallEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"moduleMaintainerModePreference"];
	self.navigationItem.rightBarButtonItem = nil;
	if(manualInstallEnabled) {
		//UIBarButtonItem *iButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(manualAddModule:)];
		UIImage *mmmImg = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MMM" ofType:@"png"]];
		UIBarButtonItem *iButton = [[UIBarButtonItem alloc] initWithImage:mmmImg style:UIBarButtonItemStyleBordered target:self action:@selector(manualAddModule:)];
		[mmmImg release];
		self.navigationItem.rightBarButtonItem = iButton;
		[iButton release];
	}
}

- (void)resetTableSelection {
	NSIndexPath *tableSelection = [table indexPathForSelectedRow];
	[table deselectRowAtIndexPath:tableSelection animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	//[table reloadData];	// populate our table's data
	//DLog(@"  (SINC)  ");
	
	if(![[moduleManager swordInstallManager] userDisclaimerConfirmed]) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Disclaimer", @"") message: NSLocalizedString(@"DisclaimerMsg", @"")
								   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
	}
	if([NSThread isMainThread]) {
		[self resetTableSelection];
	} else {
		[self performSelectorOnMainThread:@selector(resetTableSelection) withObject:nil waitUntilDone:YES];
	}
	//if(tabController.moreNavigationController) {
	//	DLog(@"\n-SwordInstallNavigationController:  has a nav controller");
	//}
}

- (void)viewDidAppear:(BOOL)animated
{
}

- (IBAction)manualAddModule:(id)sender {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
                           forView:tabController.moreNavigationController.view
                             cache:YES];
	
    [UIView setAnimationDuration:1];
	[tabController.moreNavigationController.view addSubview:manualInstallViewController.view];
    [UIView commitAnimations];

	[manualInstallViewController startServer];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (![[moduleManager swordInstallManager] userDisclaimerConfirmed])
		return 0;
	return [[[moduleManager swordInstallManager] installSourceList] count];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (![[moduleManager swordInstallManager] userDisclaimerConfirmed]) {
		((UITableView*)table).sectionHeaderHeight = 40.5;
		return NSLocalizedString(@"InstallManagerDisabled", @"");
	}
	return @"";
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kCellIdentifier = @"id";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellIdentifier] autorelease];
	}
	NSArray *currentArray = [[moduleManager swordInstallManager] installSourceList];
	cell.textLabel.text = [[currentArray objectAtIndex:indexPath.row] caption];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;	
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![[moduleManager swordInstallManager] userDisclaimerConfirmed])
		return;
	SwordInstallSource *sIS = [[[moduleManager swordInstallManager] installSourceList] objectAtIndex:indexPath.row];
	if(![sIS isSwordManagerLoaded]) {
		// we need to display a busy indicator, cause it can take a LONG time to do file IO on the device...
		[viewController performSelectorInBackground: @selector(displayBusyIndicator) withObject: nil];

		[sIS swordManager];

		[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
	}
	[((NavigatorModuleTypes*)navigatorModuleTypes) setDataArray:[sIS moduleListByType]];
	((NavigatorModuleTypes*)navigatorModuleTypes).title = [sIS caption];
	[((NavigatorModuleTypes*)navigatorModuleTypes) reloadTable];
	
	// need to set the current install source, for when we want to install a module.
	[moduleManager setCurrentInstallSource:sIS];
	
	[tabController.moreNavigationController pushViewController:navigatorModuleTypes animated:YES];
	
}

/*- (void)navigationController:(UINavigationController *)navController willShowViewController:(UIViewController *)vController animated:(BOOL)animated {
	if([vController.title isEqualToString:@"Sources"]) {
		if(![[moduleManager swordInstallManager] userDisclaimerConfirmed]) {
			[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Disclaimer", @"") message: NSLocalizedString(@"DisclaimerMsg", @"")
									   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
		}
		NSIndexPath *tableSelection = [table indexPathForSelectedRow];
		[table deselectRowAtIndexPath:tableSelection animated:NO];
		// to make the navigation faster, try to pre-load the mod.d .conf files...
		//  unfortunately, this seems to cause a crash.  Removing this until the source of the crash is discovered...
		//[moduleManager performSelectorInBackground: @selector(readSwordInstallSourceModuleConfigFiles) withObject: nil];
	}
}*/


//
// UIAlertView delegate method
//
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//DLog(@"Clicked button %d", buttonIndex);
	if (buttonIndex == 1) {
		//DLog(@"alertView: didDismissWithButtonIndex:  %d", buttonIndex);
		[[moduleManager swordInstallManager] setUserDisclainerConfirmed: YES];
		[table reloadData];
		//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		//NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		//[prefs setObject: @"YES" forKey: @"userDisclaimer"];
		//[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"userDisclaimerAccepted"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	[pool release];
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"ManualInstallEnabledChanged" object:nil];
	[super dealloc];
}

@end
