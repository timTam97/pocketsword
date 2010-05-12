//
//  PSDictionaryOverlayViewController.h
//  PocketSword
//
//  Created by Nic Carter on 26/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSDictionaryViewController.h"

@interface PSDictionaryOverlayViewController : UIViewController {
	PSDictionaryViewController *dictionaryViewController;
	UIView *grayView;
}

@property (nonatomic, readwrite, retain) PSDictionaryViewController *dictionaryViewController;

@end
