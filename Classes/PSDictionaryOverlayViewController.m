//
//  PSDictionaryOverlayViewController.m
//  PocketSword
//
//  Created by Nic Carter on 26/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSDictionaryOverlayViewController.h"


@implementation PSDictionaryOverlayViewController

@synthesize dictionaryViewController;
/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	grayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
	grayView.backgroundColor = [UIColor darkGrayColor];
	grayView.alpha = 0.5;
	self.view = grayView;
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

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
    [super dealloc];
	[grayView release];
	[dictionaryViewController release];
}


@end
