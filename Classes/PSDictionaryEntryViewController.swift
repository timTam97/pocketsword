//
//  PSDictionaryEntryViewController.swift
//  PocketSword
//
//  Displays a single dictionary entry in a WKWebView (pushed/presented from
//  PSDictionaryViewController when the user taps a key). Tapping a link inside
//  the rendered entry either drills into another dictionary entry in-place,
//  expands a cross-reference into Bible text, or surfaces the result in the
//  shared info pane.
//
//  Swift port (Wave 3) of the former Classes/PSDictionaryEntryViewController.{h,mm}.
//  Zero C++ — a plain UIViewController leaf. It reaches the SWORD engine only
//  through the Foundation-only facades (SwordManager / SwordDictionary) and the
//  PSModuleController HTML/link helpers, all visible via the bridging header.
//  Its single consumer, PSDictionaryViewController.mm, drives it through the
//  unchanged @objc surface (-setDictionaryEntryTitle: / -setDictionaryEntryText:
//  / -setScalesPageToFit:).
//
//  Created by Nic Carter on 27/09/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//

import UIKit
import WebKit

@objc(PSDictionaryEntryViewController)
final class PSDictionaryEntryViewController: UIViewController, WKNavigationDelegate {

    // Mirror of the Obj-C string #define macros in SwordModule.h. Obj-C
    // `#define @"..."` string macros do NOT import into Swift, so the literal
    // values are reproduced here verbatim — they must stay byte-identical to
    // SwordModule.h or link resolution silently breaks.
    private static let attrTypeModule = "modulename"   // ATTRTYPE_MODULE
    private static let attrTypeAction = "action"       // ATTRTYPE_ACTION
    private static let attrTypeValue  = "value"        // ATTRTYPE_VALUE
    private static let swOutputRefKey = "OutputRefKey"  // SW_OUTPUT_REF_KEY
    private static let swOutputTextKey = "OutputTextKey" // SW_OUTPUT_TEXT_KEY

    @objc var entryHTML: String?
    @objc var entryTitle: String?
    @objc var dictionaryDescriptionWebView: WKWebView?

    override func loadView() {
        let screen = PSResizing.mainScreenBounds().size

        let baseView = UIView(frame: CGRect(x: 0, y: 0, width: screen.width, height: screen.height))
        baseView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationItem.title = entryTitle ?? ""

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: screen.width, height: screen.height),
                                configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let entryHTML = entryHTML {
            webView.loadHTMLString(entryHTML, baseURL: nil)
        }
        baseView.addSubview(webView)

        dictionaryDescriptionWebView = webView

        modalTransitionStyle = .crossDissolve
        view = baseView
    }

    @objc(setDictionaryEntryTitle:)
    func setDictionaryEntryTitle(_ title: String?) {
        var title = title
        if let t = title, t.count > 20 {
            title = "\(t.prefix(20))..."
        }
        entryTitle = title
        navigationItem.title = title
    }

    @objc(setDictionaryEntryText:)
    func setDictionaryEntryText(_ entry: String?) {
        entryHTML = entry
        if let entry = entry {
            dictionaryDescriptionWebView?.loadHTMLString(entry, baseURL: nil)
        }
    }

    @objc(setScalesPageToFit:)
    func setScalesPageToFit(_ scalesPageToFit: Bool) {
        // scalesPageToFit not available on WKWebView; handled via viewport meta tag in HTML
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            NotificationCenter.default.post(name: .rotateInfoPane, object: nil)
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        PSResizing.supportedInterfaceOrientations()
    }

    func webView(_ wv: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        autoreleasepool {
            let request = navigationAction.request
            let rData = request.url.flatMap { PSModuleController.data(forLink: $0) }
            var entry: String? = nil

            if let rData = rData,
               let module = rData[Self.attrTypeModule] as? String,
               module != "Bible",
               module != "",
               (rData[Self.attrTypeAction] as? String) != "showImage" {

                let mod = module

                let swordDictionary = PSModuleController.default()?.swordManager?.module(withName: mod) as? SwordDictionary
                if let swordDictionary = swordDictionary {
                    entry = swordDictionary.entry(forKey: rData[Self.attrTypeValue] as? String ?? "")
                } else {
                    let notInstalled = NSLocalizedString("ModuleNotInstalled", comment: "is not installed.")
                    entry = "<p style=\"color:grey;text-align:center;font-style:italic;\">\(mod) \(notInstalled)</p>"
                }
                let t = (rData[Self.attrTypeValue] as? String)?.removingPercentEncoding
                let body = "<div style=\"-webkit-text-size-adjust: none;\"><b>\(t ?? "")</b><br /><p>\(entry ?? "")</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>"
                let descr = PSModuleController.createInfoHTMLString(body,
                                                                   usingModuleForPreferences: PSModuleController.default()?.primaryDictionary?.name)
                setDictionaryEntryTitle(t)
                if let descr = descr {
                    dictionaryDescriptionWebView?.loadHTMLString(descr, baseURL: nil)
                }

                decisionHandler(.cancel)
                return

            } else if let rData = rData,
                      (rData[Self.attrTypeAction] as? String) == "showRef" {
                let array = PSModuleController.default()?.primaryBible?.attributeValue(forEntryData: rData, cleanFeed: true) as? [[String: Any]]
                var tmpEntry = ""
                for dict in array ?? [] {
                    let curRef = PSModuleController.createRefString(dict[Self.swOutputRefKey] as? String) ?? ""
                    tmpEntry += "<b><a href=\"bible:///\(curRef)\">\(curRef)</a>:</b> "
                    tmpEntry += "\(dict[Self.swOutputTextKey] as? String ?? "")<br />"
                }
                if !tmpEntry.isEmpty {
                    let cleaned = tmpEntry.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    entry = PSModuleController.createInfoHTMLString(cleaned,
                                                                   usingModuleForPreferences: PSModuleController.default()?.primaryBible?.name)
                }
            }

            if let entry = entry {
                NotificationCenter.default.post(name: .showInfoPane, object: entry)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
