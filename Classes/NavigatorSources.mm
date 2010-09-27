//
//  NavigatorSources.m
//  PocketSword
//
//  Created by Nic Carter on 8/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorSources.h"
#import "NavigatorModuleTypes.h"
#import "NavigatorModules.h"
#import "iPhoneHTTPServerDelegate.h"

@implementation NavigatorSources

//@synthesize moduleManager;
@synthesize tabController;

// displaying the Install Sources

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.navigationItem.title = NSLocalizedString(@"InstallSourcesTitle", @"Sources");
	[self addManualInstallButton];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addManualInstallButton) name:@"ModuleMaintainerModeChanged" object:nil];
}

// available actions (via Edit button):
//		- Add Source
//		- Edit/Remove Sources (have this also cover "add" with a + button there?)
//		- Module Maintainer Mode (if preference is set)
//		

- (void)addManualInstallButton {
	//BOOL manualInstallEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"moduleMaintainerModePreference"];
	self.navigationItem.rightBarButtonItem = nil;
	if([[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed]) {
		UIBarButtonItem *iButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(editButtonPressed:)];
		//UIBarButtonItem *iButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"MMM.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(editButtonPressed:)];//manualAddModule
		self.navigationItem.rightBarButtonItem = iButton;
		[iButton release];
	}
}

// TODO: add /*NSLocalizedString(@"DeleteSource", @""),*/ to the list of buttons?
- (IBAction)editButtonPressed:(id)sender {
	UIActionSheet *actionSheet;
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"moduleMaintainerModePreference"]) {
		actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"ManageSources", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"RefreshSourceList", @""), NSLocalizedString(@"AddFTPSource", @""), /*NSLocalizedString(@"AddHTTPSource", @""),*/ NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @""), nil];
	} else {
		actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"ManageSources", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"RefreshSourceList", @""), nil];
	}
	
	[actionSheet showFromTabBar:tabController.tabBar];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == actionSheet.cancelButtonIndex)
		return;
	
	NSString *buttonPressedTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
	if([buttonPressedTitle isEqualToString:NSLocalizedString(@"AddFTPSource", @"")]) {
		addSourceViewController.serverType = INSTALLSOURCE_TYPE_FTP;
		[self presentModalViewController:addSourceViewController animated:YES];
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"AddHTTPSource", @"")]) {
		addSourceViewController.serverType = INSTALLSOURCE_TYPE_HTTP;
		[self presentModalViewController:addSourceViewController animated:YES];
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"DeleteSource", @"")]) {
		//not currently implemented...
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"RefreshSourceList", @"")]) {
		if(![PSModuleController checkNetworkConnection]) {
			[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil] show];		
			return;
		}
		[[[PSModuleController defaultModuleController] swordInstallManager] refreshMasterRemoteInstallSourceList];
		[table reloadData];
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"")]) {
		[self manualAddModule:nil];
	}
}

- (void)resetTableSelection {
	NSIndexPath *tableSelection = [table indexPathForSelectedRow];
	[table deselectRowAtIndexPath:tableSelection animated:YES];
	[table reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	//[table reloadData];	// populate our table's data
	//DLog(@"  (SINC)  ");
	
	if(![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed]) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Disclaimer", @"") message: NSLocalizedString(@"DisclaimerMsg", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
	}
	if([NSThread isMainThread]) {
		[self resetTableSelection];
	} else {
		[self performSelectorOnMainThread:@selector(resetTableSelection) withObject:nil waitUntilDone:YES];
	}
//	for(int i=0;i<5;i++) {
//		if([[tabController.viewControllers objectAtIndex:i] isMemberOfClass:[NavigatorSources class]])
//			NSLog(@"Downloader is NOT in the More Tab (is tab number %d)", i);
//	}
}

//- (void)viewDidAppear:(BOOL)animated
//{
//}

- (IBAction)manualAddModule:(id)sender {
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
//                           forView:tabController.moreNavigationController.view
//                             cache:YES];
//	
//    [UIView setAnimationDuration:1];
//	[tabController.moreNavigationController.view addSubview:[manualInstallViewController view]];
//    [UIView commitAnimations];
	[tabController presentModalViewController:manualInstallViewController animated:YES];

	[manualInstallViewController startServer];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed])
		return 0;
	return [[[[PSModuleController defaultModuleController] swordInstallManager] installSourceList] count];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed]) {
		//((UITableView*)table).sectionHeaderHeight = 40.5;
		return NSLocalizedString(@"InstallManagerDisabled", @"");
	} else {
		//((UITableView*)table).sectionHeaderHeight = 80.0;
		return NSLocalizedString(@"InstallManagerDownloadsHint", @"");
	}
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kCellIdentifier = @"source-id";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier] autorelease];
	}
	NSArray *currentArray = [[[PSModuleController defaultModuleController] swordInstallManager] installSourceList];
	cell.textLabel.text = [[currentArray objectAtIndex:indexPath.row] caption];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;	
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed])
		return;
	SwordInstallSource *sIS = [[[[PSModuleController defaultModuleController] swordInstallManager] installSourceList] objectAtIndex:indexPath.row];
	if(![sIS isSwordManagerLoaded]) {
		// we need to display a busy indicator, cause it can take a LONG time to do file IO on the device...
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
		//[[PSModuleController defaultModuleController] displayBusyIndicator];

		[sIS swordManager];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
		//[[PSModuleController defaultModuleController] hideBusyIndicator];
	}
	[((NavigatorModuleTypes*)navigatorModuleTypes) setDataArray:[sIS moduleListByType]];
	((NavigatorModuleTypes*)navigatorModuleTypes).title = [sIS caption];
	[((NavigatorModuleTypes*)navigatorModuleTypes) reloadTable];
	
	// need to set the current install source, for when we want to install a module.
	[[PSModuleController defaultModuleController] setCurrentInstallSource:sIS];
	
	[tabController.moreNavigationController pushViewController:navigatorModuleTypes animated:YES];
	
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *caption = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[[[PSModuleController defaultModuleController] swordInstallManager] removeInstallSourceNamed:caption withReinitialize:YES];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
	}
}

/*- (void)navigationController:(UINavigationController *)navController willShowViewController:(UIViewController *)vController animated:(BOOL)animated {
	if([vController.title isEqualToString:@"Sources"]) {
		if(![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed]) {
			[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Disclaimer", @"") message: NSLocalizedString(@"DisclaimerMsg", @"")
									   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
		}
		NSIndexPath *tableSelection = [table indexPathForSelectedRow];
		[table deselectRowAtIndexPath:tableSelection animated:NO];
		// to make the navigation faster, try to pre-load the mod.d .conf files...
		//  unfortunately, this seems to cause a crash.  Removing this until the source of the crash is discovered...
		//[[PSModuleController defaultModuleController] performSelectorInBackground: @selector(readSwordInstallSourceModuleConfigFiles) withObject: nil];
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
		[[[PSModuleController defaultModuleController] swordInstallManager] setUserDisclainerConfirmed: YES];
		[self addManualInstallButton];
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
