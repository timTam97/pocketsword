//
//  PSInfoPopupViewController.swift
//  PocketSword
//
//  Hosts the WKWebView that shows Strong's entries, morph tags, footnotes,
//  cross-references and dictionary lookups in a native sheet. Replaces the
//  hand-rolled slide-up overlay that PSTabBarControllerDelegate used to build
//  in showInfo:.
//
//  Swift port (Wave 2) of the former Classes/PSInfoPopupViewController.{h,mm}.
//  Zero C++ — a plain UIViewController leaf whose only consumer is the
//  PSTabBarControllerDelegate coordinator (via PocketSword-Swift.h). The @objc
//  surface reproduces the original Obj-C public API 1:1: the readonly `webView`
//  property and -loadHTML:.
//

import UIKit
import WebKit

@objc(PSInfoPopupViewController)
final class PSInfoPopupViewController: UIViewController {

    @objc private(set) var webView: WKWebView!

    private var pendingHTML: String?

    override func loadView() {
        let root = UIView(frame: PSResizing.mainScreenBounds())
        root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.backgroundColor = UIColor.systemBackground

        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: root.bounds, configuration: cfg)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.backgroundColor = UIColor.systemBackground
        wv.isOpaque = false
        // Push content below the sheet grabber so the first line of the
        // dictionary entry isn't crammed against the top edge.
        let insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        wv.scrollView.contentInset = insets
        wv.scrollView.scrollIndicatorInsets = insets
        root.addSubview(wv)

        self.webView = wv
        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let pendingHTML = pendingHTML {
            webView.loadHTMLString(pendingHTML, baseURL: nil)
            self.pendingHTML = nil
        }
    }

    @objc(loadHTML:)
    func loadHTML(_ html: String?) {
        guard let html = html else { return }
        if isViewLoaded {
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            pendingHTML = html
        }
    }
}
