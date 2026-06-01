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

#import "PocketSwordSceneDelegate.h"
#import "PocketSwordAppDelegate.h"
#import "PSTabBarControllerDelegate.h"
// PSLaunchViewController + the @objc(PSLaunchDelegate) protocol are now Swift —
// reach them via the generated reverse header (a .mm may import it; a .h may not).
#import "PocketSword-Swift.h"

// Declare PSLaunchDelegate conformance here (not in the public header) per §2A
// Rule 2: the Swift protocol is only visible through PocketSword-Swift.h.
@interface PocketSwordSceneDelegate () <PSLaunchDelegate>
@end

@implementation PocketSwordSceneDelegate {
	NSURL *_pendingLaunchURL;
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
	if (![scene isKindOfClass:[UIWindowScene class]]) {
		return;
	}
	UIWindowScene *windowScene = (UIWindowScene *)scene;

	PSLaunchViewController *lVC = [[PSLaunchViewController alloc] init];
	[lVC setDelegate:self];

	self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
	self.window.backgroundColor = [UIColor systemBackgroundColor];
	self.window.rootViewController = lVC;

	[lVC performSelectorInBackground:@selector(startInitializingPocketSword) withObject:nil];

	[self.window makeKeyAndVisible];

	_pendingLaunchURL = connectionOptions.URLContexts.anyObject.URL;
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
	PocketSwordAppDelegate *appDelegate = [PocketSwordAppDelegate sharedAppDelegate];
	for (UIOpenURLContext *urlContext in URLContexts) {
		[appDelegate application:[UIApplication sharedApplication] handleOpenURL:urlContext.URL options:nil];
	}
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_PocketSword"]) {
		[PSLaunchViewController resetPreferences];
	}
}

- (void)sceneWillResignActive:(UIScene *)scene {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)finishedInitializingPocketSword:(id)lVC {
	PocketSwordAppDelegate *appDelegate = [PocketSwordAppDelegate sharedAppDelegate];
	PSTabBarControllerDelegate *tbcd = [[PSTabBarControllerDelegate alloc] init];
	appDelegate.tabBarControllerDelegate = tbcd;

	self.window.rootViewController = tbcd.tabBarController;

	if (_pendingLaunchURL) {
		NSURL *url = _pendingLaunchURL;
		_pendingLaunchURL = nil;
		[appDelegate application:[UIApplication sharedApplication] handleOpenURL:url options:nil];
	}
}

@end
