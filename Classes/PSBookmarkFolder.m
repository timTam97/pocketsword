//
//  PSBookmarkFolder.m
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

#import "PSBookmarkFolder.h"
#import "PSBookmark.h"


@implementation PSBookmarkFolder

@synthesize children;

+ (NSString*)hexStringFromColor:(UIColor *)color {
    const CGFloat *c = CGColorGetComponents(color.CGColor);
	CGFloat r, g, b;
	r = c[0];
	g = c[1];
	b = c[2];
	
	// Fix range if needed
	if (r < 0.0f) r = 0.0f;
	if (g < 0.0f) g = 0.0f;
	if (b < 0.0f) b = 0.0f;
	
	if (r > 1.0f) r = 1.0f;
	if (g > 1.0f) g = 1.0f;
	if (b > 1.0f) b = 1.0f;
	
	// Convert to hex string between 0x00 and 0xFF
	return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

+ (UIColor*)colorFromHexString:(NSString*)hexString {
	//NSLog(@"%@", hexString);
	if(!hexString || [hexString length] < 7)
		return [UIColor clearColor];
	NSString *rString = [NSString stringWithFormat:@"0x%@", [hexString substringWithRange:NSMakeRange(1, 2)]];
	float r, g, b;
	[[NSScanner scannerWithString:rString] scanHexFloat:&r];
	//NSLog(@"%@ - %f", rString, r);
	NSString *gString = [NSString stringWithFormat:@"0x%@", [hexString substringWithRange:NSMakeRange(3, 2)]];
	[[NSScanner scannerWithString:gString] scanHexFloat:&g];
	//NSLog(@"%@ - %f", gString, g);
	NSString *bString = [NSString stringWithFormat:@"0x%@", [hexString substringWithRange:NSMakeRange(5, 2)]];
	[[NSScanner scannerWithString:bString] scanHexFloat:&b];
	//NSLog(@"%@ - %f", bString, b);
	
	return [UIColor colorWithRed:(r/255.0f) green:(g/255.0f) blue:(b/255.0f) alpha:0.8f];
}

+ (NSString*)rgbStringFromHexString:(NSString*)hexString {
	//NSLog(@"%@", hexString);
	if(!hexString || [hexString length] < 7)
		return @"transparent";
	NSString *rString = [NSString stringWithFormat:@"0x%@", [hexString substringWithRange:NSMakeRange(1, 2)]];
	float r, g, b;
	[[NSScanner scannerWithString:rString] scanHexFloat:&r];
	//NSLog(@"%@ - %f", rString, r);
	NSString *gString = [NSString stringWithFormat:@"0x%@", [hexString substringWithRange:NSMakeRange(3, 2)]];
	[[NSScanner scannerWithString:gString] scanHexFloat:&g];
	//NSLog(@"%@ - %f", gString, g);
	NSString *bString = [NSString stringWithFormat:@"0x%@", [hexString substringWithRange:NSMakeRange(5, 2)]];
	[[NSScanner scannerWithString:bString] scanHexFloat:&b];
	//NSLog(@"%@ - %f", bString, b);
	
	return [NSString stringWithFormat:@"rgba(%d,%d,%d,0.8)", (int)r, (int)g, (int)b];
}

- (id)init {
	self = [super init];
	if(self) {
		folder = YES;
	}
	return self;
}

- (id)initWithName:(NSString *)n dateAdded:(NSDate *)da dateLastAccessed:(NSDate *)dla rgbHexString:(NSString*)rgb children:(NSArray*)c {
	self = [super initWithName:n dateAdded:da dateLastAccessed:dla];
	if(self) {
		self.rgbHexString = rgb;
		self.children = c;
		folder = YES;
	}
	return self;
}

- (void)dealloc {
	self.children = nil;
	self.rgbHexString = nil;
	[super dealloc];
}

- (void)addChild:(PSBookmarkObject*)child {
	int capacity = 1;
	if(children)
		capacity += [children count];
	NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:capacity];
	if(children)
		[tmpArray addObjectsFromArray:children];
	[tmpArray addObject:child];
	self.children = tmpArray;
}

- (void)addChildren:(NSArray*)kids {
	int capacity = [kids count];
	if(children)
		capacity += [children count];
	NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:capacity];
	if(children)
		[tmpArray addObjectsFromArray:children];
	[tmpArray addObjectsFromArray:kids];
	self.children = tmpArray;
}

- (NSArray*)folders {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:5];
	for(PSBookmarkObject *obj in children) {
		if(obj.folder) {
			[ret addObject:obj];
		}
	}
	return ret;
}

- (NSString *)getHighlightRGBColourStringForBookAndChapterRef:(NSString*)bookAndChapterRef withVerse:(NSString *)verse {
	NSArray *possibleBookmarks = [self getBookmarksForBookAndChapterRef:bookAndChapterRef];
	if(possibleBookmarks && [possibleBookmarks count] > 0) {
		for(PSBookmark *bookmark in possibleBookmarks) {
			if(bookmark.rgbHexString) {
				NSString *v = [[bookmark.ref componentsSeparatedByString:@":"] objectAtIndex: 1];
				if([v isEqualToString:verse]) {
					//return bookmark.rgbHexString;
					return [PSBookmarkFolder rgbStringFromHexString:bookmark.rgbHexString];
				}
				//NSString *jsFunction = [NSString stringWithFormat:@"PS_HighlightVerseWithHexColour('%@','%@')", verse, [PSBookmarkFolder rgbStringFromHexString:bookmark.rgbHexString]];
			}
		}
	}
	return nil;
}

- (NSMutableArray *)getBookmarksForBookAndChapterRef:(NSString*)bookAndChapterRef {
	
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:1];
	for(PSBookmarkObject *bookmarkObject in self.children) {
		if([bookmarkObject isMemberOfClass:[PSBookmark class]]) {
			// tis a bookmark
			NSRange colonLocation = [((PSBookmark*)bookmarkObject).ref rangeOfString:@":"];
			if(colonLocation.location != NSNotFound) {
				NSString *bookmarkBookAndChapterRef = [((PSBookmark*)bookmarkObject).ref substringToIndex:colonLocation.location];
				if([bookmarkBookAndChapterRef isEqualToString:bookAndChapterRef]) {
					// tmp set the colour hex string to the colour of the enclosing folder (us/self!).
					bookmarkObject.rgbHexString = self.rgbHexString;
					[ret addObject:bookmarkObject];
				}
			}
		} else {
			// or could either be a PSBookmarkFolder or the PSBookmarks
			[ret addObjectsFromArray:[((PSBookmarkFolder*)bookmarkObject) getBookmarksForBookAndChapterRef:bookAndChapterRef]];
		}
	}
	return ret;
	
}

@end
