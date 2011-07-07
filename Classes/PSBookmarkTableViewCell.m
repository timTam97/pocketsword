//
//  PSBookmarkTableViewCell.m
//  PocketSword
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkTableViewCell.h"


@implementation PSBookmarkTableViewCell

@synthesize lastAccessedLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self) {
		self.lastAccessedLabel = [[[UILabel alloc] initWithFrame:CGRectMake(170, 25, 105, 15)] autorelease];
		lastAccessedLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		lastAccessedLabel.textColor = [UIColor lightGrayColor];
		lastAccessedLabel.font = [UIFont systemFontOfSize:12.0];
		lastAccessedLabel.textAlignment = UITextAlignmentRight;
		lastAccessedLabel.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:lastAccessedLabel];
	}
	return self;
}

//- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
//    
//    [super setSelected:selected animated:animated];
//    
//    // Configure the view for the selected state.
//}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	lastAccessedLabel.hidden = editing;
	[super setEditing:editing animated:animated];
}

- (void)dealloc {
	self.lastAccessedLabel = nil;
	[super dealloc];
}

@end
