//
//  SearchWebView.swift
//  PocketSword
//
//	based on code from http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/
//  Created by Nic Carter on 13/01/10.
//  Copyright 2010 The CrossWire Bible Society. All rights reserved.
//
//  Ported to Swift for the Swift migration (PR 1.2). Reproduces the former
//  Objective-C `WKWebView (SearchWebView)` category 1:1: an @objc extension on
//  WKWebView surfaces these methods to Obj-C/Obj-C++ callers via the generated
//  PocketSword-Swift.h, dispatched through the Obj-C runtime exactly as the old
//  category was. The SearchWebView.js resource is unchanged and still loaded.
//

import Foundation
import WebKit

extension WKWebView {

    @objc func highlightAllOccurencesOfString(_ str: String, completion: ((Int) -> Void)?) {
        guard let path = Bundle.main.path(forResource: "SearchWebView", ofType: "js"),
              let jsCode = try? String(contentsOfFile: path, encoding: .utf8) else {
            if let completion = completion {
                completion(0)
            }
            return
        }
        evaluateJavaScript(jsCode) { [weak self] _, _ in
            guard let self = self else { return }
            let startSearch = "PS_HighlightAllOccurencesOfString('\(str)')"
            self.evaluateJavaScript(startSearch) { [weak self] _, _ in
                guard let self = self else { return }
                self.evaluateJavaScript("PS_SearchResultCount") { countResult, _ in
                    if let completion = completion {
                        let count = (countResult as? NSNumber)?.intValue ?? 0
                        completion(count)
                    }
                }
            }
        }
    }

    @objc func removeAllHighlights() {
        evaluateJavaScript("PS_RemoveAllHighlights()", completionHandler: nil)
    }
}
