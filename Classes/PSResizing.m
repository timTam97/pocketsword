//
//  PSResizing.m
//  PocketSword
//
//  Created by Nic Carter on 1/10/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSResizing.h"


@implementation PSResizing

+(void)resizeViewsOnAppearWithTabBar:(UITabBar*)tabBar topBar:(UIView*)topBar mainView:(UIView*)mainView useStatusBar:(BOOL)useStatusBar {
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	CGFloat barLandscapeHeight = 32.0, barPortraitHeight = 44.0;
	CGFloat barHeight, viewHeight, width;
	CGFloat tabBarHeight = tabBar.frame.size.height;
	
	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	if(deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight) {
		width = screen.height;
		barHeight = barLandscapeHeight;
		viewHeight = screen.width - barLandscapeHeight - tabBarHeight;// - [UIApplication sharedApplication].statusBarFrame.size.width;
		if(useStatusBar) {
			viewHeight -= [UIApplication sharedApplication].statusBarFrame.size.width;
		}
	} else {
		width = screen.width;
		barHeight = barPortraitHeight;
		viewHeight = screen.height - barPortraitHeight - tabBarHeight;// - [UIApplication sharedApplication].statusBarFrame.size.height;
		if(useStatusBar) {
			viewHeight -= [UIApplication sharedApplication].statusBarFrame.size.height;
		}
	}
	topBar.frame = CGRectMake(0.0, 0.0, width, barHeight);
	mainView.frame = CGRectMake(0.0, barHeight, width, viewHeight);
}

+(void)resizeViewsOnRotateWithTabBar:(UITabBar*)tabBar topBar:(UIView*)topBar mainView:(UIView*)mainView fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	CGFloat barLandscapeHeight = 32.0, barPortraitHeight = 44.0;
	CGFloat barHeight, viewHeight, width;
	CGFloat tabBarHeight = tabBar.frame.size.height;
	if((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) && !(fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
		width = screen.width;
		barHeight = barLandscapeHeight;
		viewHeight = screen.height - barLandscapeHeight - tabBarHeight - [UIApplication sharedApplication].statusBarFrame.size.height;
	} else if((toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) && !(fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)) {
		width = screen.height;
		barHeight = barPortraitHeight;
		viewHeight = screen.width - barPortraitHeight - tabBarHeight - [UIApplication sharedApplication].statusBarFrame.size.width;
	}
	topBar.frame = CGRectMake(0.0, 0.0, width, barHeight);
	mainView.frame = CGRectMake(0.0, barHeight, width, viewHeight);
}
@end
