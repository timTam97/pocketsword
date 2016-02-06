//
//  PSBookmarkAddViewController.h
//  PocketSword
//
//  Created by Nic Carter on 10/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmark.h"

@interface PSBookmarksAddTableViewController : UITableViewController <UITextFieldDelegate>{
	NSString *bookAndChapterRef;
	NSString *verse;
	UITextField *descriptionTextField;
	NSString *folder;
	NSString *originalFolder;
	PSBookmark *bookmarkBeingEdited;
}

@property (strong, readwrite) NSString *bookAndChapterRef;
@property (strong, readwrite) NSString *verse;
@property (strong, readwrite) NSString *folder;
@property (strong, readwrite) NSString *originalFolder;
@property (strong, readwrite) PSBookmark *bookmarkBeingEdited;

// used to add a bookmark:
- (id)initWithBookAndChapterRef:(NSString*)ref andVerse:(NSString*)v;

// used to edit a bookmark:
- (id)initWithBookmarkToEdit:(PSBookmark*)bookmarkToEdit parentFolders:(NSString*)folders;

@end
