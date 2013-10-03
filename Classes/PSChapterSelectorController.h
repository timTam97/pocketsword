//
//  PSChapterSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "SwordBook.h"
//#import "PSRefSelectorController.h"

@interface PSChapterSelectorController : UITableViewController {
	SwordBook *book;

	int currentChapter;
	BOOL needToScroll;
}

@property (retain, readwrite) SwordBook *book;

- (void)setBookAndInit:(SwordBook*)newBook;
@end
