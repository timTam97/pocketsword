//
//  PSResizing.m
//  PocketSword
//
//  Created by Nic Carter on 1/10/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//
#import <sys/xattr.h>

#import "PSResizing.h"
#import "globals.h"

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
#define kCFCoreFoundationVersionNumber_iOS_8_0 1129.15
#endif

#define TOP_BAR_LANDSCAPE_HEIGHT 32.0
#define TOP_BAR_PORTRAIT_HEIGHT 44.0
#define BOTTOM_BAR_LANDSCAPE_HEIGHT 32.0
#define BOTTOM_BAR_PORTRAIT_HEIGHT 44.0
//#define TAB_BAR_PORTRAIT_HEIGHT 49.0
//#define TAB_BAR_LANDSCAPE_HEIGHT 35.0

@implementation PSResizing

+(void)resizeViewsOnAppearWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView useStatusBar:(BOOL)useStatusBar {
	[PSResizing resizeViewsOnAppearWithTabBarController:tabBarController topBar:topBar mainView:mainView bottomBar:nil useStatusBar:useStatusBar];
}

+(void)resizeViewsOnAppearWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView bottomBar:(UIView*)bottomBar useStatusBar:(BOOL)useStatusBar {
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	CGFloat topBarHeight, bottomBarHeight, viewHeight, width;//, tabBarY;
	CGFloat tabBarHeight = (tabBarController) ? tabBarController.tabBar.frame.size.height : 0.0;
	BOOL redrawInNewFrames = NO;
	
	UIInterfaceOrientation interfaceOrientation = [tabBarController interfaceOrientation];
	if(!tabBarController) {
		interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
		if([UIApplication sharedApplication].statusBarHidden) {
			UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
			if(UIDeviceOrientationIsLandscape(deviceOrientation))
				interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
			else if(UIDeviceOrientationIsPortrait(deviceOrientation))
				interfaceOrientation = UIInterfaceOrientationPortrait;
		}
	}
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		//DLog(@"landscape");
		redrawInNewFrames = YES;
		bottomBarHeight = (bottomBar) ? BOTTOM_BAR_LANDSCAPE_HEIGHT : 0.0;
		width = screen.height;
		topBarHeight = ([PSResizing iPad]) ? TOP_BAR_PORTRAIT_HEIGHT : TOP_BAR_LANDSCAPE_HEIGHT;
		viewHeight = screen.width - topBarHeight - tabBarHeight - bottomBarHeight;// - [UIApplication sharedApplication].statusBarFrame.size.width;
		if(useStatusBar) {
			viewHeight -= [UIApplication sharedApplication].statusBarFrame.size.width;
		}
	} else if(interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		//DLog(@"portrait");
		redrawInNewFrames = YES;
		bottomBarHeight = (bottomBar) ? BOTTOM_BAR_PORTRAIT_HEIGHT : 0.0;
		width = screen.width;
		topBarHeight = TOP_BAR_PORTRAIT_HEIGHT;
		viewHeight = screen.height - topBarHeight - tabBarHeight - bottomBarHeight;// - [UIApplication sharedApplication].statusBarFrame.size.height;
		if(useStatusBar) {
			viewHeight -= [UIApplication sharedApplication].statusBarFrame.size.height;
		}
	}
	if(redrawInNewFrames) {
		topBar.frame = CGRectMake(0.0, 0.0, width, topBarHeight);
		[topBar layoutIfNeeded];
		[topBar setNeedsDisplay];
		if(bottomBar) {
			bottomBar.frame = CGRectMake(0.0, (topBarHeight+viewHeight), width, bottomBarHeight);
			[bottomBar layoutIfNeeded];
			[bottomBar setNeedsDisplay];
		}
		mainView.frame = CGRectMake(0.0, topBarHeight, width, viewHeight);
	}
}

+(void)resizeViewsOnRotateWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	[PSResizing resizeViewsOnRotateWithTabBarController:tabBarController topBar:topBar mainView:mainView bottomBar:nil fromOrientation:fromInterfaceOrientation toOrientation:toInterfaceOrientation];
}

+(void)resizeViewsOnRotateWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView bottomBar:(UIView*)bottomBar fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation {

	if([PSResizing iPad]) {
		return;
	}
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	CGFloat topBarHeight, bottomBarHeight, viewHeight, width, bottomBarY;
	CGFloat tabBarHeight = (tabBarController) ? tabBarController.tabBar.frame.size.height : 0.0;
	BOOL redrawInNewFrames = NO;
	if((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) && !(fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
		width = screen.width;
		bottomBarHeight = (bottomBar) ? BOTTOM_BAR_LANDSCAPE_HEIGHT : 0.0;
		bottomBarY = screen.height - [UIApplication sharedApplication].statusBarFrame.size.height - (bottomBarHeight / 2.0);
		topBarHeight = TOP_BAR_LANDSCAPE_HEIGHT;
		viewHeight = screen.height - topBarHeight - tabBarHeight - bottomBarHeight - [UIApplication sharedApplication].statusBarFrame.size.height;
		redrawInNewFrames = YES;
	} else if((toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) && !(fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)) {
		width = screen.height;
		bottomBarHeight = (bottomBar) ? BOTTOM_BAR_PORTRAIT_HEIGHT : 0.0;
		bottomBarY = screen.width - [UIApplication sharedApplication].statusBarFrame.size.width - (bottomBarHeight / 2.0);
		topBarHeight = TOP_BAR_PORTRAIT_HEIGHT;
		viewHeight = screen.width - topBarHeight - tabBarHeight - bottomBarHeight - [UIApplication sharedApplication].statusBarFrame.size.width;
		redrawInNewFrames = YES;
	}
	if(redrawInNewFrames) {
		//NSLog(@"bottomBarY = %f, bottomBarHeight = %f, bottomBarYcentre = %f, topBarHeight = %f, width = %f, viewHeight = %f", bottomBarY, bottomBarHeight, (bottomBarY + (bottomBarHeight / 2.0)), topBarHeight, width, viewHeight);
		topBar.frame = CGRectMake(0.0, 0.0, width, topBarHeight);
		mainView.center = CGPointMake((width / 2.0), ((viewHeight / 2.0) + topBarHeight));
		mainView.bounds = CGRectMake(0.0, 0.0, width, viewHeight);
		if(bottomBar) {
			bottomBar.center = CGPointMake((width / 2.0), bottomBarY);
			bottomBar.bounds = CGRectMake(0.0, 0.0, width, bottomBarHeight);
		}
	}
}

+ (CGRect)getOrientationRect:(UIInterfaceOrientation)interfaceOrientation {
	CGFloat x,y,width,height;
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	BOOL isPreiOS8 = NSFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_8_0;
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		x = 0.0;
		y = 0.0;
		width = isPreiOS8 ? screen.height : screen.width;
		height = isPreiOS8 ? screen.width : screen.height;
	} else {
		x = 0.0;
		y = 0.0;
		width = screen.width;
		height = screen.height;
	}
	return CGRectMake(x, y, width, height);
}

+ (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	int rotationLockPosition = [[NSUserDefaults standardUserDefaults] integerForKey:ROTATION_LOCK_POSITION];
	//NSLog(@"rotationLockPosition == %i", rotationLockPosition);

	if (rotationLockPosition == RotationEnabled) { return YES; }
	
	if (rotationLockPosition == RotationLockedInLandscape && (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight)) { return YES; }
	
	if (rotationLockPosition == RotationLockedInPortrait && (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)) { return YES; }
	
	return NO;
}

+ (NSUInteger)supportedInterfaceOrientations {
	int rotationLockPosition = [[NSUserDefaults standardUserDefaults] integerForKey:ROTATION_LOCK_POSITION];
	switch (rotationLockPosition) {
		case RotationEnabled:
		{
			if([PSResizing iPad]) {
				return UIInterfaceOrientationMaskAll;
			} else {
				return UIInterfaceOrientationMaskAllButUpsideDown;
			}
		}
			break;
		case RotationLockedInLandscape:
		{
			return UIInterfaceOrientationMaskLandscape;
		}
			break;
		case RotationLockedInPortrait:
		{
			if([PSResizing iPad]) {
				return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
			} else {
				return UIInterfaceOrientationMaskPortrait;
			}
		}
			break;
		default:
			return UIInterfaceOrientationMaskAll;
	}
}

+ (BOOL)iPad {
	if([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)] && (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone)) {
		return YES;
	} else {
		return NO;
	}

}

+ (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *)path {
	// make sure we're not backing up this folder!
	DLog(@"Don't Backup:\n---\n%@\n---\n", path);
	
//	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.1") && &NSURLIsExcludedFromBackupKey) {
	if(&NSURLIsExcludedFromBackupKey) {
		// iOS 5.1 and later:
		NSURL *URL = [NSURL fileURLWithPath:path isDirectory:YES];
		
		assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
		
		NSError *error = nil;
		BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
									  forKey: NSURLIsExcludedFromBackupKey error: &error];
		if(!success){
			ALog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
		}
		return success;
	}
//	else {
//		// iOS 5.0.1 and earlier method, as this is backwards compatible with iOS 3.0 :P
//		const char* filePath = [path fileSystemRepresentation];
//		
//		const char* attrName = "com.apple.MobileBackup";
//		u_int8_t attrValue = 1;
//		
//		int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
//		return result == 0;
//	}
	return YES;
}

@end
