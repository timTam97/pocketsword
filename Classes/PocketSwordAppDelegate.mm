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

@implementation PocketSwordAppDelegate

@synthesize window;
@synthesize tabBarController;
//@synthesize viewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
    
	BOOL kjv = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadedBundledKJV"];
	BOOL mhcc = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadedBundledMHCC"];
	BOOL loadedLocales = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadedSWORDLocales-v1"];
	
	if(!kjv) {
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"loadedBundledKJV"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[moduleManager loadInitialModulesFromZip: [[NSBundle mainBundle] pathForResource:@"KJV" ofType:@"zip"] ofType: bible];
	}
	if(!mhcc) {
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"loadedBundledMHCC"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[moduleManager loadInitialModulesFromZip: [[NSBundle mainBundle] pathForResource:@"MHCC" ofType:@"zip"] ofType: commentary];
	}
//	if(!loadedLocales) {
//		[[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"loadedSWORDLocales-v1"];
//		[[NSUserDefaults standardUserDefaults] synchronize];
//		NSString *localesZIP = [[NSBundle mainBundle] pathForResource:@"locales.d" ofType:@"zip"];
//		DLog(@"\n\n%@\n\n", localesZIP);
//		NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
//		NSString *outfile = [root stringByAppendingPathComponent:@"locales.d"];
//		[[NSFileManager defaultManager] removeItemAtPath:outfile error:NULL];//delete it if it already exists
//		
//		//unzip the archive
//		ZipArchive *arch = [[ZipArchive alloc] init];
//		[arch UnzipOpenFile:localesZIP];
//		[arch UnzipFileTo:outfile overWrite:YES];
//		[arch UnzipCloseFile];
//		[arch release];
//		
//		[SwordManager initLocale];
//		
//	}		
	
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

