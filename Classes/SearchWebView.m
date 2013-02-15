//
//  SearchWebView.m
//  PocketSword
//
//	based on code from http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/
//  Created by Nic Carter on 13/01/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "SearchWebView.h"


@implementation UIWebView (SearchWebView)

- (NSInteger)highlightAllOccurencesOfString:(NSString*)str
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"SearchWebView" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self stringByEvaluatingJavaScriptFromString:jsCode];
	
    NSString *startSearch = [NSString stringWithFormat:@"PS_HighlightAllOccurencesOfString('%@')",str];
    [self stringByEvaluatingJavaScriptFromString:startSearch];
	
    NSString *result = [self stringByEvaluatingJavaScriptFromString:@"PS_SearchResultCount"];
    return [result integerValue];
}

- (void)removeAllHighlights
{
    [self stringByEvaluatingJavaScriptFromString:@"PS_RemoveAllHighlights()"];
}

@end
