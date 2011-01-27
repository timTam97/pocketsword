//
//  PSBookmarkAddViewController.h
//  PocketSword
//
//  Created by Nic Carter on 10/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

@interface PSBookmarksAddTableViewController : UITableViewController <UITextFieldDelegate>{
	NSString *bookAndChapterRef;
	NSString *verse;
	UITextField *descriptionTextField;
	NSString *folder;
}

@property (retain, readwrite) NSString *bookAndChapterRef;
@property (retain, readwrite) NSString *verse;
@property (retain, readwrite) NSString *folder;

- (id)initWithBookAndChapterRef:(NSString*)ref andVerse:(NSString*)v;

@end
