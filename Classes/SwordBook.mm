//
//  SwordBook.mm
//  PocketSword
//
//  Created by Nic Carter on 11/11/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SwordBook.h"


@implementation SwordBook

-(id)initWithBook:(const sword::VerseMgr::Book *)aBook {
    self = [super init];
	if(self) {
		book = aBook;
		name = [[NSString stringWithCString:aBook->getLongName() encoding:NSUTF8StringEncoding] retain];
		chapters = aBook->getChapterMax();
		//NSString *osisName = [NSString stringWithCString:aBook->getOSISName() encoding:NSUTF8StringEncoding];
		//NSString *prefAbbrev = [NSString stringWithCString:aBook->getPreferredAbbreviation() encoding:NSUTF8StringEncoding];
		//NSLog(@"%@::%@::%@", [self name], osisName, prefAbbrev);
	}
	return self;
}

-(NSInteger)verses:(NSInteger)chapter {
	return book->getVerseMax(chapter);
}

-(NSInteger)chapters {
	return chapters;
}

-(NSString*)name {
	return [[[[name stringByReplacingOccurrencesOfString: @"III " withString: @"3 "]
			  stringByReplacingOccurrencesOfString: @"II " withString: @"2 "]
			 stringByReplacingOccurrencesOfString: @"I " withString: @"1 "]
			stringByReplacingOccurrencesOfString: @" of John" withString: @" "];
}

-(void)dealloc {
	[name release];
	//if(book != nil)
	//	delete book;
	[super dealloc];
	//DLog(@"dealloc'd a SwordBook");
}

@end
