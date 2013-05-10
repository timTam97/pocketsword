//
//  PSAddSourceViewController.h
//  PocketSword
//
//  Created by Nic Carter on 10/06/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "SwordInstallSource.h"
#import "MBProgressHUD.h"

@class NavigatorSources;

@interface PSAddSourceViewController : UITableViewController <UITextFieldDelegate, MBProgressHUDDelegate> {
	UITextField *captionTextField;
	UITextField *serverTextField;
	UITextField *pathTextField;
	
	NSString *serverType;
	
	IBOutlet UINavigationItem *navBar;
	IBOutlet UINavigationBar *navigationBar;
	IBOutlet UITableView *addSourceTableView;
	IBOutlet NavigatorSources *navSources;
	
	NSMutableData *indexData;
	float expectedDataLength;
	float currentDataLength;
	MBProgressHUD *indexDownloadHUD;
}

@property (nonatomic, retain) NSString *serverType;

- (IBAction)cancelButtonPressed;
- (IBAction)saveButtonPressed;

- (void)addInstallSource:(NSString*)caption withPath:(NSString*)path andServer:(NSString*)server;

- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;

@end
