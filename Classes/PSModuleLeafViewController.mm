//
//  PSModuleLeafViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleLeafViewController.h"


@implementation PSModuleLeafViewController

BOOL trashModule = NO;

- (void)viewDidLoad {
    [super viewDidLoad];

	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"");
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
	[nc addObserver:self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object:nil];

	SwordModule *mod = [[moduleManager swordManager] moduleWithName: navBar.title];
	if(mod) {
		if([mod isLocked]) {
			//gotta ask the user if they want to unlock the module!
			DLog(@"\nlocked module!\n");
			NSString *question = NSLocalizedString(@"ModuleLockedQuestion", @"");
			NSString *messageTitle = NSLocalizedString(@"ModuleLockedTitle", @"Module Locked");
			
			//	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n[%@]", [module name], [module descr], [sIS caption]];
			[[[UIAlertView alloc] initWithTitle: messageTitle message: question
									   delegate: self cancelButtonTitle: NSLocalizedString(@"Cancel", @"Cancel") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), NSLocalizedString(@"No", @"No"), nil] show];
			
		}
	}
}


- (void)displayInfoForModule:(SwordModule*)swordModule {
	navBar.title = [swordModule name];
	[infoWebView loadHTMLString:[PSModuleController createHTMLString:[swordModule fullAboutText] usingPreferences:YES withJS:@""] baseURL:nil];
}

- (IBAction)closeLeaf:(id)sender {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight
                           forView:self.view.superview
                             cache:YES];
    [UIView setAnimationDuration:1];
	[self.view removeFromSuperview];
    [UIView commitAnimations];
}

- (IBAction)closeUnlockView:(id)sender {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp
                           forView:self.view
                             cache:YES];
    [UIView setAnimationDuration:1];
	[unlockView removeFromSuperview];
    [UIView commitAnimations];
}

- (IBAction)unlockSaveButtonPressed:(id)sender {
	//save the key
	[[[moduleManager swordManager] moduleWithName: navBar.title] unlock: unlockTextField.text];
	//redisplay the text if this is the current primary bible/commentary
	if([navBar.title isEqualToString:[[moduleManager primaryBible] name]]) {
		[[moduleManager viewController] displayChapter:[moduleManager getCurrentBibleRef] withPollingType:BibleViewPoll restoreType:RestoreVersePosition];
	} else if([navBar.title isEqualToString:[[moduleManager primaryCommentary] name]]) {
		[[moduleManager viewController] displayChapter:[moduleManager getCurrentBibleRef] withPollingType:CommentaryViewPoll restoreType:RestoreVersePosition];
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
	SwordModule *mod = [[moduleManager swordManager] moduleWithName: navBar.title];
	[mod unlock: unlockTextField.text];
	NSArray *refs = [NSArray arrayWithObjects:@"Jeremiah 29:11", @"Psalm 139:5", @"John 3:16", nil];
	for(NSString *ref in refs) {
		SwordModuleTextEntry *entry = [mod textEntryForKey:ref textType:TextTypeRendered];
		[html appendFormat:@"<p><b>%@:</b> %@</p>", [PSModuleController createRefString: entry.key], entry.text];
	}
	
	[unlockWebView loadHTMLString:[PSModuleController createHTMLString:html usingPreferences:YES withJS:@""] baseURL:nil];
	[mod unlock: nil];
	return YES;
}

- (IBAction)unlockEditButtonPressed:(id)sender {
	if([unlockTextField canBecomeFirstResponder])
		[unlockTextField becomeFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)note {
    CGRect r  = unlockToolbar.frame, t;
    //[[note.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue: &t];//use UIKeyboardFrameEndUserInfoKey instead
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &t];
    r.origin.y -=  t.size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    unlockToolbar.frame = r;
	[UIView commitAnimations];
	[unlockEditButton setEnabled:NO];
}

- (void)keyboardWillHide:(NSNotification *)note {
    CGRect r  = unlockToolbar.frame, t;
    [[note.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue: &t];
    r.origin.y +=  t.size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    unlockToolbar.frame = r;
	[UIView commitAnimations];
	[unlockEditButton setEnabled:YES];
}

- (IBAction)trashModule:(id)sender {
	NSString *question = NSLocalizedString(@"ConfirmDeleteQuestion", @"Are you sure you wish to remove this module?");
	NSString *messageTitle = NSLocalizedString(@"ConfirmDeleteTitle", @"Remove?");
	trashModule = YES;
//	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n[%@]", [module name], [module descr], [sIS caption]];
	[[[UIAlertView alloc] initWithTitle: messageTitle message: question
							   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
}

#define UNLOCK_HELP_HTML @"<head>\n\
<meta name='viewport' content='width=device-width' />\n\
<style type=\"text/css\">\n\
body {\n\
	color: white;\n\
	background-color: black;\n\
	font-size: 12pt;\n\
	font-family: Helvetica;\n\
	line-height: 130%%;\n\
}\n\
</style>\n\
</head>"

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//DLog(@"Clicked button %d", buttonIndex);
	if (buttonIndex == 1 && trashModule) {
		// user tapped @"Yes" to the trash this module question.
		DLog(@"\nremoving module: %@", navBar.title);
		trashModule = NO;
		[moduleManager removeModule: navBar.title];
		[self closeLeaf: nil];
	} else if(buttonIndex == 1) {
		// user tapped @"Yes" to unlocking this module question.
		[unlockLabel setText:NSLocalizedString(@"ModuleEnterKeyTitle", @"Enter Key:")];
		unlockNavBarItem.title = NSLocalizedString(@"ModuleUnlockScreenTitle", @"Unlock Module");
		[unlockWebView loadHTMLString:@"<html><body bgcolor='black'>&nbsp;</body></html>" baseURL:nil];
		[unlockHelpWebView loadHTMLString:[NSString stringWithFormat:@"<html>%@<body>%@</body></html>", UNLOCK_HELP_HTML, NSLocalizedString(@"ModuleUnlockHelpText", @"")] baseURL:nil];
		unlockWebView.hidden = YES;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationTransition:UIViewAnimationTransitionCurlDown
							   forView:self.view
								 cache:YES];
		
		[UIView setAnimationDuration:1];
		[self.view addSubview: unlockView];
		[UIView commitAnimations];
		[unlockTextField becomeFirstResponder];
	}
	
	[pool release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
}


- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	[nc removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	//[nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
	//[nc addObserver:self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[infoWebView loadHTMLString:@"" baseURL: nil];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)dealloc {
    [super dealloc];
}


@end

