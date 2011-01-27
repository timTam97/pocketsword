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

static PSBookmarks *psBookmarks;
/** the singleton instance */
+ (PSBookmarks *)defaultBookmarks {
    if(psBookmarks == nil) {
        psBookmarks = [[PSBookmarks alloc] init];
    }
    
	return psBookmarks;
}

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

+ (NSMutableArray *)getBookmarksForCurrentRef {
	NSString *currentRef = [PSModuleController getCurrentBibleRef];
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
		NSArray *kids = [array objectAtIndex:6];
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

- (void)loadBookmarksFromFile {
	DLog(@"\nBookmarks: loadBookmarksFromFile");
    NSString *bookmarksPath = [DEFAULT_BOOKMARKS_PATH stringByAppendingPathComponent:@"PSBookmarks.plist"];
	NSArray *data = [NSArray arrayWithContentsOfFile:bookmarksPath];
	NSMutableArray *kidsArray = [NSMutableArray arrayWithCapacity:2];
	if(data) {
		for(NSArray *child in data) {
			PSBookmarkObject *kid = [self parseArray:child];
			[kidsArray addObject:kid];
			[kid release];
		}
        self.children = kidsArray;
    } else {
        self.children = [NSArray array];
    }
	DLog(@"\n-- Bookmarks: finished loadBookmarksFromFile");
}

- (id)init {
	self = [super initWithName:nil dateAdded:nil dateLastAccessed:nil rgbHexString:nil children:nil];
	if(self) {
		self.name = NSLocalizedString(@"BookmarksTitle", @"");
		[self loadBookmarksFromFile];
	}
	return self;
}

- (NSArray *)parseBookmarkObject:(PSBookmarkObject*)bookmarkObject {
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
			NSArray *kid = [self parseBookmarkObject:child];
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
	DLog(@"\nBookmarks: saveBookmarksToFile");
    NSString *bookmarksPath = [DEFAULT_BOOKMARKS_PATH stringByAppendingPathComponent:@"PSBookmarks.plist"];
	if(bookmarks.children && [bookmarks.children count] > 0) {
		NSMutableArray *data = [NSMutableArray arrayWithCapacity:[bookmarks.children count]];
		for(PSBookmarkObject *child in bookmarks.children) {
			NSArray *kid = [bookmarks parseBookmarkObject:child];
			[data addObject:kid];
			//[kid release]; -- they're autorelease objects :P
		}
		ret = [data writeToFile:bookmarksPath atomically:YES];
	}
	
	DLog(@"\n-- Bookmarks: finished saveBookmarksToFile");
	return ret;
}


@end
