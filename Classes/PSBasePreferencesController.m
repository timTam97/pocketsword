    //
//  PSBasePreferencesController.m
//  PocketSword
//
//  Created by Nic Carter on 17/12/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSBasePreferencesController.h"


@implementation PSBasePreferencesController

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)fontNameChanged:(NSString *)newFont {}

- (void)hideFontTableView {}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
