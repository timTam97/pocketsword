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
	IBOutlet UIView *devotionalDatePickerView;
	IBOutlet UIDatePicker *devotionalDatePicker;
	IBOutlet UIBarButtonItem *todayButton;
	IBOutlet UIBarButtonItem *devotionalTitle;
	IBOutlet UIViewController *devotionalPickerViewController;
	
	BOOL loaded;
}

@property (readonly, nonatomic) BOOL loaded;

- (void)loadNewDevotionalEntry;
- (void)loadDevotionalForDate:(NSDate *)date;
- (IBAction)todayButtonPressed;
- (IBAction)moduleButtonPressed;
- (IBAction)toggleDatePicker;
- (UIView*)datePickerButton;

@end
