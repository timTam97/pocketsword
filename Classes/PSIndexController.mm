//
//  PSIndexController.mm
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSIndexController.h"
#import "ZipArchive.h"
#import "PocketSwordAppDelegate.h"

@implementation PSIndexController

@synthesize files;
@synthesize delegate;
@synthesize moduleToInstall;

- (void)addViewForHUD:(UIView *)view {
	viewForHUD = view;
}

- (void)removeViewForHUD {
	if(viewForHUD) {
		[MBProgressHUD hideAllHUDsForView:viewForHUD animated:YES];
	}
	viewForHUD = nil;
}

- (void)viewDidAppear:(BOOL)animated {
	[self start];
}

- (void)start {
	if(!self.moduleToInstall) {
		NSAssert(moduleToInstall, @"Must set the module to install before starting the Index Installer!");
	}
	if(!viewForHUD) {
		NSAssert(viewForHUD, @"you probably want an initial view set for the HUD to display on for the Index Installer :P");
	}
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		return;
	}
	[self retrieveRemoteIndexList];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {	
	// check alertView.message for which dialogue we are dealing with.
	DLog(@"\nalertView.title = %@", alertView.title);
	if([alertView.title isEqualToString:NSLocalizedString(@"NoSearchIndexTitle", @"")] || [alertView.title isEqualToString:NSLocalizedString(@"Error", @"")]) {
		[self.delegate indexInstalled:NO];
		return;
	}
	
	if (buttonIndex == 1) {
		[self installSearchIndexForModule];
	} else {
		[self.delegate indexInstalled:NO];
	}
}

- (void)_retrieveRemoteIndexList {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
	if([PSModuleController checkNetworkConnection]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];

		NSString *remoteDir = @"http://www.crosswire.org/pocketsword/indices/v1/";
		
		// Get the index directory listing
		NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: remoteDir]
												 cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 10.0];
		NSData *data = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
		if (!data) {
			DLog(@"Couldn't list remote directory");
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
			self.files = nil;
			[pool release];
			if(viewForHUD) {
				installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
				installHUD.mode = MBProgressHUDModeCustomView;
				[installHUD hide:YES afterDelay:2];
			} else {
				[delegate indexInstalled:NO];
			}
			return;
		}
		
		NSString *dataString = [[[NSString alloc] initWithData: data encoding: [NSString defaultCStringEncoding]] autorelease];
		self.files = [NSMutableArray arrayWithObjects: nil];
		NSRange dataRange;
		
		while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
			dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
			dataRange = [dataString rangeOfString: @"\""];
			if (dataRange.location != NSNotFound) {
				NSString *link = [dataString substringToIndex: dataRange.location];
				//if ([item UTF8String][0] != '/') {
				//if (![item hasPrefix:@"/"] && ![item hasSuffix:@"/"]) {
				if ([link hasSuffix:@".zip"]) {
					link = [link substringToIndex: ([link length] - 4)];
					[files addObject: link];
					//DLog(@"\nfound a file: %@", item);
				}
			}
		}
		dataString = nil;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	[pool release];
}

- (void)retrieveRemoteIndexList {
	if(viewForHUD) {
		MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:viewForHUD];
		[viewForHUD addSubview:HUD];
		
		// Regiser for HUD callbacks so we can remove it from the window at the right time
		HUD.delegate = self;
		HUD.dimBackground = YES;
		HUD.labelText = NSLocalizedString(@"SearchDownloaderTitle", @"");
		
		// Show the HUD while the provided method executes in a new thread
		[HUD showWhileExecuting:@selector(_retrieveRemoteIndexList) onTarget:self withObject:nil animated:YES];
	} else {
		[self _retrieveRemoteIndexList];
		if(self.files) {
			[self checkForRemoteIndex];
		} else {
			[delegate indexInstalled:YES];
		}
	}
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
	[hud release];
	hud = nil;
	// if we were updating, now show the appropriate dialogue
	if(self.files) {
		[self checkForRemoteIndex];
	}
	// else if we were installing, now finish up.
	else {
		[delegate indexInstalled:YES];
	}
}

- (void)checkForRemoteIndex {
	
	if(self.files) {
		SwordModule *modToInstall = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
		if(modToInstall) {
			NSString *v = [modToInstall configEntryForKey:SWMOD_CONFENTRY_VERSION];
			if(v == nil)
				v = @"0.0";//if there's no version information, it's version 0.0!
			NSString *indexName = [NSString stringWithFormat: @"%@-%@", [modToInstall name], v];
			if([files containsObject: indexName]) {
				DLog(@"\ndownloadable index for: %@", [modToInstall name]);
				UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"InstallTitle", @"Install?") message: NSLocalizedString(@"IndexControllerConfirmQuestion", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
				[alertView show];
				[alertView release];
				self.files = nil;
				return;
			} else {
				DLog(@"\nno available index for: %@", [modToInstall name]);
			}
		}
	}
	self.files = nil;

	NSString *msg = [NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"IndexControllerNoneRemote", @"No available search index for:"), moduleToInstall];
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"NoSearchIndexTitle", @"") message: msg delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
	[alertView show];
	[alertView release];

}

// Installs the search index for the provided module.
- (void)installSearchIndexForModule {
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
	if (!mod) {
		return;
	}
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        bti = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    }
	NSString *v = [mod configEntryForKey:SWMOD_CONFENTRY_VERSION];
	if(v == nil)
		v = @"0.0";//if there's no version information, it's version 0.0!
	NSString *indexName = [NSString stringWithFormat: @"%@-%@", [mod name], v];
	
	NSString *filename = [NSString stringWithFormat: @"http://www.crosswire.org/pocketsword/indices/v1/%@.zip", indexName];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisableAutoSleep object:nil];

	if(viewForHUD) {
		installHUD = [[MBProgressHUD showHUDAddedTo:viewForHUD animated:YES] retain];
		installHUD.delegate = self;
		installHUD.labelText = NSLocalizedString(@"SearchDownloaderTitle", @"");
		installHUD.detailsLabelText = moduleToInstall;
		installHUD.dimBackground = YES;
	} else {
		installHUD = nil;
	}
	// Download the data file
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: filename] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	[[NSURLConnection alloc] initWithRequest:request delegate:self];//released when the connection either fails or finishes, below...
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    responseData = [[NSMutableData alloc] init];
	responseDataExpectedLength = [response expectedContentLength];
	responseDataCurrentLength = 0;
	installationProgress = 0.01;
	if(viewForHUD) {
		installHUD.mode = MBProgressHUDModeDeterminate;
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [responseData appendData:data];
	responseDataCurrentLength = [responseData length];
	installationProgress = (float) responseDataCurrentLength / (float) responseDataExpectedLength;
	if(viewForHUD) {
		installHUD.progress = installationProgress;
	}
	if(installationProgress >= 1.0)
		installationProgress = 0.9999;//1.0 is a reserved special value that shouldn't be set here.
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [responseData release];
    [connection release];
    // Show error message
	if(viewForHUD) {
		installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
		installHUD.mode = MBProgressHUDModeCustomView;
		[installHUD hide:YES afterDelay:2];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationEnableAutoSleep object:nil];

	ALog(@"Couldn't retrieve search index for: %@", moduleToInstall);
	installationProgress = -1.0;
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }
	if(!viewForHUD) {
		[delegate indexInstalled:YES];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [connection release];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationEnableAutoSleep object:nil];

    // Use responseData
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
	NSString *outfileDir = [mod configEntryForKey:@"AbsoluteDataPath"];

	NSString *v = [mod configEntryForKey:SWMOD_CONFENTRY_VERSION];
	if(v == nil)
		v = @"0.0";//if there's no version information, it's version 0.0!
	NSString *indexName = [NSString stringWithFormat: @"%@-%@", [mod name], v];
	
	NSString *zippedIndex = [outfileDir stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.zip", indexName]];
	NSString *cluceneDir = [outfileDir stringByAppendingPathComponent: @"lucene"];
	if (![responseData writeToFile: zippedIndex atomically: NO]) {
		ALog(@"Couldn't write file: %@", zippedIndex);
		installationProgress = -1.0;
		[responseData release];
		if(viewForHUD) {
			installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
			installHUD.mode = MBProgressHUDModeCustomView;
			[installHUD hide:YES afterDelay:2];
		} else {
			[delegate indexInstalled:YES];
		}
		return;
	}
    [responseData release];

	if(viewForHUD) {
		installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
		installHUD.mode = MBProgressHUDModeCustomView;
		[installHUD hide:YES afterDelay:2];
	}

	ZipArchive *arch = [[ZipArchive alloc] init];
	[arch UnzipOpenFile:zippedIndex];
	[arch UnzipFileTo:cluceneDir overWrite:YES];
	[arch UnzipCloseFile];
	[arch release];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:zippedIndex error:NULL];
	
	DLog(@"Index (%@) installed successfully", moduleToInstall);
	
	installationProgress = 1.0;
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }
	if(!viewForHUD) {
		[delegate indexInstalled:YES];
	}
}

- (void)dealloc {
	self.files = nil;
	self.moduleToInstall = nil;
	[super dealloc];
}

@end
