//
//  PSBibleViewController.h
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSWebView.h"
#import "globals.h"

@class PSTabBarControllerDelegate;

@interface PSModuleViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate, PSWebViewDelegate> {

	UISegmentedControl			*titleSegmentedControl;
	PSWebView					*webView;
	UIBarButtonItem				*moduleButton;
	
	PSTabBarControllerDelegate	*delegate;
	
	NSString					*refToShow;
	NSString					*jsToShow;
	NSString					*tappedVerse;
	BOOL						isFullScreen;
	UIView						*previousTabBarView;
	BOOL						finishedLoading;
	NSArray						*versePositionArray;
	NSInteger					currentShownVerse;
	NSInteger					verseToShow;
	
	ShownTab					tabType;
}

@property (copy, readwrite) NSString					*refToShow;
@property (copy, readwrite) NSString					*jsToShow;
@property (copy, readwrite) NSString					*tappedVerse;
@property (readonly)		BOOL						isFullScreen;
@property (retain)			UIBarButtonItem				*moduleButton;
@property (retain)			UISegmentedControl			*titleSegmentedControl;
@property (assign)			PSTabBarControllerDelegate	*delegate;
@property (retain)			PSWebView					*webView;
@property (retain)			NSArray						*versePositionArray;

- (void)setDelegate:(PSTabBarControllerDelegate*)vc;
- (PSTabBarControllerDelegate*)delegate;

- (void)setVerseToShow:(NSInteger)verseNumber;
- (void)scrollToVerse:(NSInteger)verseNumber;

- (void)toggleFullscreen;
- (void)switchToFullscreen;
- (void)switchToNormalscreen;

- (void)setEnabledNextButton:(BOOL)enabled;
- (void)setEnabledPreviousButton:(BOOL)enabled;
- (void)setTabTitle:(NSString*)title;
- (void)setModuleNameViaNotification;

+ (void)setVoiceOverForRefSegmentedControlSubviews:(NSArray *)subviews;

@end
