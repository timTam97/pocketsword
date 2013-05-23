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

@interface PSAddSourceViewController : UIViewController <UITextFieldDelegate, MBProgressHUDDelegate, UITableViewDataSource, UITableViewDelegate> {
	UITextField *captionTextField;
	UITextField *serverTextField;
	UITextField *pathTextField;
	
	NSString *serverType;
	
	UITableView *addSourceTableView;
	NSInteger topBarHeight;
	
	NSMutableData *indexData;
	float expectedDataLength;
	float currentDataLength;
	MBProgressHUD *indexDownloadHUD;
}

@property (nonatomic, retain) NSString *serverType;

- (void)cancelButtonPressed;
- (void)saveButtonPressed;

- (void)addInstallSource:(NSString*)caption withPath:(NSString*)path andServer:(NSString*)server;

- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;

@end
