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
		if(indexController) {
			[indexController removeViewForHUD];
		} else {
			[MBProgressHUD hideAllHUDsForView:viewForHUD animated:YES];
		}
	}
	viewForHUD = nil;
}

- (void)indexInstalled:(PSIndexController*)sender {
	[indexController release];
	indexController = nil;
	[delegate moduleDownloaded:self];
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
		installModuleHUD.labelText = NSLocalizedString(@"Installing", @"");
		installModuleHUD.detailsLabelText = module.name;
		installModuleHUD.mode = MBProgressHUDModeDeterminate;
		installModuleHUD.dimBackground = YES;
		[viewForHUD addSubview:installModuleHUD];
		[installModuleHUD show:YES];
	} else {
		installModuleHUD = nil;
	}
	installModuleTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05 invocation: invocation repeats: YES];
}

- (void)updateInstallModuleHUD {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
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
			installModuleHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
			installModuleHUD.labelText = NSLocalizedString(@"InstalledButtonTitle", @"");
			installModuleHUD.mode = MBProgressHUDModeCustomView;
			[installModuleHUD hide:YES afterDelay:1];
		} else {
			UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
			installModuleHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
			installModuleHUD.delegate = self;
			installModuleHUD.labelText = NSLocalizedString(@"InstalledButtonTitle", @"");
			installModuleHUD.detailsLabelText = module.name;
			installModuleHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
			installModuleHUD.mode = MBProgressHUDModeCustomView;
			[viewToUse addSubview:installModuleHUD];
			[installModuleHUD show:YES];
			[installModuleHUD hide:YES afterDelay:1];
		}
	} else if (failed) {
		//show fail msg
		if(viewForHUD) {
			installModuleHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
			installModuleHUD.mode = MBProgressHUDModeCustomView;
			[installModuleHUD hide:YES afterDelay:1];
		} else {
			UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
			installModuleHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
			installModuleHUD.delegate = self;
			installModuleHUD.labelText = NSLocalizedString(@"Error", @"");
			installModuleHUD.detailsLabelText = [NSString stringWithFormat:@"%@:\n%@", NSLocalizedString(@"InstallProblem", @""), module.name];
			installModuleHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
			installModuleHUD.mode = MBProgressHUDModeCustomView;
			[viewToUse addSubview:installModuleHUD];
			[installModuleHUD show:YES];
			[installModuleHUD hide:YES afterDelay:1];
		}
	}
	
	[pool release];
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	[hud release];
	hud = nil;
	if(removingHUDViewInProgress) {
		removingHUDViewInProgress = NO;
		return;
	}
	SwordModule *installedModule = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:[module name]];
	
	if(!installedModule) {
		[delegate moduleDownloaded:self];
	} else if(![installedModule hasSearchIndex] && installedModule.type == bible) {
		indexController = [[PSIndexController alloc] init];
		indexController.delegate = self;
		indexController.moduleToInstall = installedModule.name;
		[indexController addViewForHUD:viewForHUD];
		[indexController start:NO];
	} else {
		[delegate moduleDownloaded:self];
	}
}

@end
