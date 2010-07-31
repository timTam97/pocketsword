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

#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "ViewController.h"
#import "SwordManager.h"
#import "SwordInstallManager.h"
#import "globals.h"
#import "SwordInstallSource.h"
#import "SwordModule.h"
#import "SwordDictionary.h"
#import "PSModuleType.h"
#import "SwordKey.h"
#import "PSRefSelectorController.h"

#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>

@interface PSModuleController : NSObject {
	// IB Outlets
	//IBOutlet UIWebView *bibleWebView;
	//IBOutlet UIWebView *commentaryWebView;
	
	//IBOutlet UIBarButtonItem *bibleTitle;
	//IBOutlet UIBarButtonItem *commentaryTitle;
	//IBOutlet UIBarButtonItem *dictionaryTitle;

	//IBOutlet id bookmarkAddButton;
	
	IBOutlet id viewController;
	//IBOutlet PSRefSelectorController *refSelectorController;
	
	SwordModule *primaryBible;
	SwordModule *primaryCommentary;
	SwordDictionary *primaryDictionary;
	SwordDictionary *primaryDevotional;
	
	SwordManager *swordManager;
	SwordInstallManager *swordInstallManager;
	SwordInstallSource *currentInstallSource;

	NSTimer *busyTimer;
}

@property (assign) SwordModule *primaryBible;
@property (assign) SwordModule *primaryCommentary;
@property (assign) SwordDictionary *primaryDictionary;
@property (assign) SwordDictionary *primaryDevotional;
@property (assign) SwordInstallManager *swordInstallManager;
@property (assign) SwordManager *swordManager;
@property (retain, readwrite) SwordInstallSource *currentInstallSource;
@property (retain, readwrite) NSTimer *busyTimer;

+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript;
+ (NSString *)createHTMLString:(NSString*)body withJS:(NSString*)javascript;
+ (NSString *)createRefString:(NSString*)ref;
+ (NSString*)createTitleRefString:(NSString *)newTitle;
+ (BOOL)checkNetworkConnection;
+ (NSDictionary *)dataForLink:(NSURL *)aURL;

- (id)init;
- (id)viewController;
- (void)loadInitialModulesFromZip:(NSString*)zippedModule ofType:(ModuleType)modType;
- (BOOL)isLoaded:(NSString *)module;
- (NSString *)getCurrentBibleRef;
- (void)loadPrimaryBible:(NSString *)newText;
- (void)loadPrimaryCommentary:(NSString *)newText;
- (void)loadPrimaryDictionary:(NSString *)newText;
- (void)loadPrimaryDevotional:(NSString *)newText;
- (NSString *)setToNextChapter;
- (NSString *)setToPreviousChapter;
- (void)reload;
- (PSStatusReporter*)getInstallationProgress;
- (BOOL)installModule:(NSString *)name;
- (BOOL)installModuleWithModule:(SwordModule*)swordModule;
- (BOOL)removeModule:(NSString *)name;
- (void)reloadLastBible;
- (void)reloadLastCommentary;
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraCode;
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS;
- (void)dealloc;
//- (NSString *)getDescription:(NSString *)name fromSource:(SwordInstallSource *)source;
- (void)setPreferences/*:(NSMutableDictionary *)prefs*/;
//- (void)readSwordInstallSourceModuleConfigFiles;

- (void)displayBusyIndicator;
- (void)hideBusyIndicator;
- (void)doubleClose:(NSTimer *)theTimer;

@end
