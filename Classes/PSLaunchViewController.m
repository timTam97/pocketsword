    //
//  PSLaunchViewController.m
//  PocketSword
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSLaunchViewController.h"
#import "globals.h"
#import "PSModuleController.h"
#import "ZipArchive.h"

#define LOCALES_VERSION					@"loadedSWORDLocales-v2.3"
#define STRONGS_REAL_GREEK_VERSION		@"loadedBundledStrongsRealGreek-v1.4-261211"

@implementation PSLaunchViewController

@synthesize delegate;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
/*
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization.
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

+ (void)resetPreferences {
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
	NSArray *moduleList = [[[PSModuleController defaultModuleController] swordManager] listModules];
	for(SwordModule *mod in moduleList) {
		[mod resetPreferences];
	}
	[moduleManager setPrimaryBible: nil];
	[moduleManager setPrimaryCommentary: nil];
	[moduleManager setPrimaryDictionary: nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	//DLog(@"running...");
    if([PSResizing iPad]) {
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
		if(UIDeviceOrientationIsLandscape(deviceOrientation)) {
			[launchImageView setImage:[UIImage imageNamed:@"Default-Landscape~ipad.png"]];
		} else {
			[launchImageView setImage:[UIImage imageNamed:@"Default-Portrait~ipad.png"]];
		}
		[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

//		UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
//		if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//			[launchImageView setImage:[UIImage imageNamed:@"Default-Landscape~ipad.png"]];
//		} else {
//			[launchImageView setImage:[UIImage imageNamed:@"Default-Portrait~ipad.png"]];
//		}
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[activityIndicator stopAnimating];
	[super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

}

- (void)startInitializingPocketSword {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	//DLog(@"start the Launch configuring...");
	PSModuleController *moduleManager = [PSModuleController defaultModuleController];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// testing unlocking mechanism:
	//[defaults removeObjectForKey:DefaultsModuleCipherKeysKey];
	//[defaults synchronize];
	
	if([defaults boolForKey:@"reset_PocketSword"]) {
		[PSLaunchViewController resetPreferences];
	}
	
	BOOL kjv = [defaults boolForKey:@"loadedBundledKJV"];
	BOOL loadedLocales = [defaults boolForKey:LOCALES_VERSION];
	BOOL strongsAndMorph = [defaults boolForKey:@"loadedBundledStrongsAndMorph"];
	BOOL strongsRealGreek = [defaults boolForKey:STRONGS_REAL_GREEK_VERSION];
	BOOL removeModulePrefs = [defaults boolForKey:@"removedModulePreferences"];
	
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
	
	if(!removeModulePrefs) {
		NSArray *moduleList = [[[PSModuleController defaultModuleController] swordManager] listModules];
		for(SwordModule *mod in moduleList) {
			[mod resetPreferences];
		}
		[defaults setBool: YES forKey:@"removedModulePreferences"];
		[defaults synchronize];
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
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: DefaultsInsomniaPreference]) {
		[UIApplication sharedApplication].idleTimerDisabled = YES;
	}

	[[NSFileManager defaultManager] removeItemAtPath: DEFAULT_MMM_PATH error:NULL];//delete our normal tmp folder...

	[(NSObject*)delegate performSelectorOnMainThread:@selector(finishedInitializingPocketSword) withObject:nil waitUntilDone:NO];
	//[delegate finishedInitializingPocketSword];
	
	[pool release];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return YES;
	//return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
