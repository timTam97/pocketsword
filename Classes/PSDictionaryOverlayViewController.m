//
//  PSDictionaryOverlayViewController.m
//  PocketSword
//
//  Created by Nic Carter on 26/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSDictionaryOverlayViewController.h"
#import "globals.h"


@implementation PSDictionaryOverlayViewController

@synthesize dictionaryViewController;

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	grayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height)];
	if([[NSUserDefaults standardUserDefaults] boolForKey:DefaultsNightModePreference]) {
		grayView.backgroundColor = [UIColor blackColor];
	} else {
		grayView.backgroundColor = [UIColor whiteColor];
	}
	grayView.alpha = 0.5;
	self.view = grayView;
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[dictionaryViewController searchBarCancelButtonClicked:nil];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	[grayView removeFromSuperview];
	[grayView release];
	grayView = nil;
}


- (void)dealloc {
	[grayView release];
	[dictionaryViewController release];
    [super dealloc];
}


@end
