//
//  PSIndexController.mm
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSIndexController.h"


@implementation PSIndexController

@synthesize downloadableIndices;
@synthesize installedIndices;
@synthesize noAvailableIndices;

@synthesize moduleManager;

- (BOOL)updateInstalledIndexListWithRemoteIndices {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	//NSMutableArray *ri = [NSMutableArray arrayWithObject: nil];
	
	NSString *remoteDir = @"http://pocketsword.net/indices/";
	
	// Get the index directory listing
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: remoteDir]
											 cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	NSData *responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		DLog(@"Couldn't list remote directory");
		//as a fallback, call the local version:
		[self updateInstalledIndexList];
		[pool release];
		return NO;
	}
	
	NSString *dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
	NSMutableArray *files = [NSMutableArray arrayWithObjects: nil];
	NSRange dataRange;
	
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *link = [dataString substringToIndex: dataRange.location];
			//if ([item UTF8String][0] != '/') {
			//if (![item hasPrefix:@"/"] && ![item hasSuffix:@"/"]) {
			if ([link hasSuffix:@".zip"]) {
				link = [link substringToIndex: ([link length] - 4)];
				[files addObject: link];
				//NSLog(@"found a file: %@", item);
			}
		}
	}
	
	NSMutableArray *modules = [[[moduleManager swordManager] listModules] mutableCopy];
	NSMutableArray *current = [NSMutableArray arrayWithObjects: nil];
	NSMutableArray *rest = [NSMutableArray arrayWithObjects: nil];

	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[modules sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];
	
	//first get the installed indices:
	for(SwordModule *mod in modules) {
		if([mod hasSearchIndex]) {
			[current addObject: [mod name]];
			NSLog(@"installed index for: %@", [mod name]);
		} else {
			[rest addObject: mod];
		}
	}
	
	self.installedIndices = current;
	//[current release];
	
	//reset
	current = [NSMutableArray arrayWithObjects: nil];
	modules = rest;
	rest = [NSMutableArray arrayWithObjects: nil];
	
	//next get the downloadable indices:
	for(SwordModule *mod in modules) {
		if([files containsObject: [[mod name] lowercaseString]]) {
			[current addObject: [mod name]];
			NSLog(@"downloadable index for: %@", [mod name]);
		} else {
			[rest addObject: [mod name]];
			NSLog(@"no available index for: %@", [mod name]);
		}
	}
	
	self.downloadableIndices = current;
	//[current release];

	self.noAvailableIndices = rest;
	//[rest release];

	[pool release];
	return YES;
}

- (void)updateInstalledIndexList {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSArray *modules = [[moduleManager swordManager] listModules];
	NSMutableArray *ii = [NSMutableArray arrayWithObjects: nil];
	NSMutableArray *rest = [NSMutableArray arrayWithObjects: nil];
	
	for(SwordModule *mod in modules) {
		if([mod hasSearchIndex]) {
			[ii addObject: [mod name]];
		} else {
			[rest addObject: [mod name]];
		}
	}
	
	self.installedIndices = ii;
	[ii release];
	self.noAvailableIndices = rest;
	[rest release];
	
	[pool release];
}

- (BOOL)installIndexForModule:(NSString *)mod {
	
}

-(void)dealloc {
	self.downloadableIndices = nil;
	self.installedIndices = nil;
	self.noAvailableIndices = nil;
	self.moduleManager = nil;
	[super dealloc];
}

@end
