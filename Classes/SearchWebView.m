//
//  SearchWebView.m
//  PocketSword
//
//	based on code from http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/
//  Created by Nic Carter on 13/01/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//

#import "SearchWebView.h"


@implementation WKWebView (SearchWebView)

- (void)highlightAllOccurencesOfString:(NSString*)str completion:(void(^)(NSInteger count))completion
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"SearchWebView" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self evaluateJavaScript:jsCode completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSString *startSearch = [NSString stringWithFormat:@"PS_HighlightAllOccurencesOfString('%@')", str];
        [self evaluateJavaScript:startSearch completionHandler:^(id _Nullable result2, NSError * _Nullable error2) {
            [self evaluateJavaScript:@"PS_SearchResultCount" completionHandler:^(id _Nullable countResult, NSError * _Nullable error3) {
                if(completion) {
                    NSInteger count = [countResult integerValue];
                    completion(count);
                }
            }];
        }];
    }];
}

- (void)removeAllHighlights
{
    [self evaluateJavaScript:@"PS_RemoveAllHighlights()" completionHandler:nil];
}

@end
