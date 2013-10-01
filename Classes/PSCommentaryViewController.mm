//
//  PSCommentaryViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSCommentaryViewController.h"
#import "PSModuleController.h"
#import "PSTabBarControllerDelegate.h"
#import "PSResizing.h"
#import "SwordManager.h"
#import "SwordDictionary.h"

@implementation PSCommentaryViewController

- (id)init {
	self = [super init];
	if(self) {
		tabType = CommentaryTab;
	}
	return self;
}

@end
