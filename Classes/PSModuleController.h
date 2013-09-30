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


#import "SwordModule.h"
#import "PSModuleDownloadItem.h"
#import "PSStatusReporter.h"

@class SwordManager, SwordInstallManager, SwordInstallSource, SwordDictionary, PSModuleType, SwordKey, SwordModule;

@interface PSModuleController : NSObject <PSModuleDownloadDelegate> {
	
	SwordModule *primaryBible;
	SwordModule *primaryCommentary;
	SwordDictionary *primaryDictionary;
	SwordDictionary *primaryDevotional;
	
	SwordManager *swordManager;
	SwordInstallManager *swordInstallManager;
	SwordInstallSource *currentInstallSource;

	NSTimer *busyTimer;
	float installationProgress;
	NSInteger showNetworkIndicatorCount;
	NSInteger disableAutoSleepCount;
	
	NSMutableArray *downloadQueue;
}

@property (assign) SwordModule *primaryBible;
@property (assign) SwordModule *primaryCommentary;
@property (assign) SwordDictionary *primaryDictionary;
@property (assign) SwordDictionary *primaryDevotional;
@property (assign) SwordManager *swordManager;
@property (retain) SwordInstallSource *currentInstallSource;
@property (retain) NSTimer *busyTimer;
@property (retain) NSMutableArray *downloadQueue;

+ (PSModuleController *)defaultModuleController;
+ (void)releaseDefaultModuleController;

+ (NSString *)createInfoHTMLString:(NSString*)body usingModuleForPreferences:(NSString*)moduleName;
+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript usingModuleForPreferences:(NSString*)moduleName fixedWidth:(BOOL)fixedWidth;
+ (NSString *)createRefString:(NSString*)ref;
+ (NSString*)createTitleRefString:(NSString *)newTitle;
+ (BOOL)checkNetworkConnection;
+ (NSDictionary *)dataForLink:(NSURL *)aURL;
+ (NSString *)getCurrentBibleRef;
+ (void)setFirstRefAvailable:(NSString*)first;
+ (void)setLastRefAvailable:(NSString*)last;
+ (NSString*)getFirstRefAvailable;
+ (NSString*)getLastRefAvailable;

- (id)init;
- (void)installModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType removeZip:(BOOL)temporaryZip internalModule:(BOOL)internalModule;
- (BOOL)isLoaded:(NSString *)module;
- (void)loadPrimaryBible:(NSString *)newText;
- (void)loadPrimaryCommentary:(NSString *)newText;
- (void)loadPrimaryDictionary:(NSString *)newText;
- (void)loadPrimaryDevotional:(NSString *)newText;
- (NSString *)setToNextChapter;
- (NSString *)setToPreviousChapter;
- (void)reload;
#ifdef __cplusplus
- (PSStatusReporter*)getInstallationProgress;
#endif
//- (BOOL)installModule:(NSString *)name;
- (BOOL)installModuleWithModule:(SwordModule*)swordModule;
- (BOOL)installModuleWithModule:(SwordModule*)swordModule fromSource:(SwordInstallSource*)swordInstallSource;
- (BOOL)removeModule:(NSString *)name;
- (void)reloadLastBible;
- (void)reloadLastCommentary;
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraCode;
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS;
- (void)setPreferences/*:(NSMutableDictionary *)prefs*/;
- (SwordInstallManager *)swordInstallManager;

- (void)didReceiveMemoryWarning;//never called by the OS - must be called manually!
- (void)dealloc;

+ (void)queueModuleDownloadItem:(PSModuleDownloadItem*)downloadItem;
+ (BOOL)isModuleDownloading:(NSString*)moduleName;
+ (void)removeViewForHUDForModuleDownloadItem:(NSString*)moduleName;
- (BOOL)tryDownloading;

//- (void)displayBusyIndicator;
//- (void)hideBusyIndicator;
//- (void)doubleClose:(NSTimer *)theTimer;

@end
