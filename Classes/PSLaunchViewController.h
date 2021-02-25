/*****************************************************************************
 *
 * PSLaunchViewController.h -    We display this while the app is initialising, before
 * it displays a module.
 *
 * Created by Nic Carter on 27/01/11
 *
 * Copyright 2002-2013 CrossWire Bible Society (http://www.crosswire.org)
 *    CrossWire Bible Society
 *    P. O. Box 2528
 *    Tempe, AZ  85280-2528
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation version 2.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 */

@protocol PSLaunchDelegate <NSObject>
@required
- (void)finishedInitializingPocketSword:(id)launchViewController;
@end


@interface PSLaunchViewController : UIViewController {
	id <PSLaunchDelegate> __weak delegate;
}

@property (nonatomic, weak) id <PSLaunchDelegate> delegate;

+ (void)resetPreferences;
- (void)startInitializingPocketSword;

@end
