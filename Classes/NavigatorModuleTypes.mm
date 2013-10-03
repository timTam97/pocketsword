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
#import "PSResizing.h"
#import "PocketSwordAppDelegate.h"
#import "PSModuleController.h"
#import "NavigatorSources.h"
#import "globals.h"
#import "SwordInstallSource.h"
#import "SwordInstallManager.h"

// displaying the Module Types

@implementation NavigatorModuleTypes

@synthesize dataArray;

- (void)updateRefreshButton {
	[self updateRefreshButton:YES];
}

- (void)updateRefreshButton:(BOOL)enabled {
	BOOL downloading = [[PSModuleController defaultModuleController] tryDownloading];
	self.navigationItem.rightBarButtonItem = nil;
	UIBarButtonItem *refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshDownloadSource:)];
	[refreshBarButtonItem setEnabled:(downloading ? NO : enabled)];
	self.navigationItem.rightBarButtonItem = refreshBarButtonItem;
	[refreshBarButtonItem release];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self updateRefreshButton:YES];
	
	NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:tableSelection animated:YES];
}

- (void)reloadTable {
	[self.tableView reloadData];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if(([dataArray count] == 0)  && [PSModuleController checkNetworkConnection] && ![[PSModuleController defaultModuleController] tryDownloading]) {
		[self _refreshDownloadSource];
	}
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateRefreshButton) name:NotificationModulesChanged object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
	NavigatorModuleLanguages *moduleLanguages = [[NavigatorModuleLanguages alloc] initWithStyle:UITableViewStyleGrouped];
	[moduleLanguages setData:[dataArray objectAtIndex:indexPath.row]];
	moduleLanguages.title = [(PSModuleType*)[dataArray objectAtIndex:indexPath.row] moduleType];
	[moduleLanguages reloadTable];
	[self.navigationController pushViewController:moduleLanguages animated:YES];
	[moduleLanguages release];
}

- (void)cancelRefreshDownloadSource {
	//incomplete
	// need to do more than this!!!
	[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	[hud release];
	hud = nil;
    [self updateRefreshButton:YES];
	
	[self refreshDataArray];
}

- (void)_refreshDownloadSource {
	MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:(((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window)];
	[(((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window) addSubview:HUD];
	
	// Regiser for HUD callbacks so we can remove it from the window at the right time
	HUD.delegate = self;
	HUD.labelText = NSLocalizedString(@"RefreshingModuleSource", @"Refreshing Module Source");
	HUD.detailsLabelText = self.title;
	HUD.dimBackground = YES;
	
	// Show the HUD while the provided method executes in a new thread
	[HUD showWhileExecuting:@selector(refreshCurrentInstallSource) onTarget:[PSModuleController defaultModuleController] withObject:nil animated:YES];

    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        bti = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    }
}
- (void)refreshDownloadSource:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		[pool release];
		return;
	}
	
    [self updateRefreshButton:NO];
	[self _refreshDownloadSource];
	
	[pool release];
}

- (void)handleRefreshStatus {
	//PSStatusReporter *reporter = [[PSModuleController defaultModuleController] getInstallationProgress];
	BOOL failed = NO;
	float progress = 0.0f;
	while (progress < 1.0f) {
		//[statusBar setProgress: reporter->fileProgress];
		//HUD.progress = progress;
		usleep(100);
		PSStatusReporter *reporter = [[PSModuleController defaultModuleController] getInstallationProgress];
		progress = reporter->fileProgress;
		if(progress == -1.0) {
			failed = YES;
			break;
		}
	}
	if(failed) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"RefreshProblem", @"A problem occurred during the refresh.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
	}
	
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }
	
}

- (void)showHUD {
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
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
		[self performSelectorInBackground:@selector(showHUD) withObject:nil];
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			
			[sIS swordManager];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[MBProgressHUD hideHUDForView:self.view animated:YES];
			});
		});
		
		
	}
	[self setDataArray:[sIS moduleListByType]];
	//self.title = [sIS caption];
	[self.tableView reloadData];
	
	// need to set the current install source, for when we want to install a module.
	[[PSModuleController defaultModuleController] setCurrentInstallSource:sIS];

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)dealloc {
	[dataArray release];
	[super dealloc];
}
@end
