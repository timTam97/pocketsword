//
//  PSModuleUnlockViewController.h
//  PocketSword
//
//  Created by Nic Carter on 4/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "globals.h"


@interface PSModuleUnlockViewController : UIViewController {
	
	IBOutlet UIBarButtonItem	*unlockEditButton;
	IBOutlet UIBarButtonItem	*unlockSaveButton;
	IBOutlet UIWebView			*unlockWebView;
	IBOutlet UIWebView			*unlockHelpWebView;
	IBOutlet UILabel			*unlockLabel;
	IBOutlet UITextField		*unlockTextField;
	//IBOutlet UIView				*unlockView;
	IBOutlet UIToolbar			*unlockToolbar;
	IBOutlet UINavigationItem	*unlockNavBarItem;
	
	NSString *moduleName;
}

@property (copy) NSString *moduleName;

- (IBAction)unlockEditButtonPressed:(id)sender;

- (IBAction)unlockSaveButtonPressed:(id)sender;
- (IBAction)closeUnlockView:(id)sender;

- (BOOL)textFieldShouldReturn:(UITextField *)textField;
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;

@end
