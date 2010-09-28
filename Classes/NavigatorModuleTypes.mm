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

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	//[table reloadData];	// populate our table's data
	
	self.navigationItem.rightBarButtonItem = nil;
	UIBarButtonItem *refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshDownloadSource:)];
	self.navigationItem.rightBarButtonItem = refreshBarButtonItem;
	[refreshBarButtonItem release];

	[cancelButton setTitle: NSLocalizedString(@"Cancel", @"Cancel") forState: UIControlStateNormal];
	
	NSIndexPath *tableSelection = [table indexPathForSelectedRow];
	[table deselectRowAtIndexPath:tableSelection animated:YES];
}

- (void)reloadTable {
	[table reloadData];
}


- (void)viewDidAppear:(BOOL)animated {
	//sometimes the busy modal view doesn't clear properly from the previous view, so we can re-remove it here.
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	//[[PSModuleController defaultModuleController] hideBusyIndicator];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


// the InstallSource probably has downloadable modules that aren't supported in PocketSword yet,
//   so we don't display all categories available, but instead only the categories supported by SwordManager.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [dataArray count];
//	if ([dataArray count] == 0)
//		return 0;
//	else
//		return [[SwordManager moduleTypes] count];
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if ([dataArray count] == 0) {
		//((UITableView*)table).sectionHeaderHeight = 40.5;
		return NSLocalizedString(@"NoModulesRefresh", @"No modules here. Try a refresh.");
	}
	else {
		//((UITableView*)table).sectionHeaderHeight = 1.0;
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
	[[navigatorSources tabController].moreNavigationController pushViewController:navigatorModuleLanguages animated:YES];
	
}

- (void)createRefreshTimer {
	SEL method = @selector(updateRefreshStatus);
	NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setTarget: self];
	[invocation setSelector: method];
	
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 invocation: invocation repeats: YES];
}

- (IBAction)cancelRefreshDownloadSource {
	// need to do more than this!!!
	[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
}

- (IBAction)refreshDownloadSource:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if(![PSModuleController checkNetworkConnection]) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.")
								   delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil] show];		
		[pool release];
		return;
	}
	
	[[navigatorSources tabController].moreNavigationController popViewControllerAnimated: NO];
	//[self performSelectorInBackground: @selector(runRefreshDownloadSource) withObject: nil];
	//testing:
	[[[PSModuleController defaultModuleController] swordInstallManager] resetInstallationProgress];
	[self performSelectorOnMainThread: @selector(showRefreshStatus) withObject: nil waitUntilDone: YES];
	[[PSModuleController defaultModuleController] performSelectorInBackground: @selector(refreshCurrentInstallSource) withObject:nil];
	//[self updateRefreshStatus];
	//end testing.
	
	[self createRefreshTimer];
	
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
	
	[statusText setText: @""];
	//[ViewController showModal:statusController.view withTiming:0.3];
	[navigatorSources.tabController presentModalViewController: statusController animated: YES];
	
	[pool release];
}

- (void)updateRefreshStatus {
	PSStatusReporter *reporter = [[PSModuleController defaultModuleController] getInstallationProgress];
	BOOL failed = YES;
	float progress = reporter->fileProgress;
	[statusBar setProgress: reporter->fileProgress];
	//[statusOverallBar setProgress: reporter->overallProgress];
	//NSString *desc = [[NSString alloc] initWithCString: reporter->getDescription() encoding: [NSString defaultCStringEncoding]];
	//[statusOverallText setText: desc];
	//[desc release];
	
	//DLog(@"  -------  Progress: %f", progress);
	//if(!refreshTimer)
		//NSLog(@"######################### borken");
	
	if (progress == 1.0) {
		if(refreshTimer) {// move this to updateRefreshStatus?
			[refreshTimer performSelectorOnMainThread:@selector(invalidate) withObject:nil waitUntilDone:YES];
			//[refreshTimer invalidate];
			refreshTimer = nil;
		}
		[self performSelectorOnMainThread:@selector(hideOperationStatus) withObject:nil waitUntilDone:YES];
		//[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		
		failed = NO;
	} else if (progress == -1.0) {
		failed = YES;
	} else {
		failed = NO;
	}
	
	if (failed) {
		if(refreshTimer) {// move this to updateRefreshStatus?
			[refreshTimer performSelectorOnMainThread:@selector(invalidate) withObject:nil waitUntilDone:YES];
			//[refreshTimer invalidate];
			refreshTimer = nil;
		}
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"RefreshProblem", @"A problem occurred during the refresh.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil] show];		
	}
}

- (void)hideOperationStatus {
	//NSLog(@" ++++++++ hideOperationStatus");
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[navigatorSources.tabController dismissModalViewControllerAnimated: YES];
	//[ViewController hideModal:statusController.view withTiming:0.3];
	
	[statusText setText: @""];
	[statusOverallText setText: @""];
	[statusBar setProgress: 0.0];
	[statusOverallBar setProgress: 0.0];
	[pool release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void)dealloc {
	[dataArray release];
	[super dealloc];
}
@end
