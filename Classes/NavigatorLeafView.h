//
//  NavigatorLeafView.h
//  PocketSword
//
//  Created by Nic Carter on 13/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "PSModuleDownloadItem.h"

@class SwordModule;

@interface NavigatorLeafView : UIViewController <UINavigationBarDelegate, PSModuleDownloadDelegate> {
	WKWebView *detailsWebView;

	SwordModule *module;
}

@property (strong, readwrite) SwordModule *module;
@property (strong) WKWebView *detailsWebView;

@end
