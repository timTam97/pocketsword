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

@property (retain, readwrite) NSString *bookAndChapterRef;
@property (retain, readwrite) NSString *verse;
@property (retain, readwrite) NSString *folder;
@property (retain, readwrite) NSString *originalFolder;
@property (retain, readwrite) PSBookmark *bookmarkBeingEdited;

// used to add a bookmark:
- (id)initWithBookAndChapterRef:(NSString*)ref andVerse:(NSString*)v;

// used to edit a bookmark:
- (id)initWithBookmarkToEdit:(PSBookmark*)bookmarkToEdit parentFolders:(NSString*)folders;

@end
