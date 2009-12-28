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
#import "SwordDictionary.h"
#import "PSModuleType.h"
#import "SwordKey.h"

#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>

@interface PSModuleController : NSObject {
	// IB Outlets
	//IBOutlet id statusBar;
	//IBOutlet id statusText;
	//IBOutlet id moduleTable;
	//IBOutlet UIBarButtonItem *bibleNavBtn;
	//IBOutlet UIBarButtonItem *commentaryNavBtn;
	IBOutlet UIWebView *bibleWebView;
	IBOutlet UIWebView *commentaryWebView;
	
	IBOutlet UIBarButtonItem *bibleTitle;
	IBOutlet UIBarButtonItem *commentaryTitle;
	IBOutlet UIBarButtonItem *dictionaryTitle;
//	IBOutlet UIBarButtonItem *dictionaryDescriptionTitle;

	IBOutlet id bookmarkAddButton;
	
	IBOutlet id dataController;
	IBOutlet id viewController;
	
	SwordModule *primaryBible;
	SwordModule *primaryCommentary;
	SwordDictionary *primaryDictionary;
	
	SwordManager *swordManager;
	SwordInstallManager *swordInstallManager;
	SwordInstallSource *currentInstallSource;
}

@property (assign) SwordModule *primaryBible;
@property (assign) SwordModule *primaryCommentary;
@property (assign) SwordDictionary *primaryDictionary;
@property (assign) SwordInstallManager *swordInstallManager;
@property (assign) SwordManager *swordManager;
@property (retain, readwrite) SwordInstallSource *currentInstallSource;

+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript;
+ (NSString *)createHTMLString:(NSString*)body withJS:(NSString*)javascript;
+ (NSString *)createRefString:(NSString*)ref;
+ (BOOL)checkNetworkConnection;

- (PSModuleController *)init;
- (id)viewController;
- (void)loadInitialModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType;
- (BOOL)isLoaded:(NSString *)module;
- (NSString *)getCurrentBibleRef;
- (void)loadPrimaryBible:(NSString *)newText;
- (void)loadPrimaryCommentary:(NSString *)newText;
- (void)loadPrimaryDictionary:(NSString *)newText;
- (NSString *)setToNextChapter;
- (NSString *)setToPreviousChapter;
- (void)reload;
- (PSStatusReporter*)getInstallationProgress;
- (BOOL)installModule:(NSString *)name;
- (BOOL)installModuleWithModule:(SwordModule*)swordModule;
- (BOOL)removeModule:(NSString *)name;
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraCode;
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS;
- (void)dealloc;
//- (NSString *)getDescription:(NSString *)name fromSource:(SwordInstallSource *)source;
- (void)setPreferences/*:(NSMutableDictionary *)prefs*/;
//- (void)readSwordInstallSourceModuleConfigFiles;

- (void)displayBusyIndicator;
- (void)hideBusyIndicator;


@end
