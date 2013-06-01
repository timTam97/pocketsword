//
//  NavigatorLeafView.h
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "SwordModule.h"

#import "PSModuleDownloadItem.h"
#import "PSIndexController.h"


@interface NavigatorLeafView : UIViewController <UINavigationBarDelegate, PSModuleDownloadDelegate> {
	IBOutlet UIWebView *detailsView;

	SwordModule *module;
}

@property (retain, readwrite) SwordModule *module;

@end
