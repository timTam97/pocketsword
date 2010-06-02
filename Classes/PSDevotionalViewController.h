//
//  PSDevotionalViewController.h
//  PocketSword
//
//  Created by Nic Carter on 27/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//


@interface PSDevotionalViewController : UIViewController {
	IBOutlet UIWebView *devotionalWebView;
	IBOutlet UIView *devotionalDatePickerView;
	IBOutlet UIDatePicker *devotionalDatePicker;
	
	IBOutlet id moduleManager;
}

- (void)loadDevotionalForDate:(NSDate *)date;
- (IBAction)todayButtonPressed;
- (IBAction)toggleDatePicker:(id)sender;

@end
