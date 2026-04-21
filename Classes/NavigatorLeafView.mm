//
//  NavigatorLeafView.mm
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorLeafView.h"
#import "PSModuleController.h"
#import "SwordModule.h"
#import "SwordManager.h"
#import "SwordInstallSource.h"
#import "PSTabBarControllerDelegate.h"

@implementation NavigatorLeafView

@synthesize module, detailsWebView;

- (void)loadView {
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;
	WKWebView *leafWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight) configuration:[[WKWebViewConfiguration alloc] init]];
	self.view = leafWebView;
	self.detailsWebView = leafWebView;
}

- (NSString*)refreshInstallButton {
	UIBarButtonItem *installBarButtonItem;
	NSString *currentInstalledVersion = nil;
	SwordModule *installedModule = [[SwordManager defaultManager] moduleWithName:module.name];
	NSString *availableModuleVersion = [module version];
	if(installedModule && [availableModuleVersion isEqualToString:[installedModule version]]) {
		currentInstalledVersion = [installedModule version];
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"InstalledButtonTitle", @"") style:UIBarButtonItemStylePlain target:self action:nil];
		[installBarButtonItem setEnabled:NO];
	} else if(installedModule) {
		currentInstalledVersion = [installedModule version];
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"UpgradeButtonTitle", @"") style:UIBarButtonItemStylePlain target:self action:@selector(confirmUpgrade)];
		[installBarButtonItem setEnabled:YES];
	} else {
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"InstallButtonTitle", @"") style:UIBarButtonItemStylePlain target:self action:@selector(confirmInstall)];
		[installBarButtonItem setEnabled:YES];
	}
    
    if([PSModuleController isModuleDownloading:module.name]) {
		[installBarButtonItem setEnabled:NO];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
		self.navigationItem.rightBarButtonItem = installBarButtonItem;
	});
    
    return currentInstalledVersion;
}

- (void)refreshDetailsView {
    NSString *currentInstalledVersion = [self refreshInstallButton];

	NSString *about = [PSModuleController createHTMLString:[module fullAboutText:currentInstalledVersion] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil fixedWidth:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^ {
        [self->detailsWebView loadHTMLString:about baseURL:nil];
    });
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.title = module.name;
	self.navigationItem.rightBarButtonItem = nil;
	BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference];
	UIColor *backgroundColor = (nightMode) ? [UIColor blackColor] : [UIColor whiteColor];
	[detailsWebView setBackgroundColor:backgroundColor];
    
    [self refreshDetailsView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDetailsView) name:NotificationModulesChanged object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
	[detailsWebView loadHTMLString:@"" baseURL:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewDidDisappear:animated];
}

- (void)confirmUpgrade {
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"") message:NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"") style:UIAlertActionStyleCancel handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	if([[module name] isEqualToString: @"Personal"]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"Error") message:NSLocalizedString(@"NotSupported", @"") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"Ok") style:UIAlertActionStyleCancel handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	SwordInstallSource *sIS = [[PSModuleController defaultModuleController] currentInstallSource];

	NSString *question = NSLocalizedString(@"ConfirmUpgrade", @"Would you like to upgrade this module?");
	NSString *messageTitle = NSLocalizedString(@"InstallTitle", @"");

	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n%@\n[%@]", [module name], [module descr], [module installSize], [sIS caption]];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:messageTitle message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No") style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		// Upgrade the module: remove it first and then install the new version.
		[[PSModuleController defaultModuleController] removeModule:self->module.name];
		PSModuleDownloadItem *dItem = [[PSModuleDownloadItem alloc] initWithModule:self->module swordInstallSource:[[PSModuleController defaultModuleController] currentInstallSource] viewForHUD:self->detailsWebView];
		[PSModuleController queueModuleDownloadItem:dItem];
		[self refreshInstallButton];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmInstall {
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"") message:NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"") style:UIAlertActionStyleCancel handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	if([[module name] isEqualToString: @"Personal"]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"Error") message:NSLocalizedString(@"NotSupported", @"") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"Ok") style:UIAlertActionStyleCancel handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	SwordInstallSource *sIS = [[PSModuleController defaultModuleController] currentInstallSource];

	NSString *question = NSLocalizedString(@"ConfirmInstall", @"Would you like to install this module?");
	NSString *messageTitle = NSLocalizedString(@"InstallTitle", @"");

	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n%@\n[%@]", [module name], [module descr], [module installSize], [sIS caption]];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:messageTitle message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No") style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		// Install the module
		PSModuleDownloadItem *dItem = [[PSModuleDownloadItem alloc] initWithModule:self->module swordInstallSource:[[PSModuleController defaultModuleController] currentInstallSource] viewForHUD:self->detailsWebView];
		[PSModuleController queueModuleDownloadItem:dItem];
		[self refreshInstallButton];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}


- (void)moduleDownloaded:(PSModuleDownloadItem *)sender {
	[self refreshDetailsView];
}

- (void)viewWillDisappear:(BOOL)animated {
	[PSModuleController removeViewForHUDForModuleDownloadItem:module.name];
	[super viewWillDisappear:animated];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
