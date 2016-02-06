//
//  PSDictionaryEntryViewController.h
//  PocketSword
//
//  Created by Nic Carter on 27/09/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

@interface PSDictionaryEntryViewController : UIViewController <UIWebViewDelegate> {
	UIWebView *dictionaryDescriptionWebView;
	NSString *entryHTML;
	NSString *entryTitle;
}

@property (strong) NSString *entryHTML;
@property (strong) NSString *entryTitle;
@property (strong) UIWebView *dictionaryDescriptionWebView;

- (void)setDictionaryEntryTitle:(NSString*)title;
- (void)setDictionaryEntryText:(NSString*)entry;
- (void)setScalesPageToFit:(BOOL)scalesPageToFit;

@end
