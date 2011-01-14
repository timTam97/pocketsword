//
//  PSBookmarkFolderColourSelectorViewController.h
//  PocketSword
//
//  Created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

@protocol PSBookmarkFolderColourSelectorDelegate <NSObject>
@required
- (void)rgbHexColorStringDidChange:(NSString *)newColorHexString;
@end

@interface PSBookmarkFolderColourSelectorViewController : UITableViewController {
	id <PSBookmarkFolderColourSelectorDelegate> delegate;
	NSString *currentSelectedColor;
	NSArray *selectableColours;
}

@property (nonatomic, assign) id <PSBookmarkFolderColourSelectorDelegate> delegate;
@property (retain, readwrite) NSString *currentSelectedColor;
@property (retain, readwrite) NSArray *selectableColours;

- (id)initWithColorString:(NSString*)rgbHexString delegate:(id)del;

@end
