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


@interface PSRefSelectorController : UIViewController {
	NSArray *refSelectorBooks;
	NSArray *refSelectorBooksIndex;
	NSString *currentlyViewedBookName;
	
	int refSelectorOTBookCount;
	NSInteger refSelectorBook;
	NSInteger refSelectorChapter;
	
	// UIPickerView version of the ref selector
	IBOutlet UIPickerView		*refSelector;
	IBOutlet UIView				*refSelectorView;
	IBOutlet UIBarButtonItem	*refSelectorTitle;
	
	// UIButton version of the ref selector
	IBOutlet UIView				*refToucherView;
	IBOutlet UINavigationItem	*refToucherTitle;
	IBOutlet UIScrollView		*refToucherBookScrollView;
	UIScrollView					*refToucherMiscScrollView;
	
	// UITableView version of the ref selector
	IBOutlet UITableView					*refTable;
	IBOutlet UINavigationController	*refNavigationController;

	IBOutlet id moduleManager;
}

@property (assign) NSInteger refSelectorBook;
@property (assign) NSInteger refSelectorChapter;
@property (retain, readwrite) NSArray *refSelectorBooks;
@property (retain, readwrite) NSArray *refSelectorBooksIndex;
@property (retain, readwrite) NSString *currentlyViewedBookName;

// UIPickerView version of the ref selector
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component;
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component;
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;

// UIButton version of the ref selector
- (void)removeButtonsFromMiscScrollView:(BOOL)animated;
- (void)drawRefToucher:(RefToucherType)objects;
- (void)selectedBook:(id)sender;
- (void)selectedChapter:(id)sender;
- (void)selectedVerse:(id)sender;
- (void)hideNavigation;

// common methods for each version
- (void)updateRefSelectorBooks;
- (NSString*)bookName:(NSInteger)bookIndex;
- (NSString*)bookShortName:(NSInteger)bookIndex;
- (NSString*)bookOSISName:(NSInteger)bookIndex;
- (NSInteger)bookIndex:(NSString*)bookName;
- (void)toggleNavigation:(ShownTab)shownTab;

@end
