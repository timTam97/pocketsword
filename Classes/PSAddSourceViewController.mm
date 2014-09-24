//
//  PSAddSourceViewController.m
//  PocketSword
//
//  Created by Nic Carter on 10/06/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSAddSourceViewController.h"
#import "NavigatorSources.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import "PocketSwordAppDelegate.h"
#import "globals.h"
#import "SwordInstallManager.h"

@implementation PSAddSourceViewController

@synthesize serverType;

#define CAPTION_SECTION	0
#define SERVER_SECTION	1
#define PATH_SECTION	2
#define SECTIONS		3


#pragma mark -
#pragma mark View lifecycle

- (void)loadView {
	
	//Calculate Screensize. based on http://stackoverflow.com/a/13068718
	BOOL statusBarHidden = [[UIApplication sharedApplication] isStatusBarHidden ];
	
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	
	//check if you should rotate the view, e.g. change width and height of the frame
	BOOL rotate = NO;
	if ( UIInterfaceOrientationIsLandscape( [UIApplication sharedApplication].statusBarOrientation ) ) {
		if (frame.size.width < frame.size.height) {
			rotate = YES;
		}
	}
	
	if ( UIInterfaceOrientationIsPortrait( [UIApplication sharedApplication].statusBarOrientation ) ) {
		if (frame.size.width > frame.size.height) {
			rotate = YES;
		}
	}
	
	if (rotate) {
		CGFloat tmp = frame.size.height;
		frame.size.height = frame.size.width;
		frame.size.width = tmp;
	}
	
	
	if (statusBarHidden) {
		frame.size.height -= [[UIApplication sharedApplication] statusBarFrame].size.height;
	}
	
	UIView *v = [[UIView alloc] initWithFrame: frame];
	v.backgroundColor = [UIColor whiteColor];
	v.autoresizingMask  = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	// add toolbar with the title
	UIToolbar *tbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,frame.size.width,44)];
	tbar.barStyle = UIBarStyleBlack;
	NSString *t = [NSString stringWithFormat:@"Add%@SourceTitle", serverType];
	UIBarButtonItem *titleButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(t, @"") style:UIBarButtonItemStylePlain target:nil action:nil];
	UIBarButtonItem *flexLeft = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *flexRight = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed)];
	UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveButtonPressed)];

	NSArray *tbarButtons = [NSArray arrayWithObjects: cancelButton, flexLeft, titleButton, flexRight, saveButton, nil];
	[titleButton release];
	[flexLeft release];
	[flexRight release];
	[cancelButton release];
	[saveButton release];
	tbar.items = tbarButtons;
	[v addSubview:tbar];
	topBarHeight = tbar.frame.size.height;
	
	// add empty UITableView
	frame.size.height -= tbar.frame.size.height;
	frame.origin = CGPointMake(0, tbar.frame.size.height);
	addSourceTableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
	[v addSubview:addSourceTableView];
	addSourceTableView.delegate = self;
	addSourceTableView.dataSource = self;
	
	self.view = v;
	[tbar release];
	[v release];

    CGRect fieldFrames = CGRectMake(20,12,280,25);
    if([PSResizing iPad]) {
        //different frames for the iPad
        fieldFrames = CGRectMake(60,12,560,25);
    }
	
    captionTextField = [[UITextField alloc] initWithFrame:fieldFrames];
	[captionTextField setPlaceholder:@"e.g. CrossWire 1"];
	captionTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	captionTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	captionTextField.returnKeyType = UIReturnKeyNext;
	captionTextField.delegate = self;
	
	serverTextField = [[UITextField alloc] initWithFrame:fieldFrames];
	[serverTextField setPlaceholder:@"e.g. ftp.crosswire.org"];
	serverTextField.keyboardType = UIKeyboardTypeURL;
	serverTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	serverTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	serverTextField.returnKeyType = UIReturnKeyNext;
	serverTextField.delegate = self;
	
	pathTextField = [[UITextField alloc] initWithFrame:fieldFrames];
	[pathTextField setPlaceholder:@"e.g. /pub/sword/raw"];
	pathTextField.keyboardType = UIKeyboardTypeURL;
	pathTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	pathTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	pathTextField.returnKeyType = UIReturnKeyDone;
	pathTextField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
	[nc addObserver:self selector:@selector(keyboardDidShow:) name: UIKeyboardDidShowNotification object:nil];
	[captionTextField becomeFirstResponder];
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
	[super viewWillDisappear:animated];
}

- (void)keyboardWillShow:(NSNotification *)note {
    if([PSResizing iPad]) {
        //don't do this magic on the iPad
        return;
    }
    CGRect r  = addSourceTableView.frame, t;
    //[[note.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue: &t];//use UIKeyboardFrameEndUserInfoKey in iOS4
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &t];
	//UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	//t = [mainWindow convertRect:t fromWindow:nil];
    ////r.size.height -=  t.size.height;
	NSInteger baseHeight = [[UIScreen mainScreen] bounds].size.height - topBarHeight - [UIApplication sharedApplication].statusBarFrame.size.height; //remove top bar & status bar.

    r.size.height = baseHeight - t.size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    addSourceTableView.frame = r;
	[UIView commitAnimations];
}

- (void)keyboardDidShow:(NSNotification *)note {
	if([captionTextField isFirstResponder]) {
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:CAPTION_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([serverTextField isFirstResponder]) {
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SERVER_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([pathTextField isFirstResponder]) {
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:PATH_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if([captionTextField isFirstResponder]) {
		[serverTextField becomeFirstResponder];
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SERVER_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([serverTextField isFirstResponder]) {
		[pathTextField becomeFirstResponder];
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:PATH_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([pathTextField isFirstResponder]) {
		[self saveButtonPressed];
	}
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	[self keyboardDidShow:nil];
}
	   
- (void)keyboardWillHide:(NSNotification *)note {
    if([PSResizing iPad]) {
        //don't do this magic on the iPad
        return;
    }
    CGRect r  = addSourceTableView.frame;
	//CGRect t;
    //[[note.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue: &t];
    //r.size.height +=  t.size.height;
	NSInteger baseHeight = [[UIScreen mainScreen] bounds].size.height - topBarHeight - [UIApplication sharedApplication].statusBarFrame.size.height; //remove top bar & status bar.
	r.size.height = baseHeight;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    addSourceTableView.frame = r;
	[UIView commitAnimations];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex != [alertView cancelButtonIndex]) {
		[self addInstallSource:captionTextField.text withPath:pathTextField.text andServer:serverTextField.text];
	}
}

- (void)cancelButtonPressed {
	[captionTextField resignFirstResponder];
	[serverTextField resignFirstResponder];
	[pathTextField resignFirstResponder];
	[self dismissModalViewControllerAnimated:YES];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    indexData = [[NSMutableData alloc] init];
	expectedDataLength = [response expectedContentLength];
	currentDataLength = 0.0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [indexData appendData:data];
	currentDataLength = [indexData length];
	indexDownloadHUD.progress = (float)currentDataLength / (float) expectedDataLength;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
    [indexData release];
	indexData = nil;
	
	[indexDownloadHUD hide:YES];
	
	//perhaps dodgy, display a warning.
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Warning", @"") message: NSLocalizedString(@"CannotVerifyInstallSourceWarning", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
	[alertView show];
	[alertView release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	if(indexData) {
		indexDownloadHUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]] autorelease];
		indexDownloadHUD.mode = MBProgressHUDModeCustomView;
		[indexDownloadHUD hide:YES afterDelay:2];
		[self addInstallSource:captionTextField.text withPath:pathTextField.text andServer:serverTextField.text];
	} else {
		[indexDownloadHUD hide:YES];
		//perhaps dodgy, display a warning.
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Warning", @"") message: NSLocalizedString(@"CannotVerifyInstallSourceWarning", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
		[alertView show];
		[alertView release];
	}
    [indexData release];
	indexData = nil;
}

- (void)saveButtonPressed {
	NSString *caption = captionTextField.text;
	NSString *server = serverTextField.text;
	NSString *path = pathTextField.text;
	if(!caption || [caption isEqualToString:@""] || !server || [server isEqualToString:@""] || !path || [path isEqualToString:@""]) {
		//you must fill in all fields to add a new source
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"FillInAllFieldsMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		return;
	}
	
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@/mods.d.tar.gz", [serverType lowercaseString], server, path]];
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	[connection start];
	[connection release];
	
	indexDownloadHUD = [[MBProgressHUD showHUDAddedTo:(((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window) animated:YES] retain];
	indexDownloadHUD.delegate = self;
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	BOOL dismissModal = NO;
	if(indexDownloadHUD.mode == MBProgressHUDModeCustomView) {
		dismissModal = YES;
	}
	[indexDownloadHUD removeFromSuperview];
	[indexDownloadHUD release];
	indexDownloadHUD = nil;
	if(dismissModal) {
		[self dismissModalViewControllerAnimated:YES];
		captionTextField.text = @"";
		serverTextField.text = @"";
		pathTextField.text = @"";
	}
}

- (void)addInstallSource:(NSString*)caption withPath:(NSString*)path andServer:(NSString*)server {
	SwordInstallSource *is = [[SwordInstallSource alloc] initWithType:serverType];
	
	[is setCaption:caption];
	[is setDirectory:path];
	[is setSource:server];
	[is setUID:[NSString stringWithFormat:@"%@-%@", server, caption]];
	
	[[[PSModuleController defaultModuleController] swordInstallManager] addInstallSource:is];
	[is release];
	is = nil;
		
	if(indexDownloadHUD && indexDownloadHUD.mode == MBProgressHUDModeCustomView) {
		// we will dismiss ourselves when the HUD is done...
	} else {
		[self dismissModalViewControllerAnimated:YES];
		captionTextField.text = @"";
		serverTextField.text = @"";
		pathTextField.text = @"";
	}
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SECTIONS;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	switch(indexPath.section) {
		case CAPTION_SECTION:
			[cell addSubview:captionTextField];
			break;
		case SERVER_SECTION:
			[cell addSubview:serverTextField];
			break;
		case PATH_SECTION:
			[cell addSubview:pathTextField];
			break;
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch(section) {
		case CAPTION_SECTION:
			return NSLocalizedString(@"AddSourceCaptionTitle", @"");
		case SERVER_SECTION:
			return NSLocalizedString(@"AddSourceServerTitle", @"");
		case PATH_SECTION:
			return NSLocalizedString(@"AddSourcePathTitle", @"");
	}
	return @"";
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	[captionTextField release];
	[serverTextField release];
	[pathTextField release];
	[addSourceTableView release];
	[super viewDidUnload];
}


- (void)dealloc {
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if([PSResizing iPad]) {
        return [PSResizing shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    } else {
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
    }
}

@end

