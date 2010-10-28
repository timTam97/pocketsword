//
//  PSResizing.m
//  PocketSword
//
//  Created by Nic Carter on 1/10/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSResizing.h"

#define TOP_BAR_LANDSCAPE_HEIGHT 32.0
#define TOP_BAR_PORTRAIT_HEIGHT 44.0
//#define TAB_BAR_PORTRAIT_HEIGHT 49.0
//#define TAB_BAR_LANDSCAPE_HEIGHT 35.0

@implementation PSResizing

+(void)resizeViewsOnAppearWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView useStatusBar:(BOOL)useStatusBar {
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	CGFloat barHeight, viewHeight, width;//, tabBarY;
	CGFloat tabBarHeight = (tabBarController) ? tabBarController.tabBar.frame.size.height : 0.0;
	BOOL redrawInNewFrames = NO;
	
	UIInterfaceOrientation interfaceOrientation = tabBarController.interfaceOrientation;
	if(!tabBarController) {
		UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
		if(UIDeviceOrientationIsLandscape(deviceOrientation))
			interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
		else if(UIDeviceOrientationIsPortrait(deviceOrientation))
			interfaceOrientation = UIInterfaceOrientationPortrait;
	}
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		redrawInNewFrames = YES;
		//tabBarHeight = TAB_BAR_LANDSCAPE_HEIGHT;
		width = screen.height;
		barHeight = TOP_BAR_LANDSCAPE_HEIGHT;
		viewHeight = screen.width - TOP_BAR_LANDSCAPE_HEIGHT - tabBarHeight;// - [UIApplication sharedApplication].statusBarFrame.size.width;
		if(useStatusBar) {
			viewHeight -= [UIApplication sharedApplication].statusBarFrame.size.width;
		}
		//tabBarY = viewHeight+barHeight;
		//if(useStatusBar) tabBarY += [UIApplication sharedApplication].statusBarFrame.size.width;
	} else if(interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
		redrawInNewFrames = YES;
		//tabBarHeight = TAB_BAR_PORTRAIT_HEIGHT;
		width = screen.width;
		barHeight = TOP_BAR_PORTRAIT_HEIGHT;
		viewHeight = screen.height - TOP_BAR_PORTRAIT_HEIGHT - tabBarHeight;// - [UIApplication sharedApplication].statusBarFrame.size.height;
		if(useStatusBar) {
			viewHeight -= [UIApplication sharedApplication].statusBarFrame.size.height;
		}
		//tabBarY = viewHeight+barHeight;
		//if(useStatusBar) tabBarY += [UIApplication sharedApplication].statusBarFrame.size.height;
	}
	if(redrawInNewFrames) {
		topBar.frame = CGRectMake(0.0, 0.0, width, barHeight);
		[topBar layoutIfNeeded];
		[topBar setNeedsDisplay];
		mainView.frame = CGRectMake(0.0, barHeight, width, viewHeight);
		//tabBarController.tabBar.frame = CGRectMake(0.0, tabBarY, width, tabBarHeight);
		//tabBarController.selectedViewController.view.frame = CGRectMake(0.0, 0.0, width, tabBarY);
	}
}

+(void)resizeViewsOnRotateWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	//CGFloat barLandscapeHeight = 32.0, barPortraitHeight = 44.0;
	CGFloat barHeight, viewHeight, width;
	CGFloat tabBarHeight = (tabBarController) ? tabBarController.tabBar.frame.size.height : 0.0;
	BOOL redrawInNewFrames = NO;
	if((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) && !(fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
		width = screen.width;
		barHeight = TOP_BAR_LANDSCAPE_HEIGHT;
		viewHeight = screen.height - TOP_BAR_LANDSCAPE_HEIGHT - tabBarHeight - [UIApplication sharedApplication].statusBarFrame.size.height;
		redrawInNewFrames = YES;
	} else if((toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) && !(fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)) {
		width = screen.height;
		barHeight = TOP_BAR_PORTRAIT_HEIGHT;
		viewHeight = screen.width - TOP_BAR_PORTRAIT_HEIGHT - tabBarHeight - [UIApplication sharedApplication].statusBarFrame.size.width;
		redrawInNewFrames = YES;
	}
	if(redrawInNewFrames) {
		topBar.frame = CGRectMake(0.0, 0.0, width, barHeight);
		mainView.frame = CGRectMake(0.0, barHeight, width, viewHeight);
	}
}

+ (CGRect)getOrientationRect:(UIInterfaceOrientation)interfaceOrientation {
	CGFloat x,y,width,height;
	CGSize screen = [[UIScreen mainScreen] bounds].size;
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		x = 0.0;
		y = 0.0;
		width = screen.height;
		height = screen.width;
	} else {
		x = 0.0;
		y = 0.0;
		width = screen.width;
		height = screen.height;
	}
	return CGRectMake(x, y, width, height);
}

@end
