//
//  SwordBook.mm
//  PocketSword
//
//  Created by Nic Carter on 11/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "SwordBook.h"
#include <localemgr.h>


@implementation SwordBook

-(id)initWithBook:(const sword::VersificationMgr::Book *)aBook {
    self = [super init];
	if(self) {
		book = aBook;

		// get system localemgr to be able to translate the english bookname
        sword::LocaleMgr *lmgr = sword::LocaleMgr::getSystemLocaleMgr();
		
		// set localized book name
		name = [NSString stringWithCString:lmgr->translate(aBook->getLongName()) encoding:NSUTF8StringEncoding];
		if(!name) {
			name = [NSString stringWithCString:lmgr->translate(aBook->getLongName()) encoding:NSISOLatin1StringEncoding];
		}
        [name retain];
		
		//name = [[NSString stringWithCString:aBook->getLongName() encoding:NSUTF8StringEncoding] retain];
		chapters = aBook->getChapterMax();
		//NSString *osisName = [NSString stringWithCString:aBook->getOSISName() encoding:NSUTF8StringEncoding];
		//NSString *prefAbbrev = [NSString stringWithCString:aBook->getPreferredAbbreviation() encoding:NSUTF8StringEncoding];
		//NSString *rawName = [NSString stringWithCString:aBook->getLongName() encoding:NSUTF8StringEncoding];
		//DLog(@"\n%@::%@::%@", rawName, osisName, name);
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
			stringByReplacingOccurrencesOfString: @" of John" withString: @""];
}

- (NSString*)shortName {
	NSString *ret = [[self name] stringByReplacingOccurrencesOfString:@" " withString:@""];
	int maxIndex = 3;
	if([ret length] < maxIndex)
		maxIndex = [ret length];
	ret = [ret substringToIndex:maxIndex];
	return ret;
}

-(NSString*)osisName {
	return [NSString stringWithCString:book->getOSISName() encoding:NSUTF8StringEncoding];
}

-(void)dealloc {
	[name release];
	//if(book != nil)
	//	delete book;
	[super dealloc];
	//DLog(@"dealloc'd a SwordBook");
}

@end
