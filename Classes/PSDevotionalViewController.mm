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
#import "ViewController.h"
#import "HistoryController.h"

@implementation PSDevotionalViewController

@synthesize loaded;

- (IBAction)moduleButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	loaded = NO;
	redisplayDatePicker = NO;
	
	devotionalTabBarItem.title = NSLocalizedString(@"TabBarTitleDevotional", @"Devotional");
	todayButton.title = NSLocalizedString(@"TodayButtonTitle", @"");
	
	NSString *devoTitle = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];
	if(!devoTitle)
		devoTitle = NSLocalizedString(@"None", @"");
	else {
		if(![[PSModuleController defaultModuleController] primaryDevotional])
			[[PSModuleController defaultModuleController] loadPrimaryDevotional:devoTitle];
	}
	if([PSResizing iPad]) {
		[devotionalTitle setTitle:devoTitle];
		[devotionalDatePickerViewController retain];//try to make our date picker never run away!
	} else {
		self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
		UIBarButtonItem *moduleButton = [[UIBarButtonItem alloc] initWithTitle:devoTitle style:UIBarButtonItemStyleBordered target:self action:@selector(moduleButtonPressed)];
		self.navigationItem.rightBarButtonItem = moduleButton;
		[moduleButton release];
	}
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devotionalChanged:) name:NotificationDevotionalChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDevotional) name:NotificationNightModeChanged object:nil];
}

- (void)reloadDevotional {
	if(loaded) {
		[self loadDevotionalForDate:devotionalDatePicker.date];
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
		//[dateFormatter setDateFormat:@"MMMM d"];
		//dateTitle = [dateFormatter stringFromDate:newDate];
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
	[self loadDevotionalForDate:devotionalDatePicker.date];
	[self setDevotionalDateTitle:devotionalDatePicker.date];
}

- (IBAction)todayButtonPressed {
	[devotionalDatePicker setDate:[NSDate date] animated:YES];
}

- (void)devotionalChanged:(id)object {
	NSString *lastModule = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];
	if(!lastModule) {
		loaded = NO;
		self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"None", @"");
		NSString *devoHTMLString = [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil];
		[devotionalWebView loadHTMLString:devoHTMLString baseURL:nil];
		return;
	}
	SwordDictionary *devo = (SwordDictionary *)[defSwordManager moduleWithName:lastModule];
	NSString *newText = [devo name];
	int i = ([newText length] > 8) ? 8 : [newText length];
	//but ".." is the equiv of another char, so if length <= 9, use the full name.  eg "Swe1917Of" should display full name.
	NSString *t = ([newText length] <= 9) ? newText : [NSString stringWithFormat:@"%@..", [newText substringToIndex:i]];
	
	self.navigationItem.rightBarButtonItem.title = t;
	[self loadDevotionalForDate:devotionalDatePicker.date];
	loaded = YES;
}

//- (void)popoverControllerDidDismissPopover:(UIPopoverController *)poverController {
- (void)popoverControllerDidDismissPopover:(id)poverController {
	[self loadNewDevotionalEntry];
	[popoverController release];
	popoverController = nil;
}

- (void)displayPopover {
	UIView *fromView = [self datePickerButton];
	CGRect fromRect = CGRectMake((fromView.frame.size.width/2.0f), fromView.frame.size.height, 1, 1);
	[popoverController presentPopoverFromRect:fromRect inView:fromView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if([devotionalDatePickerView superview] && ![popoverController isPopoverVisible]) {
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
		 
- (IBAction)toggleDatePicker {
    BOOL iPad = [PSResizing iPad];
	if(!loaded)
		return;
	if([devotionalDatePickerView superview] || [popoverController isPopoverVisible]) {
        if(!iPad) {
			[ViewController hideModal:devotionalDatePickerView withTiming:0.3];
        } else {
            [popoverController dismissPopoverAnimated:YES];
			[popoverController release];
			popoverController = nil;
        }
		[self loadNewDevotionalEntry];
	} else {
		Class cls = NSClassFromString(@"UIPopoverController");
		if(iPad && cls) {
			popoverController = [[cls alloc] initWithContentViewController:devotionalDatePickerViewController];
			[popoverController setDelegate:self];
			[popoverController setContentViewController:devotionalDatePickerViewController];
			[popoverController setPopoverContentSize:CGSizeMake(320.0f, 260.0f)];
			//[popoverController setPopoverContentSize:devotionalDatePickerViewController.view.frame.size];
			[self displayPopover];
		} else {
			UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
			if([UIApplication sharedApplication].statusBarHidden) {
				interfaceOrientation = [[self tabBarController] interfaceOrientation];//(UIInterfaceOrientation)[[UIDevice currentDevice] orientation];;
			}
			if(interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
				devotionalDatePickerView.transform = CGAffineTransformIdentity;
				devotionalDatePickerView.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
			} else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
				devotionalDatePickerView.transform = CGAffineTransformIdentity;
				devotionalDatePickerView.transform = CGAffineTransformMakeRotation(3.0 * M_PI / 2.0);
			} else if(interfaceOrientation == UIInterfaceOrientationPortrait) {
				devotionalDatePickerView.transform = CGAffineTransformIdentity;
			} else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
				devotionalDatePickerView.transform = CGAffineTransformIdentity;
				devotionalDatePickerView.transform = CGAffineTransformMakeRotation(2.0 * M_PI / 2.0);
			}
			[ViewController showModal:devotionalDatePickerView withTiming:0.3];
		}
	}
}

- (UIView*)datePickerButton {
	return (UIView*)self.navigationItem.titleView;
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
		
		devotionalDatePicker.timeZone = [NSTimeZone localTimeZone];
		devotionalDatePicker.calendar = [NSCalendar currentCalendar];
		[devotionalDatePicker setDate:[NSDate date] animated:NO];
		[self loadDevotionalForDate:devotionalDatePicker.date];
	}
//	NSLog(@"pre.y = %d", devotionalWebView.frame.origin.y);
//	devotionalWebView.frame = CGRectMake(0, 44, 320, 367);
//	NSLog(@"post.y = %d", devotionalWebView.frame.origin.y);
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
		NSString *devoHTMLString = [PSModuleController createHTMLString:[NSString stringWithFormat:@"<center>%@</center>", NSLocalizedString(@"NoModulesInstalled", @"")] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil];
		[devotionalWebView loadHTMLString:devoHTMLString baseURL:nil];
		return;
	}
	SwordDictionary *devo = (SwordDictionary *)[defSwordManager moduleWithName:lastModule];
	//NSString *devoHTMLString = [[devo entryForKey:dateKey] stringByAppendingString:@"<p>&nbsp;</p><p>&nbsp;</p>"];
	NSString *devoHTMLString = [NSString stringWithFormat:@"<br/>%@<p>&nbsp;</p><p>&nbsp;</p>", [devo entryForKey:dateKey]];
	devoHTMLString = [PSModuleController createInfoHTMLString:devoHTMLString usingModuleForPreferences:devo.name];
	//devoHTMLString = [PSModuleController createHTMLString:devoHTMLString usingPreferences:YES withJS:@"" usingModuleForPreferences:devo.name];
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


			[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: DefaultsLastRef];
			[[NSUserDefaults standardUserDefaults] setObject: verse forKey: DefaultsBibleVersePosition];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowBibleTab object:nil];
			[HistoryController addHistoryItem:BibleTab];
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

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	[popoverController release];
	popoverController = nil;
	[devotionalDatePickerViewController release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)dealloc {
	[devotionalDatePickerViewController release];
    [super dealloc];
}


@end
