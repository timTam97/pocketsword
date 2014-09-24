//
//  PSDevotionalViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 27/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSDevotionalViewController.h"
#import "globals.h"
#import "SwordManager.h"
#import "SwordDictionary.h"
#import "PSModuleController.h"
#import "PSTabBarControllerDelegate.h"
#import "PSHistoryController.h"
#import "PSResizing.h"

@implementation PSDevotionalViewController

@synthesize loaded, currentDevotionalDate, devDatePicker, devPickerView, devotionalWebView;

- (void)loadView {
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	
	UIWebView *wv = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	wv.delegate = self;
	wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	wv.backgroundColor = [UIColor whiteColor];
	NSString *html = @"<html><body bgcolor=\"white\">@nbsp;</body></html>";
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		html = @"<html><body bgcolor=\"black\">@nbsp;</body></html>";
		wv.backgroundColor = [UIColor blackColor];
	}
	[wv loadHTMLString: html baseURL: nil];
	[baseView addSubview:wv];
	self.devotionalWebView = wv;
	[wv release];
	
	self.view = baseView;
	[baseView release];
}

- (void)setDelegate:(PSTabBarControllerDelegate*)delegate {
	NSString *devoTitle = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];
	if(!devoTitle) {
		devoTitle = NSLocalizedString(@"None", @"");
	} else {
		if(![[PSModuleController defaultModuleController] primaryDevotional])
			[[PSModuleController defaultModuleController] loadPrimaryDevotional:devoTitle];
	}
	UIBarButtonItem *moduleButton = [[UIBarButtonItem alloc] initWithTitle:devoTitle style:UIBarButtonItemStyleBordered target:delegate action:@selector(toggleModulesListFromButton:)];
	self.navigationItem.rightBarButtonItem = moduleButton;
	[moduleButton release];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	loaded = NO;
	redisplayDatePicker = NO;
	self.currentDevotionalDate = [NSDate date];
		
	self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devotionalChanged:) name:NotificationDevotionalChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDevotional) name:NotificationNightModeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDevotionalTitle) name:UIApplicationSignificantTimeChangeNotification object:nil];
	if(UIApplicationWillEnterForegroundNotification) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDevotionalTitle) name:UIApplicationWillEnterForegroundNotification object:nil];
	}
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
	[popoverController release];
	popoverController = nil;
	self.devDatePicker = nil;
	self.devPickerView = nil;
	self.currentDevotionalDate = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)dealloc {
	self.devotionalWebView = nil;
    [super dealloc];
}

- (void)refreshDevotionalTitle {
	[self setDevotionalDateTitle:self.currentDevotionalDate];
}

- (void)reloadDevotional {
	if(loaded) {
		[self loadDevotionalForDate:self.currentDevotionalDate];
		[self setDevotionalDateTitle:self.currentDevotionalDate];
	}
}

- (void)setDevotionalDateTitle:(NSDate*)newDate {
	NSString *dateTitle = @"";
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	if([dateFormatter respondsToSelector:@selector(setDoesRelativeDateFormatting:)]) {
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
		[dateFormatter setDateStyle:NSDateFormatterLongStyle];
		[dateFormatter setDoesRelativeDateFormatting:YES];
		dateTitle = [dateFormatter stringFromDate:newDate];
	} else {
		[dateFormatter setDateFormat:@"MMMM d"];
		dateTitle = [dateFormatter stringFromDate:newDate];
	}
	NSRange foundComma = [dateTitle rangeOfString:@","];
	NSRange foundSpace = [dateTitle rangeOfString:@" "];
	if(foundComma.location != NSNotFound) {
		dateTitle = [dateTitle substringToIndex:foundComma.location];
	} else if(foundSpace.location != NSNotFound && ([dateTitle length] > 6)) {
		NSString *yearValue = [dateTitle substringFromIndex:([dateTitle length] - 5)];
		if([yearValue integerValue] > 2000) {
			dateTitle = [dateTitle substringToIndex:([dateTitle length] - 5)];
		}
		
	}
	
	[(UIButton*)(self.navigationItem.titleView) setTitle:dateTitle forState:UIControlStateNormal];
}

- (void)loadNewDevotionalEntry {
	//read in what is set in the date picker and show that day's devo
	[self loadDevotionalForDate:self.currentDevotionalDate];
	[self setDevotionalDateTitle:self.currentDevotionalDate];
}

- (void)todayButtonPressed {
	[self.devDatePicker setDate:[NSDate date] animated:YES];
}

- (void)devotionalChanged:(id)object {
	NSString *lastModule = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];
	if(!lastModule) {
		loaded = NO;
		self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"None", @"");
		NSString *devoHTMLString = [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil fixedWidth:YES];
		[devotionalWebView loadHTMLString:devoHTMLString baseURL:nil];
		return;
	}
	SwordDictionary *devo = (SwordDictionary *)[defSwordManager moduleWithName:lastModule];
	NSString *newText = [devo name];
	int i = ([newText length] > 8) ? 8 : [newText length];
	//but ".." is the equiv of another char, so if length <= 9, use the full name.  eg "Swe1917Of" should display full name.
	NSString *t = ([newText length] <= 9) ? newText : [NSString stringWithFormat:@"%@..", [newText substringToIndex:i]];
	
	self.navigationItem.rightBarButtonItem.title = t;
	[self loadDevotionalForDate:self.currentDevotionalDate];
	loaded = YES;
}

- (void)popoverControllerDidDismissPopover:(id)poverController {
	self.currentDevotionalDate = [self.devDatePicker date];
	[self loadNewDevotionalEntry];
	[popoverController release];
	popoverController = nil;
	self.devDatePicker = nil;
	self.devPickerView = nil;
}

- (void)displayPopover {
	UIView *fromView = (UIView*)self.navigationItem.titleView;
	CGRect fromRect = CGRectMake((fromView.frame.size.width/2.0f), fromView.frame.size.height, 1, 1);
	[popoverController presentPopoverFromRect:fromRect inView:fromView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if(self.devPickerView && ![popoverController isPopoverVisible]) {
		[self toggleDatePicker];
		redisplayDatePicker = YES;
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
	if([popoverController isPopoverVisible]) {
		[self displayPopover];
	} else if(redisplayDatePicker) {
		redisplayDatePicker = NO;
		[self toggleDatePicker];
	}
}

- (void)createPicker {
	BOOL iPad = [PSResizing iPad];
	static const int BASE_VIEW_HEIGHT = 260;
	CGRect screenRect = [[UIScreen mainScreen] bounds];

	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, (iPad ? 320.0f : screenRect.size.width), BASE_VIEW_HEIGHT)];
	baseView.backgroundColor = [UIColor whiteColor];
	baseView.autoresizingMask = UIViewAutoresizingNone;
	CGFloat xOffset = (iPad ? 0.0f : (screenRect.size.width - 320.0f) / 2.0f);
	UIView *dpView = [[UIView alloc] initWithFrame:CGRectMake(xOffset, (iPad ? 44.0f : 0.0f), (iPad ? 320.0f : screenRect.size.width), (BASE_VIEW_HEIGHT - 44.0f))];
	dpView.autoresizingMask = UIViewAutoresizingNone;
	dpView.backgroundColor = [UIColor whiteColor];
	UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, (BASE_VIEW_HEIGHT - 44.0f))];
	datePicker.datePickerMode = UIDatePickerModeDate;
	[datePicker setDate:self.currentDevotionalDate];
	datePicker.autoresizingMask = UIViewAutoresizingNone;
	[dpView addSubview:datePicker];
	UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, (iPad ? 320.0f : screenRect.size.width), 44.0f)];
	toolbar.barStyle = UIBarStyleBlack;
	UIBarButtonItem *todayToolbarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"TodayButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(todayButtonPressed)];
	[todayToolbarButton setTitleTextAttributes: @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:[UIFont buttonFontSize]], NSForegroundColorAttributeName: [UIColor whiteColor] } forState:UIControlStateNormal];
	UIBarButtonItem *spaceToolbarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *doneToolbarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(toggleDatePicker)];
	[doneToolbarButton setTitleTextAttributes: @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:[UIFont buttonFontSize]], NSForegroundColorAttributeName: [UIColor whiteColor] } forState:UIControlStateNormal];
	UIBarButtonItem *lSpaceToolbarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	lSpaceToolbarButton.width = 20.0f;
	UIBarButtonItem *rSpaceToolbarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	rSpaceToolbarButton.width = 20.0f;

	//toolbarButtons = @[ todayToolbarButton, spaceToolbarButton, doneToolbarButton ];
	NSArray *toolbarButtons = [NSArray arrayWithObjects:lSpaceToolbarButton, todayToolbarButton, spaceToolbarButton, doneToolbarButton, rSpaceToolbarButton, nil];
	[todayToolbarButton release];
	[spaceToolbarButton release];
	[doneToolbarButton release];
	[lSpaceToolbarButton release];
	[rSpaceToolbarButton release];
	toolbar.items = toolbarButtons;
	
	[baseView addSubview:dpView];
	[dpView release];
	[baseView addSubview:toolbar];
	[toolbar release];
	
	// need to keep a reference to the UIDatePicker for when the today button is tapped.
	//    or we bite the bullet and start using blocks & do it all here? :P
	self.devDatePicker = datePicker;
	[datePicker release];
	
	// need to keep a reference to the baseView to show/hide it.
	self.devPickerView = baseView;
	[baseView release];
	
}

- (void)toggleDatePicker {
    BOOL iPad = [PSResizing iPad];
	if(!loaded)
		return;
	if(self.devPickerView || [popoverController isPopoverVisible]) {
		self.currentDevotionalDate = [self.devDatePicker date];
        if(!iPad) {
			[PSTabBarControllerDelegate hideModal:self.devPickerView withTiming:0.3];
        } else {
            [popoverController dismissPopoverAnimated:YES];
			[popoverController release];
			popoverController = nil;
        }
		self.devDatePicker = nil;
		self.devPickerView = nil;
		[self loadNewDevotionalEntry];
	} else {
		[self createPicker];
		if(iPad) {
			UIViewController *dpVC = [[UIViewController alloc] init];
			dpVC.view = self.devPickerView;
			popoverController = [[UIPopoverController alloc] initWithContentViewController:dpVC];
			[popoverController setDelegate:self];
			[popoverController setPopoverContentSize:CGSizeMake(320.0f, 260.0f)];
			[self displayPopover];
			[dpVC release];
		} else {
			if([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0f) {
				UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
				if([UIApplication sharedApplication].statusBarHidden) {
					interfaceOrientation = [[self tabBarController] interfaceOrientation];
				}
				if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
					self.devPickerView.transform = CGAffineTransformIdentity;
					self.devPickerView.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
				} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
					self.devPickerView.transform = CGAffineTransformIdentity;
					self.devPickerView.transform = CGAffineTransformMakeRotation(3.0 * M_PI / 2.0);
				} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
					self.devPickerView.transform = CGAffineTransformIdentity;
				} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
					self.devPickerView.transform = CGAffineTransformIdentity;
					self.devPickerView.transform = CGAffineTransformMakeRotation(2.0 * M_PI / 2.0);
				}
			}
			self.devDatePicker.frame = CGRectMake(0, 44, 320, 216);
			[PSTabBarControllerDelegate showModal:self.devPickerView withTiming:0.3];
		}
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(!loaded) {
		
		UIButton *titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
		titleButton.backgroundColor = [UIColor clearColor];
		titleButton.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont buttonFontSize]];
		titleButton.showsTouchWhenHighlighted = YES;
		[titleButton setTitle:@"" forState:UIControlStateNormal];
		[titleButton setImage:[UIImage imageNamed:@"devo-open.png"] forState:UIControlStateNormal];
		[titleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		titleButton.frame = CGRectMake(0, 0, 150, 40);
		[titleButton addTarget: self action: @selector(toggleDatePicker) forControlEvents: UIControlEventTouchUpInside];
		
		self.navigationItem.titleView = titleButton;
		[self setDevotionalDateTitle:[NSDate date]];
		
		self.currentDevotionalDate = [NSDate date];
		[self loadDevotionalForDate:self.currentDevotionalDate];
	} else {
		[self setDevotionalDateTitle:self.currentDevotionalDate];
	}
}

- (void)loadDevotionalForDate:(NSDate *)date {
	if(!date) {
		loaded = NO;
		return;
	}
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"MM.dd"];
	NSString *dateKey = [dateFormatter stringFromDate:date];
	NSString *lastModule = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];
	if(!lastModule) {
		loaded = NO;
		NSString *devoHTMLString = [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil fixedWidth:YES];
		[devotionalWebView loadHTMLString:devoHTMLString baseURL:nil];
		return;
	}
	SwordDictionary *devo = (SwordDictionary *)[defSwordManager moduleWithName:lastModule];
	NSString *devoHTMLString = [NSString stringWithFormat:@"<br/>%@<p>&nbsp;</p><p>&nbsp;</p>", [devo entryForKey:dateKey]];
	devoHTMLString = [PSModuleController createInfoHTMLString:devoHTMLString usingModuleForPreferences:devo.name];
	devoHTMLString = [[devoHTMLString stringByReplacingOccurrencesOfString:@"<!P><br />" withString:@"<p>"] stringByReplacingOccurrencesOfString:@"<!/P><br />" withString:@"</p>"];
	[devotionalWebView loadHTMLString:devoHTMLString baseURL:nil];
	loaded = YES;
}

- (BOOL)isDailyReadingPlanner:(NSString *)module {
	BOOL planner = NO;
	if([module isEqualToString:@"BibleCompanion"]) {
		planner = YES;
	} else if([module isEqualToString:@"MCheyne"]) {
		planner = YES;
	} else if([module isEqualToString:@"OneYearRead"]) {
		planner = YES;
	} else if([module isEqualToString:@"CitireAnuala"]) {
		planner = YES;
	}
	return planner;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	NSString *lastModule = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];

	//NSLog(@"\nDictionaryDescription: requestString: %@\nDD: %@", [[request URL] absoluteString], lastModule);
	
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;
	
	if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
		
		if([self isDailyReadingPlanner:lastModule]) {
			// if we are going to jump straight to the verse in the Bible tab:
			NSString *chapter, *verse;
			
			NSString *ref = [rData objectForKey:ATTRTYPE_VALUE];
			NSArray *comps = [ref componentsSeparatedByString:@":"];
			
			if([comps count] > 1) {
				//we have a verse
				verse = [comps objectAtIndex:1];
				chapter = [comps objectAtIndex:0];//just the book & ch
			} else {
				verse = @"1";
				chapter = ref;
			}
			chapter = [[[chapter stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByReplacingOccurrencesOfString:@"+" withString:@" "];

			[[NSUserDefaults standardUserDefaults] setObject: [PSModuleController createRefString:chapter] forKey: DefaultsLastRef];
			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowBibleTab object:nil];
			[PSHistoryController addHistoryItem:BibleTab];
			entry = nil;
			load = NO;
			
		} else {
			// otherwise we show the info pane.
				
			NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData cleanFeed:YES];
			NSMutableString *tmpEntry = [@"" mutableCopy];
			for(NSDictionary *dict in array) {
				NSString *curRef = [PSModuleController createRefString: [dict objectForKey:SW_OUTPUT_REF_KEY]];
				[tmpEntry appendFormat:@"<b><a href=\"bible:///%@\">%@</a>:</b> ", curRef, curRef];
				[tmpEntry appendFormat:@"%@<br />", [dict objectForKey:SW_OUTPUT_TEXT_KEY]];
			}
			if(![tmpEntry isEqualToString:@""]) {//"[ ]" appear in the TEXT_KEYs where notes should appear, so we remove them here!
				entry = [[tmpEntry stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
				entry = [PSModuleController createInfoHTMLString: entry usingModuleForPreferences:[[[PSModuleController defaultModuleController] primaryBible] name]];
			}
			[tmpEntry release];
		}
	}
	
	
	if(entry) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];
		load = NO;
	}
	
	
	[pool release];
	return load;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


@end
