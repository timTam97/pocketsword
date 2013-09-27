//
//  PSModuleLeafViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleLeafViewController.h"
#import "PocketSwordAppDelegate.h"
#import "PSResizing.h"
#import "PSModuleSelectorController.h"

@implementation PSModuleLeafViewController

- (void)viewDidLoad {
    [super viewDidLoad];

	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"");
	self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	[infoWebView loadHTMLString:@"<html><body bgcolor=\'black\'>&nbsp;</body></html>" baseURL: nil];
	trashModule = NO;
	askToUnlock = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	[PSResizing resizeViewsOnAppearWithTabBarController:self.tabBarController topBar:infoNavBar mainView:infoWebView useStatusBar:YES];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[PSResizing resizeViewsOnRotateWithTabBarController:self.tabBarController topBar:infoNavBar mainView:infoWebView fromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: infoNavItem.title];
	if(askToUnlock && mod) {
		if([mod isLocked]) {
			//gotta ask the user if they want to unlock the module!
			DLog(@"\nlocked module!\n");
			NSString *question = NSLocalizedString(@"ModuleLockedQuestion", @"");
			NSString *messageTitle = NSLocalizedString(@"ModuleLockedTitle", @"Module Locked");
			
			//	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n[%@]", [module name], [module descr], [sIS caption]];
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: messageTitle message: question
									   delegate: self cancelButtonTitle: NSLocalizedString(@"Cancel", @"Cancel") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), NSLocalizedString(@"No", @"No"), nil];
			[alertView show];
			[alertView release];
			askToUnlock = NO;
		}
	}
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	//[infoWebView loadHTMLString:@"<html><body bgcolor=\'black\'>&nbsp;</body></html>" baseURL: nil];
}


- (void)displayInfoForModule:(SwordModule*)swordModule {
	[self.tabBarController setSelectedIndex:0];
	infoNavItem.title = [swordModule name];
	self.tabBarItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"AboutTitle", @""), [swordModule name]];
	preferencesTabBarItem.title = [NSString stringWithFormat:@"%@ %@", [swordModule name], NSLocalizedString(@"TabBarTitlePreferences", @"")];
	[prefController displayPrefsForModule:swordModule];
	[infoWebView loadHTMLString:[PSModuleController createHTMLString:[swordModule fullAboutText] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil] baseURL:nil];
}

- (IBAction)closeLeaf:(id)sender {
	askToUnlock = YES;
	if(moduleSelectorController.moduleToView) {
		//notify to close the module list.
		[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleModuleList object:nil];
	} else {
		if([PSResizing iPad]) {
			[self dismissModalViewControllerAnimated:YES];
		} else {
			[self.navigationController popViewControllerAnimated:YES];
		}
	}
}

- (IBAction)trashModule:(id)sender {
	NSString *question = NSLocalizedString(@"ConfirmDeleteQuestion", @"Are you sure you wish to remove this module?");
	NSString *messageTitle = NSLocalizedString(@"ConfirmDeleteTitle", @"Remove?");
	trashModule = YES;
	//	NSString *message = [question stringByAppendingFormat: @"\n%@\n%@\n[%@]", [module name], [module descr], [sIS caption]];
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: messageTitle message: question
							   delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil];
	[alertView show];
	[alertView release];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	//DLog(@"Clicked button %d", buttonIndex);
	if (buttonIndex == 1 && trashModule) {
		// user tapped @"Yes" to the trash this module question.
		DLog(@"\nremoving module: %@", infoNavItem.title);
		trashModule = NO;
		[[PSModuleController defaultModuleController] removeModule: infoNavItem.title];
		[self closeLeaf: nil];
	} else if(buttonIndex == 1) {
		// user tapped @"Yes" to unlocking this module question.
		[self presentModalViewController:unlockViewController animated:YES];
	}
	
	[pool release];
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return [PSResizing shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

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

