//
//  PSResizing.h
//  PocketSword
//
//  Created by Nic Carter on 1/10/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

@interface PSResizing : NSObject {

}

+(void)resizeViewsOnAppearWithTabBar:(UITabBar*)tabBar topBar:(UIView*)topBar mainView:(UIView*)mainView useStatusBar:(BOOL)useStatusBar;
+(void)resizeViewsOnRotateWithTabBar:(UITabBar*)tabBar topBar:(UIView*)topBar mainView:(UIView*)mainView fromOrientation:(UIInterfaceOrientation)fromInterfaceOrientation toOrientation:(UIInterfaceOrientation)toInterfaceOrientation;

@end
