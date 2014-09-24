//
//  SwordInstallManager.mm
//  Eloquent
//
//  Created by Manfred Bergmann on 13.08.07.
//  Copyright 2007 The CrossWire Bible Society. All rights reserved.
//

#import "SwordInstallManager.h"
#import "SwordInstallSource.h"
#import "SwordManager.h"
#import "SwordModule.h"
#import "globals.h"

#include "installmgr.h"


#ifdef __cplusplus
//typedef std::map<sword::SWBuf, sword::InstallSource *> InstallSourceMap;
typedef sword::multimapwithdefault<sword::SWBuf, sword::SWBuf, std::less <sword::SWBuf> > ConfigEntMap;
#endif

#define INSTALLSOURCE_SECTION_TYPE_FTP  "FTPSource"
#define INSTALLSOURCE_SECTION_TYPE_HTTP	"HTTPSource"

@implementation SwordInstallManager

@dynamic configPath;
@synthesize configFilePath;
@synthesize installSources;
@synthesize installSourceList;

float status;

// ------------------- getter / setter -------------------
- (NSString *)configPath {
    return configPath;
}

- (void)setConfigPath:(NSString *)value {
    //DLog(@"[SwordInstallManager -setConfigPath:%@]", value);
    
    if(configPath != value) {
        [configPath release];
        configPath = [value copy];
        
        if(value != nil) {            
            // check for existence
            NSFileManager *fm = [NSFileManager defaultManager];
            BOOL isDir;
            if(([fm fileExistsAtPath:configPath] == NO) && createPath == YES) {
                // create path
                [fm createDirectoryAtPath:configPath withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            if(([fm fileExistsAtPath:configPath isDirectory:&isDir] == YES) && (isDir)) {
                // set configFilePath
                [self setConfigFilePath:[configPath stringByAppendingPathComponent:@"InstallMgr.conf"]];
                static NSString *LAST_UPDATED_REPOS = @"updatedRepositories-20140924";
				BOOL xbr = [[NSUserDefaults standardUserDefaults] boolForKey: LAST_UPDATED_REPOS];
				if(!xbr) {
					[fm removeItemAtPath:configFilePath error:NULL];
				}

				// check config
                if([fm fileExistsAtPath:configFilePath] == NO) {
                    // create config entry
                    sword::SWConfig config([configFilePath cStringUsingEncoding:NSUTF8StringEncoding]);
                    config["General"]["PassiveFTP"] = "true";
                    config.Save();
					
                    // create default HTTP Install source
                    SwordInstallSource *is = [[[SwordInstallSource alloc] initWithType:INSTALLSOURCE_TYPE_HTTP] autorelease];
                    [is setCaption:@"CrossWire"];
                    [is setSource:@"ftp.crosswire.org"];
                    [is setDirectory:@"/ftpmirror/pub/sword/raw"];
					[is setUID:@"20081216195754"];
                    [self addInstallSource:is withReinitialize:NO];
					
//					[is setCaption:@"CrossWire 2"];
//					[is setSource:@"ftp.crosswire.org"];
//					[is setDirectory:@"/ftpmirror/pub/sword/betaraw"];
//					[is setUID:@"20090224125400"];
//					[self addInstallSource:is withReinitialize:NO];
					
//                    [is setCaption:@"CrossWire av11n"];
//                    [is setSource:@"ftp.crosswire.org"];
//                    [is setDirectory:@"/ftpmirror/pub/sword/avraw"];
//					[is setUID:@"20120224005000"];
//                    [self addInstallSource:is withReinitialize:NO];
					
					[is setType:INSTALLSOURCE_TYPE_FTP];
					[is setCaption:@"NET (Bible.org)"];
					[is setSource:@"ftp.bible.org"];
					[is setDirectory:@"/sword"];
					[is setUID:@"20090514005700"];
					[self addInstallSource:is withReinitialize:NO];
					
					[is setType:INSTALLSOURCE_TYPE_FTP];
					[is setCaption:@"Xiphos"];
					[is setSource:@"ftp.xiphos.org"];
					[is setDirectory:@"."];                    
					[is setUID:@"20090514005900"];
					[self addInstallSource:is withReinitialize:NO];
					
					[[NSUserDefaults standardUserDefaults] setBool:YES forKey: LAST_UPDATED_REPOS];
					
                }
				
				// init installMgr
				[self reinitialize];

            } else {
                ALog(@"[SwordInstallManager -setConfigPath:] config path does not exist!");
            }
        }
    }
}

// -------------------- methods --------------------

// initialization
+ (SwordInstallManager *)defaultController {
    static SwordInstallManager *singleton;
    if(singleton == nil) {
        singleton = [[SwordInstallManager alloc] init];
    }
    
    return singleton;
}

/**
base path of the module installation
 */
- (id)init {
    //DLog(@"[SwordInstallManager -init]");

    self = [super init];
    if(self) {
        createPath = NO;
        [self setConfigPath:nil];
        [self setConfigFilePath:nil];
        [self setInstallSources:[NSMutableDictionary dictionary]];
        [self setInstallSourceList:[NSMutableArray array]];
		status = 0.0;
    }
    
    return self;
}

/**
 initialize with given path
 */
- (id)initWithPath:(NSString *)aPath createPath:(BOOL)create {
    
    //DLog(@"[SwordInstallManager -initWithPath:]");
    
    self = [self init];
    if(self) {
        createPath = create;
        [self setConfigPath:aPath];
		status = 0.0;
    }
    
    return self;
}

/** re-init after adding or removing new modules */
- (void)reinitialize {

    //DLog(@"[SwordInstallManager -reinitialize] loading config!");
    sword::SWConfig config([configFilePath UTF8String]);
    config.Load();

    // init installMgr
    BOOL disclaimerConfirmed = NO;
    if(swInstallMgr != nil) {
        disclaimerConfirmed = [self userDisclaimerConfirmed];
    }
    //swInstallMgr = new sword::InstallMgr([configPath UTF8String]);
	//	InstallMgr::InstallMgr(const char *privatePath, StatusReporter *sr, SWBuf u, SWBuf p) {
	if(statusReporter != nil)
		delete statusReporter;
	statusReporter = new PSStatusReporter();
	if(swInstallMgr != nil)
		delete swInstallMgr;
	swInstallMgr = new sword::InstallMgr([configPath UTF8String], statusReporter, "ftp", "installmgr@pocketsword.crosswire.org");
	//swInstallMgr = new sword::InstallMgr([configPath UTF8String], statusReporter);
    if(swInstallMgr == nil) {
        ALog(@"[SwordInstallManager -reinitialize] could not initialize InstallMgr!");
    } else {
		[self setUserDisclainerConfirmed:disclaimerConfirmed];
        
        // empty all lists
        [installSources removeAllObjects];
        [installSourceList removeAllObjects];
        
        // init install sources
        for(sword::InstallSourceMap::iterator it = swInstallMgr->sources.begin(); it != swInstallMgr->sources.end(); it++) {
            //sword::InstallSource *sis = it->second;
            //SwordInstallSource *is = [[SwordInstallSource alloc] initWithSource:(id)sis];
            SwordInstallSource *is = [[SwordInstallSource alloc] initWithSource:it->second];
            
            [installSources setObject:is forKey:[is caption]];
            // also add to list
            [installSourceList addObject:is];
			[is release];
        }
		//sort the installSourceList by "caption"
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"caption" ascending:YES];
		NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
		[installSourceList sortUsingDescriptors:sortDescriptors];
		[sortDescriptor release];
    }
}

- (void)dealloc {
    DLog(@"[SwordInstallManager -finalize]");

    if(swInstallMgr != nil) {
        delete swInstallMgr;
    }
	if(statusReporter != nil) {
		delete statusReporter;
	}
    
    [self setConfigPath:nil];
    [self setInstallSources:nil];
    [self setInstallSourceList:nil];
    [self setConfigFilePath:nil];
    
    [super dealloc];
}

- (void)addInstallSource:(SwordInstallSource *)is withReinitialize:(BOOL)reinit {
	// save at once
    sword::SWConfig config([configFilePath cStringUsingEncoding:NSUTF8StringEncoding]);
	if([[is type] isEqualToString:INSTALLSOURCE_TYPE_FTP]) {
		config["Sources"].insert(ConfigEntMap::value_type(INSTALLSOURCE_SECTION_TYPE_FTP, [[is configEntry] UTF8String]));
	} else {
		config["Sources"].insert(ConfigEntMap::value_type(INSTALLSOURCE_SECTION_TYPE_HTTP, [[is configEntry] UTF8String]));
	}
    config.Save();
    
    // reinit
	if(reinit)
		[self reinitialize];
	
}

// add/remove install sources
- (void)addInstallSource:(SwordInstallSource *)is {
    [self addInstallSource:is withReinitialize:YES];
}

//if we're just removing & adding an install source, we only need to reinitialize after re-adding the IS again.
// Note that if you remove an InstallSource and don't reinitialize, data will be dirty and you will run into trouble!
//      So, play nicely.  :P
- (void)removeInstallSource:(SwordInstallSource *)is withReinitialize:(BOOL)performReinitialize {
	[self removeInstallSourceNamed:[is caption] withReinitialize:performReinitialize];
}

- (void)removeInstallSourceNamed:(NSString*)caption withReinitialize:(BOOL)performReinitialize {

    // remove source
    [installSources removeObjectForKey:caption];
    
    // save at once
    sword::SWConfig config([configFilePath cStringUsingEncoding:NSUTF8StringEncoding]);
    config["Sources"].erase(INSTALLSOURCE_SECTION_TYPE_HTTP);
	config["Sources"].erase(INSTALLSOURCE_SECTION_TYPE_FTP);
    
    // build up new
    NSEnumerator *iter = [installSources objectEnumerator];
    SwordInstallSource *sis = nil;
    while((sis = [iter nextObject])) {
		if([[sis type] isEqualToString:INSTALLSOURCE_TYPE_FTP]) {
			config["Sources"].insert(ConfigEntMap::value_type(INSTALLSOURCE_SECTION_TYPE_FTP, [[sis configEntry] UTF8String]));
		} else {
			config["Sources"].insert(ConfigEntMap::value_type(INSTALLSOURCE_SECTION_TYPE_HTTP, [[sis configEntry] UTF8String]));
		}
    }
    config.Save();
    
    // reinit
	if(performReinitialize) {
		[self reinitialize];
	}
}

- (void)updateInstallSource:(SwordInstallSource *)is {
    // first remove, then add again
    [self removeInstallSource:is withReinitialize:NO];
    [self addInstallSource:is];
}

// installation/uninstallation
- (int)installModule:(SwordModule *)aModule fromSource:(SwordInstallSource *)is withManager:(SwordManager *)manager {
    
    int stat = -1;
    if([[is source] isEqualToString:@"localhost"]) {
        stat = swInstallMgr->installModule([manager swManager], [[is directory] UTF8String], [[aModule name] UTF8String]);
    } else {
        stat = swInstallMgr->installModule([manager swManager], 0, [[aModule name] UTF8String], [is installSource]);
    }

    return stat;
}

- (int)refreshMasterRemoteInstallSourceList {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	
    int stat = swInstallMgr->refreshRemoteSourceConfiguration();
    if(stat) {
        ALog(@"[SwordInstallMgr -refreshMasterRemoteInstallSourceList] Unable to refresh with master install source!");
    }
    
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	
	[self reinitialize];

	[pool release];
    return stat;
}

/**
 uninstalls a module from a SwordManager
 */
- (int)uninstallModule:(SwordModule *)aModule fromManager:(SwordManager *)swManager {
    
    int stat = swInstallMgr->removeModule([swManager swManager], [[aModule name] UTF8String]);
    
    return stat;
}

// list modules in sources
- (NSArray *)listModulesForSource:(SwordInstallSource *)is {
    return [is listModules];
}

// list modules in sources
- (NSArray *)listModulesForSource:(SwordInstallSource *)is byType:(NSString *)type {
    return [[is swordManager] modulesForType: type];
}

// list all modules in all sources, by type.
- (NSArray *)listAllModulesByType:(NSString *)type {
	NSMutableArray *ret = [NSMutableArray arrayWithObjects: nil];
	for (int i = 0; i < [installSourceList count]; i++) {
		SwordInstallSource *sIS = [installSourceList objectAtIndex: i];
		NSArray *mods = [[sIS swordManager] modulesForType: type];
		for (int j = 0; j < [mods count]; j++) {
			[ret addObject: [[mods objectAtIndex: j] name]];
		}
		//[mods release];
	}
	return ret;
}


- (PSStatusReporter *)getInstallationProgress {
	if (status == 1.0) {
		statusReporter->fileProgress = 1.0;
	} else if (status == -1.0) {
		statusReporter->fileProgress = -1.0;
	}
	return statusReporter;
}

- (void)resetInstallationProgress {
	statusReporter->overallProgress = 0.0;
	statusReporter->fileProgress = 0.0;
	statusReporter->totalBytesReported = 0.0;
	statusReporter->completedBytesReported = 0.0;
	status = 0.0;
}


/** refresh modules of this source 
 refreshing the install source is necessary before installation of 
 */
- (int)refreshInstallSource:(SwordInstallSource *)is {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[self resetInstallationProgress];

	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	DLog(@"SwordInstallManager -refreshInstallSource: START");
	
    int ret = 1;
    
    if(is == nil) {
        ALog(@"[SwordInstallManager -refreshInstallSourceForName:] install source is nil");
    } else {
        if([[is source] isEqualToString:@"localhost"] == NO) {
            ret = swInstallMgr->refreshRemoteSource([is installSource]);
			//ret = -1;//DEBUG
			[self updateInstallSource: is];
        } else {
			[self updateInstallSource: is];
            DLog(@"[SwordInstallManager -refreshInstallSource:] not refreshing, DIR source");
        }
    }
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	if(!ret) // success = 0 for refreshRemoteSource()
		status = 1.0;
	else
		status = -1.0;
	
	[pool release];
	DLog(@"SwordInstallManager -refreshInstallSource: END");
    return ret;
}

- (void)refreshAllInstallSources {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	
	for (int i = 0; i < [installSourceList count]; i++) {
		SwordInstallSource *sIS = [installSourceList objectAtIndex: i];
		[self refreshInstallSource: sIS];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	DLog(@"refreshAllInstallSources complete...");
	[pool release];
}


/**
 returns an array of Modules with status set, nil on error
 */
- (NSArray *)moduleStatusInInstallSource:(SwordInstallSource *)is baseManager:(SwordManager *)baseMgr {
    
    NSArray *ret = nil;
    
    // get modules map
    NSMutableArray *ar = [NSMutableArray array];
    std::map<sword::SWModule *, int> modStats = swInstallMgr->getModuleStatus(*[baseMgr swManager], *[[is swordManager] swManager]);
    sword::SWModule *module;
	int modStatus;
	for(std::map<sword::SWModule *, int>::iterator it = modStats.begin(); it != modStats.end(); it++) {
		module = it->first;
		modStatus = it->second;
        
        SwordModule *mod = [[SwordModule alloc] initWithSWModule:module];
        [mod setStatus:modStatus];
        [ar addObject:mod];
		[mod release];
	}
    
    if(ar) {
        ret = [NSArray arrayWithArray:ar];
		//[ar release];
    }
    
    return ret;
}

- (BOOL)userDisclaimerConfirmed {
    return swInstallMgr->isUserDisclaimerConfirmed();
}

- (void)setUserDisclainerConfirmed:(BOOL)flag {
    swInstallMgr->setUserDisclaimerConfirmed(flag);
}

/** low level access */
- (sword::InstallMgr *)installMgr {
    return swInstallMgr;
}

@end
