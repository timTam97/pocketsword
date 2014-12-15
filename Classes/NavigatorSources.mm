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
#import "PSResizing.h"
#import "PSAddSourceViewController.h"
#import "PSModuleController.h"
#import "SwordManager.h"
#import "SwordInstallManager.h"
#import "globals.h"

@implementation NavigatorSources

// displaying the Install Sources

- (void)viewDidLoad {
	[super viewDidLoad];
		
	mmmMenuDisplayed = NO;
	self.navigationItem.title = NSLocalizedString(@"InstallSourcesTitle", @"Sources");
	self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
	[self addManualInstallButton];
}

// available actions (via Edit button):
//		- Add Source
//		- Edit/Remove Sources (have this also cover "add" with a + button there?)
//		- Module Maintainer Mode (if preference is set)
//		

- (void)addManualInstallButton {
	self.navigationItem.rightBarButtonItem = nil;
	if([[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed]) {
		UIBarButtonItem *iButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(editButtonPressed:)];
		self.navigationItem.rightBarButtonItem = iButton;
		[iButton release];
	}
}

- (void)editButtonPressed:(id)sender {
	if(mmmMenuDisplayed) {
		return;
	}
	mmmMenuDisplayed = YES;
	UIActionSheet *actionSheet;
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsModuleMaintainerModePreference]) {
		actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"ManageSources", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"RefreshSourceList", @""), NSLocalizedString(@"AddFTPSource", @""), /*NSLocalizedString(@"AddHTTPSource", @""),*/ NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @""), nil];
	} else {
		actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"ManageSources", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"RefreshSourceList", @""), nil];
	}
	if([PSResizing iPad]) {
		[actionSheet showFromBarButtonItem:sender animated:YES];
	} else {
		[actionSheet showFromTabBar:self.tabBarController.tabBar];
	}
	[actionSheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	mmmMenuDisplayed = NO;
	if(buttonIndex == actionSheet.cancelButtonIndex)
		return;
	
	NSString *buttonPressedTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
	if([buttonPressedTitle isEqualToString:NSLocalizedString(@"AddFTPSource", @"")]) {
		PSAddSourceViewController *addSourceViewController = [[PSAddSourceViewController alloc] initWithNibName:nil bundle:nil];
		addSourceViewController.serverType = INSTALLSOURCE_TYPE_FTP;
		[self presentModalViewController:addSourceViewController animated:YES];
		[addSourceViewController release];
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"AddHTTPSource", @"")]) {
		PSAddSourceViewController *addSourceViewController = [[PSAddSourceViewController alloc] initWithNibName:nil bundle:nil];
		addSourceViewController.serverType = INSTALLSOURCE_TYPE_HTTP;
		[self presentModalViewController:addSourceViewController animated:YES];
		[addSourceViewController release];
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"DeleteSource", @"")]) {
		//not currently implemented...
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"RefreshSourceList", @"")]) {
		if(![PSModuleController checkNetworkConnection]) {
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
			[alertView show];
			[alertView release];
			return;
		}
		if([[PSModuleController defaultModuleController] tryDownloading]) {
			return;//cannot refresh while downloading a module!
		}
		MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:self.view];
		[self.view addSubview:HUD];
		HUD.delegate = self;
		// Show the HUD while the provided method executes in a new thread
		[HUD showWhileExecuting:@selector(refreshMasterRemoteInstallSourceList) onTarget:[[PSModuleController defaultModuleController] swordInstallManager] withObject:nil animated:YES];
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"")]) {
		[self manualAddModule];
	}
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	[hud release];
	hud = nil;
	[self.tableView reloadData];
}

- (void)resetInstallSourcesListing {
	NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:tableSelection animated:YES];
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	if(![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Disclaimer", @"") message: NSLocalizedString(@"DisclaimerMsg", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
		[alertView show];
		[alertView release];
	}
	if([NSThread isMainThread]) {
		[self resetInstallSourcesListing];
	} else {
		[self performSelectorOnMainThread:@selector(resetInstallSourcesListing) withObject:nil waitUntilDone:YES];
	}
}

- (void)manualAddModule {
	iPhoneHTTPServerDelegate *manualInstallViewController = [[iPhoneHTTPServerDelegate alloc] initWithNibName:nil bundle:nil];
	manualInstallViewController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	[self presentModalViewController:manualInstallViewController animated:YES];

	[manualInstallViewController startServer];
	[manualInstallViewController release];
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
		return NSLocalizedString(@"InstallManagerDisabled", @"");
	} else {
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

- (void)showHUD {
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![[[PSModuleController defaultModuleController] swordInstallManager] userDisclaimerConfirmed])
		return;
	SwordInstallSource *sIS = [[[[PSModuleController defaultModuleController] swordInstallManager] installSourceList] objectAtIndex:indexPath.row];
	if(![sIS isSwordManagerLoaded]) {
		// we need to display a busy indicator, cause it can take a LONG time to do file IO on the device...
		[self performSelectorInBackground:@selector(showHUD) withObject:nil];
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			
			[sIS swordManager];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[MBProgressHUD hideHUDForView:self.view animated:YES];
			});
		});
	}
	NavigatorModuleTypes *navigatorModuleTypes = [[NavigatorModuleTypes alloc] initWithStyle:UITableViewStyleGrouped];
	[navigatorModuleTypes setDataArray:[sIS moduleListByType]];
	navigatorModuleTypes.title = [sIS caption];
	[navigatorModuleTypes reloadTable];
	
	// need to set the current install source, for when we want to install a module.
	[[PSModuleController defaultModuleController] setCurrentInstallSource:sIS];
	
	[self.navigationController pushViewController:navigatorModuleTypes animated:YES];
	[navigatorModuleTypes release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *caption = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[[[PSModuleController defaultModuleController] swordInstallManager] removeInstallSourceNamed:caption withReinitialize:YES];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
	}
}

//
// UIAlertView delegate method
//
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	
	if (buttonIndex == 1) {
		[[[PSModuleController defaultModuleController] swordInstallManager] setUserDisclainerConfirmed: YES];
		[self addManualInstallButton];
		[self.tableView reloadData];
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"userDisclaimerAccepted"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"ManualInstallEnabledChanged" object:nil];
	[super dealloc];
}

@end

@implementation PSStatusController

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;//UIModalTransitionStyleCrossDissolve;
}

@end
