//
//  PSBookmarkTableViewCell.h
//  PocketSword
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//


@interface PSBookmarkTableViewCell : UITableViewCell
{
	UILabel *lastAccessedLabel;
}

@property (readwrite, retain) UILabel *lastAccessedLabel;

@end
