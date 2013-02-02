//
//  PSDevotionalViewController.h
//  PocketSword
//
//  Created by Nic Carter on 27/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//


@interface PSDevotionalViewController : UIViewController {
	IBOutlet UITabBarItem				*devotionalTabBarItem;
	IBOutlet UIWebView *devotionalWebView;
	IBOutlet UIBarButtonItem *devotionalTitle;

	IBOutlet UIViewController	*devotionalDatePickerViewController;
	IBOutlet UIView				*devotionalDatePickerView;
	IBOutlet UIDatePicker		*devotionalDatePicker;
	IBOutlet UIBarButtonItem	*todayButton;

	NSDate *currentDevotionalDate;
	
	id popoverController;
	BOOL loaded;
	BOOL redisplayDatePicker;
}

@property (readonly, nonatomic) BOOL loaded;
@property (readwrite, retain) NSDate *currentDevotionalDate;

- (void)loadNewDevotionalEntry;
- (void)loadDevotionalForDate:(NSDate *)date;
- (IBAction)todayButtonPressed;
- (IBAction)moduleButtonPressed;
- (IBAction)toggleDatePicker;
- (UIView*)datePickerButton;
- (void)setDevotionalDateTitle:(NSDate*)newDate;

@end
