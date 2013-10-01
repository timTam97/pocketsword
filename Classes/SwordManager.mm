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
#import "PSModuleType.h"

#include <string>
#include <list>

#include "gbfplain.h"
#include "thmlplain.h"
#include "osisplain.h"
//#include "msstringmgr.h"
#import "globals.h"
#import "utils.h"
//#import "SwordBook.h"
//#import "SwordBible.h"
//#import "SwordCommentary.h"
#import "SwordDictionary.h"
//#import "SwordListKey.h"
//#import "SwordVerseKey.h"
#include <installmgr.h>

using std::string;
using std::list;

@interface SwordManager (PrivateAPI)

- (void)refreshModules;

@end

@implementation SwordManager (PrivateAPI)

- (void)refreshModules {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // loop over modules
    sword::SWModule *mod;
	NSMutableArray *types = [[NSMutableArray alloc] initWithCapacity:4];
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

		if([type isEqualToString:SWMOD_CATEGORY_DICTIONARIES] && cat == devotional) {
			type = SWMOD_CATEGORY_DAILYDEVS;
		}
		if(![types containsObject: type]) {
			[types insertObject: type atIndex: [types count]];
		}
		   // at this point I want to manually exclude "cult" texts until there is a disclaimer about them in there!
		if((cat & cult) == cult) {
			//this is a questionable/cult module & we're currently not allowing these!
		} else if([type isEqualToString:SWMOD_CATEGORY_DICTIONARIES] && ![SwordManager moduleCategoryAllowed: cat]) {
			//we currently don't handle all dictionary types...
		} else {
			[dict setObject:sm forKey:[sm name]];
		}
		[sm release];
        
        
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
	//sort the types into alphabetical order
	[types sortUsingSelector: @selector(compare:)];
    [self setModuleTypes:types];
	[types release];
    // set modules
    [self setModules:dict];
	NSMutableArray *arrayList = [[NSMutableArray alloc] initWithCapacity: [moduleTypes count]];
	for (int i = 0; i < [moduleTypes count]; i++) {
		if([[SwordManager moduleTypes] containsObject: [moduleTypes objectAtIndex: i]]) {
			PSModuleType *smt = [[PSModuleType alloc] initWithModules:[self modulesForType: [moduleTypes objectAtIndex: i]] withModuleType:[moduleTypes objectAtIndex: i]];
			[arrayList addObject: smt];
			[smt release];
			//DLog(@"\nfound a moduleType: %@", [moduleTypes objectAtIndex: i]);
		}
	}
	//alphabetically sort the arrayList by "name"
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"moduleType" ascending:YES];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[arrayList sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];
	
	[self setModuleListByType:arrayList];
	[arrayList release];
}

@end

@implementation SwordManager

@synthesize modules;
@synthesize modulesPath;
@synthesize managerLock;
@synthesize temporaryManager;
@synthesize moduleTypes;
@synthesize moduleListByType;

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

//Effectively, this is a list of the module types that are currently supported.
+ (NSArray *)moduleTypes {
    return [NSArray arrayWithObjects:
            SWMOD_CATEGORY_BIBLES, 
            SWMOD_CATEGORY_COMMENTARIES,
            SWMOD_CATEGORY_DICTIONARIES,
			SWMOD_CATEGORY_DAILYDEVS,
            //SWMOD_CATEGORY_GENBOOKS, 
			nil];
}

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


/**
 return a manager for the specified path
 */
+ (SwordManager *)managerWithPath:(NSString *)path {
    SwordManager *manager = [[[SwordManager alloc] initWithPath:path] autorelease];
    return manager;
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
	[instance release];
	instance = nil;
}

/* 
 Initializes Sword Manager with the path to the folder that contains the mods.d, modules.
*/
- (id)initWithPath:(NSString *)path {

	if((self = [super init])) {
        // this is our main swManager
        temporaryManager = NO;
        
        self.modulesPath = path;

		self.modules = [NSDictionary dictionary];
		NSRecursiveLock *rl = [[NSRecursiveLock alloc] init];
		self.managerLock = rl;
		[rl release];

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

/** 
 initialize a new SwordManager with given SWMgr
 */
- (id)initWithSWMgr:(sword::SWMgr *)aSWMgr {
    
    self = [super init];
    if(self) {
        swManager = aSWMgr;
        // this is a temporary swManager
        temporaryManager = YES;
        
		self.modules = [NSDictionary dictionary];
		NSRecursiveLock *rl = [[NSRecursiveLock alloc] init];
		self.managerLock = rl;
		[rl release];
        
		[self refreshModules];
    }
    
    return self;
}

- (void)dealloc {
    if(!temporaryManager) {
		if(swManager != nil)
			delete swManager;
		[modules release];
		[moduleListByType release];
		[modulesPath release];
		self.managerLock = nil;
		[moduleTypes release];
		[super dealloc];
	}
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
            
            SendNotifyModulesChanged(nil);
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
 adds modules in this path
 */
- (void)addPath:(NSString *)path {
    
	[managerLock lock];
	if(swManager == nil) {
		//swManager = new sword::SWMgr([path UTF8String], true, new sword::EncodingFilterMgr(sword::ENC_UTF8));
		swManager = new sword::SWMgr([path UTF8String], true, new sword::MarkupFilterMgr(sword::FMT_HTMLHREF, sword::ENC_HTML));
    } else {
		swManager->augmentModules([path UTF8String]);
    }
	
	[self refreshModules];
	[managerLock unlock];
    
    SendNotifyModulesChanged(nil);
}

/** 
 Unloads Sword Manager.
*/
- (void)finalize {
    DLog(@"[SwordManager -finalize]");
    
    if(!temporaryManager) {
        delete swManager;
    }
    
	[super finalize];
}

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
			[ret release];
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
	[sortDescriptor release];
	
	return [NSArray arrayWithArray:ret];
}
- (NSArray *)moduleNames {
    return [modules allKeys];
}

/** 
 Retrieve list of installed modules as an array, where the module has a specific feature
*/
- (NSArray *)modulesForFeature:(NSString *)feature {

    NSMutableArray *ret = [NSMutableArray array];
    for(SwordModule *mod in [modules allValues]) {
        if([mod hasFeature:feature]) {
            [ret addObject:mod];
        }
    }
	
    // sort
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor]; 
    [ret sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];

	return [NSArray arrayWithArray:ret];
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
	} else if([searchType isEqualToString:SWMOD_CATEGORY_DAILYDEVS]) {
		searchType = SWMOD_CATEGORY_DICTIONARIES;
		catType = devotional;
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
	[sortDescriptor release];
    
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
