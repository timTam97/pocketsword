//
//  PSVerseSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "SwordBook.h"

@interface PSVerseSelectorController : UITableViewController {
	SwordBook *book;
	NSInteger chapter;
}

@property (retain, readwrite) SwordBook *book;
@property (assign, readwrite) NSInteger chapter;

@end
