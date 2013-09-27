//
//  NavigatorSources.h
//  PocketSword
//
//  Created by Nic Carter on 8/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "MBProgressHUD.h"

@class NavigatorModuleTypes;
@class iPhoneHTTPServerDelegate;

@interface NavigatorSources : UITableViewController  <UINavigationControllerDelegate, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, MBProgressHUDDelegate> {
	
	BOOL mmmMenuDisplayed;
}

- (void)manualAddModule;
- (void)addManualInstallButton;
- (void)editButtonPressed:(id)sender;
- (void)resetInstallSourcesListing;

@end

@interface PSStatusController : UIViewController {}
@end
