    //
//  PSModuleUnlockViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 4/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSModuleUnlockViewController.h"
#import "PSModuleController.h"
#import "PSResizing.h"
#import "SwordManager.h"


@implementation PSModuleUnlockViewController

@synthesize moduleName, unlockToolbar, unlockWebView, unlockTextField, unlockHelpWebView, unlockSaveButton, unlockEditButton;

#define UNLOCK_HELP_HTML @"<head>\n\
<meta name='viewport' content='width=device-width' />\n\
<style type=\"text/css\">\n\
body {\n\
color: white;\n\
background-color: black;\n\
font-size: 12pt;\n\
font-family: Helvetica Neue;\n\
line-height: 130%%;\n\
}\n\
</style>\n\
</head>"

- (void)disableScrolling:(UIWebView*)webview {
	UIScrollView* currentScrollView = nil;
    for (UIView* subView in webview.subviews) {
        if ([subView respondsToSelector:@selector(scrollsToTop)]) {
            currentScrollView = (UIScrollView*)subView;
        }
    }
	if([currentScrollView respondsToSelector:@selector(isScrollEnabled)]) {
		[currentScrollView setScrollEnabled:NO];
	}
}

- (void)loadView {
	static const CGFloat HelpWebViewHeight = 110.0;
	
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 20, viewWidth, viewHeight)];
	baseView.backgroundColor = [UIColor blackColor];
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(closeUnlockView:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	[cancelButton release];
	
	UIWebView *helpWV = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, HelpWebViewHeight)];
	[self disableScrolling:helpWV];
	[baseView addSubview:helpWV];
	self.unlockHelpWebView = helpWV;
	[helpWV release];
	
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 122, 130, 21)];
	label.font = [UIFont systemFontOfSize:17.0];
	label.textColor = [UIColor whiteColor];
	label.backgroundColor = [UIColor blackColor];
	label.text = NSLocalizedString(@"ModuleEnterKeyTitle", @"Enter Key:");
	[baseView addSubview:label];
	[label release];
	
	UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(150, 117, 160, 31)];
	textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	textField.autocorrectionType = UITextAutocorrectionTypeNo;
	textField.returnKeyType = UIReturnKeyDone;
	textField.delegate = self;
	textField.backgroundColor = [UIColor whiteColor];
	textField.borderStyle = UITextBorderStyleRoundedRect;
	[baseView addSubview:textField];
	self.unlockTextField = textField;
	[textField release];
	
	UIWebView *testWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 183, viewWidth, 193)];
	[self disableScrolling:testWebView];
	[baseView addSubview:testWebView];
	self.unlockWebView = testWebView;
	[testWebView release];
	
	CGFloat tbY = viewHeight - 44.0 - self.navigationController.navigationBar.frame.size.height - 20.0;
	UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, tbY, viewWidth, 44)];
	toolbar.barStyle = UIBarStyleBlack;
	UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(unlockSaveButtonPressed:)];
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(unlockEditButtonPressed:)];
	NSArray *toolbarItems = [NSArray arrayWithObjects:saveButton, flexSpace, editButton, nil];
	[toolbar setItems:toolbarItems animated:NO];
	self.unlockSaveButton = saveButton;
	[saveButton release];
	[flexSpace release];
	self.unlockEditButton = editButton;
	[editButton release];
	[baseView addSubview:toolbar];
	self.unlockToolbar = toolbar;
	[toolbar release];
	
	self.view = baseView;
	[baseView release];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	self.navigationItem.title = NSLocalizedString(@"ModuleUnlockScreenTitle", @"Unlock Module");
	[unlockWebView loadHTMLString:@"<html><body bgcolor='black'>&nbsp;</body></html>" baseURL:nil];
	[unlockHelpWebView loadHTMLString:[NSString stringWithFormat:@"<html>%@<body>%@</body></html>", UNLOCK_HELP_HTML, NSLocalizedString(@"ModuleUnlockHelpText", @"")] baseURL:nil];
	unlockWebView.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object:nil];
	[unlockTextField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
	self.moduleName = nil;
	self.unlockHelpWebView = nil;
	self.unlockTextField = nil;
	self.unlockWebView = nil;
	self.unlockToolbar = nil;
	self.unlockEditButton = nil;
	self.unlockSaveButton = nil;
    [super dealloc];
}

- (void)closeUnlockView:(id)sender {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)unlockSaveButtonPressed:(id)sender {
	//save the key
	[[[[PSModuleController defaultModuleController] swordManager] moduleWithName: moduleName] unlock: unlockTextField.text];
	//redisplay the text if this is the current primary bible/commentary
	if([moduleName isEqualToString:[[[PSModuleController defaultModuleController] primaryBible] name]]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
	} else if([moduleName isEqualToString:[[[PSModuleController defaultModuleController] primaryCommentary] name]]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
	}
	[self closeUnlockView:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	//load the key into the module & test it with:
	// @"Jeremiah 29:11"
	// @"Psalm 139:5"
	// @"John 3:16"
	unlockWebView.hidden = NO;
	NSMutableString *html = [NSMutableString string];
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: moduleName];
	[mod unlock: unlockTextField.text];
	NSArray *refs = [NSArray arrayWithObjects:@"Jeremiah 29:11", @"Psalm 139:5", @"John 3:16", nil];
	for(NSString *ref in refs) {
		SwordModuleTextEntry *entry = [mod textEntryForKey:ref textType:TextTypeRendered];
		[html appendFormat:@"<p><b>%@:</b> %@</p>", [PSModuleController createRefString: entry.key], entry.text];
	}
	
	[unlockWebView loadHTMLString:[PSModuleController createInfoHTMLString:html usingModuleForPreferences:mod.name] baseURL:nil];
	[mod unlock: nil];
	return YES;
}

- (void)unlockEditButtonPressed:(id)sender {
	if([unlockTextField canBecomeFirstResponder])
		[unlockTextField becomeFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)note {
    CGRect r  = unlockToolbar.frame, t;
	[[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &t];
    r.origin.y -=  t.size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    unlockToolbar.frame = r;
	[UIView commitAnimations];
	[unlockEditButton setEnabled:NO];
	[unlockSaveButton setEnabled:NO];
}

- (void)keyboardWillHide:(NSNotification *)note {
    CGRect r  = unlockToolbar.frame, t;
	[[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &t];
    r.origin.y +=  t.size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    unlockToolbar.frame = r;
	[UIView commitAnimations];
	[unlockEditButton setEnabled:YES];
	[unlockSaveButton setEnabled:YES];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if([PSResizing iPad]) {
        return [PSResizing shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    } else {
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
    }
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}


@end
