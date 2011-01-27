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
#import "PSLanguageCode.h"
#import "PSModuleController.h"
#import "ZipArchive.h"
#import "SwordManager.h"
#import "SwordDictionary.h"
#import "HistoryController.h"

@implementation PocketSwordAppDelegate

@synthesize window, urlToOpen, launchedWithOptions;

+ (PocketSwordAppDelegate *)sharedAppDelegate {
    return (PocketSwordAppDelegate *) [UIApplication sharedApplication].delegate;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_PocketSword"]) {
		[PSLaunchViewController resetPreferences];
	}
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	self.launchedWithOptions = launchOptions;
	
    // Add the tab bar controller's current view as a subview of the window
    //[window addSubview:tabBarController.view];
	[window addSubview:launchViewController.view];
	[launchViewController performSelectorInBackground:@selector(startInitializingPocketSword) withObject:nil];
	
	return YES;
}

- (void)finishedInitializingPocketSword {
	DLog(@"finishedInitializing, now to display the tab bar controller");
	[launchViewController.view removeFromSuperview];
    [window addSubview:tabBarController.view];
	
	if(self.launchedWithOptions) {
		NSURL *url = [launchedWithOptions objectForKey:UIApplicationLaunchOptionsURLKey];
		// uncomment these lines for testing the open url functionality
		//	url = [NSURL URLWithString:@"sword:///John+3:16"]; // verse with no module
		//	url = [NSURL URLWithString:@"sword://KJV/John+3:16"]; // verse with module (bible)
		//	url = [NSURL URLWithString:@"sword://MHCC/John+3:16"]; // verse with module (commentary)
		//	url = [NSURL URLWithString:@"sword://ABCDEF/John+3:16"]; // verse with non-existent module
		//	url = [NSURL URLWithString:@"sword://ABCDEF/John+3:16?type=commentary"]; // verse with non-existent module and type
		//	url = [NSURL URLWithString:@"sword:///John+3:16?type=bible&module=list"]; // bible list
		//	url = [NSURL URLWithString:@"sword:///John+3:16?type=commentary&module=list"]; // commentary list
		//	url = [NSURL URLWithString:@"sword:///John+3:16-18"]; // verse with range (should ignore range)	
		if (url != nil) {
			[self application:[UIApplication sharedApplication] handleOpenURL:url];
		}
		self.launchedWithOptions = nil;
	}
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
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    if(!url || ![[url scheme] isEqualToString:@"sword"]) {
		return NO;
	}
    
	self.urlToOpen = url;
	
	NSString *module = [url host];
	NSString *reference = [url path];
	reference = [[[reference stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByReplacingOccurrencesOfString:@"+" withString:@" "];

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
		
		[viewController setShownTabTo:BibleTab];

		[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddBibleHistoryItem object:nil];
		[HistoryController addHistoryItem:BibleTab];
	} else {			
		if (module != nil && ![module isEqualToString:LIST]) {
			// they requested a specific module and it is available
			[[PSModuleController defaultModuleController] loadPrimaryCommentary:module];
		}
		
		[viewController setShownTabTo:CommentaryTab];

		[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsCommentaryVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
		//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationAddCommentaryHistoryItem object:nil];
		[HistoryController addHistoryItem:CommentaryTab];
	}
	
	if (module != nil && [module isEqualToString:LIST]) {
		[viewController toggleModulesListAnimated:NO withModule:nil];
	}

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	[[NSUserDefaults standardUserDefaults] synchronize];
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
    //[tabBarController release];
	self.window = nil;
	self.urlToOpen = nil;
	self.launchedWithOptions = nil;
    //[window release];
	[PSLanguageCode doneWithLookupTable];
    [super dealloc];
}

@end

@implementation UITabBarController (PocketSword)
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}
@end

@implementation UINavigationController (PocketSword)
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}
@end
