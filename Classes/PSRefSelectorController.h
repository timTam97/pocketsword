//
//  PSRefSelectorController.h
//  PocketSword
//
//  Created by Nic Carter on 3/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"

typedef enum {
    Books = 1,
    Chapters,
	Verses
} RefToucherType;


@interface PSRefSelectorController : UITableViewController {
	NSArray *refSelectorBooks;
	NSArray *refSelectorBooksIndex;
	NSString *currentlyViewedBookName;
	
	//int refSelectorOTBookCount;
	NSInteger refSelectorBook;
	NSInteger refSelectorChapter;
}

@property (assign) NSInteger refSelectorBook;
@property (assign) NSInteger refSelectorChapter;
@property (retain, readwrite) NSArray *refSelectorBooks;
@property (retain, readwrite) NSArray *refSelectorBooksIndex;
@property (retain, readwrite) NSString *currentlyViewedBookName;

- (void)resetBooks:(NSNotification *)notification;
- (void)updateRefSelectorBooks;
- (NSString*)bookName:(NSInteger)bookIndex;
- (NSString*)bookShortName:(NSInteger)bookIndex;
- (NSString*)bookOSISName:(NSInteger)bookIndex;
- (NSInteger)bookIndex:(NSString*)bookName;
- (void)willShowNavigation;
- (void)setupNavigation;

@end
