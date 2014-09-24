//
//  PSModuleLeafViewController.mm
//  PocketSword
//
//  Created by Nic Carter on 21/02/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleInfoViewController.h"
#import "PocketSwordAppDelegate.h"
#import "PSResizing.h"
#import "PSModuleSelectorController.h"
#import "SwordModule.h"
#import "PSModuleController.h"
#import "PSModulePreferencesController.h"
#import "PSModuleUnlockViewController.h"
#import "SwordManager.h"

@implementation PSModuleInfoViewController

@synthesize infoWebView, swordModule;

- (void)loadView {
	CGFloat viewWidth = [[UIScreen mainScreen] bounds].size.width;
	CGFloat viewHeight = [[UIScreen mainScreen] bounds].size.height;
	
	UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];

	UIWebView *infoWV = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewHeight)];
	infoWV.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	infoWV.backgroundColor = [UIColor whiteColor];
	self.infoWebView = infoWV;
	[baseView addSubview:infoWV];
	self.view = baseView;
	[infoWV release];
	[baseView release];
}

- (void)viewDidLoad {
    [super viewDidLoad];

	UIBarButtonItem *trashButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(trashModule:)];
	self.tabBarController.navigationItem.rightBarButtonItem = trashButton;
	[trashButton release];

	self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	[infoWebView loadHTMLString:@"<html><body bgcolor=\'black\'>&nbsp;</body></html>" baseURL: nil];
	trashModule = NO;
	askToUnlock = YES;
	if(self.swordModule) {
		[self displayInfoForModule:swordModule];
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	SwordModule *mod = [[[PSModuleController defaultModuleController] swordManager] moduleWithName: self.tabBarController.navigationItem.title];
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


- (void)displayInfoForModule:(SwordModule*)sModule {
	self.swordModule = sModule;
	[self.tabBarController setSelectedIndex:0];
	self.tabBarController.navigationItem.title = [swordModule name];
	UITabBarItem *tbi = [[UITabBarItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"AboutTitle", @""), [swordModule name]] image:[UIImage imageNamed:@"About.png"] tag:101];
	self.tabBarItem = tbi;
	[tbi release];
	[infoWebView loadHTMLString:[PSModuleController createHTMLString:[swordModule fullAboutText] usingPreferences:YES withJS:@"" usingModuleForPreferences:nil fixedWidth:NO] baseURL:nil];
}

- (void)closeLeaf:(id)sender {
	askToUnlock = YES;
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)trashModule:(id)sender {
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
		DLog(@"\nremoving module: %@", self.tabBarController.navigationItem.title);
		trashModule = NO;
		[[PSModuleController defaultModuleController] removeModule: self.tabBarController.navigationItem.title];
		[self closeLeaf: nil];
	} else if(buttonIndex == 1) {
		// user tapped @"Yes" to unlocking this module question.
		PSModuleUnlockViewController *unlockViewController = [[PSModuleUnlockViewController alloc] initWithNibName:nil bundle:nil];
		unlockViewController.moduleName = self.tabBarController.navigationItem.title;
		UINavigationController *unlockVCN = [[UINavigationController alloc] initWithRootViewController:unlockViewController];
		unlockVCN.navigationBar.barStyle = UIBarStyleBlack;
		[self presentModalViewController:unlockVCN animated:YES];
		[unlockViewController release];
		[unlockVCN release];
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
	[super viewDidUnload];
}

- (void)dealloc {
	self.infoWebView = nil;
	self.swordModule = nil;
    [super dealloc];
}


@end

