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
#import "PSChapterSelectorController.h"

@implementation PSRefSelectorController

@synthesize refSelectorChapter;
@synthesize refSelectorBook;
@synthesize refSelectorBooks;
@synthesize refSelectorBooksIndex;
@synthesize currentlyViewedBookName;

//- (void)awakeFromNib {
//	refToucherMiscScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64, 320, 416)];
//	[refToucherMiscScrollView setBackgroundColor:[UIColor blackColor]];
//	[refToucherBookScrollView setBackgroundColor:[UIColor blackColor]];
//
//}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetBooks:) name:NotificationRefSelectorResetBooks object:nil];
}

- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationRefSelectorResetBooks object:nil];
}

- (void)resetBooks:(NSNotification *)notification {
	self.refSelectorBooks = nil;
}

- (void)viewWillAppear:(BOOL)animated {
	NSIndexPath *tableSelection = [refTable indexPathForSelectedRow];
	[refTable deselectRowAtIndexPath:tableSelection animated:YES];
    [super viewWillAppear:animated];
}

- (void)dealloc {
	[refSelectorBooks release];
	[refSelectorBooksIndex release];
//	[refToucherMiscScrollView release];
	[currentlyViewedBookName release];
	[super dealloc];
}

//- (void)hideNavigation {
//	if([refToucherView superview]) {
//		[refToucherView removeFromSuperview];
//	}
//	if([refNavigationController.view superview]) {
//		[ViewController hideModal:refNavigationController.view withTiming:0.3];
//	}
//}

- (void)toggleNavigation {
	//BOOL refPickerMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"refPickerPreference"];
	
	if([refNavigationController.view superview]) {
		//[ViewController hideModal:refNavigationController.view withTiming:0.3];
		[[viewController tabBarController] dismissModalViewControllerAnimated:YES];
	} else {
		[self updateRefSelectorBooks];
		[refTable reloadData];
		refNavigationController.navigationBar.topItem.title = NSLocalizedString(@"RefSelectorBookTitle", @"Book");
		UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(toggleNavigation)];
		refNavigationController.navigationBar.topItem.leftBarButtonItem = cancel;
		[cancel release];
		//refNavigationController.navigationItem.title = NSLocalizedString(@"RefSelectorBookTitle", @"Book");
		[refNavigationController popToRootViewControllerAnimated:NO];
		//[ViewController showModal:refNavigationController.view withTiming:0.3];
		[[viewController tabBarController] presentModalViewController:refNavigationController animated:YES];

		NSIndexPath *ip = nil;
		int bookCount = [refSelectorBooks count];
		for(int i=0;i<bookCount;i++) {
			if([currentlyViewedBookName isEqualToString:[((SwordBook*)[refSelectorBooks objectAtIndex:i]) name]]) {
				ip = [NSIndexPath indexPathForRow: 0 inSection: i];
			}
		}
		[refTable scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
	}
	return;
	
/*	if(!refPickerMode) {
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
	}
	
	if([refSelectorView superview]) {
		//hide the refSelector
		[ViewController hideModal:refSelectorView withTiming:0.3];
		[self setRefSelectorBooks: nil];
	} else {
		//show the refSelector
		if(shownTab == BibleTab) {
			[refSelectorTitle setTitle:[[[PSModuleController defaultModuleController] primaryBible] name]];
		} else {
			[refSelectorTitle setTitle:[[[PSModuleController defaultModuleController] primaryCommentary] name]];
		}
		[self updateRefSelectorBooks];
		[ViewController showModal:refSelectorView withTiming:0.3];
		
		NSString *curBibRef = [[PSModuleController defaultModuleController] getCurrentBibleRef];
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
			NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsBibleVersePosition];
			verse = [versePosition intValue];
			if(verse == 0)
				verse++;
		} else {
			NSString *versePosition = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsCommentaryVersePosition];
			verse = [versePosition intValue];
			if(verse == 0)
				verse++;
		}
		verse--;
		[refSelector selectRow: verse inComponent: 2 animated: YES];
	}*/
	
}

/*- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
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
}*/

- (void)updateRefSelectorBooks {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *currentRefSystemName = [[[PSModuleController defaultModuleController] primaryBible] versification];
	if(!currentRefSystemName) //if there are no Bibles, fall back to the commentary versification
		currentRefSystemName = [[[PSModuleController defaultModuleController] primaryCommentary] versification];
	if(!currentRefSystemName)
		currentRefSystemName = @"KJV";//if no ref system, default to kjv
	const sword::VerseMgr::System *refSystem = sword::VerseMgr::getSystemVerseMgr()->getVersificationSystem([currentRefSystemName cStringUsingEncoding:NSUTF8StringEncoding]);
	if(!refSystem) {
		refSystem = sword::VerseMgr::getSystemVerseMgr()->getVersificationSystem("KJV");
	}
	int numberOfBooks = refSystem->getBookCount();
	refSelectorOTBookCount = refSystem->getBMAX()[0];
	NSMutableArray *books = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray *booksIndex = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray *booksFullIndex = [[[NSMutableArray alloc] init] autorelease];
	//BOOL addNextBook = NO;
	for(int i = 0; i < numberOfBooks; i++) {
		SwordBook *book = [[SwordBook alloc] initWithBook:refSystem->getBook(i)];
		[books addObject:book];
		//if(!(i%2) || addNextBook) {
		//if(addNextBook)
		//addNextBook = NO;
			if(![booksFullIndex containsObject:[book shortName]])
				[booksIndex addObject:[book shortName]];
			else {
				//addNextBook = YES;
			}
		//}
		[booksFullIndex addObject:[book shortName]];
		[book release];
	}
	//NSLog(@"refSelector: %d books, %d refSelectorOTBookCount", numberOfBooks, refSelectorOTBookCount);
	NSString *currentBook = [PSModuleController getCurrentBibleRef];
	currentBook = [[currentBook componentsSeparatedByString:@":"] objectAtIndex:0];
	NSRange spaceRange = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
	if(spaceRange.location != NSNotFound) {
		currentBook = [currentBook substringToIndex: spaceRange.location];
	}

	[self setRefSelectorBooks:books];
	[self setRefSelectorBooksIndex:booksIndex];
	[self setCurrentlyViewedBookName:currentBook];

	//reset the picker.
	refSelectorBook = 0;
	refSelectorChapter = 1;

	[pool release];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [refSelectorBooks count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"] autorelease];
	}
	
	cell.textLabel.text = [self bookName:indexPath.section];
	if([currentlyViewedBookName isEqualToString:cell.textLabel.text]) {
		cell.textLabel.textColor = [UIColor blueColor];
	} else {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"]) {
			cell.textLabel.textColor = [UIColor whiteColor];
		} else {
			cell.textLabel.textColor = [UIColor blackColor];
		}
	}
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"nightModePreference"]) {
		cell.backgroundColor = [UIColor blackColor];
	} else {
		cell.backgroundColor = [UIColor whiteColor];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	PSChapterSelectorController *chapterSelectorController = [[PSChapterSelectorController alloc] init];
	NSDictionary *proxyDict = [NSDictionary dictionaryWithObject:viewController forKey:@"viewController"];
	NSDictionary *optionsDict = [NSDictionary dictionaryWithObject:proxyDict forKey:UINibExternalObjects];
	[[NSBundle mainBundle] loadNibNamed:@"PSChapterSelectorController" owner:chapterSelectorController options:optionsDict];
	[chapterSelectorController setBookAndInit: [refSelectorBooks objectAtIndex:indexPath.section]];
	[refNavigationController pushViewController:chapterSelectorController animated:YES];
	[chapterSelectorController release];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	//jump to ch1, v1 of that book.
	//[ViewController hideModal:self.navigationController.view withTiming:0.3];
	[[viewController tabBarController] dismissModalViewControllerAnimated:YES];
	[viewController updateViewWithSelectedBookName:[[refSelectorBooks objectAtIndex:indexPath.section] name] chapter:1 verse:1];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	return self.refSelectorBooksIndex;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	for(int i=0;i<[refSelectorBooks count];i++) {
		if([[self bookShortName:i] isEqualToString:[self.refSelectorBooksIndex objectAtIndex:index]])
			return i;
	}
	return 0;
}

- (NSString*)bookName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) name];
}

- (NSString*)bookShortName:(NSInteger)bookIndex
{
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) shortName];
}

- (NSString*)bookOSISName:(NSInteger)bookIndex {
	return [((SwordBook*)[refSelectorBooks objectAtIndex:bookIndex]) osisName];
}

- (NSInteger)bookIndex:(NSString*)bookName {
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

/*- (void)selectedBook:(id)sender {
	NSString *btn = [(UIButton*)sender currentTitle];
	//NSLog(@"pressed book %@", btn);
	for(int i=0;i<[refSelectorBooks count];i++) {
		if([[self bookShortName:i] isEqualToString:btn]) {
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
//	[[PSModuleController defaultModuleController] displayBusyIndicator];
	NSString *btn = [(UIButton*)sender currentTitle];
	//NSLog(@"pressed verse %@", btn);
	[self toggleNavigation: BibleTab];
	[[[PSModuleController defaultModuleController] viewController] updateViewWithSelectedBook:refSelectorBook chapter:refSelectorChapter verse:[btn integerValue]];
//	[[PSModuleController defaultModuleController] hideBusyIndicator];
}

+ (UIButton*)generateButton:(CGRect)frame withTitle:(NSString*)title {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = frame;
	button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	[button setTitle:title forState:UIControlStateNormal];
	[button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
	button.showsTouchWhenHighlighted = YES;
	//[[button layer] setCornerRadius:8.0f];
	[[button layer] setMasksToBounds:YES];
	[[button layer] setBorderWidth:1.0f];
	[[button layer] setBorderColor:[[UIColor brownColor] CGColor]];

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
	[self drawRefToucher:Books];
}

- (void)backToChapter {
	[self removeButtonsFromMiscScrollView:YES];
	[self drawRefToucher:Chapters];
}

#define BUTTON_WIDTH			50
#define BUTTON_HEIGHT			35
#define BUTTON_X_BORDER_PADDING	10
#define BUTTON_Y_BORDER_PADDING	10
#define BUTTON_X_PADDING		0
#define BUTTON_Y_PADDING		0

- (void)drawRefToucher:(RefToucherType)objects {
	int x = BUTTON_X_BORDER_PADDING;
	int y = BUTTON_Y_BORDER_PADDING;
	int numberOfButtons = 1;
	switch(objects) {
		case Books:
		{
			refToucherTitle.title = NSLocalizedString(@"RefSelectorBookTitle", @"Book");
			UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(hideNavigation)];
			[refToucherTitle setLeftBarButtonItem:cancel animated:NO];
			[cancel release];
			if([refToucherMiscScrollView superview])
				[refToucherMiscScrollView removeFromSuperview];
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
			refToucherTitle.title = [NSString stringWithFormat:@"%@ %@", [self bookName:refSelectorBook], NSLocalizedString(@"RefSelectorChapterTitle", @"Chapter")];
			UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"RefSelectorBackButtonTitle", @"Back") style:UIBarButtonItemStyleBordered target:self action:@selector(backToBook)];
			[refToucherTitle setLeftBarButtonItem:refresh animated:YES];
			[refresh release];
		}
			break;
		case Verses:
		{
			numberOfButtons = [((SwordBook*)[refSelectorBooks objectAtIndex:refSelectorBook]) verses:refSelectorChapter];
			refToucherTitle.title = [NSString stringWithFormat:@"%@ %d %@", [self bookName:refSelectorBook], refSelectorChapter, NSLocalizedString(@"RefSelectorVerseTitle", @"Verse")];
			UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"RefSelectorBackButtonTitle", @"Back") style:UIBarButtonItemStyleBordered target:self action:@selector(backToChapter)];
			[refToucherTitle setLeftBarButtonItem:refresh animated:YES];
			[refresh release];
		}
			break;
	}
	
	
	for(int i = 0; i < numberOfButtons; i++) {
		NSString *title;
		if(objects != Books)
			title = [NSString stringWithFormat:@"%d", i+1];
		else
			title = [self bookShortName:i];
		UIButton *button = [PSRefSelectorController generateButton:CGRectMake(x, y, BUTTON_WIDTH, BUTTON_HEIGHT) withTitle:title];
//		CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
//		[gradientLayer setBounds:[button bounds]];
//		[gradientLayer setPosition:CGPointMake([button bounds].size.width/2, [button bounds].size.height/2)];
//		[gradientLayer setStartPoint:CGPointMake(0.5, 0.0)];
//		[gradientLayer setEndPoint:CGPointMake(0.5, 0.5)];
//		[[button layer] insertSublayer:gradientLayer atIndex:0];
		
		if((objects == Books) && (i < refSelectorOTBookCount)) {
			[button setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
			//[gradientLayer setColors:[NSArray arrayWithObjects:(id)[[UIColor whiteColor] CGColor], (id)[[UIColor greenColor] CGColor], nil]];
			//[[button layer] setBackgroundColor:[[UIColor colorWithPatternImage:[UIImage imageNamed:@"ref-background.jpeg"]] CGColor]];
		} else if(objects == Books) {
			[button setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
			//[gradientLayer setColors:[NSArray arrayWithObjects:(id)[[UIColor whiteColor] CGColor], (id)[[UIColor orangeColor] CGColor], nil]];
			//[[button layer] setBackgroundColor:[[UIColor colorWithPatternImage:[UIImage imageNamed:@"ref-background.jpeg"]] CGColor]];
		} else if(objects == Chapters) {
			[button setTitleColor:[UIColor magentaColor] forState:UIControlStateNormal];
			//[gradientLayer setColors:[NSArray arrayWithObjects:(id)[[UIColor whiteColor] CGColor], (id)[[UIColor magentaColor] CGColor], nil]];
			//[[button layer] setBackgroundColor:[[UIColor colorWithPatternImage:[UIImage imageNamed:@"ref-background.jpeg"]] CGColor]];
		} else {
			[button setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
			//[gradientLayer setColors:[NSArray arrayWithObjects:(id)[[UIColor whiteColor] CGColor], (id)[[UIColor yellowColor] CGColor], nil]];
			//[[button layer] setBackgroundColor:[[UIColor colorWithPatternImage:[UIImage imageNamed:@"ref-background.jpeg"]] CGColor]];
		}
		//[gradientLayer release];
		
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
	int width = (numberOfButtons > 5) ? ((6 * (BUTTON_WIDTH + BUTTON_X_PADDING)) - BUTTON_X_PADDING) : ((numberOfButtons * (BUTTON_WIDTH + BUTTON_X_PADDING)) - BUTTON_X_PADDING);
	int height = (numberOfButtons % 6) ? (y + BUTTON_HEIGHT + BUTTON_Y_PADDING - BUTTON_Y_BORDER_PADDING) : (y - BUTTON_Y_BORDER_PADDING);
	UIView *background = [[UIView alloc] initWithFrame:CGRectMake(BUTTON_X_BORDER_PADDING, BUTTON_Y_BORDER_PADDING, width, height)];
	[background setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"ref-background.jpeg"]]];
	UIView *filler = nil;
	if(numberOfButtons > 5 && (numberOfButtons % 6)) {
		//we need some filler to hide part of the background
		height = BUTTON_HEIGHT;
		width = (6 - (numberOfButtons % 6)) * BUTTON_WIDTH;
		filler = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
		[filler setBackgroundColor:[UIColor blackColor]];
	}
	
	if(objects == Books) {
		[refToucherBookScrollView setContentSize:CGSizeMake(320, y+BUTTON_HEIGHT + BUTTON_Y_PADDING + BUTTON_Y_BORDER_PADDING)];
		[refToucherBookScrollView scrollRectToVisible:CGRectMake(0, 0, 320, 10) animated:NO];
		[refToucherBookScrollView insertSubview:background atIndex:0];
		if(filler) {
			[refToucherBookScrollView addSubview:filler];
			[filler release];
		}
	} else {
		[refToucherMiscScrollView setContentSize:CGSizeMake(320, y+BUTTON_HEIGHT + BUTTON_Y_PADDING + BUTTON_Y_BORDER_PADDING)];
		[refToucherMiscScrollView scrollRectToVisible:CGRectMake(0, 0, 320, 10) animated:NO];
		[refToucherMiscScrollView insertSubview:background atIndex:0];
		if(filler) {
			[refToucherMiscScrollView addSubview:filler];
			[filler release];
		}
	}
	[background release];
}
*/
@end
