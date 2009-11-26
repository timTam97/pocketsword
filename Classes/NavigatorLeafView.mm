//
//  NavigatorLeafView.mm
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NavigatorLeafView.h"


@implementation NavigatorLeafView

@synthesize module;
NSTimer *downloadTimer;

- (void)viewWillAppear:(BOOL)animated {
	self.title = module.name;
	self.navigationItem.rightBarButtonItem = nil;
	BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"];
	UIColor *backgroundColor = (nightMode) ? [UIColor blackColor] : [UIColor whiteColor];
	[detailsView setBackgroundColor:backgroundColor];
	
	UIBarButtonItem *installBarButtonItem;
	if ([[moduleManager swordManager] isModuleInstalled:module.name]) {
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"InstalledButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:nil];
		[installBarButtonItem setEnabled:NO];
	} else {
		installBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"InstallButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(confirmInstall)];
		[installBarButtonItem setEnabled:YES];
	}
	self.navigationItem.rightBarButtonItem = installBarButtonItem;
	[installBarButtonItem release];
	NSString *about = [ModuleManager createHTMLString:[module fullAboutText] usingPreferences:YES withJS:@""];
	//DLog(@"%@", about);
	[detailsView loadHTMLString:about baseURL:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
	[detailsView loadHTMLString:@"" baseURL:nil];
}

- (void)confirmInstall {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if(![ModuleManager checkNetworkConnection]) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.")
								   delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil] show];		
		[pool release];
		return;
	}

	//Is it already installed?
	//BOOL installedAlready = [[moduleManager swordManager] isModuleInstalled: module.name];
	SwordInstallSource *sIS = [moduleManager currentInstallSource];
	
	NSString *question = NSLocalizedString(@"ConfirmInstall", @"Would you like to install this module?");
	NSString *messageTitle = NSLocalizedString(@"InstallTitle", @"");
	//if(installedAlready) {
	//	question = @"This module is already installed, do you wish to download it again?";
	//	messageTitle = @"Download again?";
	//}
	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n[%@]", [module name], [module descr], [sIS caption]];
	[[[UIAlertView alloc] initWithTitle: messageTitle message: message
							   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];

	[pool release];
}

//
// UIAlertView delegate method
//
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//DLog(@"Clicked button %d", buttonIndex);
	if (buttonIndex == 1) {
		//DLog(@"alertView: didDismissWithButtonIndex: -- waitingForInstall");
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

	//UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	//[navController setNavigationBarHidden: YES];
	//[navigationController presentModalViewController: navController animated: YES];
	[tabController.moreNavigationController presentModalViewController: statusController animated: YES];
	
	[pool release];
}

- (void)runInstallation {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[[moduleManager swordInstallManager] resetInstallationProgress];
	
	[moduleManager performSelectorInBackground: @selector(installModuleWithModule:) withObject: module];

	[self performSelectorOnMainThread: @selector(showDownloadStatus) withObject: nil waitUntilDone: NO];
	//[self showDownloadStatus];
	
	//DLog(@"runInstallation:  calling [moduleManager installModule: %@]", [module name]);
	[self updateInstallationStatus];
	
	[pool release];
}

- (void)updateInstallationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	PocketSwordStatusReporter *reporter = [moduleManager getInstallationProgress];
	BOOL failed = YES;
	float progress = reporter->overallProgress;
	[statusBar setProgress: reporter->fileProgress];
	[statusOverallBar setProgress: reporter->overallProgress];
	
	NSString *desc = [NSString stringWithCString:reporter->getDescription() encoding:[NSString defaultCStringEncoding]];
	//DLog(@"%@", desc);
	NSRange dataRange = [desc rangeOfString: @")"];
	if(dataRange.location != NSNotFound) {
		//desc = [NSString stringWithFormat: @"%@ %@)", [desc substringToIndex: dataRange.location], NSLocalizedString(@"files", @"")];
		desc = [NSString stringWithFormat: @"%@ files)", [desc substringToIndex: dataRange.location]];
	}
	//DLog(@"%@", desc);
	[statusOverallText setText: desc];
	
	//DLog(@"updateInstallationStatus: Progress: %f", progress);
	
	if (progress == 1.0) {
		[moduleManager reload];
		[moduleTable reloadData];
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
		[moduleManager reload];
		[self performSelectorOnMainThread: @selector(hideOperationStatus) withObject: nil waitUntilDone: NO];
		[moduleTable reloadData];
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"InstallProblem", @"A problem occurred during the installation.")
								   delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil] show];		
	}
	[pool release];
}

- (void)hideOperationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//[tabController dismissModalViewControllerAnimated: YES];
	[tabController.moreNavigationController dismissModalViewControllerAnimated: YES];
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
