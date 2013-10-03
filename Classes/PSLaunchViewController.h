//
//  PSLaunchViewController.h
//  PocketSword
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

@protocol PSLaunchDelegate <NSObject>
@required
- (void)finishedInitializingPocketSword:(id)launchViewController;
@end


@interface PSLaunchViewController : UIViewController {
	id <PSLaunchDelegate> delegate;
}

@property (nonatomic, assign) id <PSLaunchDelegate> delegate;

+ (void)resetPreferences;
- (void)startInitializingPocketSword;

@end
