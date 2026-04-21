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

@class SwordManager, SwordDictionary, PSModuleType, SwordKey, SwordModule;

@interface PSModuleController : NSObject {

	SwordModule *primaryBible;
	SwordModule *primaryCommentary;
	SwordDictionary *primaryDictionary;

	SwordManager *swordManager;

	NSTimer *busyTimer;
}

@property (strong) SwordModule *primaryBible;
@property (strong) SwordModule *primaryCommentary;
@property (strong) SwordDictionary *primaryDictionary;
@property (strong) SwordManager *swordManager;
@property (strong) NSTimer *busyTimer;

+ (PSModuleController *)defaultModuleController;
+ (void)releaseDefaultModuleController;

+ (NSString *)createInfoHTMLString:(NSString*)body usingModuleForPreferences:(NSString*)moduleName;
+ (NSString *)createHTMLString:(NSString*)body usingPreferences:(BOOL)usePrefs withJS:(NSString*)javascript usingModuleForPreferences:(NSString*)moduleName fixedWidth:(BOOL)fixedWidth;
+ (NSString *)createRefString:(NSString*)ref;
+ (NSString*)createTitleRefString:(NSString *)newTitle;
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
- (NSString *)setToNextChapter;
- (NSString *)setToPreviousChapter;
- (void)reload;
- (BOOL)removeModule:(NSString *)name;
- (void)reloadLastBible;
- (void)reloadLastCommentary;
- (NSString *)getBibleChapter:(NSString *)chapter withExtraJS:(NSString *)extraCode;
- (NSString *)getCommentaryChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS;
- (void)setPreferences;

- (void)didReceiveMemoryWarning;//never called by the OS - must be called manually!

@end
