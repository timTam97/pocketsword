//
//  PSModuleUnlockViewController.h
//  PocketSword
//
//  Created by Nic Carter on 4/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"


@interface PSModuleUnlockViewController : UIViewController <UITextFieldDelegate> {
	
	UIBarButtonItem		*unlockEditButton;
	UIBarButtonItem		*unlockSaveButton;
	UIWebView			*unlockWebView;
	UIWebView			*unlockHelpWebView;
	UITextField			*unlockTextField;
	UIToolbar			*unlockToolbar;
	
	NSString			*moduleName;
}

@property (copy)   NSString			*moduleName;
@property (retain) UIWebView		*unlockHelpWebView;
@property (retain) UITextField		*unlockTextField;
@property (retain) UIWebView		*unlockWebView;
@property (retain) UIToolbar		*unlockToolbar;
@property (retain) UIBarButtonItem	*unlockEditButton;
@property (retain) UIBarButtonItem	*unlockSaveButton;

- (IBAction)unlockEditButtonPressed:(id)sender;

- (IBAction)unlockSaveButtonPressed:(id)sender;
- (IBAction)closeUnlockView:(id)sender;

- (BOOL)textFieldShouldReturn:(UITextField *)textField;
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;

@end
