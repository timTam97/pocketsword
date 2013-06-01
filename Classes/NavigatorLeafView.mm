//
//  NavigatorLeafView.mm
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorLeafView.h"
#import "ViewController.h"

@implementation NavigatorLeafView

@synthesize module;

- (NSString*)refreshInstallButton {
	UIBarButtonItem *installBarButtonItem;
	NSString *currentInstalledVersion = nil;
	SwordModule *installedModule = [[SwordManager defaultManager] moduleWithName:module.name];
	NSString *availableModuleVersion = [module version];
	if(installedModule && [availableModuleVersion isEqualToString:[installedModule version]]) {
		currentInstalledVersion = [installedModule version];
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"InstalledButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:nil];
		[installBarButtonItem setEnabled:NO];
	} else if(installedModule) {
		currentInstalledVersion = [installedModule version];
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"UpgradeButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(confirmUpgrade)];
		[installBarButtonItem setEnabled:YES];
	} else {
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"InstallButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(confirmInstall)];
		[installBarButtonItem setEnabled:YES];
	}
    
    if([PSModuleController isModuleDownloading:module.name]) {
		[installBarButtonItem setEnabled:NO];
    }
    
    self.navigationItem.rightBarButtonItem = installBarButtonItem;
	[installBarButtonItem release];
    
    return currentInstalledVersion;
}

- (void)refreshDetailsView {
    NSString *currentInstalledVersion = [self refreshInstallButton];

	NSString *about = [PSModuleController createHTMLString:[module fullAboutText:currentInstalledVersion] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil];
	[detailsView loadHTMLString:about baseURL:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.title = module.name;
	self.navigationItem.rightBarButtonItem = nil;
	BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference];
	UIColor *backgroundColor = (nightMode) ? [UIColor blackColor] : [UIColor whiteColor];
	[detailsView setBackgroundColor:backgroundColor];
    
    [self refreshDetailsView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDetailsView) name:NotificationModulesChanged object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
	[detailsView loadHTMLString:@"" baseURL:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)confirmUpgrade {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];		
		[alertView show];
		[alertView release];
		[pool release];
		return;
	}
	
	if([[module name] isEqualToString: @"Personal"]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"Error") message: NSLocalizedString(@"NotSupported", @"")
								   delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		[pool release];
		return;
	}
	
	SwordInstallSource *sIS = [[PSModuleController defaultModuleController] currentInstallSource];
	
	NSString *question = NSLocalizedString(@"ConfirmUpgrade", @"Would you like to upgrade this module?");
	NSString *messageTitle = NSLocalizedString(@"InstallTitle", @"");
	
	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n%@\n[%@]", [module name], [module descr], [module installSize], [sIS caption]];
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: messageTitle message: message
							   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
	[alertView show];
	[alertView release];
	
	[pool release];
}

- (void)confirmInstall {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		[pool release];
		return;
	}
	
	if([[module name] isEqualToString: @"Personal"]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"Error") message: NSLocalizedString(@"NotSupported", @"")
								   delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		[pool release];
		return;
	}

	SwordInstallSource *sIS = [[PSModuleController defaultModuleController] currentInstallSource];
	
	NSString *question = NSLocalizedString(@"ConfirmInstall", @"Would you like to install this module?");
	NSString *messageTitle = NSLocalizedString(@"InstallTitle", @"");
	
	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n%@\n[%@]", [module name], [module descr], [module installSize], [sIS caption]];
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: messageTitle message: message
							   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
	[alertView show];
	[alertView release];

	[pool release];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	SwordModule *installedModule = [[SwordManager defaultManager] moduleWithName:module.name];
	BOOL performInstall = NO;
	
	if (buttonIndex == 1 && !installedModule) {
		//install the module
		performInstall = YES;
	} else if(buttonIndex == 1) {
		//upgrade the module, so remove it first and then install the new version.
		[[PSModuleController defaultModuleController] removeModule:module.name];
		
		performInstall = YES;
	}
	
	if(performInstall) {
		PSModuleDownloadItem *dItem = [[PSModuleDownloadItem alloc] initWithModule:module swordInstallSource:[[PSModuleController defaultModuleController] currentInstallSource] viewForHUD:detailsView];
		[PSModuleController queueModuleDownloadItem:dItem];
		[dItem release];
		[self refreshInstallButton];
	}
	
	[pool release];
}

- (void)moduleDownloaded:(PSModuleDownloadItem *)sender {
	[self refreshDetailsView];
}

- (void)viewWillDisappear:(BOOL)animated {
	[PSModuleController removeViewForHUDForModuleDownloadItem:module.name];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[module release];
	[super dealloc];
}

@end
