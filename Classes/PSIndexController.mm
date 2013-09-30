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
#import "PSModuleController.h"
#import "SwordModule.h"
#import "globals.h"
#import "SwordManager.h"

@implementation PSIndexController

@synthesize files;
@synthesize delegate;
@synthesize moduleToInstall;

- (void)addViewForHUD:(UIView *)view {
	viewForHUD = view;
}

- (void)removeViewForHUD {
	if(viewForHUD) {
		removingHUDViewInProgress = YES;
		[MBProgressHUD hideAllHUDsForView:viewForHUD animated:YES];
	}
	viewForHUD = nil;
}

- (void)viewDidAppear:(BOOL)animated {
	[self start:YES];
}

- (void)start:(BOOL)modal {
	promptForDownload = modal;
	if(!self.moduleToInstall) {
		ALog(@"Must set the module to install before starting the Index Installer!");
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
	if([alertView.title isEqualToString:NSLocalizedString(@"NoSearchIndexTitle", @"")] || [alertView.title isEqualToString:NSLocalizedString(@"Error", @"")]) {
		[self.delegate indexInstalled:self];
		return;
	}
	
	if (buttonIndex == 1) {
		[self installSearchIndexForModule];
	} else {
		[self.delegate indexInstalled:self];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
		if (!data) {
			
			ALog(@"Couldn't list remote directory");
			self.files = nil;
			if(viewForHUD) {
				installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
				installHUD.mode = MBProgressHUDModeCustomView;
				[installHUD hide:YES afterDelay:1];
			} else {
				[delegate indexInstalled:self];
			}
			
		} else {
			
			NSString *dataString = [[[NSString alloc] initWithData: data encoding: [NSString defaultCStringEncoding]] autorelease];
			self.files = [NSMutableArray arrayWithObjects: nil];
			NSRange dataRange;
			
			while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
				dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
				dataRange = [dataString rangeOfString: @"\""];
				if (dataRange.location != NSNotFound) {
					NSString *link = [dataString substringToIndex: dataRange.location];
					if ([link hasSuffix:@".zip"]) {
						link = [link substringToIndex: ([link length] - 4)];
						[files addObject: link];
					}
				}
			}
			dataString = nil;
		}
	}
	
	[pool release];
}

- (void)retrieveRemoteIndexList {
	if(viewForHUD) {
		installHUD = [[[MBProgressHUD alloc] initWithView:viewForHUD] autorelease];
		[viewForHUD addSubview:installHUD];
		installHUD.delegate = self;
		installHUD.removeFromSuperViewOnHide = YES;
		installHUD.dimBackground = YES;
		installHUD.labelText = NSLocalizedString(@"SearchDownloaderTitle", @"");
		[installHUD show:YES];
	}
	
	[self _retrieveRemoteIndexList];
	
	if(viewForHUD) {
		[installHUD hide:YES];
	} else {
		if(self.files) {
			[self checkForRemoteIndex];
		} else {
			[delegate indexInstalled:self];
		}
	}
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
//	[hud removeFromSuperview];
//	[hud release];
//	hud = nil;
	if(removingHUDViewInProgress) {
		removingHUDViewInProgress = NO;
		return;
	}
	// if we were updating, now show the appropriate dialogue
	if(self.files) {
		[self checkForRemoteIndex];
	}
	// else if we were installing, now finish up.
	else {
		[delegate indexInstalled:self];
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
				if(promptForDownload) {
					UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: [modToInstall name] message: NSLocalizedString(@"IndexControllerConfirmQuestion", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
					[alertView show];
					[alertView release];
					self.files = nil;
					return;
				} else {
					self.files = nil;
					[self installSearchIndexForModule];
					return;
				}
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
		installHUD = [MBProgressHUD showHUDAddedTo:viewForHUD animated:YES];
		installHUD.delegate = self;
		installHUD.removeFromSuperViewOnHide = YES;
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
    // Show error message
	if(viewForHUD) {
		installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
		installHUD.mode = MBProgressHUDModeCustomView;
		[installHUD hide:YES afterDelay:1];
	} else {
		UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
		MBProgressHUD *finishedHUD = [[[MBProgressHUD alloc] initWithView:viewToUse] autorelease];
		finishedHUD.delegate = self;
		finishedHUD.removeFromSuperViewOnHide = YES;
		finishedHUD.labelText = NSLocalizedString(@"SearchDownloaderTitle", @"");
		finishedHUD.detailsLabelText = moduleToInstall;
		finishedHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
		finishedHUD.mode = MBProgressHUDModeCustomView;
		[viewToUse addSubview:finishedHUD];
		[finishedHUD show:YES];
		[finishedHUD hide:YES afterDelay:1];
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
			[installHUD hide:YES afterDelay:1];
		} else {
			UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
			MBProgressHUD *finishedHUD = [[[MBProgressHUD alloc] initWithView:viewToUse] autorelease];
			finishedHUD.delegate = self;
			finishedHUD.removeFromSuperViewOnHide = YES;
			finishedHUD.labelText = NSLocalizedString(@"SearchDownloaderTitle", @"");
			finishedHUD.detailsLabelText = moduleToInstall;
			finishedHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]] autorelease];
			finishedHUD.mode = MBProgressHUDModeCustomView;
			[viewToUse addSubview:finishedHUD];
			[finishedHUD show:YES];
			[finishedHUD hide:YES afterDelay:1];
		}
		return;
	}
    [responseData release];

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
	if(viewForHUD) {
		installHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
		installHUD.mode = MBProgressHUDModeCustomView;
		[installHUD hide:YES afterDelay:1];
	} else {
		UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
		MBProgressHUD *finishedHUD = [[[MBProgressHUD alloc] initWithView:viewToUse] autorelease];
		finishedHUD.delegate = self;
		finishedHUD.removeFromSuperViewOnHide = YES;
		finishedHUD.labelText = NSLocalizedString(@"SearchDownloaderTitle", @"");
		finishedHUD.detailsLabelText = moduleToInstall;
		finishedHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
		finishedHUD.mode = MBProgressHUDModeCustomView;
		[viewToUse addSubview:finishedHUD];
		[finishedHUD show:YES];
		[finishedHUD hide:YES afterDelay:1];
	}
	
}

- (void)dealloc {
	self.files = nil;
	self.moduleToInstall = nil;
	[super dealloc];
}

@end
