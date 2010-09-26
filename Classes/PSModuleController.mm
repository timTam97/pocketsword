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

#import <SystemConfiguration/SystemConfiguration.h>

#import "PSModuleController.h"
#import "ZipArchive.h"
#import "ViewController.h"
#import "SwordDictionary.h"

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
//@synthesize swordInstallManager;
@synthesize swordManager;
@synthesize currentInstallSource;
@synthesize busyTimer;

float installationProgress;

static PSModuleController *instance;
/** the singleton instance */
+ (PSModuleController *)defaultModuleController {
    if(instance == nil) {
		// unfortunately, the sword::InstallMgr won't create these directories & will silently fail if they don't exist!
		[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"] withIntermediateDirectories: YES attributes: NULL error: NULL];
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

// note: this will install all the modules contained within a supplied ZIP file.
- (void)installModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType removeZip:(BOOL)temporaryZip {
	
	if(!zippedModule)
		return;
	
	// unfortunately, the sword::InstallMgr won't create these directories & will silently fail if they don't exist!
	[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"] withIntermediateDirectories: YES attributes: NULL error: NULL];
	if (![[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]]) {
		ALog(@"Couldn't create mods.d");
	}

	DLog(@"\n\n%@\n\n", zippedModule);
	NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	NSString *outfile = [root stringByAppendingPathComponent:@"out"];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:outfile error:NULL];

	//unzip the archive
	ZipArchive *arch = [[ZipArchive alloc] init];
	[arch UnzipOpenFile:zippedModule];
	[arch UnzipFileTo:outfile overWrite:YES];
	[arch UnzipCloseFile];
	[arch release];
	
	//install the module/s contained in the archive:
	[swordManager installModulesFromPath:outfile];
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
		DLog(@"[PSModuleController init]");
		installationProgress = 0.0;
		
		//migration of modules, for v1.3.0: will allow backup of modules with iTunes sync...
		if([[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH_OLD stringByAppendingString: @"mods.d"]]) {
			//need to migrate from the old to the new...
			NSString *fromPath = [DEFAULT_MODULE_PATH_OLD stringByAppendingString: @"mods.d"];
			NSString *toPath = [DEFAULT_MODULE_PATH stringByAppendingString:@"mods.d"];
			if([[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:NULL]) {
				DLog(@"moved mods.d from %@ to %@", fromPath, toPath);
			} else {
				DLog(@"failed to move mods.d folder");
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
		[ViewController setFirstRefAvailable: [NSString stringWithFormat: @"%@ 1", book]];
		book = [NSString stringWithCString:lManager->translate("Revelation of John") encoding:NSUTF8StringEncoding];
		if(!book) {
			book = [NSString stringWithCString:lManager->translate("Revelation of John") encoding:NSISOLatin1StringEncoding];
		}
		[ViewController setLastRefAvailable: [NSString stringWithFormat: @"%@ 22", book]];
		
		
		// This seems to sometimes cause a crash on start-up in the SWORD-lib code.  removing this line fixes it...
		//[self performSelectorInBackground: @selector(readSwordInstallSourceModuleConfigFiles) withObject: nil];
		
		/*
		// debug code to print out all available fonts...
		NSArray *names = [UIFont familyNames];
		for(NSString *n in names) {
		 //NSLog(@"%@", n);
			NSArray *fontNames = [UIFont fontNamesForFamilyName:n];
			for(NSString *nn in fontNames) {
		 //NSLog(@"->		%@", nn);
			}
		}
		
		 */
		
		[self setPreferences];
		[self reloadLastBible];
		[self reloadLastCommentary];
	}
	return self;
}

// This method was written to speed up access of the downloads tab.
//  However, this often causes a crash when there are more than one Install Sources, so it shouldn't be used!
//- (void)readSwordInstallSourceModuleConfigFiles {
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	NSArray *sourceList = [swordInstallManager installSourceList];
//	for (SwordInstallSource *source in sourceList) {
//		[source swordManager];
//	}
//	[pool release];
//}

- (void)setPreferences/*:(NSMutableDictionary *)prefs*/ {
	if(swordManager) {
		BOOL redLetter = [[NSUserDefaults standardUserDefaults] boolForKey:@"redLetterPreference"];
		BOOL strongs = [[NSUserDefaults standardUserDefaults] boolForKey:@"strongsPreference"];
		BOOL morphs = [[NSUserDefaults standardUserDefaults] boolForKey:@"morphPreference"];
		BOOL greekAccents = [[NSUserDefaults standardUserDefaults] boolForKey:@"greekAccentsPreference"];
		BOOL HVP = [[NSUserDefaults standardUserDefaults] boolForKey:@"hvpPreference"];
		BOOL hebrewCantillation = [[NSUserDefaults standardUserDefaults] boolForKey:@"hebrewCantillationPreference"];
		BOOL scriptRefs = [[NSUserDefaults standardUserDefaults] boolForKey:@"scriptRefsPreference"];
		BOOL footnotes = [[NSUserDefaults standardUserDefaults] boolForKey:@"footnotesPreference"];
		BOOL headings = [[NSUserDefaults standardUserDefaults] boolForKey:@"headingsPreference"];
		
		[swordManager setGlobalOption: SW_OPTION_SCRIPTREFS value: ((scriptRefs) ? SW_ON : SW_OFF)];
		[swordManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_HEADINGS value: ((headings) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_FOOTNOTES value: ((footnotes) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: @"OSIS Ruby" value: SW_ON];		
		[swordManager setGlobalOption: SW_OPTION_REDLETTERWORDS value: ((redLetter) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_VARIANTS value: SW_OPTION_VARIANTS_PRIMARY ];//could make this an option?
		[swordManager setGlobalOption: SW_OPTION_GREEKACCENTS value: ((greekAccents) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_HEBREWPOINTS value: ((HVP) ? SW_ON : SW_OFF) ];
		[swordManager setGlobalOption: SW_OPTION_HEBREWCANTILLATION value: ((hebrewCantillation) ? SW_ON : SW_OFF) ];
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
	
//	NSString *ref = nil;
//	if (primaryBible)
//		ref = [[[NSString stringWithUTF8String: ([primaryBible swModule])->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
//	else if(primaryCommentary)
//		ref = [[[NSString stringWithUTF8String: ([primaryCommentary swModule])->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
//	if(ref) {
//		return [PSModuleController createRefString:ref];
//	} else {
//		return @"Genesis 1"; // hard code to return a default valid result
//	}
}

- (void)loadPrimaryBible:(NSString *)newText {
	primaryBible = [swordManager moduleWithName:newText];
	[[NSUserDefaults standardUserDefaults] setObject: newText forKey: DefaultsLastBible];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRefSelectorResetBooks object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
	//refSelectorController.refSelectorBooks = nil;
	BOOL headings = [[NSUserDefaults standardUserDefaults] boolForKey:@"headingsPreference"];
	[primaryBible setHeadings:headings];
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
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	if(primaryCommentary && !ret) {
		[primaryCommentary setChapter: cur];
		ret = [primaryCommentary setToNextChapter];
		[[NSUserDefaults standardUserDefaults] setObject: @"1" forKey: DefaultsCommentaryVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
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
		[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%d", verse] forKey: DefaultsBibleVersePosition];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	if(primaryCommentary) {
		if(!ret) {
			[primaryCommentary setChapter: cur];
			ret = [primaryCommentary setToPreviousChapter];
			verse = [primaryCommentary getVerseMax];
			[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%d", verse] forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
		} else if(verse) {
			[[NSUserDefaults standardUserDefaults] setObject: [NSString stringWithFormat:@"%d", verse] forKey: DefaultsCommentaryVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
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
			//([primaryBible swModule])->setKey(loc);
			BOOL headings = [[NSUserDefaults standardUserDefaults] boolForKey:@"headingsPreference"];
			[primaryBible setHeadings:headings];
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

- (BOOL)installModuleWithModule:(SwordModule*)swordModule {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	SwordInstallSource *sIS = self.currentInstallSource;
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

	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = YES;
	application.idleTimerDisabled = YES;//disable auto-lock while we're installing a module, as it could take a while!
	
	int status = [[self swordInstallManager] installModule: swordModule fromSource: sIS withManager: swordManager];
	
	application.networkActivityIndicatorVisible = NO;
	BOOL insomniaMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"insomniaPreference"];
	application.idleTimerDisabled = insomniaMode;//set it to obey the user pref.
	
	[self reload];
	
	if (status != 0) {
		ALog(@"Couldn't install module (%@)!\n", [swordModule name]);
		ret = NO;
	} else {
		DLog(@"Module %@ installed successfully!\n%d modules installed.", [swordModule name], [[swordManager moduleNames] count]);
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

- (BOOL)installModule:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	DLog(@"[PSModuleController -installModule: %@ fromSource: %@]", name, [self.currentInstallSource caption]);

	installationProgress = 0.01;
	SwordInstallSource *sIS = self.currentInstallSource;
	SwordModule *swordModule;
	if(!sIS) {
		for (int i = 0; i < [[[self swordInstallManager] installSourceList] count]; i++) {
			sIS = [[swordInstallManager installSourceList] objectAtIndex: i];
			SwordManager *sM = [sIS swordManager];
			swordModule = [sM moduleWithName: name];
			if (swordModule) {
				break;
			}
		}
	} else {
		SwordManager *sM = [sIS swordManager];
		swordModule = [sM moduleWithName: name];
	}
	if (!swordModule) {
		ALog(@"Couldn't find module (%@) to install!\n", name);
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	
	[pool release];
	return [self installModuleWithModule:swordModule];

}

- (BOOL)removeModule:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	DLog(@"Removing module: %@", name);
	
	//remove the cipherKey for the module.
	NSMutableDictionary	*cipherKeys = [NSMutableDictionary dictionaryWithDictionary:[userDefaults objectForKey:DefaultsModuleCipherKeysKey]];
	[cipherKeys removeObjectForKey: name];
    [userDefaults setObject:cipherKeys forKey:DefaultsModuleCipherKeysKey];
	
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
	int numberOfBibles = [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] count];
	int numberOfCommentaries = [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
	
	if([[moduleToRemove typeString] isEqualToString: SWMOD_CATEGORY_DICTIONARIES]) {
		//need to remove the dictionary cache, if it exists
		[((SwordDictionary*)moduleToRemove) removeCache];
	}


	if(moduleToRemove) {
		stat = [[self swordInstallManager] uninstallModule: moduleToRemove fromManager: swordManager];	
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
	NSString *ref = chapter;
	NSRange colonRange = [chapter rangeOfString:@":"];
	if(colonRange.location != NSNotFound) {
		ref = [chapter substringToIndex: colonRange.location];
	}
	if (!primaryBible) {
		[self reload];
		
		[self reloadLastBible];
		
		if (!primaryBible) {
			return [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] withJS:@""];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryBible object:nil];
	}
	//[primaryBible hasSearchIndex];
//	int i = ([[primaryBible name] length] > 5) ? 5 : [[primaryBible name] length];
//	NSString *title = ([[primaryBible name] length] > i) ? [NSString stringWithFormat:@"%@..", [[primaryBible name] substringToIndex:i]] : [[primaryBible name] substringToIndex:i];
//	[bibleTitle setTitle: title];
	NSString *text = [primaryBible getChapter:chapter withExtraJS:extraJS];
	
	//DLog(@"\n%@", text);
	[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: DefaultsLastRef];
	[[NSUserDefaults standardUserDefaults] synchronize];
	return text;
}

// Grabs the commentary text for a given chapter (e.g. "Gen 1")
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS {
	NSString *ref = chapter;
	NSRange colonRange = [chapter rangeOfString:@":"];
	if(colonRange.location != NSNotFound) {
		ref = [chapter substringToIndex: colonRange.location];
	}
	if (!primaryCommentary) {
		[self reload];
		
		[self reloadLastCommentary];
		
		if (!primaryCommentary) {
			return [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] withJS:@""];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewPrimaryCommentary object:nil];
	}
//	int i = ([[primaryCommentary name] length] > 5) ? 5 : [[primaryCommentary name] length];
//	NSString *title = ([[primaryCommentary name] length] > i) ? [NSString stringWithFormat:@"%@..", [[primaryCommentary name] substringToIndex:i]] : [[primaryCommentary name] substringToIndex:i];
//	[commentaryTitle setTitle: title];
	NSString *text = [primaryCommentary getChapter:chapter withExtraJS:extraJS];
	
	//DLog(@"\n%@", text);
	[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: DefaultsLastRef];
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
		[mutableTitle appendString: [newTitle substringFromIndex: verseRange.location]];
		titleToDisplay = mutableTitle;
	} else {
		titleToDisplay = newTitle;
	}
	return titleToDisplay;
}

+ (NSString *)createHTMLString:(NSString*)body withJS:(NSString*)javascript {
	return [PSModuleController createHTMLString:body usingPreferences:YES withJS:javascript];
}

// allows you to add extra javascript into the <head> html object.
+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript
{
	NSString *fontName = @"Helvetica";
	NSString *fontSize = @"14";
	NSString *fontColor = @"black";
	NSString *backgroundColor = @"white";
	NSString *linkColor = @"fuchsia";
	
	NSInteger fs = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
	if(usePrefs) {
		fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"fontNamePreference"];
		if(!fontName)
			fontName = @"Helvetica";
		BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"];
		fs = (fs == 0) ? 14 : fs;
		fontSize = [NSString stringWithFormat:@"%d", fs];
		fontColor = (nightMode) ? @"white" : @"black";
		backgroundColor = (nightMode) ? @"black" : @"white";
	} else {
		fs = 14;
	}
	NSString *fontSizeMinusOne = [NSString stringWithFormat:@"<font style=\"font-size: %dpt;line-height: 0%%;\">", (fs-2)];
	NSString *finalBody = [body stringByReplacingOccurrencesOfString:@"<font size=\"-1\">" withString:fontSizeMinusOne];

	//-webkit-user-select: none; needs to be added to the body CSS to disable copy&paste.
	
	return [NSString stringWithFormat: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
			<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"\n\
			\"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n\
			<html dir=\"ltr\" xmlns=\"http://www.w3.org/1999/xhtml\"\n\
			xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n\
			xsi:schemaLocation=\"http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd\"\n\
			xml:lang=\"en\" >\n\
			<head>\n\
			<meta name='viewport' content='width=device-width' />\n\
			<style type=\"text/css\">\n\
			body {\n\
				color: %@;\n\
				background-color: %@;\n\
				font-size: %@pt;\n\
				font-family: %@;\n\
				line-height: 130%%;\n\
			}\n\
			i.transChangeAdded {\n\
				color: gray;\n\
			}\n\
			a {\n\
				color: %@;\n\
				text-decoration: none;\n\
			}\n\
			a.verse {\n\
				font-size: 70%%;\n\
				vertical-align: super;\n\
				line-height: 0%%;\n\
				color: %@;\n\
			}\n\
			a.x {\n\
				color: gray;\n\
				font-size: small;\n\
				vertical-align: super;\n\
				line-height: 0%%;\n\
				font-variant: small-caps;\n\
			}\n\
			a.n {\n\
				color: gray;\n\
				font-size: small;\n\
				vertical-align: super;\n\
				line-height: 0%%;\n\
				font-variant: small-caps;\n\
			}\n\
			a.strongs {\n\
				color: gray;\n\
				text-decoration: none;\n\
				vertical-align: super;\n\
				font-size: 70%%;\n\
				font-style: italic;\n\
			}\n\
			a.morph {\n\
				color: gray;\n\
				text-decoration: none;\n\
				vertical-align: super;\n\
				font-size: 70%%;\n\
				font-style: italic;\n\
			}\n\
			%@\n\
			</style>\n\
			%@\n\
			<title>PocketSword</title>\n\
			</head>\n\
			<body>\n<div>%@</div>\n</body>\n</html>", 
			fontColor,
			backgroundColor, 
			fontSize,
			fontName,
			linkColor,
			fontColor,
			RUBY_CSS,
			javascript,
			finalBody];
}

+ (BOOL)checkNetworkConnection {

	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = YES;

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
	application.networkActivityIndicatorVisible = NO;
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


@end
