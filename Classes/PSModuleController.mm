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

#import "PSModuleController.h"
#import "ZipArchive.h"
#import "ViewController.h"
#import "SwordDictionary.h"

#include <localemgr.h>


@implementation PSModuleController

@synthesize primaryBible;
@synthesize primaryCommentary;
@synthesize primaryDictionary;
@synthesize swordInstallManager;
@synthesize swordManager;
@synthesize currentInstallSource;

float installationProgress;

- (void)loadInitialModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType {
	
	if(!zippedModule)
		return;
	
	DLog(@"\n\n%@\n\n", zippedModule);
	NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	//NSString *file = [root stringByAppendingPathComponent:[notification object]];
	NSString *outfile = [root stringByAppendingPathComponent:@"out"];
	
	//unzip the archive
	ZipArchive *arch = [[ZipArchive alloc] init];
	[arch UnzipOpenFile:zippedModule];
	[arch UnzipFileTo:outfile overWrite:YES];
	[arch UnzipCloseFile];
	[arch release];
	
	//install the module/s contained in the archive:
	[swordManager installModulesFromPath:outfile];
	[self reload];
	
	//reload the moduleTable
	//[moduleTable reloadData];
	[viewController reloadModuleTable];

	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:zippedModule error:NULL];//this won't remove the zip file on the iPhone device.............
	[fileManager removeItemAtPath:outfile error:NULL];
	
	if((!primaryBible && (modType == bible)) || (!primaryCommentary && (modType == commentary))) {
		NSString *ref = [self getCurrentBibleRef];
		[viewController displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
		[bookmarkAddButton setEnabled:YES];
	}
	
}

- (PSModuleController *)init {
	self = [super init];
	installationProgress = 0.0;

	// unfortunately, the sword::InstallMgr won't create these directories & will silently fail if they don't exist!
	[[NSFileManager defaultManager] createDirectoryAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]
							  withIntermediateDirectories: YES attributes: NULL error: NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath: [DEFAULT_MODULE_PATH stringByAppendingString: @"mods.d"]] != YES) {
		ALog(@"Couldn't create mods.d");
	}
	swordManager = [[SwordManager defaultManager] retain];
	swordInstallManager = [[[SwordInstallManager alloc] initWithPath: DEFAULT_INSTALLER_PATH createPath: YES] retain];

	BOOL userDisclaimer = [[NSUserDefaults standardUserDefaults] boolForKey: @"userDisclaimerAccepted"];
	if (userDisclaimer) {
		[swordInstallManager setUserDisclainerConfirmed: YES];
	}
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
	
	//for debug purposes, we can enable the following line...  don't want this for the release version!
	//[swordInstallManager performSelectorInBackground:@selector(refreshMasterRemoteInstallSourceList) withObject:nil];
	
	
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
	
	return self;
}

- (ViewController *)viewController {
	return viewController;
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
		
		[swordManager setGlobalOption: SW_OPTION_SCRIPTREFS value: SW_OFF];
		[swordManager setGlobalOption: SW_OPTION_STRONGS value: SW_OFF ];
		[swordManager setGlobalOption: SW_OPTION_HEADINGS value: SW_ON ];
		[swordManager setGlobalOption: SW_OPTION_FOOTNOTES value: SW_OFF ];
		[swordManager setGlobalOption: @"OSIS Ruby" value: SW_ON];		
		if (redLetter)
			[swordManager setGlobalOption: SW_OPTION_REDLETTERWORDS value: SW_ON ];
		else
			[swordManager setGlobalOption: SW_OPTION_REDLETTERWORDS value: SW_OFF ];

		/*
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_MORPHS];
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_FOOTNOTES];
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_SCRIPTREFS];
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_REDLETTERWORDS];
		 [modDisplayOptions setObject:SW_ON  forKey:SW_OPTION_HEADINGS];
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_HEBREWPOINTS];
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_HEBREWCANTILLATION];
		 [modDisplayOptions setObject:SW_OFF forKey:SW_OPTION_GREEKACCENTS];
		*/
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
	return NO;
}

- (NSString *)getCurrentBibleRef {
	NSString *lastRef = [[NSUserDefaults standardUserDefaults] stringForKey: @"lastRef"];
	if (!lastRef) {
		[[NSUserDefaults standardUserDefaults] setObject: @"Genesis 1" forKey: @"lastRef"];
		[[NSUserDefaults standardUserDefaults] synchronize];
//		[defaults setPersistentDomain: [NSDictionary dictionaryWithObject: @"Genesis 1" forKey: @"lastRef"] forName: [[NSBundle mainBundle] bundleIdentifier]];
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
	[[NSUserDefaults standardUserDefaults] setObject: newText forKey: @"lastBible"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadPrimaryCommentary:(NSString *)newText {
	primaryCommentary = [swordManager moduleWithName:newText];
	[[NSUserDefaults standardUserDefaults] setObject: newText forKey: @"lastCommentary"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadPrimaryDictionary:(NSString *)newText {
	primaryDictionary = (SwordDictionary *)[swordManager moduleWithName:newText];
	[[NSUserDefaults standardUserDefaults] setObject: newText forKey: @"lastDictionary"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	int i = ([newText length] > 8) ? 8 : [newText length];
	NSString *title = ([newText length] > i) ? [NSString stringWithFormat:@"%@..", [newText substringToIndex:i]] : [newText substringToIndex:i];
	[dictionaryTitle setTitle: title];
//	[dictionaryDescriptionTitle setTitle: title];
}

- (NSString *)setToNextChapter {
	NSString *ret = nil;
	NSString *cur = [self getCurrentBibleRef];
	if(primaryBible) {
		[primaryBible setChapter: cur];
		ret = [primaryBible setToNextChapter];
	}
	if(primaryCommentary && !ret) {
		[primaryCommentary setChapter: cur];
		ret = [primaryCommentary setToNextChapter];
	}
	return ret;
}

- (NSString *)setToPreviousChapter {
	NSString *ret = nil;
	NSString *cur = [self getCurrentBibleRef];
	if(primaryBible) {
		[primaryBible setChapter: cur];
		ret = [primaryBible setToPreviousChapter];
	}
	if(primaryCommentary && !ret) {
		[primaryCommentary setChapter: cur];
		ret = [primaryCommentary setToPreviousChapter];
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
	//sword::SWKey loc;
	NSString *ch;
	sword::SWKey dictLoc;
	NSString *bibleName;
	NSString *commentaryName;
	NSString *dictionaryName;
	
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
	
	[swordManager reInit];
	[self setPreferences];
	installationProgress = 0;
	
	if (restoreBible) {
		primaryBible = [swordManager moduleWithName: bibleName];
		if (primaryBible) {
			sword::VerseKey *curKey = (sword::VerseKey*)([primaryBible swModule])->getKey();
			curKey->setText([ch cStringUsingEncoding: NSUTF8StringEncoding]);
			//([primaryBible swModule])->setKey(loc);
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
	
	if([[swordManager moduleNames] count] == 0) {
		[bookmarkAddButton setEnabled:NO];
	}
	[dataController updateRefSelectorBooks:YES];
}

- (PSStatusReporter*)getInstallationProgress {
	PSStatusReporter *reporter = [swordInstallManager getInstallationProgress];
	if(installationProgress == -1 || installationProgress == 1) {
		reporter->overallProgress = installationProgress;
	}
	return reporter;
}

- (BOOL)installModuleWithModule:(SwordModule*)swordModule {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	SwordInstallSource *sIS = [self currentInstallSource];
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
	
	int status = [swordInstallManager installModule: swordModule fromSource: sIS withManager: swordManager];
	
	application.networkActivityIndicatorVisible = NO;
	BOOL insomniaMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"insomniaPreference"];
	application.idleTimerDisabled = insomniaMode;//set it to obey the user pref.
	
	[self reload];
	[viewController reloadModuleTable];
	//[moduleTable reloadData];
	
	if (status != 0) {
		ALog(@"Couldn't install module (%@)!\n", [swordModule name]);
		ret = NO;
	} else {
		DLog(@"Module %@ installed successfully!\n%d modules installed.", [swordModule name], [[swordManager moduleNames] count]);
		ret = YES;
	}
	if((!primaryBible && ([swordModule type] == bible)) || (!primaryCommentary && [swordModule type] == commentary)) {
		NSString *ref = [self getCurrentBibleRef];
		[viewController displayChapter:ref withPollingType:NoViewPoll restoreType:RestoreVersePosition];
		[bookmarkAddButton setEnabled:YES];
	}
	// else if (!primaryCommentary && [swordModule type] == commentary) {
	//	NSString *ref = [self getCurrentBibleRef];
	//	if(!ref)
	//		ref = @"Genesis 1";
	//	[commentaryNavBtn setTitle: ref];
	//	[commentaryWebView loadHTMLString: [self getCommentaryChapter: ref withExtraJS: @""] baseURL: nil];
	//}
	//if ([[swordManager moduleNames] count] == 1) {
	//	[bibleNavBtn setTitle: @"Genesis 1"];
	//	//[commentaryNavBtn setTitle: @"Genesis 1"];
	//	[bibleWebView loadHTMLString: [self getBibleChapter: @"Genesis 1" withExtraJS: @""] baseURL: nil];
	//	[bookmarkAddButton setEnabled:YES];
	//}
	[pool release];
	
	installationProgress = 1.0;
	return ret;
}

- (BOOL)refreshCurrentInstallSource {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[swordInstallManager refreshInstallSource:[self currentInstallSource]];
	[[self currentInstallSource] resetSwordManagerLoaded];
	[pool release];
	return YES;
}

- (BOOL)installModule:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	DLog(@"[PSModuleController -installModule: %@ fromSource: %@]", name, [[self currentInstallSource] caption]);

	installationProgress = 0.01;
	SwordInstallSource *sIS = currentInstallSource;
	SwordModule *swordModule;
	if(!sIS) {
		for (int i = 0; i < [[swordInstallManager installSourceList] count]; i++) {
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
	SwordModule *moduleToRemove = [swordManager moduleWithName: name];
	int stat = 1;
	sword::SWKey loc;

	NSString *primaryBibleName = nil;
	NSString *primaryCommentaryName = nil;
	NSString *primaryDictionaryName = nil;
	if (primaryBible) {
		primaryBibleName = [primaryBible name];
		loc = ([primaryBible swModule])->getKeyText();
	}
	if (primaryCommentary) {
		primaryCommentaryName = [primaryCommentary name];
		loc = ([primaryCommentary swModule])->getKeyText();
	}
	if (primaryDictionary) {
		primaryDictionaryName = [primaryDictionary name];
	}
	int numberOfBibles = [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] count];
	int numberOfCommentaries = [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] count];
	
	if([[moduleToRemove typeString] isEqualToString: SWMOD_CATEGORY_DICTIONARIES]) {
		//need to remove the dictionary cache, if it exists
		[((SwordDictionary*)moduleToRemove) removeCache];
	}
	

	if(moduleToRemove) {
		stat = [swordInstallManager uninstallModule: moduleToRemove fromManager: swordManager];	
	}
	
	BOOL success = (stat == 0) ? YES : NO;
		
	if ([name isEqualToString: primaryBibleName]) {
		primaryBible = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastBible"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSString *nsLoc = [NSString stringWithCString: loc.getText() encoding: [NSString defaultCStringEncoding]];
		[bibleWebView loadHTMLString: [self getBibleChapter: nsLoc withExtraJS: @""] baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
	} else if ([name isEqualToString: primaryCommentaryName]) {
		primaryCommentary = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastCommentary"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSString *nsLoc = [NSString stringWithCString: loc.getText() encoding: [NSString defaultCStringEncoding]];
		[commentaryWebView loadHTMLString: [self getCommentaryChapter: nsLoc withExtraJS: @""] baseURL: [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
	} else if([name isEqualToString: primaryDictionaryName]) {
		primaryDictionary = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastDictionary"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}		
	
	// move these outside of this method & these are called by the caller after -removeModule is called.
	[self reload];
	//[moduleTable reloadData];
	[viewController reloadModuleTable];
	
	if (numberOfBibles == 1 && primaryBible == nil) {
		//well, we now have 0, ie, none!
		//[bibleNavBtn setTitle: @"PocketSword"];
		[viewController setTabTitle: @"PocketSword" ofTab:BibleTab];
		[bibleWebView loadHTMLString: [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] withJS:@""] baseURL: nil];
		[bookmarkAddButton setEnabled:NO];
		[viewController setEnabledBibleNextButton: NO];
		[viewController setEnabledBiblePreviousButton: NO];
	}
	
	if (numberOfCommentaries == 1 && primaryCommentary == nil) {
		//no commentaries left...
		//[commentaryNavBtn setTitle: @"PocketSword"];
		[viewController setTabTitle: @"PocketSword" ofTab:CommentaryTab];
		[commentaryWebView loadHTMLString: [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] withJS:@""] baseURL: nil];
		//[bookmarkAddButton setEnabled:NO];
		[viewController setEnabledCommentaryNextButton: NO];
		[viewController setEnabledCommentaryPreviousButton: NO];
	}
	
	if([name isEqualToString: primaryDictionaryName]) {
		[viewController reloadDictionaryData];
	}
	
	[pool release];
	return success;
}

- (void)reloadLastBible {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastModule = [defaults stringForKey: @"lastBible"];
	
	if (lastModule != nil) {
		primaryBible = [swordManager moduleWithName: lastModule];
	}
	
	if (!primaryBible && [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] count] > 0) {
		primaryBible = [[swordManager modulesForType:SWMOD_CATEGORY_BIBLES] objectAtIndex: 0];
		//[prefs removeObjectForKey: @"bookmarks"]; -- why did we used to do this here?????
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: [primaryBible name] forKey: @"lastBible"];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void)reloadLastCommentary {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastModule = [defaults stringForKey: @"lastCommentary"];
	
	if (lastModule != nil) {
		primaryCommentary = [swordManager moduleWithName: lastModule];
	}
	
	if (!primaryCommentary && [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] count] > 0) {
		primaryCommentary = [[swordManager modulesForType:SWMOD_CATEGORY_COMMENTARIES] objectAtIndex: 0];
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		[prefs setObject: [primaryCommentary name] forKey: @"lastCommentary"];
		
		[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[prefs release];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

// Grabs the bible text for a given chapter (e.g. "Gen 1")
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS {
	if (!primaryBible) {
		[self reload];
		
		[self reloadLastBible];
		
		if (!primaryBible) {
			return [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] withJS:@""];
		}
	}
	//[primaryBible hasSearchIndex];
	int i = ([[primaryBible name] length] > 5) ? 5 : [[primaryBible name] length];
	NSString *title = ([[primaryBible name] length] > i) ? [NSString stringWithFormat:@"%@..", [[primaryBible name] substringToIndex:i]] : [[primaryBible name] substringToIndex:i];
	[bibleTitle setTitle: title];
	NSString *text = [primaryBible getChapter:chapter withExtraJS:extraJS];
	
	//DLog(@"\n%@", text);
	[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: @"lastRef"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	return text;
}

// Grabs the commentary text for a given chapter (e.g. "Gen 1")
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS {
	if (!primaryCommentary) {
		[self reload];
		
		[self reloadLastCommentary];
		
		if (!primaryCommentary) {
			return [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] withJS:@""];
		}
	}
	int i = ([[primaryCommentary name] length] > 5) ? 5 : [[primaryCommentary name] length];
	NSString *title = ([[primaryCommentary name] length] > i) ? [NSString stringWithFormat:@"%@..", [[primaryCommentary name] substringToIndex:i]] : [[primaryCommentary name] substringToIndex:i];
	[commentaryTitle setTitle: title];
	NSString *text = [primaryCommentary getChapter:chapter withExtraJS:extraJS];
	
	//DLog(@"\n%@", text);
	[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: @"lastRef"];
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
	
	if(usePrefs) {
		NSInteger fs = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSizePreference"];
		fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"fontNamePreference"];
		if(!fontName)
			fontName = @"Helvetica";
		BOOL nightMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"];
		fs = (fs == 0) ? 14 : fs;
		fontSize = [NSString stringWithFormat:@"%d", fs];
		fontColor = (nightMode) ? @"white" : @"black";
		backgroundColor = (nightMode) ? @"black" : @"white";
	}
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
				//-webkit-user-select: none;\n\
			}\n\
			!P {\n\
			}\n\
			sup {\n\
				line-height: 0%%;\n\
			}\n\
			a:link {\n\
				color: %@;\n\
				text-decoration: none;\n\
			}\n\
			a:visited {\n\
				color: %@;\n\
				text-decoration: none;\n\
			}\n\
			a:active {\n\
				color: %@;\n\
				text-decoration: none;\n\
			}\n\
			%@\n\
			</style>\n\
			%@\n\
			</head>\n\
			<body><div>%@</div></body></html>", 
			fontColor,
			backgroundColor, 
			fontSize,
			fontName,
			fontColor,
			fontColor,
			fontColor,
			RUBY_CSS,
			javascript,
			body];
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
			DLog(@"Wi-Fi");
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
				DLog(@"Wi-Fi 2");
			}
		}
		
		if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
		{
			// ... but WWAN connections are OK if the calling application
			//     is using the CFNetwork (CFSocketStream?) APIs.
			retVal = YES;
			DLog(@"WWAN");
		}
		
	}
	if(!retVal) {
		DLog(@"NO NETWORK AVAILABLE");
	}
	CFRelease(reachability);
	application.networkActivityIndicatorVisible = NO;
	return retVal;
}

- (void)displayBusyIndicator
{
	[viewController performSelectorInBackground: @selector(displayBusyIndicator) withObject: nil];
}

- (void)hideBusyIndicator
{
	[viewController performSelectorInBackground: @selector(hideBusyIndicator) withObject: nil];
}

@end
