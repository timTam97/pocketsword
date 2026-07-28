/*	SwordManager.mm - Sword API wrapper for Modules.

    Copyright 2008 Manfred Bergmann
    Based on code by Will Thimbleby

	This program is free software; you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation version 2.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
	even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	General Public License for more details. (http://www.gnu.org/licenses/gpl.html)
*/
//#import <UIKit/UIKit.h>
#import "SwordManager.h"
#import "SwordManager+Cpp.h"
#import "SwordModule+Cpp.h"
#import "PocketSword-Swift.h"

#include <string>
#include <list>

#include "gbfplain.h"
#include "thmlplain.h"
#include "osisplain.h"
//#include "msstringmgr.h"
#import "globals.h"
#import "utils.h"
//#import "SwordBible.h"
//#import "SwordCommentary.h"
#import "SwordDictionary.h"
#import "SwordDictionary+Cpp.h"
//#import "SwordListKey.h"
//#import "SwordVerseKey.h"
#include <installmgr.h>
#include <versificationmgr.h>

using std::string;
using std::list;

@interface SwordManager (PrivateAPI)

- (void)refreshModules;
/// Which dictionary sub-categories the app can actually render. Consumed only by
/// -refreshModules (below) to keep glossaries / essays out of the module list, so it
/// is internal rather than part of the public facade.
+ (BOOL)moduleCategoryAllowed:(ModuleCategory)cat;

@end

@implementation SwordManager (PrivateAPI)

+ (BOOL)moduleCategoryAllowed:(ModuleCategory)cat {
	switch (cat) {
		case undefinedCategory:
			return YES;
		case glossary:
			return NO;
		case essay:
			return NO;
		case devotional:
			return YES;//beta
		default:
			return NO;
	}
}

- (void)refreshModules {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // loop over modules
    sword::SWModule *mod;
	//NSMutableArray *langs = [NSMutableArray arrayWithObjects: nil];
	for(sword::ModMap::iterator it = swManager->Modules.begin(); it != swManager->Modules.end(); it++) {
		mod = it->second;
        
        // create module instances
        NSString *type;
        //NSString *name;
		//NSString *mLang;
        if(mod->isUnicode()) {
            type = [NSString stringWithUTF8String:mod->getType()];
            //name = [NSString stringWithUTF8String:mod->Name()];
            //mLang = [NSString stringWithUTF8String:mod->Lang()];
        } else {
            type = [NSString stringWithCString:mod->getType() encoding:NSISOLatin1StringEncoding];
            //name = [NSString stringWithCString:mod->Name() encoding:NSISOLatin1StringEncoding];
            //mLang = [NSString stringWithCString:mod->Lang() encoding:NSISOLatin1StringEncoding];
        }
        
        SwordModule *sm;// = [[SwordModule alloc] initWithSWModule:mod swordManager:self];
		//we may want to incorporate this code at a later point, so I'm leaving this in here atm...
//		if([type isEqualToString:SWMOD_CATEGORY_BIBLES]) {
//            sm = [[SwordBible alloc] initWithSWModule:mod swordManager:self];
//        } else if([type isEqualToString:SWMOD_CATEGORY_COMMENTARIES]) {
//            sm = [[SwordCommentary alloc] initWithSWModule:mod swordManager:self];
        /*} else*/ if([type isEqualToString:SWMOD_CATEGORY_DICTIONARIES]) {
			//mod->AddRenderFilter(new sword::PLAINHTML());
			
            sm = [[SwordDictionary alloc] initWithSWModule:mod swordManager:self];
//        } else if([type isEqualToString:SWMOD_CATEGORY_GENBOOKS]) {
//            sm = [[SwordGenBook alloc] initWithSWModule:mod swordManager:self];
        } else {
            sm = [[SwordModule alloc] initWithSWModule:mod swordManager:self];
        }
		
		ModuleCategory cat = [sm cat];

		   // at this point I want to manually exclude "cult" texts until there is a disclaimer about them in there!
		if((cat & cult) == cult) {
			//this is a questionable/cult module & we're currently not allowing these!
		} else if([type isEqualToString:SWMOD_CATEGORY_DICTIONARIES] && ![SwordManager moduleCategoryAllowed: cat]) {
			//we currently don't handle all dictionary types...
		} else {
			[dict setObject:sm forKey:[sm name]];
		}
        
        
        // prepare display filters
		/*switch(mod->Markup()) {
			case sword::FMT_GBF:
				if(!gbfFilter) {
					gbfFilter = new sword::GBFHTMLHREF();
                }
				if(!gbfStripFilter) {
					gbfStripFilter = new sword::GBFPlain();
                }
				mod->AddRenderFilter(gbfFilter);
				mod->AddStripFilter(gbfStripFilter);
				break;
            case sword::FMT_THML:
				if(!thmlFilter) {
					thmlFilter = new sword::ThMLHTMLHREF();
                }
				if(!thmlStripFilter) {
					thmlStripFilter = new sword::ThMLPlain();
                }
				mod->AddRenderFilter(thmlFilter);
				mod->AddStripFilter(thmlStripFilter);
				break;
            case sword::FMT_OSIS:
				if(!osisFilter) {
					osisFilter = new sword::OSISHTMLHREF();
                }
				if(!osisStripFilter) {
					osisStripFilter = new sword::OSISPlain();
                }
				mod->AddRenderFilter(osisFilter);
				mod->AddStripFilter(osisStripFilter);
				break;
            case sword::FMT_PLAIN:
            default:
				if(!plainFilter) {
					plainFilter = new sword::PLAINHTML();
                }
				mod->AddRenderFilter(plainFilter);
				break;
		}*/
	}
    // set modules
    [self setModules:dict];
}

@end

@implementation SwordManager

@synthesize modules;
@synthesize modulesPath;
@synthesize managerLock;

# pragma mark - class methods

+ (void)initLocale {
    // set locale swManager
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString *localePath = [docPath stringByAppendingPathComponent:@"locales.d"];

    
	sword::LocaleMgr *lManager = sword::LocaleMgr::getSystemLocaleMgr();
    lManager->loadConfigDir([localePath UTF8String]);

	//sword::LocaleMgr *lManager = new sword::LocaleMgr::LocaleMgr([localePath UTF8String]);
    
    //get the language
    NSArray *availLocales = [NSLocale preferredLanguages];
    //NSLocale *loc = [NSLocale currentLocale];
    //NSString *lang = [loc objectForKey:NSLocaleIdentifier];
    
    NSString *lang = nil;
    NSString *loc = nil;
    BOOL haveLocale = NO;
    // for every language, check if we know the locales
	sword::StringList localelist = lManager->getAvailableLocales();
    NSEnumerator *iter = [availLocales objectEnumerator];
    while((loc = [iter nextObject]) && !haveLocale) {
		// replace "-" with "_" as SWORD and iOS use different ways of signifying locales...
		loc = [loc stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
        // check if this locale is available in SWORD
		sword::StringList::iterator it;
		//sword::SWBuf locale;
        for(it = localelist.begin(); it != localelist.end(); ++it) {
            //locale = *it;
            NSString *swLoc = [NSString stringWithCString:(*it).c_str() encoding:NSUTF8StringEncoding];
			//DLog(@"\nloc: %@   swLoc: %@", loc, swLoc);
            if([swLoc hasPrefix:loc]) {
                haveLocale = YES;
                lang = swLoc;
                break;
            }
        }
		
		if(!haveLocale) {
			//perhaps we have something else we can fall back on?
			NSRange dashRange = [loc rangeOfString:@"_"];
			if(dashRange.location != NSNotFound) {
				loc = [loc substringToIndex:dashRange.location];
				// check if this modified locale is available in SWORD
				for(it = localelist.begin(); it != localelist.end(); ++it) {
					//locale = *it;
					NSString *swLoc = [NSString stringWithCString:(*it).c_str() encoding:NSUTF8StringEncoding];
					//DLog(@"\nloc: %@   swLoc: %@", loc, swLoc);
					if([swLoc hasPrefix:loc]) {
						haveLocale = YES;
						lang = swLoc;
						break;
					}
				}
			}
		}

    }
	
    
    // if still haveLocale is still NO, we have a problem
    // use english for testing
    if(haveLocale) {
        // set the locale
        lManager->setDefaultLocaleName([lang UTF8String]);
    }
	//sword::LocaleMgr::setSystemLocaleMgr(lManager);
}

// Foundation-only wrapper over sword::LocaleMgr::translate so callers (e.g.
// PSTabBarControllerDelegate) need not touch the C++ LocaleMgr API directly.
// Keeps the public header C++-clean for the Swift bridging header.
+ (NSString *)translateBookName:(NSString *)bookName {
	if(!bookName) return nil;
	sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
	return [NSString stringWithCString:lmgr->translate([bookName cStringUsingEncoding:NSUTF8StringEncoding], "en") encoding:NSUTF8StringEncoding];
}

// Foundation-only wrapper over sword::LocaleMgr::translate (no target locale ->
// the *current system* locale, unlike +translateBookName: which forces "en").
// Mirrors the LocaleMgr use that previously lived in -[PSModuleController init],
// including the UTF-8 -> ISO-Latin-1 fallback decode, so the Swift port need not
// touch the C++ LocaleMgr API. Keeps the public header C++-clean.
+ (NSString *)translateToSystemLocale:(NSString *)englishText {
	if(!englishText) return nil;
	sword::LocaleMgr *lManager = sword::LocaleMgr::getSystemLocaleMgr();
	const char *translated = lManager->translate([englishText cStringUsingEncoding:NSUTF8StringEncoding]);
	NSString *result = [NSString stringWithCString:translated encoding:NSUTF8StringEncoding];
	if(!result) {
		result = [NSString stringWithCString:translated encoding:NSISOLatin1StringEncoding];
	}
	return result;
}

static SwordManager *instance;
/** the singleton instance */
+ (SwordManager *)defaultManager {
    if(instance == nil) {
        // use default path
        instance = [[SwordManager alloc] initWithPath:DEFAULT_MODULE_PATH];
    }
    
	return instance;
}

+ (void)releaseDefaultManager {
	instance = nil;
}

/* 
 Initializes Sword Manager with the path to the folder that contains the mods.d, modules.
*/
- (id)initWithPath:(NSString *)path {

	if((self = [super init])) {
        self.modulesPath = path;

		self.modules = [NSDictionary dictionary];
		NSRecursiveLock *rl = [[NSRecursiveLock alloc] init];
		self.managerLock = rl;

        // setting locale
        [SwordManager initLocale];
        
        [self reInit];
        
        sword::StringList options = swManager->getGlobalOptions();
        sword::StringList::iterator	it;
        for(it = options.begin(); it != options.end(); it++) {
            [self setGlobalOption:[NSString stringWithCString:it->c_str() encoding:NSUTF8StringEncoding] value:SW_OFF];
        }        
    }	
	
	return self;
}

- (void)dealloc {
	// -initWithPath: is now the only initialiser, so this manager always owns its
	// swManager (the former -initWithSWMgr: "temporary manager" that borrowed one
	// had no callers and is gone).
	if(swManager != nil)
		delete swManager;
}



/** 
 reinit the swManager 
 */
- (void)reInit {
    
	[managerLock lock];
    if(modulesPath && [modulesPath length] > 0) {
        
        // modulePath is the main sw manager
        //swManager = new sword::SWMgr([modulesPath UTF8String], true, new sword::EncodingFilterMgr(sword::ENC_UTF8));
		swManager = new sword::SWMgr([modulesPath UTF8String], true, new sword::MarkupFilterMgr(sword::FMT_HTMLHREF, sword::ENC_HTML), false, false);

        if(!swManager) {
            ALog(@"[SwordManager -reInit] cannot create SWMgr instance for default module path!");
        } else {
			
//#if defined (_APPLE_IOS_)
//			swManager->augmentModules([DEFAULT_BUILTIN_MODULE_PATH UTF8String]);
//#endif
            /*
			NSFileManager *fm = [NSFileManager defaultManager];
            NSArray *subDirs = [fm directoryContentsAtPath:modulesPath];
            // for all sub directories add module
            BOOL directory;
            NSString *fullSubDir = nil;
            NSString *subDir = nil;
            for(subDir in subDirs) {
                // as long as it's not hidden
                if(![subDir hasPrefix:@"."]) {
                    fullSubDir = [modulesPath stringByAppendingPathComponent:subDir];
                    fullSubDir = [fullSubDir stringByStandardizingPath];
                    
                    //if its a directory
                    if([fm fileExistsAtPath:fullSubDir isDirectory:&directory]) {
                        if(directory) {
                            swManager->augmentModules([fullSubDir UTF8String]);
                        }
                    }
                }
            }
            
            // also add the executing path to the path of modules
            NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
			DLog(@"bundlePath = %@", bundlePath);
            if(bundlePath) {
                // remove last path component
                NSString *appPath = [bundlePath stringByDeletingLastPathComponent];
                swManager->augmentModules([appPath UTF8String]);
            }*/
            
            // clear some data
            [self refreshModules];
        }
    }
	
	// unlock all modules that have a cipher key.
	NSDictionary *cipherKeys = [userDefaults objectForKey:DefaultsModuleCipherKeysKey];
    for(NSString *modName in cipherKeys) {
        NSString *key = [cipherKeys objectForKey:modName];
        [self setCipherKey:key forModuleNamed:modName];
    }
	
	[managerLock unlock];    
}

/**
 Unloads Sword Manager.
*/

- (BOOL)isModuleInstalled:(NSString *)name {
	BOOL ret = YES;
	SwordModule *sm = [modules objectForKey:name];
	if(!sm) {
		sword::SWModule *mod = [self getSWModuleWithName:name];
		if(!mod) {
			ret = NO;
		}
	}
	return ret;
}

/**
 get module with name from internal list
 */
- (SwordModule *)moduleWithName:(NSString *)name {
	
	if(!name)
		return nil;
    
	SwordModule	*ret = [modules objectForKey:name];
    if(!ret) {
        sword::SWModule *mod = [self getSWModuleWithName:name];
        if(mod) {
            NSString *type;
            if(mod->isUnicode()) {
                type = [NSString stringWithUTF8String:mod->getType()];
            } else {
                type = [NSString stringWithCString:mod->getType() encoding:NSISOLatin1StringEncoding];
            }
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:modules];
            // create module
			/*
            if([type isEqualToString:SWMOD_CATEGORY_BIBLES]) {
                ret = [[[SwordBible alloc] initWithName:name swordManager:self] autorelease];
            } else if([type isEqualToString:SWMOD_CATEGORY_COMMENTARIES]) {
                ret = [[[SwordBible alloc] initWithName:name swordManager:self] autorelease];
                //ret = [[[SwordCommentary alloc] initWithName:name swordManager:self] autorelease];
            } else*/ if([type isEqualToString:SWMOD_CATEGORY_DICTIONARIES]) {
                ret = [[SwordDictionary alloc] initWithName:name swordManager:self];
            }/* else if([type isEqualToString:SWMOD_CATEGORY_GENBOOKS]) {
                ret = [[[SwordGenBook alloc] initWithName:name swordManager:self] autorelease];
            }*/ else {
                ret = [[SwordModule alloc] initWithName:name swordManager:self];
            }
            [dict setObject:ret forKey:name];
            self.modules = dict;
        }
    }
    
	return ret;
}

- (void)setCipherKey:(NSString *)key forModuleNamed:(NSString *)name {
	[managerLock lock];	
	if(key)
		swManager->setCipherKey([name UTF8String], [key UTF8String]);
	else
		swManager->setCipherKey([name UTF8String], "");
	[managerLock unlock];
}

#pragma mark - module access

/** 
 Sets global options such as 'Strongs' or 'Footnotes'. 
 */
- (void)setGlobalOption:(NSString *)option value:(NSString *)value {
	[managerLock lock];
    swManager->setGlobalOption([option UTF8String], [value UTF8String]);
	[managerLock unlock];
}

/** 
 list all module and return them in a Array 
 */
- (NSArray *)listModules {
    NSMutableArray *ret = [NSMutableArray array];
	[ret addObjectsFromArray:[modules allValues]];
    // sort
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor]; 
    [ret sortUsingDescriptors:sortDescriptors];
	
	return [NSArray arrayWithArray:ret];
}
- (NSArray *)moduleNames {
    return [modules allKeys];
}

/*
 Retrieve list of installed modules as an array, where type is: @"Biblical Texts", @"Commentaries", ..., @"ALL"
*/
- (NSArray *)modulesForType:(NSString *)type {

    NSMutableArray *ret = [NSMutableArray array];
	NSString *searchType = type;
	ModuleCategory catType = errorCategory;
	
	if([searchType isEqualToString:SWMOD_CATEGORY_DICTIONARIES]) {
		catType = undefinedCategory;
	}
	
    for(SwordModule *mod in [modules allValues]) {
        if([[mod typeString] isEqualToString:searchType]) {
			if(catType != errorCategory) {
				if([mod cat] == catType)
					[ret addObject:mod];
			} else {
				[ret addObject:mod];
			}
        }
    }
    
    // sort
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor]; 
    [ret sortUsingDescriptors:sortDescriptors];
    
	return [NSArray arrayWithArray:ret];
}


// WARNING: you need to do a manual refresh of the modules after this!
- (void)installModulesFromPath:(NSString *)path
{
	/*
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *subDirs = [fm directoryContentsAtPath:modulesPath];
	// for all sub directories add module
	BOOL directory;
	NSString *fullSubDir = nil;
	NSString *subDir = nil;
	for(subDir in subDirs) {
		// as long as it's not hidden
		if(![subDir hasPrefix:@"."]) {
			fullSubDir = [modulesPath stringByAppendingPathComponent:subDir];
			fullSubDir = [fullSubDir stringByStandardizingPath];
			
			//if its a directory
			if([fm fileExistsAtPath:fullSubDir isDirectory:&directory]) {
				if(directory) {
					//swManager->augmentModules([fullSubDir UTF8String]);
				}
			}
		}
	}*/

	sword::InstallMgr *swInstallMgr = new sword::InstallMgr();
	sword::SWMgr *tmpManager = new sword::SWMgr([path UTF8String]);
	sword::ModMap::iterator it;
	sword::SWModule *curMod = 0;
	for (it = tmpManager->Modules.begin(); it != tmpManager->Modules.end(); it++) {
		curMod = (*it).second;
		swInstallMgr->installModule(swManager, [path UTF8String], curMod->getName());
	}
	
	// TODO: now to traverse the subdirectories searching for more modules?
	
	delete swInstallMgr;
	delete tmpManager;
}

// Foundation-only wrapper over sword::InstallMgr::removeModule so callers (e.g.
// PSModuleController) need not touch the C++ InstallMgr API directly. Mirrors the
// new/removeModule/delete sequence that previously lived in
// -[PSModuleController removeModule:]. Returns YES on success (stat == 0).
- (BOOL)removeModuleNamed:(NSString *)name {
	if(!name) return NO;
	sword::InstallMgr *swInstallMgr = new sword::InstallMgr();
	int stat = swInstallMgr->removeModule(swManager, [name UTF8String]);
	delete swInstallMgr;
	return (stat == 0) ? YES : NO;
}

#pragma mark - lowlevel methods

/** 
 return the sword swManager of this class 
 */
- (sword::SWMgr *)swManager {
    return swManager;
}

/**
 Retrieves C++ SWModule pointer - used internally by SwordBible. 
 */
- (sword::SWModule *)getSWModuleWithName:(NSString *)moduleName {
	sword::SWModule *module = NULL;

	[managerLock lock];
	module = swManager->Modules[[moduleName UTF8String]];	
	[managerLock unlock];
    
	return module;
}

@end
