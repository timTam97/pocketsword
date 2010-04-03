//
//  PSRefSelectorController.mm
//  PocketSword
//
//  Created by Nic Carter on 3/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "PSRefSelectorController.h"
#import <versemgr.h>
#import "SwordBook.h"
#import "PSModuleController.h"

@implementation PSRefSelectorController

@synthesize refSelectorChapter;
@synthesize refSelectorBook;
@synthesize refSelectorBooks;

- (void)awakeFromNib {
	refToucherMiscScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64, 320, 416)];
	[refToucherMiscScrollView setBackgroundColor:[UIColor darkGrayColor]];
	[refToucherBookScrollView setBackgroundColor:[UIColor darkGrayColor]];
}

- (void)dealloc {
	[refSelectorBooks release];
	[refToucherMiscScrollView release];
	[super dealloc];
}

- (void)toggleNavigation:(ShownTab)shownTab {
	
	if([refToucherView superview]) {
		//[ViewController hideModal:refToucherView withTiming:0.3];
		[refToucherView removeFromSuperview];
	} else {
		if([refToucherMiscScrollView superview])
			[refToucherMiscScrollView removeFromSuperview];
		[self removeButtonsFromMiscScrollView:NO];
		//[self updateRefSelectorBooks];
		[self drawRefToucher:Books];
		//[ViewController showModal:refToucherView withTiming:0.3];
		[(((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window) addSubview:refToucherView];
	}
	return;
	
	if([refSelectorView superview]) {
		//hide the refSelector
		[ViewController hideModal:refSelectorView withTiming:0.3];
		[self setRefSelectorBooks: nil];
	} else {
		//show the refSelector
		if(shownTab == BibleTab) {
			[refSelectorTitle setTitle:[[moduleManager primaryBible] name]];
		} else {
			[refSelectorTitle setTitle:[[moduleManager primaryCommentary] name]];
		}
		[self updateRefSelectorBooks];
		[ViewController showModal:refSelectorView withTiming:0.3];
		
		NSString *curBibRef = [moduleManager getCurrentBibleRef];
		curBibRef = [PSModuleController createRefString: curBibRef];
		NSRange range = [curBibRef rangeOfCharacterFromSet: [NSCharacterSet whitespaceCharacterSet] options: NSBackwardsSearch];
		NSUInteger book = [self bookIndex: [curBibRef substringToIndex: range.location]];
		int chapter = 1;
		sscanf([[[curBibRef componentsSeparatedByString: @" "] lastObject] UTF8String], "%d", &chapter);
		--chapter;
		if (book != NSNotFound) {
			[refSelector selectRow: book inComponent: 0 animated: YES];
			[self setRefSelectorBook: book];
			[refSelector reloadComponent:1];
		}
		[refSelector reloadAllComponents];
		[refSelector selectRow: chapter inComponent: 1 animated: YES];
		[self setRefSelectorChapter: chapter+1];
		[refSelector reloadComponent:2];
		int verse = 1;
		if(shownTab == BibleTab) {
			NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"bibleVersePosition"];
			verse = [versePosition intValue];
			if(verse == 0)
				verse++;
		} else {
			NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: @"commentaryVersePosition"];
			verse = [versePosition intValue];
			if(verse == 0)
				verse++;
		}
		verse--;
		[refSelector selectRow: verse inComponent: 2 animated: YES];
	}
	
}

//
// UIPickerView delegate and data source methods
//
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
	return 3;// One for book, one for chapter, one for verse.
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
	// We have 66 books and numChapters chapters. numChapters is updated when the book
	// changes to reflect the number of chapters in the book
	if (component == 0) {
		//return 66;
		return [refSelectorBooks count];
	}
	else if(component == 1) {
		//return numChapters;
		return [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) chapters];
	} else {
		return [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) verses:refSelectorChapter];
	}
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
	switch (component) {
		case 0 :
			return 180.0;
		case 1 :
			return 60.0;
		case 2 :
			return 60.0;
	}
	return 60.0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	if (component == 0) {
		//return [BOOKS objectAtIndex: row];
		return [((SwordBook*)[refSelectorBooks objectAtIndex:row]) name];
	} else {
		return [NSString stringWithFormat: @"%d", row + 1];
	}
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
	if (component == 0) {
		//DLog(@"picker selected Book row %d = %@", row, [((SwordBook*)[refSelectorBooks objectAtIndex:row]) name]);
		//NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
		// Update the picker to contain the appropriate number of chapters
		//numChapters = [[CHAPTERS objectAtIndex: row] intValue];
		
		refSelectorBook = row;
		refSelectorChapter = 1;//reset to the top chapter
		[pickerView reloadComponent: 1];
		[pickerView selectRow: 0 inComponent: 1 animated: YES];
		[pickerView reloadComponent: 2];
		[pickerView selectRow: 0 inComponent: 2 animated: YES];
		
		//[pool release];
	} else if (component == 1) {
		//DLog(@"picker selected Chapter row %d = actual ch%d", row, (row+1));
		refSelectorChapter = row+1;
		[pickerView reloadComponent: 2];
		[pickerView selectRow: 0 inComponent: 2 animated: YES];
	}
}

- (void)updateRefSelectorBooks {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *currentRefSystemName = [[moduleManager primaryBible] versification];
	if(!currentRefSystemName) //if there are no Bibles, fall back to the commentary versification
		currentRefSystemName = [[moduleManager primaryCommentary] versification];
	if(!currentRefSystemName)
		currentRefSystemName = @"KJV";//if no ref system, default to kjv
	const sword::VerseMgr::System *refSystem = sword::VerseMgr::getSystemVerseMgr()->getVersificationSystem([currentRefSystemName cStringUsingEncoding:NSUTF8StringEncoding]);
	if(!refSystem) {
		refSystem = sword::VerseMgr::getSystemVerseMgr()->getVersificationSystem("KJV");
	}
	int numberOfBooks = refSystem->getBookCount();
	refSelectorOTBookCount = refSystem->getBMAX()[0];
	NSMutableArray *books = [[[NSMutableArray alloc] init] autorelease];
	for(int i = 0; i < numberOfBooks; i++) {
		SwordBook *book = [[SwordBook alloc] initWithBook:refSystem->getBook(i)];
		[books addObject:book];
		//[books insertObject:book atIndex:i];
		[book release];
	}
	//NSLog(@"refSelector: %d books, %d refSelectorOTBookCount", numberOfBooks, refSelectorOTBookCount);
	[self setRefSelectorBooks:books];

	//reset the picker.
	refSelectorBook = 0;
	refSelectorChapter = 1;

	[pool release];
}

- (NSString*)bookName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) name];
}

- (NSString*)bookButtonName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) buttonName];
}

- (NSString*)bookOSISName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) osisName];
}

- (NSInteger)bookIndex:(NSString*)bookName
{
	NSInteger ret = NSNotFound;
	for(int i = 0; i < [refSelectorBooks count]; i++) {
		if([[((SwordBook*)[refSelectorBooks objectAtIndex:i]) name] isEqualToString:bookName]) {
			//DLog(@"\nbookName: %@\nindex: %d", bookName, i);
			ret = i;
			break;
		}
	}
	return ret;
}

- (void)selectedBook:(id)sender {
	NSString *btn = [(UIButton*)sender currentTitle];
	//NSLog(@"pressed book %@", btn);
	for(int i=0;i<[refSelectorBooks count];i++) {
		if([[self bookButtonName:i] isEqualToString:btn]) {
			refSelectorBook = i;
			break;
		}
	}
	[self removeButtonsFromMiscScrollView:YES];
	[refToucherView addSubview:refToucherMiscScrollView];
	[self drawRefToucher:Chapters];
}

- (void)selectedChapter:(id)sender {
	NSString *btn = [(UIButton*)sender currentTitle];
	//NSLog(@"pressed chapter %@", btn);
	refSelectorChapter = [btn integerValue];
	[self removeButtonsFromMiscScrollView:YES];
	[self drawRefToucher:Verses];
}

- (void)selectedVerse:(id)sender {
//	[moduleManager displayBusyIndicator];
	NSString *btn = [(UIButton*)sender currentTitle];
	//NSLog(@"pressed verse %@", btn);
	[self toggleNavigation: BibleTab];
	[[moduleManager viewController] updateViewWithSelectedBook:refSelectorBook chapter:refSelectorChapter verse:[btn integerValue]];
//	[moduleManager hideBusyIndicator];
}

+ (UIButton*)generateButton:(CGRect)frame withTitle:(NSString*)title {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = frame;
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
	button.showsTouchWhenHighlighted = YES;
	[[button layer] setCornerRadius:8.0f];
	[[button layer] setMasksToBounds:YES];
	[[button layer] setBorderWidth:1.0f];

	return button;
}

- (void)removeButtonsFromMiscScrollView:(BOOL)animated {
	if(animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.3];
	}
	for(UIView *view in [refToucherMiscScrollView subviews]) {
		[view removeFromSuperview];
	}
	if(animated) {
		[UIView commitAnimations];
	}
}

- (void)backToBook {
	[self removeButtonsFromMiscScrollView:YES];
	//[self drawRefToucher:Books];
	refToucherTitle.title = NSLocalizedString(@"RefSelectorBookTitle", @"Book");
	[refToucherTitle setRightBarButtonItem:nil animated:YES];
	[refToucherMiscScrollView removeFromSuperview];
}

- (void)backToChapter {
	[self removeButtonsFromMiscScrollView:YES];
	[self drawRefToucher:Chapters];
}

#define BUTTON_WIDTH			48
#define BUTTON_HEIGHT			30
#define BUTTON_X_BORDER_PADDING	10
#define BUTTON_Y_BORDER_PADDING	10
#define BUTTON_X_PADDING		2
#define BUTTON_Y_PADDING		2

//- (void)resetBooks {
//	[self removeButtonsFromMiscScrollView:NO];
//	[self updateRefSelectorBooks];
//}

- (void)drawRefToucher:(RefToucherType)objects {
	int x = BUTTON_X_BORDER_PADDING;
	int y = BUTTON_Y_BORDER_PADDING;//74;
	int numberOfButtons = 1;
	switch(objects) {
		case Books:
		{
			refToucherTitle.title = NSLocalizedString(@"RefSelectorBookTitle", @"Book");
			[refToucherTitle setRightBarButtonItem:nil animated:NO];
			if(!refSelectorBooks) {
				//need to reset the view.
				[self removeButtonsFromMiscScrollView:NO];
				[self updateRefSelectorBooks];
				for(UIView *view in [refToucherBookScrollView subviews]) {
					[view removeFromSuperview];
				}
			} else {
				//NSLog(@"refSelectorBooks already set, not resetting the BookScrollView");
				return;
			}
			numberOfButtons = [refSelectorBooks count];
		}
			break;
		case Chapters:
		{
			numberOfButtons = [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) chapters];
			refToucherTitle.title = NSLocalizedString(@"RefSelectorChapterTitle", @"Chapter");
			UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"RefSelectorBackButtonTitle", @"Back") style:UIBarButtonItemStyleBordered target:self action:@selector(backToBook)];
			[refToucherTitle setRightBarButtonItem:refresh animated:NO];
			[refresh release];
		}
			break;
		case Verses:
		{
			numberOfButtons = [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) verses:refSelectorChapter];
			refToucherTitle.title = NSLocalizedString(@"RefSelectorVerseTitle", @"Verse");
			UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"RefSelectorBackButtonTitle", @"Back") style:UIBarButtonItemStyleBordered target:self action:@selector(backToChapter)];
			[refToucherTitle setRightBarButtonItem:refresh animated:NO];
			[refresh release];
		}
			break;
	}
	
	
	for(int i = 0; i < numberOfButtons; i++) {
		NSString *title;
		if(objects != Books)
			title = [NSString stringWithFormat:@"%d", i+1];
		else
			title = [self bookButtonName:i];
		UIButton *button = [PSRefSelectorController generateButton:CGRectMake(x, y, BUTTON_WIDTH, BUTTON_HEIGHT) withTitle:title];
		if((objects == Books) && (i < refSelectorOTBookCount))
			[[button layer] setBackgroundColor:[[UIColor greenColor] CGColor]];
		else if(objects == Books)
			[[button layer] setBackgroundColor:[[UIColor orangeColor] CGColor]];
		else if(objects == Chapters)
			[[button layer] setBackgroundColor:[[UIColor magentaColor] CGColor]];
		else
			[[button layer] setBackgroundColor:[[UIColor yellowColor] CGColor]];
		
		SEL buttonSelector;
		switch(objects) {
			case Books:
				buttonSelector = @selector(selectedBook:);
				break;
			case Chapters:
				buttonSelector = @selector(selectedChapter:);
				break;
			case Verses:
			default:
				buttonSelector = @selector(selectedVerse:);
				break;
		}
		
		[button addTarget:self action:buttonSelector forControlEvents:UIControlEventTouchUpInside];
		if(objects == Books)
			[refToucherBookScrollView addSubview:button];
		else
			[refToucherMiscScrollView addSubview:button];
		
		x += BUTTON_WIDTH + BUTTON_X_PADDING;
		if(x >= 270) {
			x = BUTTON_X_BORDER_PADDING;
			y += BUTTON_HEIGHT + BUTTON_Y_PADDING;
		}
	}
	if(objects == Books) {
		[refToucherBookScrollView setContentSize:CGSizeMake(320, y+BUTTON_HEIGHT + BUTTON_Y_PADDING)];
		[refToucherBookScrollView scrollRectToVisible:CGRectMake(0, 0, 320, 10) animated:NO];
	} else {
		[refToucherMiscScrollView setContentSize:CGSizeMake(320, y+BUTTON_HEIGHT + BUTTON_Y_PADDING)];
		[refToucherMiscScrollView scrollRectToVisible:CGRectMake(0, 0, 320, 10) animated:NO];
	}
}

@end
