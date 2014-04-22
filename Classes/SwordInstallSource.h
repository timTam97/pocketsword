//
//  SwordInstallSource.h
//  Eloquent
//
//  Created by Manfred Bergmann on 13.08.07.
//  Copyright 2007 The CrossWire Bible Society. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifdef __cplusplus
#include <swmgr.h>
#include <installmgr.h>
//class sword::SWModule;
using sword::SWModule;
#endif

@class SwordManager;
@class SwordInstallManager;

#define INSTALLSOURCE_TYPE_FTP  @"FTP"
#define INSTALLSOURCE_TYPE_HTTP @"HTTP"

@interface SwordInstallSource : NSObject {
    
#ifdef __cplusplus
    sword::InstallSource *swInstallSource;
#endif
    
    /** the sword manager for this source */
    SwordManager *swordManager;
	NSLock *managerCreationLock;
    
    BOOL temporarySource;
	BOOL swordManagerLoaded;
}

@property (assign, readwrite) NSLock *managerCreationLock;

// init
- (id)init;
#ifdef __cplusplus
- (id)initWithSource:(sword::InstallSource *)is;
#endif
- (id)initWithType:(NSString *)aType;
- (void)dealloc;

// accessors
- (NSString *)caption;
- (void)setCaption:(NSString *)aCaption;
- (NSString *)type;
- (void)setType:(NSString *)aType;
- (NSString *)source;
- (void)setSource:(NSString *)aSource;
- (NSString *)directory;
- (void)setDirectory:(NSString *)aDir;
- (void)setUID:(NSString *)aUID;
- (NSString *)uid;


// get config entry
- (NSString *)configEntry;

// install module
- (void)installModuleWithName:(NSString *)mName 
                 usingManager:(SwordManager *)swManager 
        withInstallController:(SwordInstallManager *)sim;

// list modules of this source
- (NSArray *)listModules;
/** list module types */
- (NSArray *)listModuleTypes;
// get associated SwordManager
- (SwordManager *)swordManager;
- (BOOL)isSwordManagerLoaded;
- (void)resetSwordManagerLoaded;
- (NSArray *)moduleListByType;

#ifdef __cplusplus
- (sword::InstallSource *)installSource;
#endif

@end
