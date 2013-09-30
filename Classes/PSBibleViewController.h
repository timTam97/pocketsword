//
//  PSBibleViewController.h
//  PocketSword
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSWebView.h"
#import "globals.h"

@class PSCommentaryViewController;
@class ViewController;

@interface PSBibleViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate, PSWebViewDelegate> {

	UIBarButtonItem			*bibleSearchButton;
	UISegmentedControl		*titleSegmentedControl;
	IBOutlet PSWebView		*webView;
	UIBarButtonItem			*switchModuleButton;
	
	PSCommentaryViewController	*commentaryView;
	ViewController				*delegate;
	
	NSString					*refToShow;
	NSString					*jsToShow;
	NSString					*tappedVerse;
	BOOL						isFullScreen;
	UIView						*previousTabBarView;
	BOOL						finishedLoading;
	
	ShownTab					tabType;
}

@property (copy, readwrite) NSString					*refToShow;
@property (copy, readwrite) NSString					*jsToShow;
@property (copy, readwrite) NSString					*tappedVerse;
@property (readonly)		BOOL						isFullScreen;
@property (assign)			PSCommentaryViewController	*commentaryView;
@property (retain)			UIBarButtonItem				*switchModuleButton;
@property (retain)			UISegmentedControl			*titleSegmentedControl;
@property (assign)			ViewController				*delegate;
@property (retain)			PSWebView					*webView;

- (void)setDelegate:(ViewController*)vc;

- (void)toggleFullscreen;
- (void)switchToFullscreen;
- (void)switchToNormalscreen;

- (void)setEnabledNextButton:(BOOL)enabled;
- (void)setEnabledPreviousButton:(BOOL)enabled;
- (void)setTabTitle:(NSString*)title;
- (void)setModuleNameViaNotification;

@end
