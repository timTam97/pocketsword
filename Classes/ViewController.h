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
#import "ModuleManager.h"
#import "DataController.h"

#include <swmgr.h>
#include <swmodule.h>
#include <markupfiltmgr.h>
#include <filemgr.h>

using namespace sword;

@interface ViewController : UIViewController {
	// Tab bar
	IBOutlet id tabController;
	IBOutlet id tabBar;
	
	// Read tab
	IBOutlet id textView;
	IBOutlet id navBtn;
	IBOutlet id prevBtn;
	IBOutlet id nextBtn;
	IBOutlet id refSelector;
	
	// Module tab
	IBOutlet id moduleTable;
	
	// Search tab
	IBOutlet id progressBar;
	IBOutlet id resultsTable;
	
	// Bookmarks tab
	IBOutlet id bookmarksTable;
	
	// Status view
	IBOutlet id statusController;
	IBOutlet id statusTitle;
	IBOutlet id statusText;
	IBOutlet id statusBar;
	
	IBOutlet id moduleManager;
	IBOutlet id dataController;
}

- (IBOutlet id)getTextView;
- (IBOutlet id)getNavBtn;
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
- (void)confirmInstall:(NSString *)name;
- (void)updateInstallationStatus;
- (IBAction)nextChapter:(id)sender;
- (IBAction)prevChapter:(id)sender;
- (IBAction)toggleNavigation:(id)sender;
- (IBAction)updateViewWithSelectedChapter:(id)sender;
- (IBAction)toggleModuleTableEditing:(id)sender;
- (IBAction)toggleBookmarksTableEditing:(id)sender;
- (IBAction)addBookmark:(id)sender;
- (void)getRemoteModuleList;

@end
