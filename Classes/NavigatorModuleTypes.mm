//
//  NavigatorLevel2.mm
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "NavigatorModuleTypes.h"
#import "PSModuleType.h"
#import "NavigatorModuleLanguages.h"

// displaying the Module Types

@implementation NavigatorModuleTypes

@synthesize dataArray;

NSTimer *refreshTimer;

- (void)createRefreshTimer {
	SEL method = @selector(updateRefreshStatus);
	NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setTarget: self];
	[invocation setSelector: method];
	
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
}

- (void)_refreshDownloadSource {
	[[[PSModuleController defaultModuleController] swordInstallManager] resetInstallationProgress];
	[self performSelectorOnMainThread: @selector(showRefreshStatus) withObject: nil waitUntilDone: YES];
	[[PSModuleController defaultModuleController] performSelectorInBackground: @selector(refreshCurrentInstallSource) withObject:nil];
	
	[self createRefreshTimer];
	
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        bti = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    }	
}


- (void)updateRefreshButton {
	self.navigationItem.rightBarButtonItem = nil;
	UIBarButtonItem *refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshDownloadSource:)];
    if([[statusController view] superview]) {
		[refreshBarButtonItem setEnabled:NO];
    } else {
		[refreshBarButtonItem setEnabled:YES];
    }
	self.navigationItem.rightBarButtonItem = refreshBarButtonItem;
	[refreshBarButtonItem release];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self updateRefreshButton];

	[cancelButton setTitle: NSLocalizedString(@"Cancel", @"Cancel") forState: UIControlStateNormal];
	
	NSIndexPath *tableSelection = [table indexPathForSelectedRow];
	[table deselectRowAtIndexPath:tableSelection animated:YES];
}

- (void)reloadTable {
	[table reloadData];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	//sometimes the busy modal view doesn't clear properly from the previous view, so we can re-remove it here.
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
    if(![[statusController view] superview]) {
		if(([dataArray count] == 0)  && [PSModuleController checkNetworkConnection]) {
			[self _refreshDownloadSource];
		}
	}
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


// the InstallSource probably has downloadable modules that aren't supported in PocketSword yet,
//   so we don't display all categories available, but instead only the categories supported by SwordManager.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [dataArray count];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if ([dataArray count] == 0) {
		return NSLocalizedString(@"NoModulesRefresh", @"No modules here. Try a refresh.");
	}
	else {
		return NSLocalizedString(@"ModuleTypesHeaderText", @"");
	}
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"lvl2-id"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"lvl2-id"] autorelease];
	}
	
	cell.textLabel.text = NSLocalizedString([[dataArray objectAtIndex:indexPath.row] moduleType], @"");
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
	
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[((NavigatorModuleLanguages*)navigatorModuleLanguages) setData:[dataArray objectAtIndex:indexPath.row]];
	((NavigatorModuleLanguages*)navigatorModuleLanguages).title = [(PSModuleType*)[dataArray objectAtIndex:indexPath.row] moduleType];
	[((NavigatorModuleLanguages*)navigatorModuleLanguages) reloadTable];
	[self.navigationController pushViewController:navigatorModuleLanguages animated:YES];
	
}

- (IBAction)cancelRefreshDownloadSource {
	//incomplete
	// need to do more than this!!!
	[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
}

- (IBAction)refreshDownloadSource:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		[pool release];
		return;
	}
	
	[self _refreshDownloadSource];
	
	[pool release];
}

//- (void)runRefreshDownloadSource {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	[[[PSModuleController defaultModuleController] swordInstallManager] resetInstallationProgress];
//	
//	[self performSelectorOnMainThread: @selector(showRefreshStatus) withObject: nil waitUntilDone: YES];
//	
//	[[PSModuleController defaultModuleController] performSelectorInBackground: @selector(refreshCurrentInstallSource) withObject:nil];
//	
//	[self updateRefreshStatus];
//	
//	[pool release];
//}

- (void)showRefreshStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[statusTitle setText: NSLocalizedString(@"RefreshingModuleSource", @"Refreshing Module Source")];
	[statusOverallText setText: @""];
	[statusOverallBar setHidden: YES];
    NSString *sText = [NSString stringWithFormat: @"%@: %@", NSLocalizedString(@"RefreshingModuleSource", @""), self.title] ;
    [statusText setText: sText];
	[statusText setLineBreakMode: UILineBreakModeWordWrap];

	//[navigatorSources.tabController presentModalViewController: statusController animated: YES];
    [[statusController view] setAlpha:0.0];
    statusController.view.frame = self.view.frame;
    statusController.view.center = self.view.center;
    [self.view addSubview:[statusController view]];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.5];
    [[statusController view] setAlpha:1.0];
    [UIView commitAnimations];
    [self updateRefreshButton];
	
	[pool release];
}

- (void)updateRefreshStatus {
	PSStatusReporter *reporter = [[PSModuleController defaultModuleController] getInstallationProgress];
	BOOL failed = YES;
	float progress = reporter->fileProgress;
	[statusBar setProgress: reporter->fileProgress];
	
	//DLog(@"  -------  Progress: %f", progress);
	//if(!refreshTimer)
		//NSLog(@"######################### borken");
	
	if (progress == 1.0) {
		if(refreshTimer) {
			[refreshTimer performSelectorOnMainThread:@selector(invalidate) withObject:nil waitUntilDone:YES];
			refreshTimer = nil;
		}
		[self performSelectorOnMainThread:@selector(hideOperationStatus) withObject:nil waitUntilDone:YES];
		
		failed = NO;
	} else if (progress == -1.0) {
		failed = YES;
	} else {
		failed = NO;
	}
	
	if (failed) {
		if(refreshTimer) {
			[refreshTimer performSelectorOnMainThread:@selector(invalidate) withObject:nil waitUntilDone:YES];
			refreshTimer = nil;
		}
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"RefreshProblem", @"A problem occurred during the refresh.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
	}
}

- (void) hideOperationStatusEnded:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    [[statusController view] removeFromSuperview];
    [self updateRefreshButton];
}

- (void)refreshDataArray {
	NSArray *installSources = [[[PSModuleController defaultModuleController] swordInstallManager] installSourceList];
	SwordInstallSource *sIS = nil;
	for(SwordInstallSource *src in installSources) {
		if([self.title isEqualToString:[src caption]]) {
			sIS = src;
			break;
		}
	}
	if(!sIS) {
		[self.navigationController popViewControllerAnimated: YES];
	}
	if(![sIS isSwordManagerLoaded]) {
		// we need to display a busy indicator, cause it can take a LONG time to do file IO on the device...
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
		
		[sIS swordManager];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	}
	[self setDataArray:[sIS moduleListByType]];
	//self.title = [sIS caption];
	[self reloadTable];
	
	// need to set the current install source, for when we want to install a module.
	[[PSModuleController defaultModuleController] setCurrentInstallSource:sIS];

}

- (void)hideOperationStatus {
	//NSLog(@" ++++++++ hideOperationStatus");
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }
	
	[self refreshDataArray];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDidStopSelector:@selector(hideOperationStatusEnded:finished:context:)];
    [[statusController view] setAlpha:0.0];
    [UIView commitAnimations];
	//[self.navigationController popViewControllerAnimated: YES];//dodgy pop back to allow the user to reselect this installSource. TODO: fix........
	
	[statusText setText: @""];
	[statusOverallText setText: @""];
	[statusBar setProgress: 0.0];
	[statusOverallBar setProgress: 0.0];
	[pool release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)dealloc {
	[dataArray release];
	[super dealloc];
}
@end
