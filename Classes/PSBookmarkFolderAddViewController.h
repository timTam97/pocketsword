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

@interface PSBookmarkFolderAddViewController : UITableViewController <PSBookmarkFolderColourSelectorDelegate, UITextFieldDelegate> {
	NSString *parentFolder;
	UITextField *nameTextField;
	NSString *rgbHexString;
}

@property (retain, readwrite) NSString *parentFolder;
@property (retain, readwrite) NSString *rgbHexString;

- (id)initWithParentFolder:(NSString*)folder;

@end
