/*	SwordDict.mm - Sword API wrapper for lexicons and Dictionaries.

    Copyright 2008 Manfred Bergmann
    Based on code by Will Thimbleby

	This program is free software; you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation version 2.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
	even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	General Public License for more details. (http://www.gnu.org/licenses/gpl.html)
*/

#import "SwordDictionary.h"
#import "SwordModuleTextEntry.h"
#import "utils.h"
#import "globals.h"
#import "SwordManager.h"

@interface SwordDictionary (/* Private, class continuation */)
/** private property */
@property(readwrite, retain) NSMutableArray *keys;
@end

@interface SwordDictionary (PrivateAPI)

- (void)readKeys;
- (void)readFromCache;
- (void)writeToCache;

@end

@implementation SwordDictionary (PrivateAPI)

/**
 only the keys are stored here in an array
 */
- (void)readKeys {    
	if(!keys) {
        [self readFromCache];
    }
    
    // still no entries?
	if([keys count] == 0) {
		DLog(@"\nSwordDictionary starting to index %@", name);
        NSMutableArray *arr = [NSMutableArray array];

        [moduleLock lock];
        
        swModule->setSkipConsecutiveLinks(true);
        *swModule = sword::TOP;
        swModule->getRawEntry();        
        while(![self error]) {
            char *cStrKeyText = (char *)swModule->getKeyText();
            if(cStrKeyText) {
                NSString *keyText = [NSString stringWithUTF8String:cStrKeyText];
                if(!keyText) {
                    keyText = [NSString stringWithCString:swModule->getKeyText() encoding:NSISOLatin1StringEncoding];
                    if(!keyText) {
                        ALog(@"[SwordCommentary -readKeys] unable to create NSString instance from string: %s", cStrKeyText);
                    }
                }
                
                if(keyText) {
                    [arr addObject:[keyText capitalizedString]];
                }
            } else {
                ALog(@"[SwordCommentary -readKeys] could not get keytext from sword module!");                
            }
            
            (*swModule)++;
        }

        //DLog(@"\n-- SwordDictionary finished indexing...");
		[moduleLock unlock];
        
        self.keys = arr;
        [self writeToCache];
    }
	loaded = YES;
}

- (NSString*)cachePath {
	NSString *v = [self configEntryForKey:SWMOD_CONFENTRY_VERSION];
	if(v == nil)
		v = @"0.0";//if there's no version information, it's version 0.0!
    return [DEFAULT_APPSUPPORT_PATH stringByAppendingPathComponent:[NSString stringWithFormat:@"cache-%@-%@", [self name], v]];	
}

- (void)readFromCache {
	//open cached file
	//DLog(@"\nSwordDictionary: readFromCache %@", name);
	NSMutableArray *data = [NSMutableArray arrayWithContentsOfFile:[self cachePath]];
    if(data) {
        self.keys = data;
    } else {
        self.keys = [NSMutableArray array];
    }
	//DLog(@"\n-- SwordDictionary: finished readFromCache");
}

- (void)writeToCache {
	// save cached file
	//DLog(@"\nSwordDictionary: writeToCache %@", name);
	[keys writeToFile:[self cachePath] atomically:NO];
	//DLog(@"\n-- SwordDictionary: finished writeToCache");
}

@end

@implementation SwordDictionary

@synthesize keys;

- (void)removeCache {
	[[NSFileManager defaultManager] removeItemAtPath: [self cachePath] error: NULL];
	DLog(@"\n-- SwordDictionary: removed Cache");
}

- (id)initWithName:(NSString *)aName swordManager:(SwordManager *)aManager {    
	self = [super initWithName:aName swordManager:aManager];
    if(self) {
        self.keys = nil;
		loaded = NO;
    }
    	
	return self;
}

/** init with given SWModule */
- (id)initWithSWModule:(sword::SWModule *)aModule swordManager:(SwordManager *)aManager {
    self = [super initWithSWModule:aModule swordManager:aManager];
    if(self) {
        self.keys = nil;
		loaded = NO;
    }
    
    return self;
}

- (void)finalize {
	[super finalize];
}

- (void)dealloc {
	self.keys = nil;
	[super dealloc];
}

- (NSArray *)allKeys {
    NSArray *ret = self.keys;
    if(ret == nil) {
        [self readKeys];
        ret = self.keys;
    }
	return ret;    
}

- (BOOL)keysLoaded {
	return loaded;
}

- (void)releaseKeys {
	self.keys = nil;
	loaded = NO;
}

- (BOOL)keysCached {
	return [[NSFileManager defaultManager] fileExistsAtPath: [self cachePath]];
}

- (NSString *)fullRefName:(NSString *)ref {
	[moduleLock lock];
	
	sword::SWKey *key = swModule->createKey();
	if([self isUnicode]) {
		(*key) = toUTF8([ref uppercaseString]);
    } else {
		(*key) = toLatin1([ref uppercaseString]);
    }
	
	swModule->setKey(key);
	swModule->getRawEntry();
	
	NSString *result;
	if([self isUnicode]) {
		result = fromUTF8(swModule->getKeyText());
    } else {
		result = fromLatin1(swModule->getKeyText());
    }
	[moduleLock unlock];
	
	return result;
}

/**
 returns stripped text for key.
 nil if the key does not exist.
 */
- (NSString *)entryForKey:(NSString *)aKey {
	NSString *ret = nil;

	[moduleLock lock];	
	[self setKeyString:aKey];    
	if([self error]) {
		ALog(@"[SwordDictionary -entryForKey:] error on getting key!");
	} else {
		ret = [self renderedText];
	}
	[moduleLock unlock];

	return ret;
}

- (id)attributeValueForParsedLinkData:(NSDictionary *)data {
    id ret = nil;

    [moduleLock lock];
    NSString *attrType = [data objectForKey:ATTRTYPE_TYPE];
    if([attrType isEqualToString:@"scriptRef"] || 
       [attrType isEqualToString:@"scripRef"] ||
       [attrType isEqualToString:@"Greek"] ||
       [attrType isEqualToString:@"Hebrew"]) {
        NSString *key = [data objectForKey:ATTRTYPE_VALUE];
        ret = [self strippedTextEntriesForRef:key];
    }
    [moduleLock unlock];
    
    return ret;
}

#pragma mark - SwordModuleAccess


- (long)entryCount {
    return [[self allKeys] count];    
}

@end
