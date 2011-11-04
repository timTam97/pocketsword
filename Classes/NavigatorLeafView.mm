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
NSTimer *downloadTimer;

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
    
    if([[statusController view] superview]) {
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
}

- (void)viewDidDisappear:(BOOL)animated {
	[detailsView loadHTMLString:@"" baseURL:nil];
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

//
// UIAlertView delegate method
//
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	SwordModule *installedModule = [[SwordManager defaultManager] moduleWithName:module.name];
	
	if (buttonIndex == 1 && !installedModule) {
		//install the module
		[self performSelectorInBackground: @selector(runInstallation) withObject: nil];
		
		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: @selector(updateInstallationStatus)];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
		[invocation setTarget: self];
		[invocation setSelector: @selector(updateInstallationStatus)];
		
		downloadTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
	} else if(buttonIndex == 1) {
		//upgrade the module
		[[PSModuleController defaultModuleController] removeModule:module.name];
		
		[self performSelectorInBackground: @selector(runInstallation) withObject: nil];
		
		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: @selector(updateInstallationStatus)];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
		[invocation setTarget: self];
		[invocation setSelector: @selector(updateInstallationStatus)];
		
		downloadTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
	}
	
	[pool release];
}

- (void)showDownloadStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	//DLog(@"showDownloadStatus: %@ -> %@", module.name, [module descr]);
	[statusTitle setText: NSLocalizedString(@"Module Download", @"Module Download")];
	[statusOverallText setText: @""];
	NSString *sText = [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"Installing", @"Installing"), [module descr]] ;
	
	[statusOverallBar setHidden: NO];
	[statusText setText: sText];
	[statusText setLineBreakMode: UILineBreakModeWordWrap];

	//[[navigatorSources tabController].moreNavigationController presentModalViewController: statusController animated: YES];
	//[[self navigationController] presentModalViewController: statusController animated: YES];
    //[self presentModalViewController: statusController animated: YES];
    [[statusController view] setAlpha:0.0];
    statusController.view.frame = self.view.frame;
    statusController.view.center = self.view.center;
    [self.view addSubview:[statusController view]];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.5];
    [[statusController view] setAlpha:1.0];
    [UIView commitAnimations];
    
    [self refreshInstallButton];
	
	[pool release];
}

- (void)runInstallation {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[[[PSModuleController defaultModuleController] swordInstallManager] resetInstallationProgress];
    
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }

    if(backgroundSupported) {
        bti = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    }
	
	[[PSModuleController defaultModuleController] performSelectorInBackground: @selector(installModuleWithModule:) withObject: module];

	[self performSelectorOnMainThread: @selector(showDownloadStatus) withObject: nil waitUntilDone: NO];
	//[self showDownloadStatus];
	
	//DLog(@"runInstallation:  calling [moduleManager installModule: %@]", [module name]);
	[self updateInstallationStatus];
	
	[pool release];
}

- (void)updateInstallationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	PSStatusReporter *reporter = [[PSModuleController defaultModuleController] getInstallationProgress];
	BOOL failed = YES;
	float progress = reporter->overallProgress;
	[statusBar setProgress: reporter->fileProgress];
	[statusOverallBar setProgress: reporter->overallProgress];
	
//	NSString *desc = [NSString stringWithCString:reporter->getDescription() encoding:[NSString defaultCStringEncoding]];
//	NSRange dataRange = [desc rangeOfString: @")"];
//	if(dataRange.location != NSNotFound) {
//		desc = [NSString stringWithFormat: @"%@ files)", [desc substringToIndex: dataRange.location]];
//	}
//	[statusOverallText setText: desc];
	
	//DLog(@"updateInstallationStatus: Progress: %f", progress);
    //DLog(@"backgroundTimeRemaining: %f", [[UIApplication sharedApplication] backgroundTimeRemaining]);
	
	if (progress == 1.0) {
		[[PSModuleController defaultModuleController] reload];
		//[[[PSModuleController defaultModuleController] viewController] reloadModuleTable];
		//[moduleTable reloadData];
		//[downloadableModulesTable reloadData];
		[self performSelectorOnMainThread: @selector(hideOperationStatus) withObject: nil waitUntilDone: NO];
		failed = NO;
	}
	else if (progress == -1.0) {
		failed = YES;
	} else {
		failed = NO;
	}
	if (failed) {
		[[PSModuleController defaultModuleController] reload];
		[self performSelectorOnMainThread: @selector(hideOperationStatus) withObject: nil waitUntilDone: NO];
		//[[[PSModuleController defaultModuleController] viewController] reloadModuleTable];
		//[moduleTable reloadData];
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"InstallProblem", @"A problem occurred during the installation.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
	}
	[pool release];
}

- (void) hideOperationStatusEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    [[statusController view] removeFromSuperview];
	[self refreshInstallButton];
}

- (void)hideOperationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//[[navigatorSources tabController].moreNavigationController dismissModalViewControllerAnimated: YES];
    //[[self navigationController] dismissModalViewControllerAnimated: YES];
    //[self dismissModalViewControllerAnimated: YES];

    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }

    [self refreshDetailsView];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDidStopSelector:@selector(hideOperationStatusEnded:finished:context:)];
    [[statusController view] setAlpha:0.0];
    [UIView commitAnimations];

    
	[downloadTimer invalidate];
	
	[statusText setText: @""];
	[statusOverallText setText: @""];
	[statusBar setProgress: 0.0];
	[statusOverallBar setProgress: 0.0];
	[pool release];
}

- (void)dealloc {
	[module release];
	[downloadTimer release];
	[super dealloc];
}

@end
