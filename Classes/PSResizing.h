//
//  PSResizing.h
//  PocketSword
//
//  Created by Nic Carter on 1/10/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

@interface PSResizing : NSObject {}

+(void)resizeViewsOnAppearWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView useStatusBar:(BOOL)useStatusBar;
+(void)resizeViewsOnAppearWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView bottomBar:(UIView*)bottomBar useStatusBar:(BOOL)useStatusBar;

+(void)resizeViewsOnRotateWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
+(void)resizeViewsOnRotateWithTabBarController:(UITabBarController*)tabBarController topBar:(UIView*)topBar mainView:(UIView*)mainView bottomBar:(UIView*)bottomBar fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation;

+ (CGRect)getOrientationRect:(UIInterfaceOrientation)interfaceOrientation;

+ (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

+ (NSUInteger)supportedInterfaceOrientations;

+ (BOOL)iPad;

+ (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *)path;

@end
