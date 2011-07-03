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
	IBOutlet UIViewController *statusController;
	IBOutlet UILabel *statusTitle;
	IBOutlet UILabel *statusText;
	IBOutlet UILabel *statusOverallText;
	IBOutlet UIProgressView *statusBar;
	IBOutlet UIProgressView *statusOverallBar;
		
	SwordModule *module;
    NSUInteger bti;
}

@property (retain, readwrite) SwordModule *module;

- (void)showDownloadStatus;
- (void)runInstallation;
- (void)updateInstallationStatus;
- (void)hideOperationStatus;
- (void)dealloc;

@end
