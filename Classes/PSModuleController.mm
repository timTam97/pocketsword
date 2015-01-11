/*
 * PocketSword - A frontend for viewing SWORD project modules on iOS
 *
 * Copyright 2008-2012 CrossWire Bible Society – http://www.crosswire.org
 *	CrossWire Bible Society
 *	P. O. Box 2528
 *	Tempe, AZ  85280-2528
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation version 2.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 */

#import <SystemConfiguration/SystemConfiguration.h>

#import "PSModuleController.h"
#import "ZipArchive.h"
#import "PSTabBarControllerDelegate.h"
#import "SwordDictionary.h"
#import "PSResizing.h"

#import "SwordManager.h"
#import "SwordInstallManager.h"
#import "globals.h"
#import "SwordInstallSource.h"
#import "PSModuleType.h"
#import "SwordKey.h"
#import "PSRefSelectorController.h"


#include <localemgr.h>
#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>

//careful of the '%' in the string below!  needs to be '%%' if moved to be used in an appendByFormat: but is fine how it is right now (3/3/10 niccarter)
#define RUBY_CSS @"ruby\n\
{\n\
	display: inline-table;\n\
	text-align: center;\n\
	white-space: nowrap;\n\
	text-indent: 0;\n\
	margin: 0;\n\
	vertical-align: -10%;\n\
}\n\
\n\
ruby > rb, ruby > rbc\n\
{\n\
	display: table-row-group;\n\
	line-height: 110%;\n\
}\n\
\n\
ruby > rt, ruby > rbc + rtc\n\
{\n\
	display: table-header-group;\n\
	vertical-align: top;\n\
	font-size: 60%;\n\
	line-height: 40%;\n\
	letter-spacing: 0;\n\
}\n\
\n\
ruby > rbc + rtc + rtc\n\
{\n\
	display: table-footer-group;\n\
	font-size: 60%;\n\
	line-height: 40%;\n\
	letter-spacing: 0;\n\
}\n\
\n\
rbc > rb, rtc > rt\n\
{\n\
	display: table-cell;\n\
	letter-spacing: 0;\n\
}\n\
\n\
rtc > rt[rbspan] { display: table-caption; }\n\
\n\
rp { display: none; }\n"



@implementation PSModuleController

@synthesize primaryBible;
@synthesize primaryCommentary;
@synthesize primaryDictionary;
@synthesize primaryDevotional;
@synthesize swordManager;
@synthesize currentInstallSource;
@synthesize busyTimer;
@synthesize downloadQueue;


static PSModuleController *instance;
/** the singleton instance */
+ (PSModuleController *)defaultModuleController {
    if(instance == nil) {
		// unfortunately, the sword::InstallMgr won't create these directories & will silently fail if they don't exist!
		[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"] withIntermediateDirectories: YES attributes: NULL error: NULL];
		//[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_BUILTIN_MODULE_PATH stringByAppendingString: @"mods.d"] withIntermediateDirectories: YES attributes: NULL error: NULL];
		if (![[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]]) {
			ALog(@"Couldn't create mods.d");
		}
        // use default path
        instance = [[PSModuleController alloc] init];
    }
    
	return instance;
}

+ (void)releaseDefaultModuleController {
	[instance release];
	instance = nil;
}

static NSString *lastRefAvailable = @"Revelation 22";
static NSString *firstRefAvailable = @"Genesis 1";

+ (void)setFirstRefAvailable:(NSString*)first
{
	if(firstRefAvailable)
		[firstRefAvailable release];
	firstRefAvailable = first;
	[firstRefAvailable retain];
}

+ (void)setLastRefAvailable:(NSString*)last
{
	if(lastRefAvailable)
		[lastRefAvailable release];
	lastRefAvailable = last;
	[lastRefAvailable retain];
}

+ (NSString*)getFirstRefAvailable {
	return firstRefAvailable;
}

+ (NSString*)getLastRefAvailable {
	return lastRefAvailable;
}

// note: this will install all the modules contained within a supplied ZIP file.
- (void)installModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType removeZip:(BOOL)temporaryZip internalModule:(BOOL)internalModule {
	
	if(!zippedModule)
		return;
	
	// unfortunately, the sword::InstallMgr won't create these directories & will silently fail if they don't exist!
	[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"] withIntermediateDirectories: YES attributes: NULL error: NULL];
	//[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_BUILTIN_MODULE_PATH stringByAppendingString: @"mods.d"] withIntermediateDirectories: YES attributes: NULL error: NULL];
	if (![[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]]) {
		ALog(@"Couldn't create mods.d");
	}

	DLog(@"\n\n%@\n\n", zippedModule);
	//NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	NSString *outfile = [DEFAULT_MMM_PATH stringByAppendingPathComponent:@"out"];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:outfile error:NULL];

	//unzip the archive
	ZipArchive *arch = [[ZipArchive alloc] init];
	[arch UnzipOpenFile:zippedModule];
	[arch UnzipFileTo:outfile overWrite:YES];
	[arch UnzipCloseFile];
	[arch release];
	
	//install the module/s contained in the archive:
//	if(!internalModule) {
		[swordManager installModulesFromPath:outfile];
		[PSResizing addSkipBackupAttributeToItemAtPath:DEFAULT_MODULE_PATH];
//	} else {
//		SwordManager *swordBuiltInManager = [[SwordManager alloc] initWithPath:DEFAULT_BUILTIN_MODULE_PATH];
//		[swordBuiltInManager installModulesFromPath:outfile];
//		[swordBuiltInManager release];
//		swordBuiltInManager = nil;
//		
//		// make sure we're not backing up this folder, now that we're installing stuff in here...
//		[PSResizing addSkipBackupAttributeToItemAtPath:DEFAULT_BUILTIN_MODULE_PATH];
//	}
	[self reload];
		
	if(temporaryZip) {
		[fileManager removeItemAtPath:zippedModule error:NULL];
	}
	[fileManager removeItemAtPath:outfile error:NULL];
	
	if((!primaryBible && (modType == bible)) || (!primaryCommentary && (modType == commentary))) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
	}
	
}

- (SwordInstallManager *)swordInstallManager {
	if(!swordInstallManager) {
		swordInstallManager = [[[SwordInstallManager alloc] initWithPath: DEFAULT_INSTALLER_PATH createPath: YES] retain];
		
		BOOL userDisclaimer = [[NSUserDefaults standardUserDefaults] boolForKey: @"userDisclaimerAccepted"];
		if (userDisclaimer) {
			[swordInstallManager setUserDisclainerConfirmed: YES];
		}
	}
	return swordInstallManager;
}

- (id)init {
	self = [super init];
	if(self) {
		//DLog(@"[PSModuleController init]");
		installationProgress = 0.0;
		
		//migration of modules, for v1.3.0: will allow backup of modules with iTunes sync...
		if([[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH_OLD stringByAppendingString: @"mods.d"]]) {
			//need to migrate from the old to the new...
			NSString *fromPath = [DEFAULT_MODULE_PATH_OLD stringByAppendingString: @"mods.d"];
			NSString *toPath = [DEFAULT_MODULE_PATH stringByAppendingString:@"mods.d"];
			if([[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:NULL]) {
				ALog(@"moved mods.d from %@ to %@", fromPath, toPath);
			} else {
				ALog(@"failed to move mods.d folder");
			}
			fromPath = [DEFAULT_MODULE_PATH_OLD stringByAppendingString:@"modules"];
			toPath = [DEFAULT_MODULE_PATH stringByAppendingString:@"modules"];
			if([[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:NULL]) {
				DLog(@"moved modules from %@ to %@", fromPath, toPath);
			} else {
				DLog(@"failed to move modules folder");
			}
			
		}

		swordManager = [[SwordManager defaultManager] retain];
		swordInstallManager = nil;
		// set localized book names
		sword::LocaleMgr *lManager = sword::LocaleMgr::getSystemLocaleMgr();
		NSString *book = [NSString stringWithCString:lManager->translate("Genesis") encoding:NSUTF8StringEncoding];
		if(!book) {
			book = [NSString stringWithCString:lManager->translate("Genesis") encoding:NSISOLatin1StringEncoding];
		}
		[PSModuleController setFirstRefAvailable: [NSString stringWithFormat: @"%@ 1", book]];
		book = [NSString stringWithCString:lManager->translate("Revelation of John") encoding:NSUTF8StringEncoding];
		if(!book) {
			book = [NSString stringWithCString:lManager->translate("Revelation of John") encoding:NSISOLatin1StringEncoding];
		}
		book = [PSModuleController createRefString:[NSString stringWithFormat: @"%@ 22", book]];
		[PSModuleController setLastRefAvailable: book];
		
		showNetworkIndicatorCount = 0;
		disableAutoSleepCount = 0;
		self.downloadQueue = [NSMutableArray arrayWithCapacity:2];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayNetworkIndicator) name:NotificationDisplayNetworkIndicator object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideNetworkIndicator) name:NotificationHideNetworkIndicator object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enableAutoSleep) name:NotificationEnableAutoSleep object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disableAutoSleep) name:NotificationDisableAutoSleep object:nil];

		/*
		// debug code to print out all available fonts...
		NSArray *names = [UIFont familyNames];
		for(NSString *n in names) {
		 NSLog(@"%@", n);
			NSArray *fontNames = [UIFont fontNamesForFamilyName:n];
			for(NSString *nn in fontNames) {
		 NSLog(@"->		%@", nn);
			}
		}
		*/
		
		[self setPreferences];
		[self reloadLastBible];
		[self reloadLastCommentary];
	}
	return self;
}

- (void)disableAutoSleep {
	if(++disableAutoSleepCount == 1) {
		[UIApplication sharedApplication].idleTimerDisabled = YES;
	}
}

- (void)enableAutoSleep {
	if(--disableAutoSleepCount == 0) {
		BOOL insomniaMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsInsomniaPreference];
		[UIApplication sharedApplication].idleTimerDisabled = insomniaMode;//set it to obey the user pref.
	}
}

- (void)displayNetworkIndicator {
	if(++showNetworkIndicatorCount == 1) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	}
}

- (void)hideNetworkIndicator {
	if(--showNetworkIndicatorCount == 0) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}
}

- (void)setPreferences/*:(NSMutableDictionary *)prefs*/ {
	if(swordManager) {
		BOOL redLetter = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsRedLetterPreference];
		BOOL strongs = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsStrongsPreference];
		BOOL morphs = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsMorphPreference];
		BOOL greekAccents = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsGreekAccentsPreference];
		BOOL HVP = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHVPPreference];
		BOOL hebrewCantillation = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHebrewCantillationPreference];
		BOOL scriptRefs = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsScriptRefsPreference];
		BOOL footnotes = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsFootnotesPreference];
		BOOL headings = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHeadingsPreference];
		
		[swordManager setGlobalOption: SW_OPTION_SCRIPTREFS value: ((scriptRefs) ? SW_ON : SW_OFF)];
		[swordManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_HEADINGS value: ((headings) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_FOOTNOTES value: ((footnotes) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_REDLETTERWORDS value: ((redLetter) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_GREEKACCENTS value: ((greekAccents) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_HEBREWPOINTS value: ((HVP) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_HEBREWCANTILLATION value: ((hebrewCantillation) ? SW_ON : SW_OFF) ];
		
		// constants:
		[swordManager setGlobalOption: SW_OPTION_VARIANTS value: SW_OPTION_VARIANTS_PRIMARY ];//could make this an option?
		[swordManager setGlobalOption: SW_OPTION_GLOSSES value: SW_ON];
	}
	return;
}

- (BOOL)isLoaded:(NSString *)module {
	if (primaryBible && [[primaryBible name] isEqualToString:module])
		return YES;
	else if (primaryCommentary && [[primaryCommentary name] isEqualToString:module])
		return YES;
	else if (primaryDictionary && [[primaryDictionary name] isEqualToString:module])
		return YES;
	else if (primaryDevotional && [[primaryDevotional name] isEqualToString:module])
		return YES;
	
	return NO;
}

+ (NSString *)getCurrentBibleRef {
	
	NSString *lastRef = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastRef];
	if (!lastRef) {
		[[NSUserDefaults standardUserDefaults] setObject: @"Genesis 1" forKey: DefaultsLastRef];
		[[NSUserDefaults standardUserDefaults] synchronize];
		lastRef = @"Genesis 1";
	}
	return lastRef;
	
}

- (void)loadPrimaryBible:(NSString *)newText {
	primaryBible = [swordManager moduleWithName:newText];
	[[NSUserDefaults standardUserDefaults] setObject: newText forKey: DefaultsLastBible];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRefSelectorResetBooks object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
//	BOOL headings = GetBoolPrefForMod(DefaultsHeadingsPreference, newText);
//	[primaryBible setIntroductions:headings];
}

- (void)loadPrimaryCommentary:(NSString *)newText {
	primaryCommentary = [swordManager moduleWithName:newText];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryCommentary object:nil];
	[[NSUserDefaults standardUserDefaults] setObject: newText forKey: DefaultsLastCommentary];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadPrimaryDictionary:(NSString *)newText {
	if(primaryDictionary)
		[primaryDictionary releaseKeys];//release some memory
	
	if(newText) {
		primaryDictionary = (SwordDictionary *)[swordManager moduleWithName:newText];
		[[NSUserDefaults standardUserDefaults] setObject: newText forKey: DefaultsLastDictionary];
		[[NSUserDefaults standardUserDefaults] synchronize];

//		int i = ([newText length] > 8) ? 8 : [newText length];
//		//but ".." is the equiv of another char, so if length <= 9, use the full name.  eg "Swe1917Of" should display full name.
//		NSString *title = ([newText length] <= 9) ? newText : [NSString stringWithFormat:@"%@..", [newText substringToIndex:i]];
//		[dictionaryTitle setTitle: title];
	} else {
		primaryDictionary = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:DefaultsLastDictionary];
		[[NSUserDefaults standardUserDefaults] synchronize];
		//[dictionaryTitle setTitle: NSLocalizedString(@"None", @"None")];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryDictionary object:nil];
}

- (void)didReceiveMemoryWarning {
	//add things that can be released if we need to clear up some memory
	// won't be called by the OS, need to call this ourselves
	if(primaryDictionary)
		[primaryDictionary releaseKeys];//release some memory
	
}

- (void)loadPrimaryDevotional:(NSString *)newText {
	if(newText) {
		primaryDevotional = (SwordDictionary *)[swordManager moduleWithName:newText];
		[[NSUserDefaults standardUserDefaults] setObject: newText forKey: DefaultsLastDevotional];
	} else {
		primaryDevotional = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: DefaultsLastDevotional];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDevotionalChanged object:newText];
}

- (NSString *)setToNextChapter {
	NSString *ret = nil;
	NSString *cur = [PSModuleController getCurrentBibleRef];
	if(primaryBible) {
		[primaryBible setChapter: cur];
		ret = [primaryBible setToNextChapter];
		[[NSUserDefaults standardUserDefaults] setObject: @"1" forKey: DefaultsBibleVersePosition];
	}
	if(primaryCommentary && !ret) {
		[primaryCommentary setChapter: cur];
		ret = [primaryCommentary setToNextChapter];
		[[NSUserDefaults standardUserDefaults] setObject: @"1" forKey: DefaultsCommentaryVersePosition];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
	return ret;
}

- (NSString *)setToPreviousChapter {
	NSString *ret = nil;
	NSString *cur = [PSModuleController getCurrentBibleRef];
	NSInteger verse = nil;
	if(primaryBible) {
		[primaryBible setChapter: cur];
		ret = [primaryBible setToPreviousChapter];
		verse = [primaryBible getVerseMax];
		[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%ld", (long)verse] forKey: DefaultsBibleVersePosition];
	}
	if(primaryCommentary) {
		if(!ret) {
			[primaryCommentary setChapter: cur];
			ret = [primaryCommentary setToPreviousChapter];
			verse = [primaryCommentary getVerseMax];
			[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%ld", (long)verse] forKey: DefaultsCommentaryVersePosition];
		} else if(verse) {
			[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%ld", (long)verse] forKey: DefaultsCommentaryVersePosition];
		}
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
	return ret;
}

// Returns the description for a given text name.
//- (NSString *)getDescription:(NSString *)name fromSource:(SwordInstallSource *)source {
//	NSString *ret = @"";
//	if ([[source swordManager] isModuleInstalled: name]) {
//		ret = [[[source swordManager] moduleWithName: name] descr];
//	}
//	return ret;
//}

- (void)reload {
	BOOL restoreBible = NO;
	BOOL restoreCommentary = NO;
	BOOL restoreDictionary = NO;
	BOOL restoreDevotional = NO;
	//sword::SWKey loc;
	NSString *ch;
	sword::SWKey dictLoc;
	NSString *bibleName;
	NSString *commentaryName;
	NSString *dictionaryName;
	NSString *devotionalName;
	
	if (primaryBible) {
		restoreBible = YES;
		ch = [[[NSString stringWithCString: ([primaryBible swModule])->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
		//loc = ([primaryBible swModule])->getKeyText();
		bibleName = [primaryBible name];
	}
	
	if (primaryCommentary) {
		restoreCommentary = YES;
		ch = [[[NSString stringWithCString: ([primaryCommentary swModule])->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
		//loc = ([primaryCommentary swModule])->getKeyText();//doesn't matter that we may write over loc, they'll be the same.
		commentaryName = [primaryCommentary name];
	}
	
	if (primaryDictionary) {
		restoreDictionary = YES;
		dictLoc = ([primaryDictionary swModule])->getKeyText();
		dictionaryName = [primaryDictionary name];
	}
	
	if (primaryDevotional) {
		restoreDevotional = YES;
		devotionalName = [primaryDevotional name];
	}
	
	[swordManager reInit];
	[self setPreferences];
	installationProgress = 0;
	
	if (restoreBible) {
		primaryBible = [swordManager moduleWithName: bibleName];
		if (primaryBible) {
			sword::VerseKey *curKey = (sword::VerseKey*)([primaryBible swModule])->getKey();
			curKey->setText([ch cStringUsingEncoding: NSUTF8StringEncoding]);
//			BOOL headings = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsHeadingsPreference];
//			[primaryBible setIntroductions:headings];
		}
	}
	
	if (restoreCommentary) {
		primaryCommentary = [swordManager moduleWithName: commentaryName];
		if (primaryCommentary) {
			sword::VerseKey *curKey = (sword::VerseKey*)([primaryCommentary swModule])->getKey();
			curKey->setText([ch cStringUsingEncoding: NSUTF8StringEncoding]);
			//([primaryCommentary swModule])->setKey(loc);
		}
	}
	
	if (restoreDictionary) {
		primaryDictionary = (SwordDictionary *)[swordManager moduleWithName: dictionaryName];
		if (primaryDictionary)
			([primaryDictionary swModule])->setKey(dictLoc);
	}
	
	if(restoreDevotional) {
		primaryDevotional = (SwordDictionary *)[swordManager moduleWithName: devotionalName];
	}
	
//	if([[swordManager moduleNames] count] == 0) {
//		[bookmarkAddButton setEnabled:NO];
//	}
	//[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRefSelectorResetBooks object:nil];
	//refSelectorController.refSelectorBooks = nil;
}

- (PSStatusReporter*)getInstallationProgress {
	PSStatusReporter *reporter = [[self swordInstallManager] getInstallationProgress];
	if(installationProgress == -1 || installationProgress == 1) {
		reporter->overallProgress = installationProgress;
	}
	return reporter;
}

- (BOOL)installModuleWithModule:(SwordModule *)swordModule {
	return [self installModuleWithModule:swordModule fromSource:self.currentInstallSource];
	
}

- (BOOL)installModuleWithModule:(SwordModule*)swordModule fromSource:(SwordInstallSource*)swordInstallSource {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[swordInstallManager resetInstallationProgress];

	installationProgress = 0.01;
	BOOL ret = NO;

	// unfortunately, the sword::InstallMgr won't create these directories & will silently fail if they don't exist!
	[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]
							  withIntermediateDirectories: YES attributes: NULL error: NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]] != YES) {
		ALog(@"Couldn't create mods.d");
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	NSString *dataPath = [swordModule configEntryForKey: @"DataPath"];
	if ([dataPath hasPrefix: @"./"]) {
		dataPath = [dataPath substringFromIndex: 2];
	}
	dataPath = [DEFAULT_MODULE_PATH stringByAppendingString: dataPath];
	[[NSFileManager defaultManager] createDirectoryAtPath: dataPath 
							  withIntermediateDirectories: YES attributes: NULL error: NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath: dataPath] != YES) {
		ALog(@"Couldn't create DataPath (%@)", dataPath);
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	// TEMPORARY HACK FOR v1.4.2 until we do things properly!
	[PSResizing addSkipBackupAttributeToItemAtPath:[DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]];
	[PSResizing addSkipBackupAttributeToItemAtPath:[DEFAULT_MODULE_PATH stringByAppendingString: @"modules"]];


	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisableAutoSleep object:nil];
	
	int status = [[self swordInstallManager] installModule: swordModule fromSource: swordInstallSource withManager: swordManager];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationEnableAutoSleep object:nil];
	
	[self reload];
	
	if (status != 0) {
		ALog(@"Couldn't install module (%@)!\n", [swordModule name]);
		ret = NO;
	} else {
		DLog(@"Module %@ installed successfully!\n%lu modules installed.", [swordModule name], (unsigned long)[[swordManager moduleNames] count]);
		ret = YES;
	}
	if((!primaryBible && ([swordModule type] == bible)) || (!primaryCommentary && [swordModule type] == commentary)) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationResetBibleAndCommentaryView object:nil];
		//[bookmarkAddButton setEnabled:YES];
	} else if(!primaryDictionary && ([swordModule type] == dictionary) && ([swordModule cat] == undefinedCategory)) {
		//set it to the primaryDictionary.
		[self loadPrimaryDictionary:[swordModule name]];
	} else if(!primaryDevotional && ([swordModule type] == dictionary) && ([swordModule cat] == devotional)) {
		[self loadPrimaryDevotional:[swordModule name]];
	}
	
	// if we haven't defined the Strongs or Morph module of this type, make this the default module.
	if([swordModule hasFeature: @"GreekDef"]) {
		NSString *curSGM = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsGreekModule];
		if(!curSGM || [curSGM isEqualToString: NSLocalizedString(@"None", @"None")]) {
			[[NSUserDefaults standardUserDefaults] setObject: [swordModule name] forKey:DefaultsStrongsGreekModule];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
	if([swordModule hasFeature: @"HebrewDef"]) {
		NSString *curSHM = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsStrongsHebrewModule];
		if(!curSHM || [curSHM isEqualToString: NSLocalizedString(@"None", @"None")]) {
			[[NSUserDefaults standardUserDefaults] setObject: [swordModule name] forKey:DefaultsStrongsHebrewModule];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
	if([swordModule hasFeature: @"GreekParse"]) {
		NSString *curMGM = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsMorphGreekModule];
		if(!curMGM || [curMGM isEqualToString: NSLocalizedString(@"None", @"None")]) {
			[[NSUserDefaults standardUserDefaults] setObject: [swordModule name] forKey:DefaultsMorphGreekModule];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
	
	[pool release];
	
	installationProgress = 1.0;
	return ret;
}

- (BOOL)refreshCurrentInstallSource {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL success = [[self swordInstallManager] refreshInstallSource:self.currentInstallSource];
	[self.currentInstallSource resetSwordManagerLoaded];
	[pool release];
	return success;
}

//- (BOOL)installModule:(NSString *)name {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	DLog(@"[PSModuleController -installModule: %@ fromSource: %@]", name, [self.currentInstallSource caption]);
//
//	installationProgress = 0.01;
//	SwordInstallSource *sIS = self.currentInstallSource;
//	SwordModule *swordModule = nil;
//	if(!sIS) {
//		for (int i = 0; i < [[[self swordInstallManager] installSourceList] count]; i++) {
//			sIS = [[swordInstallManager installSourceList] objectAtIndex: i];
//			SwordManager *sM = [sIS swordManager];
//			swordModule = [sM moduleWithName: name];
//			if (swordModule) {
//				break;
//			}
//		}
//	} else {
//		SwordManager *sM = [sIS swordManager];
//		swordModule = [sM moduleWithName: name];
//	}
//	if (!swordModule) {
//		ALog(@"Couldn't find module (%@) to install!\n", name);
//		installationProgress = -1.0;
//		[pool release];
//		return NO;
//	}
//	
//	[pool release];
//	return [self installModuleWithModule:swordModule];
//
//}

- (BOOL)removeModule:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	DLog(@"Removing module: %@", name);
	
	// if it's a built-in module, don't automatically re-install it at next launch!
//	BOOL possibleBuiltIn = NO;
	if([name isEqualToString:@"KJV"]) {
		[userDefaults setBool:YES forKey:DefaultsKJVRemoved];
//		possibleBuiltIn = YES;
	} else if([name isEqualToString:@"MHCC"]) {
		[userDefaults setBool:YES forKey:DefaultsMHCCRemoved];
//		possibleBuiltIn = YES;
	} else if([name isEqualToString:@"StrongsRealHebrew"]) {
		[userDefaults setBool:YES forKey:DefaultsStrongsRealHebrewRemoved];
//		possibleBuiltIn = YES;
	} else if([name isEqualToString:@"StrongsRealGreek"]) {
		[userDefaults setBool:YES forKey:DefaultsStrongsRealGreekRemoved];
//		possibleBuiltIn = YES;
	} else if([name isEqualToString:@"Robinson"]) {
		[userDefaults setBool:YES forKey:DefaultsRobinsonRemoved];
//		possibleBuiltIn = YES;
	}
	
	//remove the cipherKey for the module.
//	NSMutableDictionary	*cipherKeys = [NSMutableDictionary dictionaryWithDictionary:[userDefaults objectForKey:DefaultsModuleCipherKeysKey]];
//	[cipherKeys removeObjectForKey: name];
//    [userDefaults setObject:cipherKeys forKey:DefaultsModuleCipherKeysKey];
	
	SwordModule *moduleToRemove = [swordManager moduleWithName: name];
	int stat = 1;

	NSString *primaryBibleName = nil;
	NSString *primaryCommentaryName = nil;
	NSString *primaryDictionaryName = nil;
	NSString *primaryDevotionalName = nil;
	if (primaryBible) {
		primaryBibleName = [primaryBible name];
		//loc = ([primaryBible swModule])->getKeyText();
	}
	if (primaryCommentary) {
		primaryCommentaryName = [primaryCommentary name];
		//loc = ([primaryCommentary swModule])->getKeyText();
	}
	if (primaryDictionary) {
		primaryDictionaryName = [primaryDictionary name];
	}
	if(primaryDevotional) {
		primaryDevotionalName = [primaryDevotional name];
	}
	NSUInteger numberOfBibles = [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] count];
	NSUInteger numberOfCommentaries = [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
	


	if(moduleToRemove) {
		if([[moduleToRemove typeString] isEqualToString: SWMOD_CATEGORY_DICTIONARIES]) {
			//need to remove the dictionary cache, if it exists
			[((SwordDictionary*)moduleToRemove) removeCache];
		}
//		BOOL wasBuiltIn = NO;
//		if(possibleBuiltIn) {
//			SwordManager *swordBuiltInManager = [[SwordManager alloc] initWithPath:DEFAULT_BUILTIN_MODULE_PATH];
//			if([swordBuiltInManager isModuleInstalled:name]) {
//				stat = [[self swordInstallManager] uninstallModule: moduleToRemove fromManager: swordBuiltInManager];
//				wasBuiltIn = YES;
//			}
//			[swordBuiltInManager release];
//			swordBuiltInManager = nil;
//		}
//		if(!wasBuiltIn) {
			stat = [[self swordInstallManager] uninstallModule: moduleToRemove fromManager: swordManager];
//		}
	}
	
	BOOL success = (stat == 0) ? YES : NO;
		
	if ([name isEqualToString: primaryBibleName]) {
		primaryBible = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:DefaultsLastBible];
		[[NSUserDefaults standardUserDefaults] synchronize];
		//NSString *nsLoc = [NSString stringWithCString: loc.getText() encoding: [NSString defaultCStringEncoding]];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
		//[bibleWebView loadHTMLString: [self getBibleChapter: [self getCurrentBibleRef] withExtraJS: @"startDetLocPoll();\n"] baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		//[bibleTitle setTitle: NSLocalizedString(@"None", @"None")];
	} else if ([name isEqualToString: primaryCommentaryName]) {
		primaryCommentary = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:DefaultsLastCommentary];
		[[NSUserDefaults standardUserDefaults] synchronize];
		//NSString *nsLoc = [NSString stringWithCString: loc.getText() encoding: [NSString defaultCStringEncoding]];
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
		//[commentaryWebView loadHTMLString: [self getCommentaryChapter: [self getCurrentBibleRef] withExtraJS: @"startDetLocPoll();\n"] baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
		//[commentaryTitle setTitle: NSLocalizedString(@"None", @"None")];
	} else if([name isEqualToString: primaryDictionaryName]) {
		primaryDictionary = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:DefaultsLastDictionary];
		[[NSUserDefaults standardUserDefaults] synchronize];
		//[dictionaryTitle setTitle: NSLocalizedString(@"None", @"None")];
	} else if([name isEqualToString:primaryDevotionalName]) {
		[self loadPrimaryDevotional:nil];
	}
	
	[self reload];
	
	if (numberOfBibles == 1 && primaryBible == nil) {
		//well, we now have 0, ie, none!
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
	}
	
	if (numberOfCommentaries == 1 && primaryCommentary == nil) {
		//no commentaries left...
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryCommentary object:nil];
	}
	
	if([name isEqualToString: primaryDictionaryName]) {
		if([[swordManager modulesForType:SWMOD_CATEGORY_DICTIONARIES] count] > 0) {
			//set the primaryDicitonary to the next available dictionary.
			[self loadPrimaryDictionary:[[[swordManager modulesForType:SWMOD_CATEGORY_DICTIONARIES] objectAtIndex:0] name]];
		} else {
			//
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationReloadDictionaryData object:nil];
	} else if([name isEqualToString: primaryDevotionalName]) {
		if([[swordManager modulesForType:SWMOD_CATEGORY_DAILYDEVS] count] > 0) {
			//set the primaryDevotional to the next available devo.
			[self loadPrimaryDevotional:[[[swordManager modulesForType:SWMOD_CATEGORY_DAILYDEVS] objectAtIndex:0] name]];
		} else {
			[self loadPrimaryDevotional:nil];
		}
	}
	
	// if it's the module selected for one of our lookups, need to set that to @"None"
	if([name isEqualToString: [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsMorphGreekModule]]) {
		[[NSUserDefaults standardUserDefaults] setObject: NSLocalizedString(@"None", @"None") forKey:DefaultsMorphGreekModule];
		[[NSUserDefaults standardUserDefaults] synchronize];
	} else if([name isEqualToString: [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsStrongsGreekModule]]) {
		[[NSUserDefaults standardUserDefaults] setObject: NSLocalizedString(@"None", @"None") forKey:DefaultsStrongsGreekModule];
		[[NSUserDefaults standardUserDefaults] synchronize];
	} else if([name isEqualToString: [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsStrongsHebrewModule]]) {
		[[NSUserDefaults standardUserDefaults] setObject: NSLocalizedString(@"None", @"None") forKey:DefaultsStrongsHebrewModule];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	[pool release];
	return success;
}

- (void)reloadLastBible {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastModule = [defaults stringForKey: DefaultsLastBible];
	
	if (lastModule) {
		primaryBible = [swordManager moduleWithName: lastModule];
	}
	
	if (!primaryBible && [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] count] > 0) {
		primaryBible = [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex: 0];
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: [primaryBible name] forKey: DefaultsLastBible];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRefSelectorResetBooks object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
	//refSelectorController.refSelectorBooks = nil;
}

- (void)reloadLastCommentary {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastModule = [defaults stringForKey: DefaultsLastCommentary];
	
	if (lastModule != nil) {
		primaryCommentary = [swordManager moduleWithName: lastModule];
	}
	
	if (!primaryCommentary && [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] count] > 0) {
		primaryCommentary = [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex: 0];
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: [primaryCommentary name] forKey: DefaultsLastCommentary];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryCommentary object:nil];
}

// Grabs the bible text for a given chapter (e.g. "Gen 1")
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS {
	if (!primaryBible) {
		[self reload];
		
		[self reloadLastBible];
		
		if (!primaryBible) {
			return [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil fixedWidth:YES];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
	}
	NSString *text = [primaryBible getChapter:chapter withExtraJS:extraJS];
	
	//DLog(@"\n%@", text);
	[[NSUserDefaults standardUserDefaults] setObject: [PSModuleController createRefString:chapter] forKey: DefaultsLastRef];
	[[NSUserDefaults standardUserDefaults] synchronize];
	return text;
}

// Grabs the commentary text for a given chapter (e.g. "Gen 1")
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS {
	if (!primaryCommentary) {
		[self reload];
		
		[self reloadLastCommentary];
		
		if (!primaryCommentary) {
			return [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil fixedWidth:YES];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryCommentary object:nil];
	}
	NSString *text = [primaryCommentary getChapter:chapter withExtraJS:extraJS];
	
	//DLog(@"\n%@", text);
	[[NSUserDefaults standardUserDefaults] setObject: [PSModuleController createRefString:chapter] forKey: DefaultsLastRef];
	[[NSUserDefaults standardUserDefaults] synchronize];
	return text;
}

- (void)dealloc {
	[swordInstallManager release];
	[swordManager release];
	[currentInstallSource release];
	[super dealloc];
}

+ (NSString *)createRefString:(NSString *)ref {
	return [[[[ref stringByReplacingOccurrencesOfString: @"III " withString: @"3 "] 
							   stringByReplacingOccurrencesOfString: @"II " withString: @"2 "] 
							  stringByReplacingOccurrencesOfString: @"I " withString: @"1 "] 
							 stringByReplacingOccurrencesOfString: @" of John " withString: @" "];
}

+ (NSString*)createTitleRefString:(NSString *)newTitle {
//	sword::VerseKey *vKey = (sword::VerseKey*)([[[PSModuleController defaultModuleController] primaryBible] swModule])->getKey();
//	vKey->setText([newTitle cStringUsingEncoding: NSUTF8StringEncoding]);
//	NSString *abbr = [NSString stringWithCString:vKey->getBookAbbrev() encoding:NSUTF8StringEncoding];

	NSMutableString *mutableTitle = [NSMutableString stringWithString:@""];
	NSString *titleToDisplay;
	NSRange verseRange = [newTitle rangeOfString:@" " options:NSBackwardsSearch];
	NSRange titleMask = NSRangeFromString(@"0 3");
	if(verseRange.location != NSNotFound) {//only @"PocketSword" wont' be here.
		NSString *rest = [newTitle substringToIndex: verseRange.location];//cuts off the @"3:16" part.
		NSRange spaceRange = [rest rangeOfString:@" "];
		if(spaceRange.location != NSNotFound) {//the book name contains a space.
			if(spaceRange.location == 1) {//single char, so probably a number, as in "1 Cor", so keep this
				[mutableTitle appendFormat: @"%c ", [newTitle characterAtIndex:0]];
				titleMask.location = 2;
			} else if(spaceRange.location == 2) {//double char, so probably a number followed by . as in "1. Cor", so keep this.
				[mutableTitle appendFormat: @"%c%c ", [newTitle characterAtIndex:0], [newTitle characterAtIndex:1]];
				titleMask.location = 3;
			}
		}
		[mutableTitle appendString: [newTitle substringWithRange: titleMask]];
//		[mutableTitle appendString: abbr];
		[mutableTitle appendString: [newTitle substringFromIndex: verseRange.location]];
		titleToDisplay = mutableTitle;
	} else {
		titleToDisplay = newTitle;
	}
	return titleToDisplay;
}

+ (NSString *)createInfoHTMLString:(NSString*)body usingModuleForPreferences:(NSString*)moduleName {
	return [PSModuleController createHTMLString:body usingPreferences:YES withJS:@"<script type=\"text/javascript\">\n<!--\n document.documentElement.style.webkitTouchCallout = \"none\";\n-->\n</script>" usingModuleForPreferences:moduleName fixedWidth:YES];
}

// allows you to add extra javascript into the <head> html object.
+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript usingModuleForPreferences:(NSString*)moduleName fixedWidth:(BOOL)fixedWidth
{
	NSString *fontName = PSDefaultFontName;
	NSString *fontSize = @"14";
	NSString *fontColor = @"black";
	NSString *backgroundColor = @"white";
	NSString *linkColor = @"fuchsia";
	
	NSInteger fs = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
	if(usePrefs) {
		fontName = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultsFontNamePreference];
		
		// if we're provided with a moduleName, try to use that module's prefs
		if(moduleName) {
			NSString *fn = GetStringPrefForMod(DefaultsFontNamePreference, moduleName);
			fontName = (fn) ? fn : fontName;
			NSInteger fsMod = GetIntegerPrefForMod(DefaultsFontSizePreference, moduleName);
			fs = (fsMod == 0) ? fs : fsMod;
		}
		
		if(!fontName)
			fontName = PSDefaultFontName;
		BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference];
		fs = (fs == 0) ? 14 : fs;
		fontSize = [NSString stringWithFormat:@"%ld", (long)fs];
		fontColor = (nightMode) ? @"white" : @"black";
		backgroundColor = (nightMode) ? @"black" : @"white";
	} else {
		fs = 14;
	}
	NSString *fontSizeMinusOne = [NSString stringWithFormat:@"<font style=\"font-size: %dpt;line-height: 0%%;\">", (int)(fs-2)];
	NSString *finalBody = [body stringByReplacingOccurrencesOfString:@"<font size=\"-1\">" withString:fontSizeMinusOne];
	NSString *iPadPadding = @"";
	NSString *lineHeight = @"1.4";
	//int normalPaddingStart = 3, largePaddingStart = 5;
	int smallPadding = 3, mediumPadding = 4, largePadding = 5, hugePadding = 6;// was 3, 3, 3, 5.
	int smallIndent = 3, mediumIndent = 3, largeIndent = 3, hugeIndent = 3;// was 3, 2, 1, 1
	int lgMarginLeft = 1, lgMarginRight = 0;
	NSString *lgVersePadding = @"left";
	NSString *lgVersePaddingInt = @"1.7";
	int lgVerseWidth = 1;
	if([PSResizing iPad]) {
		iPadPadding = @"padding: 10px;\n";
		lineHeight = @"1.6";
		if(fs <= 24) {
			// increase indenting!
			lgMarginLeft = 3;
			//normalPaddingStart = 5;
			//largePaddingStart = 7;
			smallPadding = mediumPadding = largePadding = 5;
			hugePadding = 7;
			smallIndent = 5;
			mediumIndent = 3;
			largeIndent = 1;
			hugeIndent = 1;
			lgVersePaddingInt = @"4";
			lgVerseWidth = 3;
		}
	}
	if(moduleName) {
		// check if module is RTL or LTR
		SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName:moduleName];
		if(mod) {
			if([mod isRTL]) {
				lgMarginRight = lgMarginLeft;
				lgMarginLeft = 0;
				lgVersePadding = @"right";
			}
		}
	}
	
	static NSString *viewportString = @"<meta name='viewport' content='width=device-width' />\n";

	NSMutableString *returnString = [NSMutableString stringWithFormat: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
									 <!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"\n\
									 \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n\
									 <html dir=\"ltr\" xmlns=\"http://www.w3.org/1999/xhtml\"\n\
									 xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n\
									 xsi:schemaLocation=\"http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd\"\n\
									 xml:lang=\"en\" >\n\
									 <head>\n\
									 %@\
									 <style type=\"text/css\">\n\
									 html { -webkit-text-size-adjust: none; /* Never autoresize text */ }\n\
									 body { color: %@; background-color: %@; font-size: %@pt; font-family: %@; line-height: %@; %@ }\n\"",
											((fixedWidth) ? viewportString: @""),
											fontColor, backgroundColor,		 fontSize,		  fontName,		   lineHeight,	iPadPadding];
	
	[returnString appendFormat:@"i.transChangeAdded { color: gray; }\n\
	 a { color: %@; /* linkColour */ text-decoration: none; }\n\
	 a.verse { font-size: 70%%; vertical-align: super; line-height: 130%%; color: %@; /* fontColour */ }\n\
	 a.x { color: gray; font-size: 70%%; vertical-align: super; line-height: 0%%; font-variant: small-caps; }\n\
	 a.n { color: gray; font-size: 70%%; vertical-align: super; line-height: 0%%; font-variant: small-caps; }\n\
	 a.strongs { color: gray; text-decoration: none; vertical-align: super; font-size: 70%%; font-style: italic; }\n\
	 a.morph { color: gray; text-decoration: none; vertical-align: super; font-size: 70%%; font-style: italic; }\n\
	 span.WordOfChrist { color: #D03030; }\n\
	 span.underline { border-bottom: 1px solid; }",
	 linkColor,
	 fontColor
	 ];
		
	[returnString appendFormat:
			@"blockquote.lg {\n\
				margin: 0.5em %dem 0.5em %dem;\n\
			}\n\
			blockquote.lg > a.verse {\n\
				position: relative;\n\
				float: %@;\n\
				%@: -%@em;\n\
				width: %dem;\n\
				text-align: center;\n\
				line-height: inherit;\n\
			}\n\
			div.indentedLineOfWidth-0 {\n\
				-webkit-padding-start: %dem;\n\
				text-indent: -%dem;\n\
			}\n\
			div.indentedLineOfWidth-2 {\n\
				-webkit-padding-start: %dem;\n\
				text-indent: -%dem;\n\
			}\n\
			div.indentedLineOfWidth-4 {\n\
				-webkit-padding-start: %dem;\n\
				text-indent: -%dem;\n\
			}\n\
			div.indentedLineOfWidth-6 {\n\
				-webkit-padding-start: %dem;\n\
				text-indent: -%dem;\n\
			}\n\
			%@\n\
			</style>\n\
			%@\n\
			<title>PocketSword</title>\n\
			</head>",
			lgMarginRight, lgMarginLeft,
			lgVersePadding, lgVersePadding, lgVersePaddingInt, lgVerseWidth,
			smallPadding, smallIndent,
			mediumPadding, mediumIndent,
			largePadding, largeIndent,
			hugePadding, hugeIndent,
			RUBY_CSS, javascript];

	 [returnString appendFormat:@"<body>\n<div>%@</div>\n</body>\n</html>",
			finalBody];
	
	return returnString;
}

+ (BOOL)checkNetworkConnection {

	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];

	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [@"www.crosswire.org" UTF8String]);
	SCNetworkReachabilityFlags flags;
	BOOL retVal = NO;
	if (SCNetworkReachabilityGetFlags(reachability, &flags))
	{
		if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
		{
			// if target host is not reachable
			retVal = NO;
			DLog(@"target host is not reachable");
		}
		else if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
		{
			// if target host is reachable and no connection is required
			//  then we'll assume (for now) that your on Wi-Fi
			retVal = YES;
			//DLog(@"Wi-Fi");
		}
		
		
		if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
			 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
		{
			// ... and the connection is on-demand (or on-traffic) if the
			//     calling application is using the CFSocketStream or higher APIs
			
			if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
			{
				// ... and no [user] intervention is needed
				retVal = YES;
				//DLog(@"Wi-Fi 2");
			}
		}
		
		if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
		{
			// ... but WWAN connections are OK if the calling application
			//     is using the CFNetwork (CFSocketStream?) APIs.
			retVal = YES;
			//DLog(@"WWAN");
		}
		
	}
	if(!retVal) {
		DLog(@"NO NETWORK AVAILABLE");
	}
	CFRelease(reachability);
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	return retVal;
}

//- (void)displayBusyIndicator
//{
//	[viewController performSelectorInBackground: @selector(displayBusyIndicator) withObject: nil];
//}

//- (void)hideBusyIndicator
//{
//	if(busyTimer) {
//		[busyTimer invalidate];
//		self.busyTimer = nil;
//	}
//	[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
	//[self performSelector:@selector(doubleClose:) withObject:nil afterDelay:1];
	//self.busyTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(doubleClose:) userInfo:nil repeats:NO];
//}

//- (void)doubleClose:(NSTimer *)theTimer
//{
//	[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
//}

+ (NSDictionary *)dataForLink:(NSURL *)aURL {
    // there are two types of links
    // our generated sword:// links and study data beginning with file://
	//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableDictionary *ret = nil;
    
    NSString *scheme = [aURL scheme];
    if([scheme isEqualToString:@"sword"] || [scheme isEqualToString:@"bible"]) {
        // in this case host is the module and path the reference
		ret = [NSMutableDictionary dictionary];
		if([aURL host])
			[ret setObject:[aURL host] forKey:ATTRTYPE_MODULE];
		else
			[ret setObject:[NSNull null] forKey:ATTRTYPE_MODULE];
        [ret setObject:[[[[aURL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByReplacingOccurrencesOfString:@"+" withString:@" "]
                forKey:ATTRTYPE_VALUE];
        [ret setObject:@"scriptRef" forKey:ATTRTYPE_TYPE];
        [ret setObject:@"showRef" forKey:ATTRTYPE_ACTION];
    } else if([scheme isEqualToString:@"file"] || [scheme isEqualToString:@"applewebdata"]) {
        // in this case
        NSString *path = [aURL path];
        NSString *query = [aURL query];
        if([[path lastPathComponent] isEqualToString:@"passagestudy.jsp"]) {
            NSArray *data = [query componentsSeparatedByString:@"&"];
            NSString *type = @"x";
            NSString *module = @"";
            NSString *passage = @"";
            NSString *value = @"1";
            NSString *action = @"";
            for(NSString *entry in data) {
                if([entry hasPrefix:@"type="]) {
                    type = [[entry componentsSeparatedByString:@"="] objectAtIndex:1];
					//NSLog(@"type = %@", type);
                } else if([entry hasPrefix:@"module="]) {
                    module = [[entry componentsSeparatedByString:@"="] objectAtIndex:1];
					//NSLog(@"module = %@", module);
                } else if([entry hasPrefix:@"passage="]) {
                    passage = [[entry componentsSeparatedByString:@"="] objectAtIndex:1];
					//NSLog(@"passage = %@", passage);
                } else if([entry hasPrefix:@"action="]) {
                    action = [[entry componentsSeparatedByString:@"="] objectAtIndex:1];
					//NSLog(@"action = %@", action);
                } else if([entry hasPrefix:@"value="]) {
                    value = [[entry componentsSeparatedByString:@"="] objectAtIndex:1];
					//NSLog(@"value = %@", value);
                } else {
                    ALog(@"[ExtTextViewController -dataForLink:] unknown parameter: %@\n", entry);
                }
            }
            ret = [NSMutableDictionary dictionary];
            [ret setObject:module forKey:ATTRTYPE_MODULE];
            [ret setObject:passage forKey:ATTRTYPE_PASSAGE];
            [ret setObject:value forKey:ATTRTYPE_VALUE];
            [ret setObject:action forKey:ATTRTYPE_ACTION];
            [ret setObject:type forKey:ATTRTYPE_TYPE];
        }
    }
    
	//[pool release];
    return ret;
}

+ (BOOL)isModuleDownloading:(NSString*)moduleName {
	PSModuleController *mController = [PSModuleController defaultModuleController];
	for(PSModuleDownloadItem *dItem in mController.downloadQueue) {
		if([dItem.moduleName isEqualToString:moduleName]) {
			return YES;
		}
	}
	
	return NO;
}

+ (void)removeViewForHUDForModuleDownloadItem:(NSString*)moduleName {
	PSModuleController *mController = [PSModuleController defaultModuleController];
	for(PSModuleDownloadItem *dItem in mController.downloadQueue) {
		if([dItem.moduleName isEqualToString:moduleName]) {
			[dItem removeViewForHUD];
		}
	}
}

+ (void)queueModuleDownloadItem:(PSModuleDownloadItem*)downloadItem {
	DLog(@"queueing a new download item: %@", [downloadItem moduleName]);
	PSModuleController *mController = [PSModuleController defaultModuleController];
	downloadItem.delegate = mController;
	[mController.downloadQueue addObject:downloadItem];
	[mController tryDownloading];
}

// returns NO if there are no tasks left.
- (BOOL)tryDownloading {
	DLog(@"tryDownloading called: count is %d", [self.downloadQueue count]);
	if([self.downloadQueue count] > 0) {
		[(PSModuleDownloadItem*)[self.downloadQueue objectAtIndex:0] startInstall];
		return YES;
	}
	return NO;
}

- (void)moduleDownloaded:(PSModuleDownloadItem*)sender {
	DLog(@"dItem finished with: %@", [sender moduleName]);
	[self.downloadQueue removeObject:sender];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationModulesChanged object:nil];
	[self tryDownloading];
}

@end
