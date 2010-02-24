/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2009 Ian Wagner

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

@implementation PocketSwordAppDelegate

@synthesize window;
@synthesize tabBarController;
//@synthesize viewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL kjv = [defaults boolForKey:@"loadedBundledKJV"];
	BOOL reset = [defaults boolForKey:@"reset_PocketSword"];
	BOOL loadedLocales = [defaults boolForKey:@"loadedSWORDLocales-v1"];
	BOOL strongsAndMorph = [defaults boolForKey:@"loadedBundledStrongsAndMorph"];
	
	if(reset) {
		DLog(@"\nreset_PocketSword is set");
		[defaults removeObjectForKey: @"lastRef"];
		[defaults removeObjectForKey: @"lastBible"];
		[defaults removeObjectForKey: @"lastCommentary"];
		[defaults removeObjectForKey: @"lastDictionary"];
		[defaults removeObjectForKey: @"fontNamePreference"];
		[defaults removeObjectForKey: @"nightModePreference"];
		[defaults removeObjectForKey: @"fontSizePreference"];
		[defaults removeObjectForKey: @"vplPreference"];
		[defaults removeObjectForKey: @"redLetterPreference"];
		[defaults removeObjectForKey: @"insomniaPreference"];
		[defaults removeObjectForKey: @"moduleMaintainerModePreference"];
		[defaults removeObjectForKey: @"reset_PocketSword"];
		NSArray *dicts = [[moduleManager swordManager] modulesForType: SWMOD_CATEGORY_DICTIONARIES];
		for(SwordDictionary *dict in dicts) {
			[dict removeCache];
		}
		[moduleManager setPrimaryBible: nil];
		[moduleManager setPrimaryCommentary: nil];
		[moduleManager setPrimaryDictionary: nil];
		[viewController redisplayChapter: BibleViewPoll restore: RestoreNoPosition];
	}
	
	if(!kjv) {
		[defaults setBool: YES forKey:@"loadedBundledKJV"];
		[defaults synchronize];
		[moduleManager loadInitialModulesFromZip: [[NSBundle mainBundle] pathForResource:@"KJV" ofType:@"zip"] ofType: bible];
		[moduleManager loadInitialModulesFromZip: [[NSBundle mainBundle] pathForResource:@"MHCC" ofType:@"zip"] ofType: commentary];
	}
	
	if(!strongsAndMorph) {
		[defaults setBool: YES forKey:@"loadedBundledStrongsAndMorph"];
		[defaults synchronize];
		[moduleManager loadInitialModulesFromZip:[[NSBundle mainBundle] pathForResource:@"strongsrealgreek" ofType:@"zip"] ofType:dictionary];
		[moduleManager loadInitialModulesFromZip:[[NSBundle mainBundle] pathForResource:@"strongsrealhebrew" ofType:@"zip"] ofType:dictionary];
		[moduleManager loadInitialModulesFromZip:[[NSBundle mainBundle] pathForResource:@"Robinson" ofType:@"zip"] ofType:dictionary];
		[defaults setObject:@"Robinson" forKey:DefaultsMorphGreekModule];
		[defaults setObject:@"StrongsRealGreek" forKey:DefaultsStrongsGreekModule];
		[defaults setObject:@"StrongsRealHebrew" forKey:DefaultsStrongsHebrewModule];
	}

	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	NSString *swLocales = [[docPath stringByAppendingPathComponent:@"unused"] stringByAppendingPathComponent: @"locales.d"];
	
	if(!loadedLocales) {
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"loadedSWORDLocales-v1"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSString *localesZIP = [[NSBundle mainBundle] pathForResource:@"locales.d" ofType:@"zip"];
		DLog(@"\n\n%@\n\n", localesZIP);
		[[NSFileManager defaultManager] removeItemAtPath:swLocales error:NULL];//delete it if it already exists
		
		//unzip the archive
		ZipArchive *arch = [[ZipArchive alloc] init];
		[arch UnzipOpenFile:localesZIP];
		[arch UnzipFileTo:swLocales overWrite:YES];
		[arch UnzipCloseFile];
		[arch release];
		
		//[SwordManager initLocale];
		
	}
	
	//"install" the l10n strings into SWORD for the current locale.
    NSString *localePath = [docPath stringByAppendingPathComponent:@"locales.d"];
	
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
		} else if([loc isEqualToString:@"zh-Hant"]) {
			loc = @"zh_TW"; // SWORD and Apple use different names for traditional chinese...
		}
		
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
		DLog(@"installing %@", lang);
		[[NSFileManager defaultManager] removeItemAtPath: localePath error: NULL];
		[[NSFileManager defaultManager] createDirectoryAtPath: localePath withIntermediateDirectories: NO attributes: nil error: NULL];
		if(haveLocale) {
			NSString *srcLocale = [swLocales stringByAppendingPathComponent: lang];
			NSString *dstLocale = [localePath stringByAppendingPathComponent: lang];
			[[NSFileManager defaultManager] copyItemAtPath: srcLocale toPath: dstLocale error: NULL];
			//NSLog(@"copying from: %@", srcLocale);
			//NSLog(@"		to: %@", dstLocale);
			[SwordManager initLocale];
			[moduleManager reload];
		}
	} else {
		DLog(@"already installed %@", lang);
	}

	
	
    // Add the tab bar controller's current view as a subview of the window
    [window addSubview:tabBarController.view];
	
}

- (void)applicationWillResignActive:(UIApplication *)application {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[[NSUserDefaults standardUserDefaults] synchronize];
	[PSLanguageCode doneWithLookupTable];
}
/*
// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
}
*/

/*
// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
}
*/

- (void)dealloc {
    [tabBarController release];
    [window release];
    [super dealloc];
	[PSLanguageCode doneWithLookupTable];
}

@end

