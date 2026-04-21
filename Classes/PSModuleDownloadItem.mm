//
//  PSModuleDownloadItem.m
//  PocketSword
//
//  Created by Nic Carter on 29/05/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

#import "PSModuleDownloadItem.h"
#import "SwordModule.h"
#import "SwordInstallSource.h"
#import "PSStatusReporter.h"
#import "PocketSwordAppDelegate.h"
#import "PSModuleController.h"
#import "SwordManager.h"

@implementation PSModuleDownloadItem

@synthesize delegate;
@synthesize downloadStarted;

- (id)initWithModule:(SwordModule*)swordModule swordInstallSource:(SwordInstallSource*)swordInstallSource viewForHUD:(UIView*)view {
	self = [super init];
	if(self) {
		module = swordModule;
		sIS = swordInstallSource;
		viewForHUD = view;
		installingIndex = NO;
		downloadStarted = NO;
		removingHUDViewInProgress = NO;
	}
	return self;
}

- (NSString*)moduleName {
	return module.name;
}

- (void)addViewForHUD:(UIView*)view {
	viewForHUD = view;
}

- (void)removeViewForHUD {
	if(viewForHUD && downloadStarted) {
		removingHUDViewInProgress = YES;
		[MBProgressHUD hideHUDForView:viewForHUD animated:YES];
	}
	viewForHUD = nil;
}

- (void)_install {
	[[PSModuleController defaultModuleController] installModuleWithModule:module fromSource:sIS];
}

- (void)startInstall {
	if(downloadStarted) {
		DLog(@"\n--- Download is already started! ---");
		return;
	} else {
		downloadStarted = YES;
	}
	UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
	
    if(backgroundSupported) {
        bti = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    }
	
	NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: @selector(updateInstallModuleHUD)];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setTarget: self];
	[invocation setSelector: @selector(updateInstallModuleHUD)];
	
	[self performSelectorInBackground:@selector(_install) withObject:nil];
	if(viewForHUD) {
		installModuleHUD = [[MBProgressHUD alloc] initWithView:viewForHUD];
		installModuleHUD.delegate = self;
		installModuleHUD.label.text = NSLocalizedString(@"Installing", @"");
		installModuleHUD.detailsLabel.text = module.name;
		installModuleHUD.mode = MBProgressHUDModeDeterminate;
		//installModuleHUD.dimBackground = YES;
		[viewForHUD addSubview:installModuleHUD];
		[installModuleHUD showAnimated:YES];
	} else {
		installModuleHUD = nil;
	}
	installModuleTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05 invocation: invocation repeats: YES];
}

- (void)updateInstallModuleHUD {
	@autoreleasepool {
		PSStatusReporter *reporter = [[PSModuleController defaultModuleController] getInstallationProgress];
		BOOL failed = YES;
		BOOL finished = NO;
		float progress = reporter->overallProgress;
		if(viewForHUD) {
			installModuleHUD.progress = reporter->overallProgress;
		}
		//[statusBar setProgress: reporter->fileProgress];
		//[statusOverallBar setProgress: reporter->overallProgress];
		
		if (progress == 1.0) {
			finished = YES;
			failed = NO;
		}
		else if (progress == -1.0) {
			failed = YES;
		} else {
			failed = NO;
		}
		if(finished || failed) {
			UIDevice* device = [UIDevice currentDevice];
			BOOL backgroundSupported = NO;
			if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
				backgroundSupported = device.multitaskingSupported;
			}
			
			if(backgroundSupported) {
				[[UIApplication sharedApplication] endBackgroundTask:bti];
				bti = UIBackgroundTaskInvalid;
			}
			[installModuleTimer invalidate];
		}
		
		if(finished) {
			[[PSModuleController defaultModuleController] reload];
			// show success msg
			if(viewForHUD) {
				installModuleHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]];
				installModuleHUD.label.text = NSLocalizedString(@"InstalledButtonTitle", @"");
				installModuleHUD.mode = MBProgressHUDModeCustomView;
				[installModuleHUD hideAnimated:YES afterDelay:1];
			} else {
				UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
				installModuleHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
				installModuleHUD.delegate = self;
				installModuleHUD.label.text = NSLocalizedString(@"InstalledButtonTitle", @"");
				installModuleHUD.detailsLabel.text = module.name;
				installModuleHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]];
				installModuleHUD.mode = MBProgressHUDModeCustomView;
				[viewToUse addSubview:installModuleHUD];
				[installModuleHUD showAnimated:YES];
				[installModuleHUD hideAnimated:YES afterDelay:1];
			}
		} else if (failed) {
			//show fail msg
			if(viewForHUD) {
				installModuleHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
				installModuleHUD.mode = MBProgressHUDModeCustomView;
				[installModuleHUD hideAnimated:YES afterDelay:1];
			} else {
				UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
				installModuleHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
				installModuleHUD.delegate = self;
				installModuleHUD.label.text = NSLocalizedString(@"Error", @"");
				installModuleHUD.detailsLabel.text = [NSString stringWithFormat:@"%@:\n%@", NSLocalizedString(@"InstallProblem", @""), module.name];
				installModuleHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
				installModuleHUD.mode = MBProgressHUDModeCustomView;
				[viewToUse addSubview:installModuleHUD];
				[installModuleHUD showAnimated:YES];
				[installModuleHUD hideAnimated:YES afterDelay:1];
			}
		}
	
	}
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
    DLog(@"");
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	hud = nil;
	if(removingHUDViewInProgress) {
		removingHUDViewInProgress = NO;
		return;
	}
	SwordModule *installedModule = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:[module name]];

	// A module upgrade may leave the existing FTS5 index stale (its
	// module_version meta won't match). Drop it eagerly so the next Search
	// tap re-offers the build sheet. Fresh installs with no prior index
	// short-circuit this harmlessly.
	if(installedModule && installedModule.type == bible) {
		[installedModule deleteSearchIndex];
	}
	[delegate moduleDownloaded:self];
}

@end
