//
//  PSDevotionalViewController.h
//  PocketSword
//
//  Created by Nic Carter on 27/05/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

@class PSTabBarControllerDelegate;

@interface PSDevotionalViewController : UIViewController <UIWebViewDelegate, UIPopoverControllerDelegate> {
	
	UIWebView			*devotionalWebView;

	UIView *devPickerView;
	UIDatePicker *devDatePicker;

	NSDate						*currentDevotionalDate;
	
	UIPopoverController			*popoverController;
	
	BOOL loaded;
	BOOL redisplayDatePicker;
}

@property (readonly, nonatomic) BOOL loaded;
@property (retain) NSDate *currentDevotionalDate;
@property (retain) UIView *devPickerView;
@property (retain) UIDatePicker *devDatePicker;
@property (retain) UIWebView *devotionalWebView;

- (void)setDelegate:(PSTabBarControllerDelegate*)delegate;

- (void)loadNewDevotionalEntry;
- (void)loadDevotionalForDate:(NSDate *)date;
- (void)todayButtonPressed;
- (void)toggleDatePicker;
- (void)setDevotionalDateTitle:(NSDate*)newDate;

@end
