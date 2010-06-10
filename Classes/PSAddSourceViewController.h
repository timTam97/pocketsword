//
//  PSAddSourceViewController.h
//  PocketSword
//
//  Created by Nic Carter on 10/06/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//


@interface PSAddSourceViewController : UITableViewController <UITextFieldDelegate> {
	UITextField *captionTextField;
	UITextField *serverTextField;
	UITextField *pathTextField;
	
	NSString *serverType;
	
}

@property (nonatomic, retain) NSString *serverType;

@end
