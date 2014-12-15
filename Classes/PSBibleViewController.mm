//
//  PSBibleViewController.m
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBibleViewController.h"
#import "PSModuleController.h"
#import "PSTabBarControllerDelegate.h"
#import "SwordDictionary.h"
#import "PSBookmarkAddViewController.h"
#import "PSResizing.h"
#import "PSBookmarks.h"
#import "PSBookmark.h"
#import "PSCommentaryViewController.h"
#import "SwordManager.h"

@implementation PSBibleViewController

@synthesize commentaryView;

- (id)init {
	self = [super init];
	if(self) {
		tabType = BibleTab;
	}
	return self;
}


- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	
	NSString *buttonPressedTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
	if([buttonPressedTitle isEqualToString:NSLocalizedString(@"VerseContextualMenuAddBookmark", @"")]) {
		
		//add a bookmark!
		NSString *refToBookmark = [PSModuleController createRefString:[PSModuleController getCurrentBibleRef]];
		PSBookmarksAddTableViewController *tableViewController = [[PSBookmarksAddTableViewController alloc] initWithBookAndChapterRef:refToBookmark andVerse:tappedVerse];
		UINavigationController *containingNavigationController = [[UINavigationController alloc] initWithRootViewController:tableViewController];
		[tableViewController release];
		[self presentViewController:containingNavigationController animated:YES completion:nil];
		[containingNavigationController release];
		self.tappedVerse = nil;
		
	} else if([buttonPressedTitle isEqualToString:NSLocalizedString(@"VerseContextualMenuCommentary", @"")]) {
		
		//switch to the equivalent commentary entry.
		//commentaryView.jsToShow = [NSString stringWithFormat:@"scrollToVerse(%@);\n", tappedVerse];
		[commentaryView setVerseToShow:[tappedVerse integerValue]];
		BOOL fs = [self isFullScreen];
		if(fs) {
			[self toggleFullscreen];
			[commentaryView viewWillAppear:YES];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowCommentaryTab object:nil];
		if(fs) {
			[commentaryView toggleFullscreen];
		}
		self.tappedVerse = nil;
		
	}

}


@end
