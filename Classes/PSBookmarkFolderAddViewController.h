//
//  PSBookmarkFolderAddViewController.h
//  PocketSword
//
//  Created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//
//	section 0: name
//	section 1: highlight colour
//		(defaults to @"None >" && can then tap & select a colour)
//
//	right nav item button = save button.

#import "PSBookmarkFolderColourSelectorViewController.h"

@class PSBookmarkFolder;

@interface PSBookmarkFolderAddViewController : UITableViewController <PSBookmarkFolderColourSelectorDelegate, UITextFieldDelegate> {
	NSString *parentFolder;
	UITextField *nameTextField;
	NSString *rgbHexString;
	PSBookmarkFolder *bookmarkFolderBeingEdited;
}

@property (strong, readwrite) NSString *parentFolder;
@property (strong, readwrite) NSString *rgbHexString;
@property (strong, readwrite) PSBookmarkFolder *bookmarkFolderBeingEdited;

// if bookmarkFolder is nil, we're creating a new folder,
// otherwise, we're editing an existing folder.
- (id)initWithParentFolder:(NSString*)folder bookmarkFolderToEdit:(PSBookmarkFolder*)bookmarkFolder;

@end
