//
//  PSAddSourceViewController.h
//  PocketSword
//
//  Created by Nic Carter on 10/06/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "SwordInstallSource.h"

@interface PSAddSourceViewController : UITableViewController <UITextFieldDelegate> {
	UITextField *captionTextField;
	UITextField *serverTextField;
	UITextField *pathTextField;
	
	NSString *serverType;
	
	IBOutlet UINavigationItem *navBar;
	IBOutlet UITableView *addSourceTableView;
	IBOutlet id navSources;
}

@property (nonatomic, retain) NSString *serverType;

- (IBAction)cancelButtonPressed;
- (IBAction)saveButtonPressed;

- (void)addInstallSource:(NSString*)caption withPath:(NSString*)path andServer:(NSString*)server;

- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;

@end
