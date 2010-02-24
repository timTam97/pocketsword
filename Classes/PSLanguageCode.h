//
//  LanguageCode.h
//  PocketSword
//
//  Created by Nic Carter on 22/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

//#import <Foundation/Foundation.h>


@interface PSLanguageCode : NSObject {
	NSString *code;
	NSString *descr;
}

@property (retain, readwrite) NSString *code;
@property (retain, readwrite) NSString *descr;

+(NSString*)lookupLanguageCode:(NSString*)aCode;
+(void)initLookupTable;
+(void)doneWithLookupTable;


-(id)initWithCode:(NSString*)aCode;
- (void)dealloc;
@end
