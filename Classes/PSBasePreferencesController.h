//
//  PSBasePreferencesController.h
//  PocketSword
//
//  Created by Nic Carter on 17/12/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSPreferencesFontTableViewController.h"

@interface PSBasePreferencesController : UITableViewController {

}

- (void)fontNameChanged:(NSString *)newFont;
- (void)hideFontTableView;

@end
