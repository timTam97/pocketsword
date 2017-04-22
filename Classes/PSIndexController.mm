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
    DLog(@"Starting modally? %i", modal);
	promptForDownload = modal;
	if(!self.moduleToInstall) {
		ALog(@"Must set the module to install before starting the Index Installer!");
	}
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		return;
	}
    //DLog(@"Retrieving remote index list...");
	[self retrieveRemoteIndexList];
    DLog(@"Retrieving remote index list...done");
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

- (NSMutableArray *)_retrieveRemoteIndexList {
    if([PSModuleController checkNetworkConnection]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];

        NSString *remoteDir = @"https://www.crosswire.org/pocketsword/indices/v1/";
        
        // Get the index directory listing
        DLog(@"Making network request to %@", remoteDir);
        NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: remoteDir]
                                                 cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 10.0];
        NSData *data = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
        if (!data) {
            
            ALog(@"Couldn't list remote directory");
            self.files = nil;
            if(viewForHUD) {
                installHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
                installHUD.mode = MBProgressHUDModeCustomView;
                [installHUD hideAnimated:YES afterDelay:1];
            } else {
                [delegate indexInstalled:self];
            }
            
        } else {
            //DLog(@"Got data!");
            NSString *dataString = [[NSString alloc] initWithData: data encoding: [NSString defaultCStringEncoding]];
            //DLog(@"Data retrieved: %@", dataString);
            data = nil;

            NSMutableArray *arr = [NSMutableArray array];
            
            //DLog(@"Searching for index in list...");
            NSArray *lines = [dataString componentsSeparatedByString:@"</tr>"];
            NSString *indexName = [self generateIndexName];
            for(NSString *line in lines) {
                if([line containsString:indexName]) {
                    DLog(@"Found index for %@", indexName);
                    [arr addObject:indexName];
                    return arr;
                }
            }
        }
    }
    
    return [NSMutableArray array];
}

- (void)retrieveRemoteIndexList {
	if(viewForHUD) {
		installHUD = [[MBProgressHUD alloc] initWithView:viewForHUD];
		[viewForHUD addSubview:installHUD];
		installHUD.delegate = self;
		installHUD.removeFromSuperViewOnHide = YES;
		installHUD.dimBackground = YES;
		installHUD.label.text = NSLocalizedString(@"SearchDownloaderTitle", @"");
		[installHUD showAnimated:YES];
	}
	
	self.files = [self _retrieveRemoteIndexList];
	
	if(viewForHUD) {
		[installHUD hideAnimated:YES];
	} else {
		if(self.files) {
			DLog(@"Checking for remote index...");
			[self checkForRemoteIndex];
			DLog(@"Checking for remote index...done");
		} else {
			[delegate indexInstalled:self];
		}
	}
	
}

- (NSString *)generateIndexName {
    SwordModule *modToInstall = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
    if(modToInstall) {
        NSString *v = [modToInstall configEntryForKey:SWMOD_CONFENTRY_VERSION];
        if(v == nil) v = @"0.0";//if there's no version information, it's version 0.0!
        
        NSString *indexName = [NSString stringWithFormat: @"%@-%@", [modToInstall name], v];
        return indexName;
    }
    return @"";
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
//	[hud removeFromSuperview];
//	[hud release];
//	hud = nil;
	DLog(@"hudWasHidden: %@", hud.label.text);
	if(removingHUDViewInProgress) {
		removingHUDViewInProgress = NO;
		return;
	}
	// if we were updating, now show the appropriate dialogue
	if(self.files) {
        DLog(@"Checking for remote index...");
		[self checkForRemoteIndex];
        DLog(@"Checking for remote index...done");
	}
	// else if we were installing, now finish up.
	else {
		[delegate indexInstalled:self];
	}
}

- (void)checkForRemoteIndex {
    
	if(self.files) {
        DLog(@"Have %lu files.", (unsigned long)[self.files count]);
		SwordModule *modToInstall = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
		if(modToInstall) {
			NSString *indexName = [self generateIndexName];
            DLog(@"IndexName: %@", indexName);
			if([files containsObject: indexName]) {
				DLog(@"\ndownloadable index for: %@", [modToInstall name]);
				if(promptForDownload) {
					dispatch_async(dispatch_get_main_queue(), ^{
						UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: [modToInstall name] message: NSLocalizedString(@"IndexControllerConfirmQuestion", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
						[alertView show];
					});
					self.files = nil;
					return;
				} else {
                    DLog(@"Installing search index for module.");
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

}

// Installs the search index for the provided module.
- (void)installSearchIndexForModule {
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
	if (!mod) {
		return;
	}
    DLog(@"Installing search index for module: %@", [mod name]);
    
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    DLog(@"Background task supported: %i", backgroundSupported);
    if(backgroundSupported) {
        bti = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
    }
    NSString *indexName = [self generateIndexName];
    DLog(@"Index name: %@", indexName);
	
	NSString *filename = [NSString stringWithFormat: @"https://www.crosswire.org/pocketsword/indices/v1/%@.zip", indexName];
    DLog(@"Filename: %@", filename);
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisableAutoSleep object:nil];

	if(viewForHUD) {
		installHUD = [MBProgressHUD showHUDAddedTo:viewForHUD animated:YES];
		installHUD.delegate = self;
		installHUD.removeFromSuperViewOnHide = YES;
		installHUD.label.text = NSLocalizedString(@"SearchDownloaderTitle", @"");
		installHUD.detailsLabel.text = moduleToInstall;
		installHUD.dimBackground = YES;
	} else {
		installHUD = nil;
	}
	// Download the data file
    DLog(@"Start downloading index file...");
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: filename] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];//released when the connection either fails or finishes, below...
	if(!conn) {
		ALog(@"Cannot download index: %@", filename);
	}
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
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationEnableAutoSleep object:nil];

	ALog(@"Couldn't retrieve search index for: %@", moduleToInstall);
	installationProgress = -1.0;
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    DLog(@"Background task supported: %i", backgroundSupported);
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }
    // Show error message
	if(viewForHUD) {
		installHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
		installHUD.mode = MBProgressHUDModeCustomView;
		[installHUD hideAnimated:YES afterDelay:1];
	} else {
		UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
		MBProgressHUD *finishedHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
		finishedHUD.delegate = self;
		finishedHUD.removeFromSuperViewOnHide = YES;
		finishedHUD.label.text = NSLocalizedString(@"SearchDownloaderTitle", @"");
		finishedHUD.detailsLabel.text = moduleToInstall;
		finishedHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
		finishedHUD.mode = MBProgressHUDModeCustomView;
		[viewToUse addSubview:finishedHUD];
		[finishedHUD showAnimated:YES];
		[finishedHUD hideAnimated:YES afterDelay:1];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationEnableAutoSleep object:nil];

    DLog(@"Index file finished downloading.");
    
    // Use responseData
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleToInstall];
	NSString *outfileDir = [mod configEntryForKey:@"AbsoluteDataPath"];

    NSString *indexName = [self generateIndexName];
    DLog(@"Index name: %@", indexName);
	
	NSString *zippedIndex = [outfileDir stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.zip", indexName]];
	NSString *cluceneDir = [outfileDir stringByAppendingPathComponent: @"lucene"];
    DLog(@"CLucene dir: %@", cluceneDir);
	if (![responseData writeToFile: zippedIndex atomically: NO]) {
		ALog(@"Couldn't write file: %@", zippedIndex);
		installationProgress = -1.0;
		if(viewForHUD) {
			installHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
			installHUD.mode = MBProgressHUDModeCustomView;
			[installHUD hideAnimated:YES afterDelay:1];
		} else {
			UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
			MBProgressHUD *finishedHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
			finishedHUD.delegate = self;
			finishedHUD.removeFromSuperViewOnHide = YES;
			finishedHUD.label.text = NSLocalizedString(@"SearchDownloaderTitle", @"");
			finishedHUD.detailsLabel.text = moduleToInstall;
			finishedHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Cross.png"]];
			finishedHUD.mode = MBProgressHUDModeCustomView;
			[viewToUse addSubview:finishedHUD];
			[finishedHUD showAnimated:YES];
			[finishedHUD hideAnimated:YES afterDelay:1];
		}
		return;
	}

    DLog(@"Unzipping index archive...");
	ZipArchive *arch = [[ZipArchive alloc] init];
	[arch UnzipOpenFile:zippedIndex];
    DLog(@"Unzipping to folder: %@", cluceneDir);
	[arch UnzipFileTo:cluceneDir overWrite:YES];
	[arch UnzipCloseFile];
    DLog(@"Unzipping index archive...done");
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:zippedIndex error:NULL];
	
	DLog(@"Index (%@) installed successfully", moduleToInstall);
	
	installationProgress = 1.0;
    UIDevice* device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    DLog(@"Background task supported: %i", backgroundSupported);
    if(backgroundSupported) {
        [[UIApplication sharedApplication] endBackgroundTask:bti];
        bti = UIBackgroundTaskInvalid;
    }
	if(viewForHUD) {
		installHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]];
		installHUD.mode = MBProgressHUDModeCustomView;
		[installHUD hideAnimated:YES afterDelay:1];
	} else {
		UIView *viewToUse = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
		MBProgressHUD *finishedHUD = [[MBProgressHUD alloc] initWithView:viewToUse];
		finishedHUD.delegate = self;
		finishedHUD.removeFromSuperViewOnHide = YES;
		finishedHUD.label.text = NSLocalizedString(@"SearchDownloaderTitle", @"");
		finishedHUD.detailsLabel.text = moduleToInstall;
		finishedHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]];
		finishedHUD.mode = MBProgressHUDModeCustomView;
		[viewToUse addSubview:finishedHUD];
		[finishedHUD showAnimated:YES];
		[finishedHUD hideAnimated:YES afterDelay:1];
	}
	
}


@end
