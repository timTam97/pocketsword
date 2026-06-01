//
//  PSBibleViewController.m
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSBibleViewController.h"
#import "PSModuleController.h"
#import "PSTabBarControllerDelegate.h"
#import "SwordDictionary.h"
#import "PSBookmarkAddViewController.h"
#import "PocketSword-Swift.h"
#import "PSCommentaryViewController.h"
#import "SwordManager.h"

@implementation PSBibleViewController

@synthesize commentaryView;

- (id)init {
	self = [super init];
	if(self) {
		tabType = BibleTab;
	}
	return self;
}




@end
