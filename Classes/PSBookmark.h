//
//  PSBookmark.h
//  PocketSword
//
//  Created by Nic Carter on 5/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkObject.h"

@interface PSBookmark : PSBookmarkObject {
	
	NSString *ref;
}

@property (retain, readwrite) NSString *ref;

@end
