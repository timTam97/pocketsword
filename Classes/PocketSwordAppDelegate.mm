/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2010 CrossWire Bible Society

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "PocketSwordAppDelegate.h"
#import "PocketSwordSceneDelegate.h"
#import "PocketSword-Swift.h"
#import "ZipArchive.h"
#import "SwordManager.h"
#import "SwordDictionary.h"
#import "PSTabBarControllerDelegate.h"
#import "PSBibleViewController.h"
#import "PSCommentaryViewController.h"
//#import "TestFlight.h"

@implementation PocketSwordAppDelegate

@synthesize urlToOpen, tabBarControllerDelegate;

+ (PocketSwordAppDelegate *)sharedAppDelegate {
    return (PocketSwordAppDelegate *) [UIApplication sharedApplication].delegate;
}

- (void)storeDidChange:(NSNotification *)notification {
	// We get more information from the notification, by using:
    //  NSUbiquitousKeyValueStoreChangeReasonKey or NSUbiquitousKeyValueStoreChangedKeysKey constants
    // against the notification's useInfo.
	//
    NSDictionary *userInfo = [notification userInfo];
    // get the reason (initial download, external change or quota violation change)
    
    NSNumber* reasonForChange = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey];
    if (reasonForChange) {
        // reason was deduced, go ahead and check for the change
        //
        NSInteger reason = [[userInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey] integerValue];
        if (reason == NSUbiquitousKeyValueStoreServerChange ||
			// the value changed from the remote server
            reason == NSUbiquitousKeyValueStoreInitialSyncChange) {
			// initial syncs happen the first time the device is synced
			
			BOOL initialSync = NO;
			if(reason == NSUbiquitousKeyValueStoreInitialSyncChange) {
				initialSync = YES;
			}

            NSArray *changedKeys = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangedKeysKey];
            
            // in case you have more than one key,
            // loop through and check for the one we want (PSHistoryName)
            //
            for (NSString *changedKey in changedKeys) {
                if ([changedKey isEqualToString:PSHistoryName]) {
					
					[PSHistoryController synchronizeHistoryItemsFromCloud:initialSync];
					
                }
            }
        }
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	Class cls = NSClassFromString(@"NSUbiquitousKeyValueStore");
	if(cls && NSUbiquitousKeyValueStoreDidChangeExternallyNotification) {
		// register to observe notifications from the store
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(storeDidChange:)
													 name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
												   object: [cls defaultStore]];
	}

	return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
	UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
	configuration.delegateClass = [PocketSwordSceneDelegate class];
	return configuration;
}

/*
 * Parse url's query portion (like key=value&name=something) into an NSDictionary
 */
- (NSDictionary *)parseQueryDictionaryFromURL:(NSURL *)url {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	if (url == nil || [url query] == nil || [[url query] length] == 0) {
		return result;
	}
		
	NSArray *pairs = [[url query] componentsSeparatedByString:@"&"];
	for (NSString *keyValueStr in pairs) {
		NSArray *keyValueArray = [keyValueStr componentsSeparatedByString:@"="];
		if ([keyValueArray count] > 1) {
			[result setObject:[keyValueArray objectAtIndex:1] forKey:[keyValueArray objectAtIndex:0]];
		}
	}
	
	return result;
}

/*
 * The URL format is as follows:
 *
 * scheme (required): "sword://"
 *
 * host (optional): an installed module
 *
 * path (required): a bible reference, for example: "John+3:16" or "John 3"
 *
 * query (optional): for example:
 *   "?type=bible" or 
 *   "?type=commentary&module=list"
 *   - type is either "bible" or "commentary".  bible is the default if not present.
 *   - module=list, then the current module will be selected, but the user 
 *       will be presented with a list of installed modules to choose from.
 *
 * Some complete example URLs are:
 * sword:///John+3:16                                (verse with no module specified)
 * sword://KJV/John+3:16                             (verse with module)
 * sword://ESV/John+3:16?type=bible                  (verse with module and fall-back type if not installed)
 * sword:///John+3:16?type=bible&module=list         (verse with list of bible modules)
 * sword:///John+3:16?type=commentary&module=list    (verse with list of commentary modules)
 */
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
    if(!url || ![[url scheme] isEqualToString:@"sword"]) {
		return NO;
	}
    
	self.urlToOpen = url;
	
	NSString *module = [url host];
	NSString *reference = [url path];
	reference = [[[reference stringByRemovingPercentEncoding] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByReplacingOccurrencesOfString:@"+" withString:@" "];

	NSString *chapter;
	NSString *verse;
	if ([reference rangeOfString:@":"].location == NSNotFound) {
		chapter = reference;
		verse = @"1";
	} else {
		NSArray *parts = [reference componentsSeparatedByString:@":"];
		chapter = [parts objectAtIndex:0];
		verse = [parts objectAtIndex:1];
	}
	
	// preserve only the first number in verse, i.e. change 28-30 into 28, or change 26,28;30 into 26
	NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
	int i = 1;
	for (; i < [verse length]; i++) {
		if (![digits characterIsMember:[verse characterAtIndex:i]]) {
			break;
		}
	}
	verse = [verse substringToIndex:i];
	
	
	NSDictionary *params = [self parseQueryDictionaryFromURL:url];
	NSString *type = [params objectForKey:@"type"];
	static NSString *LIST = @"list";
	
	BOOL isBible; // determined first by "module" if present, then fall back to "type", then default to "bible"
	if (module != nil && [module length] != 0) {
		// they requested a specific module
		SwordModule *requestedModule = [[PSModuleController defaultModuleController].swordManager moduleWithName:module];
		if (requestedModule != nil) {
			isBible = (requestedModule.type == bible);
		} else {
			// requested module is not installed or does not exist, so display the list of installed modules
			// TODO: prompting the user to install the module (if available) might be better
			module = LIST;
			isBible = (type == nil || [type isEqualToString:@"bible"]);
		}
	} else { 
		// no module requested
		isBible = (type == nil || [type isEqualToString:@"bible"]);

		NSString *moduleInQuery = [params objectForKey:@"module"];
		if (moduleInQuery != nil && [moduleInQuery isEqualToString:LIST]) {
			module = LIST;
		}
	}
	
	if (isBible) {
		if (module != nil && ![module isEqualToString:LIST]) {
			// they requested a specific module and it is available
			[[PSModuleController defaultModuleController] loadPrimaryBible:module];
			//[[NSUserDefaults standardUserDefaults] setObject: module forKey: DefaultsLastBible];
		}
		
		[tabBarControllerDelegate setShownTabTo:BibleTab];

		[[NSUserDefaults standardUserDefaults] setObject: [PSModuleController createRefString:chapter] forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
		[PSHistoryController addHistoryItem:BibleTab];
	} else {			
		if (module != nil && ![module isEqualToString:LIST]) {
			// they requested a specific module and it is available
			[[PSModuleController defaultModuleController] loadPrimaryCommentary:module];
		}
		
		[tabBarControllerDelegate setShownTabTo:CommentaryTab];

		[[NSUserDefaults standardUserDefaults] setObject: [PSModuleController createRefString:chapter] forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
		[PSHistoryController addHistoryItem:CommentaryTab];
	}
	
	if (module != nil && [module isEqualToString:LIST]) {
		[tabBarControllerDelegate toggleModulesListAnimated:NO withModule:nil fromButton:nil];
	}

	return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[[NSUserDefaults standardUserDefaults] synchronize];
	[PSLanguageCode doneWithLookupTable];
	[PSModuleController releaseDefaultModuleController];
	[SwordManager releaseDefaultManager];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	[[PSModuleController defaultModuleController] didReceiveMemoryWarning];
}

- (void)dealloc {
	[PSLanguageCode doneWithLookupTable];
}

@end

@implementation UITabBarController (PocketSword)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}
@end

@implementation UINavigationController (PocketSword)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [PSResizing supportedInterfaceOrientations];
}
@end
