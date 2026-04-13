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
	}
}

- (void)editButtonPressed:(id)sender {
	if(mmmMenuDisplayed) {
		return;
	}
	mmmMenuDisplayed = YES;
	UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ManageSources", @"") message:nil preferredStyle:UIAlertControllerStyleActionSheet];

	[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"RefreshSourceList", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		self->mmmMenuDisplayed = NO;
		if(![PSModuleController checkNetworkConnection]) {
			UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"") message:NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"") style:UIAlertActionStyleCancel handler:nil]];
			[self presentViewController:alert animated:YES completion:nil];
			return;
		}
		if([[PSModuleController defaultModuleController] tryDownloading]) {
			return;//cannot refresh while downloading a module!
		}

		MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
		HUD.delegate = self;

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
			[[[PSModuleController defaultModuleController] swordInstallManager] performSelector:@selector(refreshMasterRemoteInstallSourceList) withObject:nil];
			dispatch_async(dispatch_get_main_queue(), ^{
				[HUD hideAnimated:YES];
			});
		});
	}]];

	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsModuleMaintainerModePreference]) {
		[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"AddFTPSource", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			self->mmmMenuDisplayed = NO;
			PSAddSourceViewController *addSourceViewController = [[PSAddSourceViewController alloc] initWithNibName:nil bundle:nil];
			addSourceViewController.serverType = INSTALLSOURCE_TYPE_FTP;
			[self presentViewController:addSourceViewController animated:YES completion:nil];
		}]];
		[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			self->mmmMenuDisplayed = NO;
			[self manualAddModule];
		}]];
	}

	[actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
		self->mmmMenuDisplayed = NO;
	}]];

	if([PSResizing iPad]) {
		actionSheet.popoverPresentationController.barButtonItem = sender;
	}
	[self presentViewController:actionSheet animated:YES completion:nil];
}


- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
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
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Disclaimer", @"") message:NSLocalizedString(@"DisclaimerMsg", @"") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No") style:UIAlertActionStyleCancel handler:nil]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[[PSModuleController defaultModuleController] swordInstallManager] setUserDisclainerConfirmed: YES];
			[self addManualInstallButton];
			[self.tableView reloadData];
			[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"userDisclaimerAccepted"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}]];
		[self presentViewController:alert animated:YES completion:nil];
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
	[self presentViewController:manualInstallViewController animated:YES completion:nil];

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
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
	}
	NSArray *currentArray = [[[PSModuleController defaultModuleController] swordInstallManager] installSourceList];
	cell.textLabel.text = [[currentArray objectAtIndex:indexPath.row] caption];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;	
}

- (void)showHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    });
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
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *caption = [tableView cellForRowAtIndexPath: indexPath].textLabel.text;
		[[[PSModuleController defaultModuleController] swordInstallManager] removeInstallSourceNamed:caption withReinitialize:YES];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
	}
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"ManualInstallEnabledChanged" object:nil];
}

@end

@implementation PSStatusController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;//UIModalTransitionStyleCrossDissolve;
}

@end
