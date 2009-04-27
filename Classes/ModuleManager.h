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
#import "DataController.h"

#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>

using namespace sword;

@interface ModuleManager : NSObject {
	// IB Outlets
	IBOutlet id statusBar;
	IBOutlet id statusText;
	IBOutlet id moduleTable;
	
	IBOutlet id dataController;
	
	NSMutableArray *downloadableBibles;
	NSMutableArray *downloadableZCommentaries;
	NSMutableArray *downloadableRawCommentaries;
	NSMutableArray *betaBibles;
	NSMutableDictionary *installedModules;
	
	SWMgr *library;
	SWModule *primaryText;
}

@property (assign) NSMutableArray *downloadableBibles;
@property (assign) NSMutableArray *downloadableZCommentaries;
@property (assign) NSMutableArray *downloadableRawCommentaries;
@property (assign) NSMutableArray *betaBibles;
@property (assign) NSDictionary *installedModules;
@property (assign) SWMgr *library;
@property (assign) SWModule *primaryText;

- (ModuleManager *)init;
- (SWModule *)getPrimaryText;
- (void)loadPrimaryText:(NSString *)newText;
- (NSArray *)installedBibles;
- (NSDictionary *)getInstalledModules;
- (void)reload;
- (void)reloadRepositoryModuleList;
- (float)getInstallationProgress;
- (BOOL)installModule:(NSString *)name;
- (BOOL)removeModule:(NSString *)name;
- (BOOL)installSearchIndex;
- (NSString *)getChapter:(NSString *)chapter;
- (void)dealloc;

@end
