//
//  PSBookmarksController.mm
//  PocketSword
//
//  Created by Nic Carter on 19/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarksController.h"
#import "PSBookmarks.h"
#import "PSResizing.h"

@implementation PSBookmarksController

- (void)loadView {
	tableViewController = [[[PSBookmarksNavigatorController alloc] initWithBookmarkFolder:[PSBookmarks defaultBookmarks] parentFolders:nil isAddingBookmark:NO] retain];
	containingNavigationController = [[[UINavigationController alloc] initWithRootViewController:tableViewController] retain];
	self.view = containingNavigationController.view;
}

- (void)viewDidUnload {
	[super viewDidUnload];
	[tableViewController release];
	tableViewController = nil;
	[containingNavigationController release];
	containingNavigationController = nil;
}

- (void)dealloc {
	[super dealloc];
	[tableViewController release];
	[containingNavigationController release];
}

@end

