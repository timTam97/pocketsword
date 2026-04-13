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
	
	//Calculate Screensize.
	CGRect frame = [[UIScreen mainScreen] bounds];

	//check if you should rotate the view, e.g. change width and height of the frame
	UIInterfaceOrientation currentOrientation = [PSResizing currentInterfaceOrientation];
	BOOL rotate = NO;
	if ( UIInterfaceOrientationIsLandscape( currentOrientation ) ) {
		if (frame.size.width < frame.size.height) {
			rotate = YES;
		}
	}

	if ( UIInterfaceOrientationIsPortrait( currentOrientation ) ) {
		if (frame.size.width > frame.size.height) {
			rotate = YES;
		}
	}

	if (rotate) {
		CGFloat tmp = frame.size.height;
		frame.size.height = frame.size.width;
		frame.size.width = tmp;
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
	NSInteger baseHeight = [[UIScreen mainScreen] bounds].size.height - topBarHeight - [PSResizing statusBarHeight]; //remove top bar & status bar.

    r.size.height = baseHeight - t.size.height;
	[UIView animateWithDuration:0.3 animations:^{
		self->addSourceTableView.frame = r;
	}];
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
	NSInteger baseHeight = [[UIScreen mainScreen] bounds].size.height - topBarHeight - [PSResizing statusBarHeight]; //remove top bar & status bar.
	r.size.height = baseHeight;
	[UIView animateWithDuration:0.3 animations:^{
		self->addSourceTableView.frame = r;
	}];
}


- (void)cancelButtonPressed {
	[captionTextField resignFirstResponder];
	[serverTextField resignFirstResponder];
	[pathTextField resignFirstResponder];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleDownloadFailure {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	indexData = nil;

	[indexDownloadHUD hideAnimated:YES];

	//perhaps dodgy, display a warning.
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", @"") message:NSLocalizedString(@"CannotVerifyInstallSourceWarning", @"") preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No") style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self addInstallSource:self->captionTextField.text withPath:self->pathTextField.text andServer:self->serverTextField.text];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)handleDownloadSuccess {
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideNetworkIndicator object:nil];
	if(indexData) {
		indexDownloadHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Tick.png"]];
		indexDownloadHUD.mode = MBProgressHUDModeCustomView;
		[indexDownloadHUD hideAnimated:YES afterDelay:2];
		[self addInstallSource:captionTextField.text withPath:pathTextField.text andServer:serverTextField.text];
	} else {
		[indexDownloadHUD hideAnimated:YES];
		//perhaps dodgy, display a warning.
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", @"") message:NSLocalizedString(@"CannotVerifyInstallSourceWarning", @"") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"No") style:UIAlertActionStyleCancel handler:nil]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[self addInstallSource:self->captionTextField.text withPath:self->pathTextField.text andServer:self->serverTextField.text];
		}]];
		[self presentViewController:alert animated:YES completion:nil];
	}
	indexData = nil;
}

- (void)saveButtonPressed {
	NSString *caption = captionTextField.text;
	NSString *server = serverTextField.text;
	NSString *path = pathTextField.text;
	if(!caption || [caption isEqualToString:@""] || !server || [server isEqualToString:@""] || !path || [path isEqualToString:@""]) {
		//you must fill in all fields to add a new source
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"") message:NSLocalizedString(@"FillInAllFieldsMessage", @"") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"Ok") style:UIAlertActionStyleCancel handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}
	
	if(![PSModuleController checkNetworkConnection]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"") message:NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"") style:UIAlertActionStyleCancel handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayNetworkIndicator object:nil];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@/mods.d.tar.gz", [serverType lowercaseString], server, path]];
	NSURLRequest *request = [NSURLRequest requestWithURL:url];

	indexData = [[NSMutableData alloc] init];
	expectedDataLength = 0.0;
	currentDataLength = 0.0;

	NSURLSession *session = [NSURLSession sharedSession];
	downloadTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (error) {
				[self handleDownloadFailure];
			} else {
				self->indexData = [NSMutableData dataWithData:data];
				[self handleDownloadSuccess];
			}
		});
	}];
	[downloadTask resume];

	indexDownloadHUD = [MBProgressHUD showHUDAddedTo:(((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window) animated:YES];
	indexDownloadHUD.delegate = self;
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	BOOL dismissModal = NO;
	if(indexDownloadHUD.mode == MBProgressHUDModeCustomView) {
		dismissModal = YES;
	}
	[indexDownloadHUD removeFromSuperview];
	indexDownloadHUD = nil;
	if(dismissModal) {
		[self dismissViewControllerAnimated:YES completion:nil];
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
	is = nil;
		
	if(indexDownloadHUD && indexDownloadHUD.mode == MBProgressHUDModeCustomView) {
		// we will dismiss ourselves when the HUD is done...
	} else {
		[self dismissViewControllerAnimated:YES completion:nil];
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
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




- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if([PSResizing iPad]) {
        return [PSResizing supportedInterfaceOrientations];
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

@end

