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

@implementation PSDevotionalViewController

BOOL loaded;

- (void)moduleButtonPressed {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	loaded = NO;
	
	devotionalTabBarItem.title = NSLocalizedString(@"TabBarTitleDevotional", @"Devotional");
	todayButton.title = NSLocalizedString(@"TodayButtonTitle", @"");
	
	NSString *devoTitle = [[NSUserDefaults standardUserDefaults] stringForKey: DefaultsLastDevotional];
	if(!devoTitle)
		devoTitle = NSLocalizedString(@"None", @"");
	else {
		if(![[PSModuleController defaultModuleController] primaryDevotional])
			[[PSModuleController defaultModuleController] loadPrimaryDevotional:devoTitle];
	}
	//UIBarButtonItem *moduleButton = [[UIBarButtonItem alloc] initWithTitle:devoTitle style:UIBarButtonItemStyleBordered target:[[PSModuleController defaultModuleController] viewController] action:@selector(toggleModulesList)];
	UIBarButtonItem *moduleButton = [[UIBarButtonItem alloc] initWithTitle:devoTitle style:UIBarButtonItemStyleBordered target:self action:@selector(moduleButtonPressed)];
	self.navigationItem.rightBarButtonItem = moduleButton;
	[moduleButton release];
	
//	devotionalWebView.frame = CGRectMake(0, 44, 320, 367);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devotionalChanged:) name:NotificationDevotionalChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDevotional) name:NotificationNightModeChanged object:nil];
}

- (void)reloadDevotional {
	if(loaded) {
		[self loadDevotionalForDate:devotionalDatePicker.date];
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRotateInfoPane object:nil];
}

- (IBAction)toggleDatePicker:(id)sender {
	if(!loaded)
		return;
	if(devotionalDatePickerView.superview) {
		[ViewController hideModal:devotionalDatePickerView withTiming:0.3];
		//read in what is set in the date picker and show that day's devo
		[self loadDevotionalForDate:devotionalDatePicker.date];
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setDateFormat:@"MMMM d"];
		NSString *dateTitle = [dateFormatter stringFromDate:devotionalDatePicker.date];
		
		[(UIButton*)(self.navigationItem.titleView) setTitle:dateTitle forState:UIControlStateNormal];
	} else {
		UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
		if([UIApplication sharedApplication].statusBarHidden) {
			interfaceOrientation = [self.tabBarController interfaceOrientation];//(UIInterfaceOrientation)[[UIDevice currentDevice] orientation];;
		}
		//UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
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

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(!loaded) {
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setDateFormat:@"MMMM d"];
		NSString *todayTitle = [dateFormatter stringFromDate:[NSDate date]];
		
		UIButton *titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
		titleButton.backgroundColor = [UIColor clearColor];
		titleButton.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont buttonFontSize]];
		titleButton.showsTouchWhenHighlighted = YES;
		[titleButton setTitle:todayTitle forState:UIControlStateNormal];
		[titleButton setImage:[UIImage imageNamed:@"devo-open.png"] forState:UIControlStateNormal];
		[titleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		titleButton.frame = CGRectMake(0, 0, 150, 40);
		[titleButton addTarget: self action: @selector(toggleDatePicker:) forControlEvents: UIControlEventTouchUpInside];
		
		self.navigationItem.titleView = titleButton;
		
		devotionalDatePicker.locale = [NSLocale currentLocale];
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
	NSString *devoHTMLString = [PSModuleController createHTMLString:[devo entryForKey:dateKey] usingPreferences:YES withJS:@"" usingModuleForPreferences:devo.name];
	devoHTMLString = [[devoHTMLString stringByReplacingOccurrencesOfString:@"<!P><br />" withString:@"<p>"] stringByReplacingOccurrencesOfString:@"<!/P>" withString:@"</p>"];
	[devotionalWebView loadHTMLString:devoHTMLString baseURL:nil];
	loaded = YES;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL load = YES;
	
	//NSLog(@"\nDictionaryDescription: requestString: %@", [[request URL] absoluteString]);
	NSDictionary *rData = [PSModuleController dataForLink: [request URL]];
	NSString *entry = nil;
	
	if(rData && [[rData objectForKey:ATTRTYPE_ACTION] isEqualToString:@"showRef"]) {
//		BOOL strongs = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsStrongsPreference];
//		BOOL morphs = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsMorphPreference];
//		SwordManager *swordManager = [SwordManager defaultManager];
//		[swordManager setGlobalOption: SW_OPTION_STRONGS value: SW_OFF ];
//		[swordManager setGlobalOption: SW_OPTION_MORPHS value: SW_OFF ];
		NSArray *array = (NSArray*)[[[PSModuleController defaultModuleController] primaryBible] attributeValueForEntryData:rData cleanFeed:YES];
//		[swordManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
//		[swordManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
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
	
	
	if(entry) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowInfoPane object:entry];
		//[[[PSModuleController defaultModuleController] viewController] showInfo: entry];
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)dealloc {
    [super dealloc];
}


@end
