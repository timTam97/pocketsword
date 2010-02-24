//
//  SearchWebView.h
//  PocketSword
//
//	based on code from http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/
//  Created by Nic Carter on 13/01/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

@interface UIWebView (SearchWebView)

- (NSInteger)highlightAllOccurencesOfString:(NSString*)str;
- (void)removeAllHighlights;

@end
