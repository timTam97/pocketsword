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
#import "PSIndexController.h"

@interface NavigatorLeafView : UIViewController <UINavigationBarDelegate, PSIndexControllerDelegate> {
	IBOutlet UIWebView *detailsView;
	//IBOutlet NavigatorSources *navigatorSources;

	// Status view
	IBOutlet UIViewController *statusController;
	IBOutlet UILabel *statusTitle;
	IBOutlet UILabel *statusText;
	IBOutlet UILabel *statusOverallText;
	IBOutlet UIProgressView *statusBar;
	IBOutlet UIProgressView *statusOverallBar;
		
	SwordModule *module;
    NSUInteger bti;
	PSIndexController *indexController;
}

@property (retain, readwrite) SwordModule *module;

- (void)showDownloadStatus;
- (void)runInstallation;
- (void)updateInstallationStatus;
- (void)hideOperationStatus;
- (void)dealloc;

@end
