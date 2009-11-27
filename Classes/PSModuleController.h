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

#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "DataController.h"
#import "SwordManager.h"
#import "SwordInstallManager.h"
#import "globals.h"
#import "SwordInstallSource.h"
#import "SwordModule.h"

#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>

@interface PSModuleController : NSObject {
	// IB Outlets
	IBOutlet id statusBar;
	IBOutlet id statusText;
	IBOutlet id moduleTable;
	IBOutlet UIBarButtonItem *bibleNavBtn;
	IBOutlet UIWebView *bibleWebView;
	IBOutlet UIWebView *commentaryWebView;
	IBOutlet UIBarButtonItem *commentaryNavBtn;
	
	IBOutlet id bookmarkAddButton;
	IBOutlet UIBarButtonItem *biblePrevBtn;
	IBOutlet UIBarButtonItem *bibleNextBtn;
	IBOutlet UIBarButtonItem *commentaryPrevBtn;
	IBOutlet UIBarButtonItem *commentaryNextBtn;
	
	IBOutlet id dataController;
	IBOutlet id viewController;
	
	SwordModule *primaryBible;
	SwordModule *primaryCommentary;
	
	SwordManager *swordManager;
	SwordInstallManager *swordInstallManager;
	SwordInstallSource *currentInstallSource;
	sword::SWKey currentLocation;
}

@property (assign) SwordModule *primaryBible;
@property (assign) SwordModule *primaryCommentary;
@property (assign) SwordInstallManager *swordInstallManager;
@property (assign) SwordManager *swordManager;
@property (retain, readwrite) SwordInstallSource *currentInstallSource;

+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript;
+ (NSString *)createHTMLString:(NSString*)body withJS:(NSString*)javascript;
+ (BOOL)checkNetworkConnection;

- (PSModuleController *)init;
- (void)loadInitialModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType;
- (BOOL)isLoaded:(NSString *)module;
- (NSString *)getCurrentBibleRef;
- (void)loadPrimaryBible:(NSString *)newText;
- (void)loadPrimaryCommentary:(NSString *)newText;
- (NSString *)setToNextChapter;
- (NSString *)setToPreviousChapter;
- (void)reload;
- (PSStatusReporter*)getInstallationProgress;
- (BOOL)installModule:(NSString *)name;
- (BOOL)installModuleWithModule:(SwordModule*)swordModule;
- (BOOL)removeModule:(NSString *)name;
- (BOOL)installSearchIndex;
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraCode;
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS;
- (void)dealloc;
- (NSString *)getDescription:(NSString *)name fromSource:(SwordInstallSource *)source;
- (void)setPreferences/*:(NSMutableDictionary *)prefs*/;
//- (void)readSwordInstallSourceModuleConfigFiles;


@end
