/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2010 CrossWire Bible Society

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "PSResizing.h"
#import "PSLaunchViewController.h"

@class PSTabBarControllerDelegate;
@class SnoopWindow;

@interface PocketSwordAppDelegate : NSObject <UIApplicationDelegate, PSLaunchDelegate> {
    UIWindow *window;
	
	NSURL *urlToOpen;
	NSDictionary *launchedWithOptions;
	PSTabBarControllerDelegate *tabBarControllerDelegate;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) NSURL *urlToOpen;
@property (nonatomic, retain) NSDictionary *launchedWithOptions;
@property (retain) PSTabBarControllerDelegate *tabBarControllerDelegate;

+ (PocketSwordAppDelegate *)sharedAppDelegate;
- (void)storeDidChange:(NSNotification *)notification;

@end

@interface UITabBarController (PocketSword)
@end

@interface UINavigationController (PocketSword)
@end
