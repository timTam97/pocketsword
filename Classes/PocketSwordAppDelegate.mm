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

@synthesize window;
//@synthesize tabBarController;
@synthesize urlToOpen;

#define LOCALES_VERSION					@"loadedSWORDLocales-v2.2"
#define STRONGS_REAL_GREEK_VERSION		@"loadedBundledStrongsRealGreek-v1.4-100511"

+ (PocketSwordAppDelegate *)sharedAppDelegate {
    return (PocketSwordAppDelegate *) [UIApplication sharedApplication].delegate;
}

- (void)resetPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	PSModuleController *moduleManager = [PSModuleController defaultModuleController];
	DLog(@"\nResetting PocketSword");
	[defaults removeObjectForKey: @"reset_PocketSword"];
	[defaults removeObjectForKey: DefaultsLastRef];
	[defaults removeObjectForKey: DefaultsLastBible];
	[defaults removeObjectForKey: DefaultsLastCommentary];
	[defaults removeObjectForKey: DefaultsLastDictionary];
	[defaults removeObjectForKey: DefaultsFontNamePreference];
	[defaults removeObjectForKey: DefaultsNightModePreference];
	[defaults removeObjectForKey: DefaultsFontSizePreference];
	[defaults removeObjectForKey: DefaultsVPLPreference];
	[defaults removeObjectForKey: DefaultsRedLetterPreference];
	[defaults removeObjectForKey: DefaultsInsomniaPreference];
	[defaults removeObjectForKey: DefaultsModuleMaintainerModePreference];
	[defaults removeObjectForKey: @"bibleHistory"];
	[defaults removeObjectForKey: @"commentaryHistory"];
	[defaults removeObjectForKey: DefaultsModuleCipherKeysKey];
	[defaults removeObjectForKey: LOCALES_VERSION];
	[defaults synchronize];
	NSArray *dicts = [[[PSModuleController defaultModuleController] swordManager] modulesForType: SWMOD_CATEGORY_DICTIONARIES];
	for(SwordDictionary *dict in dicts) {
		[dict removeCache];
	}
	[moduleManager setPrimaryBible: nil];
	[moduleManager setPrimaryCommentary: nil];
	[moduleManager setPrimaryDictionary: nil];
	//[[moduleManager viewController] redisplayChapter: BibleViewPoll restore: RestoreNoPosition];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_PocketSword"]) {
		[self resetPreferences];
	}
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	PSModuleController *moduleManager = [PSModuleController defaultModuleController];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	// testing unlocking mechanism:
	//[defaults removeObjectForKey:DefaultsModuleCipherKeysKey];
	//[defaults synchronize];
	
	if([defaults boolForKey:@"reset_PocketSword"]) {
		[self resetPreferences];
	}
	
	BOOL kjv = [defaults boolForKey:@"loadedBundledKJV"];
	BOOL loadedLocales = [defaults boolForKey:LOCALES_VERSION];
	BOOL strongsAndMorph = [defaults boolForKey:@"loadedBundledStrongsAndMorph"];
	BOOL strongsRealGreek = [defaults boolForKey:STRONGS_REAL_GREEK_VERSION];

	if(!kjv) {
		[defaults synchronize];
		[moduleManager installModulesFromZip: [[NSBundle mainBundle] pathForResource:@"KJV" ofType:@"zip"] ofType: bible removeZip:NO];
		[moduleManager installModulesFromZip: [[NSBundle mainBundle] pathForResource:@"MHCC" ofType:@"zip"] ofType: commentary removeZip:NO];
		[defaults setBool: YES forKey:@"loadedBundledKJV"];
	}
	
	if(!strongsAndMorph) {
		[moduleManager installModulesFromZip:[[NSBundle mainBundle] pathForResource:@"strongsrealhebrew" ofType:@"zip"] ofType:dictionary removeZip:NO];
		[moduleManager installModulesFromZip:[[NSBundle mainBundle] pathForResource:@"Robinson" ofType:@"zip"] ofType:dictionary removeZip:NO];
		[defaults setObject:@"Robinson" forKey:DefaultsMorphGreekModule];
		[defaults setObject:@"StrongsRealGreek" forKey:DefaultsStrongsGreekModule];
		[defaults setObject:@"StrongsRealHebrew" forKey:DefaultsStrongsHebrewModule];
		[defaults setBool: YES forKey:@"loadedBundledStrongsAndMorph"];
		[defaults synchronize];
	}
	
	if(!strongsRealGreek) {
		//remove existing module, if it exists:
		if([[moduleManager swordManager] isModuleInstalled:@"StrongsRealGreek"]) {
			DLog(@"\nRemoving existing StrongsRealGreek module & updating...");
			[moduleManager removeModule:@"StrongsRealGreek"];
		} else {
			DLog(@"\nInstalling StrongsRealGreek for the first time...");
		}
		[moduleManager installModulesFromZip:[[NSBundle mainBundle] pathForResource:@"strongsrealgreek" ofType:@"zip"] ofType:dictionary removeZip:NO];
		[defaults setBool: YES forKey:STRONGS_REAL_GREEK_VERSION];
		NSString *curSGM = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsGreekModule];
		if(!curSGM || [curSGM isEqualToString: NSLocalizedString(@"None", @"None")]) {
			[[NSUserDefaults standardUserDefaults] setObject: @"StrongsRealGreek" forKey:DefaultsStrongsGreekModule];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}

	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	NSString *swLocales = [[docPath stringByAppendingPathComponent:@"unused"] stringByAppendingPathComponent: @"locales.d"];
	//"install" the l10n strings into SWORD for the current locale.
    NSString *localePath = [docPath stringByAppendingPathComponent:@"locales.d"];
	
	if(!loadedLocales) {
		NSString *localesZIP = [[NSBundle mainBundle] pathForResource:@"locales.d" ofType:@"zip"];
		DLog(@"\n\n%@\n\n", localesZIP);
		[[NSFileManager defaultManager] removeItemAtPath: swLocales error:NULL];//delete it if it already exists
		[[NSFileManager defaultManager] removeItemAtPath: localePath error: NULL];//delete the currently installed ones, too.
		
		//unzip the archive
		ZipArchive *arch = [[ZipArchive alloc] init];
		[arch UnzipOpenFile:localesZIP];
		[arch UnzipFileTo:swLocales overWrite:YES];
		[arch UnzipCloseFile];
		[arch release];
		
		[defaults setBool: YES forKey:LOCALES_VERSION];
		[defaults synchronize];
	}
	
	NSArray *availLocales = [NSLocale preferredLanguages];//the iPhone locale
	NSArray *currentlyInstalledStrings = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: localePath error: NULL];//currently installed SWORD locale
	NSString *lang = nil;//language we're going to use this time around
	NSString *loc = nil;//the SWORD loc we're going to use this time around
	BOOL haveLocale = NO;
	BOOL alreadyInstalled = NO;

	if([[availLocales objectAtIndex: 0] isEqualToString: @"en"]) {
		//do nothing if it's English.
		lang = @"en";
		alreadyInstalled = YES;
		haveLocale = YES;
	} else if(currentlyInstalledStrings && [currentlyInstalledStrings containsObject: [NSString stringWithFormat:@"%@-utf8.conf", [availLocales objectAtIndex: 0]]]) {
		//do nothing if it's the non-English locale we used last time.
		alreadyInstalled = YES;
		haveLocale = YES;
		lang = [availLocales objectAtIndex: 0];
	}

	NSArray *availStrings = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: swLocales error: NULL];
	NSEnumerator *iter = [availLocales objectEnumerator];
	while((loc = [iter nextObject]) && !haveLocale) {
		if([loc isEqualToString: @"en"]) {
			lang = loc;
			alreadyInstalled = YES;
			break;//default, do nothing.
		} else if([loc isEqualToString:@"zh-Hant"])
			loc = @"zh_Hant"; // SWORD and Apple use different names for traditional chinese...
		else if([loc isEqualToString:@"zh-Hans"])
			loc = @"zh_Hans"; // SWORD and Apple use different names for simplified chinese...
		
		if([currentlyInstalledStrings containsObject: [NSString stringWithFormat:@"%@-utf8.conf", loc]]) {
			//we do this because it could be the non-primary iPhone locale...
			alreadyInstalled = YES;
			lang = loc;
			break;
		}		
		// check if this locale is available in SWORD
		for(NSString *swLoc in availStrings) {
			//NSLog(@"loc: %@   swLoc: %@", loc, swLoc);
			if([swLoc hasPrefix: loc]) {
				haveLocale = YES;
				lang = swLoc;
				break;
			}
		}
	}
	if(!alreadyInstalled) {
		//NSLog(@"installing %@", lang);
		[[NSFileManager defaultManager] removeItemAtPath: localePath error: NULL];
		[[NSFileManager defaultManager] createDirectoryAtPath: localePath withIntermediateDirectories: NO attributes: nil error: NULL];
		if(haveLocale) {
			NSString *srcLocale = [swLocales stringByAppendingPathComponent: lang];
			NSString *dstLocale = [localePath stringByAppendingPathComponent: lang];
			[[NSFileManager defaultManager] copyItemAtPath: srcLocale toPath: dstLocale error: NULL];
			[SwordManager initLocale];
			[moduleManager reload];
		}
	} else {
		//NSLog(@"already installed %@", lang);
	}

    // Add the tab bar controller's current view as a subview of the window
    [window addSubview:tabBarController.view];
	
	NSURL *url = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
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
		return [self application:application handleOpenURL:url];
	} else {
		return YES;
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
		[viewController toggleModulesListAnimated:NO];
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
    [window release];
    [super dealloc];
	[PSLanguageCode doneWithLookupTable];
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
