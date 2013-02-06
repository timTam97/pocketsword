//
//  PSDevotionalViewController.h
//  PocketSword
//
//  Created by Nic Carter on 27/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//


@interface PSDevotionalViewController : UIViewController {
	
	IBOutlet UITabBarItem		*devotionalTabBarItem;
	IBOutlet UIWebView			*devotionalWebView;
	IBOutlet UIBarButtonItem	*devotionalTitle;

	UIView *devPickerView;
	UIDatePicker *devDatePicker;

	NSDate						*currentDevotionalDate;
	
	id							popoverController;
	
	BOOL loaded;
	BOOL redisplayDatePicker;
}

@property (readonly, nonatomic) BOOL loaded;
@property (readwrite, retain) NSDate *currentDevotionalDate;
@property (readwrite, retain) UIView *devPickerView;
@property (readwrite, retain) UIDatePicker *devDatePicker;

- (void)loadNewDevotionalEntry;
- (void)loadDevotionalForDate:(NSDate *)date;
- (void)todayButtonPressed;
- (IBAction)moduleButtonPressed;
- (void)toggleDatePicker;
- (void)setDevotionalDateTitle:(NSDate*)newDate;

@end
