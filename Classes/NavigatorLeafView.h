//
//  NavigatorLeafView.h
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "SwordModule.h"
#import "NavigatorSources.h"

@interface NavigatorLeafView : UIViewController <UINavigationBarDelegate> {
	IBOutlet id detailsView;
	IBOutlet NavigatorSources *navigatorSources;

	// Status view
	IBOutlet id statusController;
	IBOutlet id statusTitle;
	IBOutlet id statusText;
	IBOutlet id statusOverallText;
	IBOutlet id statusBar;
	IBOutlet id statusOverallBar;
		
	SwordModule *module;
}

@property (retain, readwrite) SwordModule *module;

- (void)showDownloadStatus;
- (void)runInstallation;
- (void)updateInstallationStatus;
- (void)hideOperationStatus;
- (void)dealloc;

@end
