//
//  SwordInstallSource.mm
//  Eloquent
//
//  Created by Manfred Bergmann on 13.08.07.
//  Copyright 2007 The CrossWire Bible Society. All rights reserved.
//

#import "SwordInstallSource.h"
#import "SwordInstallManager.h"
#import "SwordManager.h"

@interface SwordInstallSource (PrivateAPI)

- (void)setSwordManager:(SwordManager *)swManager;

@end

@implementation SwordInstallSource (PrivateAPI)

- (void)setSwordManager:(SwordManager *)swManager {
    [swManager retain];
    [swordManager release];
    swordManager = swManager;
	if(swordManager) {
		swordManagerLoaded = YES;
	}
}

@end

@implementation SwordInstallSource

@synthesize managerCreationLock;

// init
- (id)init
{
    self = [super init];
    if(self) {
		managerCreationLock = [[NSLock alloc] init];
        temporarySource = NO;
		swordManagerLoaded = NO;

        // at first we have no sword manager
        [self setSwordManager:nil];
        
        // init InstallMgr
        swInstallSource = new sword::InstallSource("", "");
        if(swInstallSource == nil) {
            ALog(@"[SwordInstallSource -init] could not init sword install source!");
        }
    }
    
    return self;
}

- (id)initWithType:(NSString *)aType {
    self = [self init];
    if(self) {
		managerCreationLock = [[NSLock alloc] init];
        // set type
        swInstallSource->type = [aType cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    return self;
}

/** init with given source */
- (id)initWithSource:(sword::InstallSource *)is {
    self = [super init];
    if(self) {
		managerCreationLock = [[NSLock alloc] init];
        temporarySource = YES;
		swordManagerLoaded = NO;
        
        // at first we have no sword manager
        [self setSwordManager:nil];
        
        swInstallSource = is;
    }
    
    return self;
}

- (void)dealloc {
	[self setSwordManager: nil];
	[managerCreationLock release];
	[super dealloc];
//	if(swordManagerLoaded) {
//		[swordManager release];
//	}
}

- (void)finalize {
    //DLog( @"[SwordInstallSource -finalize]");

    if(temporarySource == NO) {
        //DLog(@"[SwordInstallSource -finalize] deleting swInstalSource");
        //delete swInstallSource;
    }
    
    [super finalize];
}

// accessors
- (NSString *)caption {
    const char *str = swInstallSource->caption;
    return [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
}

- (void)setCaption:(NSString *)aCaption {
    swInstallSource->caption = [aCaption cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)type {
    const char *str = swInstallSource->type;
    return [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
}

- (void)setType:(NSString *)aType {
    swInstallSource->type = [aType cStringUsingEncoding:NSUTF8StringEncoding];
}

- (void)setUID:(NSString *)aUID {
	swInstallSource->uid = [aUID cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)uid {
    const char *str = swInstallSource->uid;
    return [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
}

- (NSString *)source {
    const char *str = swInstallSource->source;
    return [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
}

- (void)setSource:(NSString *)aSource {
    swInstallSource->source = [aSource cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)directory {
    const char *str = swInstallSource->directory;
    return [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
}

- (void)setDirectory:(NSString *)aDir {
    swInstallSource->directory = [aDir cStringUsingEncoding:NSUTF8StringEncoding];
}

// get config entry
- (NSString *)configEntry {
    return [NSString stringWithFormat:@"%@|%@|%@|||%@", [self caption], [self source], [self directory], [self uid]];
}

/** install module */
- (void)installModuleWithName:(NSString *)mName usingManager:(SwordManager *)swManager withInstallController:(SwordInstallManager *)sim {
    sword::InstallMgr *im = [sim installMgr];
    im->installModule([swManager swManager], 0, [mName UTF8String], swInstallSource);
}

/** list all modules of this source */
- (NSArray *)listModules {
    NSArray *ret = nil;
    
    DLog(@"[SwordInstallSource -listModules]");    
    
    SwordManager *sm = [self swordManager];
    if(sm) {
        ret = [sm listModules];
    } else {
        DLog(@"[SwordInstallSource -listModules] got nil SwordManager");        
    }
    
    return ret;
}

/** list module types */
- (NSArray *)listModuleTypes {    
    return [SwordManager moduleTypes];
}

- (NSArray *)moduleListByType {
	return [[self swordManager] moduleListByType];
}

- (BOOL)isSwordManagerLoaded {
	return swordManagerLoaded;
}

- (void)resetSwordManagerLoaded {
	swordManagerLoaded = NO;
}

// get associated SwordManager
- (SwordManager *)swordManager {

    if(swordManager == nil) {
		[managerCreationLock lock];
		//if no one else is trying to create a swordManager for this source, we'll make one.
		if(swordManager == nil) {
			// create SwordManager from the SWMgr of this source
			//DLog(@"=== creating a swordManager in [SwordInstallSource swordManager]");
			sword::SWMgr *mgr;
			if([[self source] isEqualToString:@"localhost"]) {
				// create SwordManager from new SWMgr of path
				mgr = (sword::SWMgr *)new sword::SWMgr([[self directory] UTF8String], true, NULL, false, false);
			} else {
				// create SwordManager from the SWMgr of this source
				mgr = swInstallSource->getMgr();
			}
			
			if(mgr == nil) {
				ALog(@"[SwordInstallSource -manager] have a nil SWMgr!");
			} else {
				SwordManager *swM = [[SwordManager alloc] initWithSWMgr:mgr];
				[self setSwordManager:swM];
				[swM release];
				//swordManager = [[SwordManager alloc] initWithSWMgr:mgr];
			}
		}
		//swordManagerLoaded = YES;
		[managerCreationLock unlock];
    }
    
    return swordManager;
}

/** low level API */
- (sword::InstallSource *)installSource {
    return swInstallSource;
}

@end
