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
	id <PSBookmarkFolderColourSelectorDelegate> __weak delegate;
	NSString *currentSelectedColor;
	NSArray *selectableColours;
}

@property (nonatomic, weak) id <PSBookmarkFolderColourSelectorDelegate> delegate;
@property (strong, readwrite) NSString *currentSelectedColor;
@property (strong, readwrite) NSArray *selectableColours;

- (id)initWithColorString:(NSString*)rgbHexString delegate:(id)del;

@end
