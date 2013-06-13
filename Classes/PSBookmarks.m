//
//  PSBookmarks.m
//  PocketSword
//
//  Created by Nic Carter on 12/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarks.h"
#import "globals.h"
#import "PSBookmark.h"
#import "PSBookmarkFolder.h"
#import "PSModuleController.h"

@implementation PSBookmarks

static PSBookmarks *psDefaultBookmarks;// = nil;
/** the singleton instance */
+ (PSBookmarks *)defaultBookmarks {
	//DLog(@"\nattempting access to our bookmarks...");
    if(psDefaultBookmarks == nil) {
		//DLog(@"\nOur bookmarks object doesn't exist! :P");
        psDefaultBookmarks = [[PSBookmarks alloc] initLocalBookmarks];
    }
	return psDefaultBookmarks;
}

//+ (void)initialize {
//	if (self == [PSBookmarks class]) {
//		DLog(@"\ninitialize");
//        psDefaultBookmarks = [[self alloc] initLocalBookmarks];
//    }
//}

+ (BOOL)addBookmarkObject:(PSBookmarkObject*)bookmark withFolderString:(NSString*)folderString {
	BOOL ret = NO;
	PSBookmarks *bookmarks = [PSBookmarks defaultBookmarks];
	if(!folderString || [folderString isEqualToString:@""]) {
		[bookmarks addChild:bookmark];
		ret = YES;
	} else {
		PSBookmarkFolder *parentFolder = [PSBookmarks getBookmarkFolderForFolderString:folderString];
		[parentFolder addChild:bookmark];
		ret = YES;
	}
	[PSBookmarks saveBookmarksToFile];
	return ret;
}

+ (BOOL)addBookmarkWithRef:(NSString*)r name:(NSString*)n folderString:(NSString*)folderString {
	NSDate *date = [NSDate date];
	PSBookmark *bookmark = [[PSBookmark alloc] initWithName:n dateAdded:date dateLastAccessed:date bibleReference:r];
	BOOL ret = [PSBookmarks addBookmarkObject:bookmark withFolderString:folderString];
	[bookmark release];
	return ret;
}

+ (void)deleteBookmark:(NSString*)n fromFolderString:(NSString*)folderString {
	PSBookmarkFolder *parent = [PSBookmarks getBookmarkFolderForFolderString:folderString];
	NSMutableArray *array = [parent.children mutableCopy];
	// need to identify which is the correct child
	for(PSBookmarkObject *obj in array) {
		if([obj.name isEqualToString:n]) {
			[array removeObject:obj];
			break;
		}
	}
	parent.children = array;
	[array release];
	[PSBookmarks saveBookmarksToFile];
}

+ (PSBookmarkFolder*)getBookmarkFolderForFolderString:(NSString*)folderString {
	PSBookmarks *bookmarks = [PSBookmarks defaultBookmarks];
	if(!folderString || [folderString isEqualToString:@""] || [folderString isEqualToString:NSLocalizedString(@"BookmarksTitle", @"")]) {
		return bookmarks;
	}
	NSArray *folders = [folderString componentsSeparatedByString:PSFolderSeparatorString];
	PSBookmarkFolder *parentFolder = bookmarks;
	for(int folderCount=0; folderCount<[folders count];folderCount++) {
		BOOL foundFolder = NO;
		for(int kidNumber=0;kidNumber<[parentFolder.children count];kidNumber++) {
			if([((PSBookmarkObject*)[parentFolder.children objectAtIndex:kidNumber]).name isEqualToString:[folders objectAtIndex:folderCount]]) {
				parentFolder = [parentFolder.children objectAtIndex:kidNumber];
				foundFolder = YES;
				break;
			}
		}
		if(!foundFolder) {
			// if we don't find the next folder, just place the bookmark here.  This shouldn't be possible!
			ALog(@"getBookmarkFolderForFolderString: couldn't find the folder - %@", [folders objectAtIndex:folderCount]);
			break;
		}
	}
	return parentFolder;
}

+ (NSString *)getHighlightRGBColourStringForBookAndChapterRef:(NSString*)bookAndChapterRef withVerse:(NSInteger)verse {
	return [[PSBookmarks defaultBookmarks] getHighlightRGBColourStringForBookAndChapterRef:bookAndChapterRef withVerse:[NSString stringWithFormat:@"%d", verse]];
}

+ (NSMutableArray *)getBookmarksForCurrentRef {
	NSString *currentRef = [PSModuleController createRefString:[PSModuleController getCurrentBibleRef]];
	return [PSBookmarks getBookmarksForBookAndChapterRef:currentRef];
}

+ (NSMutableArray *)getBookmarksForBookAndChapterRef:(NSString*)bookAndChapterRef {
	PSBookmarks *bookmarks = [PSBookmarks defaultBookmarks];
	return [bookmarks getBookmarksForBookAndChapterRef:bookAndChapterRef];
}

- (PSBookmarkObject *)parseArray:(NSArray *)array {
	if(!array)
		return nil;
	else if([array count] == 0)
		return nil;
	
	NSString *n = [array objectAtIndex:0];
	NSDate *da = [array objectAtIndex:1];
	NSDate *dla = [array objectAtIndex:2];
	NSString *folderString = [array objectAtIndex:3];
	if([folderString boolValue]) {
		//tis a folder
		NSString *rgb = [array objectAtIndex:4];
		if([rgb isEqualToString:@""]) {
			rgb = nil;
		}
		NSArray *kids = [array objectAtIndex:5];
		NSMutableArray *kidsArray = [NSMutableArray arrayWithCapacity:[kids count]];
		for(NSArray *child in kids) {
			PSBookmarkObject *kid = [self parseArray:child];
			[kidsArray addObject:kid];
			[kid release];
		}
		return [[PSBookmarkFolder alloc] initWithName:n dateAdded:da dateLastAccessed:dla rgbHexString:rgb children:kidsArray];
	} else {
		//tis a bookmark
		NSString *r = [array objectAtIndex:4];
		return [[PSBookmark alloc] initWithName:n dateAdded:da dateLastAccessed:dla bibleReference:r];
	}
}

- (void)loadBookmarksFromArray:(NSArray *)dataArray {
	//DLog(@"\nBookmarks: loadBookmarksFromFile");
	NSMutableArray *kidsArray = [NSMutableArray arrayWithCapacity:2];
	if(dataArray) {
		for(NSArray *child in dataArray) {
			PSBookmarkObject *kid = [self parseArray:child];
			[kidsArray addObject:kid];
			[kid release];
		}
        self.children = kidsArray;
    } else {
        self.children = [NSArray array];
    }
	//DLog(@"\n-- Bookmarks: finished loadBookmarksFromFile");
}

- (id)initLocalBookmarks {
	self = [super initWithName:nil dateAdded:nil dateLastAccessed:nil rgbHexString:nil children:nil];
	if(self) {
		self.name = NSLocalizedString(@"BookmarksTitle", @"");
		NSString *bookmarksPath = [DEFAULT_BOOKMARKS_PATH stringByAppendingPathComponent:@"PSBookmarks.plist"];
		NSArray *dataArray = [NSArray arrayWithContentsOfFile:bookmarksPath];
		[self loadBookmarksFromArray:dataArray];
	}
//	DLog(@"\n***\ncreated a local PSBookmarks object...\n***\n");
	return self;
}

- (id)initCloudBookmarks {
	self = [super initWithName:nil dateAdded:nil dateLastAccessed:nil rgbHexString:nil children:nil];
	if(self) {
		self.name = NSLocalizedString(@"BookmarksTitle", @"");
		NSData *data = [@"plistStringToCreateADataThingo" dataUsingEncoding:NSUTF8StringEncoding];
		//format should be NSPropertyListXMLFormat_v1_0
		NSArray *array = [NSPropertyListSerialization
						  propertyListWithData:data
						  options:NSPropertyListImmutable
						  format:NULL
						  error:NULL];
		[self loadBookmarksFromArray:array];
	}
//	DLog(@"\n***\ncreated a cloud PSBookmarks object...\n***\n");
	return self;

	// to write back, use:
//	[NSPropertyListSerialization dataWithPropertyList:array format:NSPropertyListXMLFormat_v1_0 options:NSPropertyListImmutable error:NULL];
//	+ (NSData *)dataWithPropertyList:(id)plist format:(NSPropertyListFormat)format options:(NSPropertyListWriteOptions)opt error:(NSError **)error


}

+ (NSDate *)lastModified:(PSBookmarkObject *)bookmarkObject {
	
	NSDate *returnDate = bookmarkObject.dateLastAccessed;
	if(bookmarkObject.folder) {
		for(PSBookmarkObject *child in ((PSBookmarkFolder *)bookmarkObject).children) {
			NSDate *childDate = [PSBookmarks lastModified:child];
			if([childDate compare:returnDate] == NSOrderedDescending) {
				returnDate = child.dateLastAccessed;
			}
		}
	}
	return returnDate;
	
}

+ (NSDate *)lastModified {
	PSBookmarks *bookmarks = [PSBookmarks defaultBookmarks];
	return [PSBookmarks lastModified:bookmarks];
}

// if our current bookmarks have been modified more recently than the new one we're sent via the cloud
//    combine the bookmarks rather than deleting any.
//    and create a copy of iCloud + local as backups.

+ (NSArray *)parseBookmarkObject:(PSBookmarkObject*)bookmarkObject {
	if(!bookmarkObject)
		return nil;
	int capacity = (bookmarkObject.folder) ? 7 : 5;
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:capacity];
	[ret addObject:bookmarkObject.name];
	[ret addObject:bookmarkObject.dateAdded];
	[ret addObject:bookmarkObject.dateLastAccessed];
	if(bookmarkObject.folder) {
		[ret addObject:@"YES"];
		if(((PSBookmarkFolder*)bookmarkObject).rgbHexString) {
			[ret addObject:((PSBookmarkFolder*)bookmarkObject).rgbHexString];
		} else {
			[ret addObject:@""];
		}
		NSMutableArray *kids = [NSMutableArray arrayWithCapacity:[((PSBookmarkFolder*)bookmarkObject).children count]];
		for(PSBookmarkObject *child in ((PSBookmarkFolder*)bookmarkObject).children) {
			NSArray *kid = [PSBookmarks parseBookmarkObject:child];
			[kids addObject:kid];
			//[kid release]; -- they're autorelease objects :P
		}
		[ret addObject:kids];
		
	} else {
		[ret addObject:@"NO"];
		[ret addObject:((PSBookmark*)bookmarkObject).ref];
	}
	
	return ret;
}

+ (BOOL)saveBookmarksToFile {
	PSBookmarks *bookmarks = [PSBookmarks defaultBookmarks];
	BOOL ret = NO;
	//DLog(@"\nBookmarks: saveBookmarksToFile");
    NSString *bookmarksPath = [DEFAULT_BOOKMARKS_PATH stringByAppendingPathComponent:@"PSBookmarks.plist"];
	if(bookmarks.children && [bookmarks.children count] > 0) {
		NSMutableArray *data = [NSMutableArray arrayWithCapacity:[bookmarks.children count]];
		for(PSBookmarkObject *child in bookmarks.children) {
			NSArray *kid = [PSBookmarks parseBookmarkObject:child];
			[data addObject:kid];
			//[kid release]; -- they're autorelease objects :P
		}
		ret = [data writeToFile:bookmarksPath atomically:YES];
	} else {
		// no bookmarks left! Write out the file to zeros...
		NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];
		ret = [data writeToFile:bookmarksPath atomically:NO];
	}
	
	DLog(@"\n-- Bookmarks: finished saveBookmarksToFile");
	return ret;
}

+ (void)importBookmarksFromV2 {
	NSArray *oldBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey: @"bookmarks2"];
	
	if(oldBookmarks) {
		PSBookmarks *bookmarks = [PSBookmarks defaultBookmarks];
		BOOL createImportedFolder = YES;
		for(PSBookmarkObject* obj in bookmarks.children) {
			if([obj.name isEqualToString:NSLocalizedString(@"BookmarksImportedFolderName", @"")]) {
				// if there already exists an @"imported" folder, don't recreate it!
				createImportedFolder = NO;
				break;
			}
		}
		if(createImportedFolder) {
			PSBookmarkFolder *importFolder = [[PSBookmarkFolder alloc] initWithName:NSLocalizedString(@"BookmarksImportedFolderName", @"") dateAdded:[NSDate date] dateLastAccessed:[NSDate date] rgbHexString:nil children:nil];
			[PSBookmarks addBookmarkObject:importFolder withFolderString:nil];
			[importFolder release];
		}
		for(NSString *ref in oldBookmarks) {
			[PSBookmarks addBookmarkWithRef:[PSModuleController createRefString:ref] name:ref folderString:NSLocalizedString(@"BookmarksImportedFolderName", @"")];
		}
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"bookmarks2"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

@end
