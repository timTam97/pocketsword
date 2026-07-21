//
//  PSWebView.swift
//  PocketSword
//
//  Swift port (Wave 4, render-path cluster) of the former PSWebView.{h,mm}.
//  PSWebView is a UIView that hosts a WKWebView and forwards the old UIWebView-
//  style API the module view controllers still call (loadHTMLString:baseURL:,
//  scrollView, setDelegate:, stringByEvaluatingJavaScriptFromString:). It acts as
//  the WKWebView's UIScrollViewDelegate, relaying scroll + auto-fullscreen events
//  to its PSWebViewDelegate.
//
//  This file is migrated ATOMICALLY with PSModuleViewController / PSBibleViewController
//  / PSCommentaryViewController (per §2A Rule 3): PSModuleViewController is the
//  base class that imports PSWebView's interface and conforms to PSWebViewDelegate,
//  and a Swift base under an Obj-C subclass header cannot compile.
//
//  The selectors / property names are preserved 1:1 so the still-Obj-C++ coordinator
//  (PSTabBarControllerDelegate.mm) keeps compiling (it reaches PSWebView via the
//  generated PocketSword-Swift.h). The original .mm had ZERO sword::; the only C++
//  was <cmath>/std::abs, replaced here with Swift's abs(_:).
//
//  Created by Nic Carter on 13/07/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

import UIKit
import WebKit

// Kept an @objc protocol: both the render VC base and the coordinator
// (PSTabBarControllerDelegate.mm) conform to / hold it. @objc so the still-Obj-C++
// coordinator binds; all methods stay (the @optional in the old header was unused
// — every method is always implemented by PSModuleViewController).
@objc protocol PSWebViewDelegate: AnyObject {
    func topReloadTriggered(_ psWebView: PSWebView)
    func bottomReloadTriggered(_ psWebView: PSWebView)
    func scrollHappened(_ psWebView: PSWebView, newOffsetY: CGFloat)
    func switchToFullscreen()
}

@objc(PSWebView)
final class PSWebView: UIView, UIScrollViewDelegate {

    private static let pullThresholdIPad: CGFloat = -130.0
    private static let pullThresholdIPhone: CGFloat = -65.0

    @objc private(set) var wkWebView: WKWebView!
    @objc weak var psDelegate: PSWebViewDelegate?
    @objc var topLength: CGFloat = 0
    @objc var bottomLength: CGFloat = 0
    @objc var autoFullscreenMode: Bool = false

    private var reloading = false
    private var cachedHeight: Float = 0
    private var currentOffsetY: CGFloat = 0

    // MARK: - Initialisation

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        wkWebView = WKWebView(frame: bounds, configuration: config)
        wkWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wkWebView.scrollView.delegate = self
        addSubview(wkWebView)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        wkWebView.frame = bounds
    }

    // MARK: - Forwarding methods (match the UIWebView API used by callers)

    @objc(loadHTMLString:baseURL:)
    func loadHTMLString(_ string: String, baseURL: URL?) {
        wkWebView.loadHTMLString(string, baseURL: baseURL)
    }

    @objc(scrollView)
    func scrollView() -> UIScrollView {
        return wkWebView.scrollView
    }

    // WKNavigationDelegate
    @objc(setDelegate:)
    func setDelegate(_ delegate: Any?) {
        wkWebView.navigationDelegate = delegate as? WKNavigationDelegate
    }

    // fire-and-forget wrapper
    @objc(stringByEvaluatingJavaScriptFromString:)
    func stringByEvaluatingJavaScriptFromString(_ script: String) {
        wkWebView.evaluateJavaScript(script, completionHandler: nil)
    }

    override var backgroundColor: UIColor? {
        didSet {
            wkWebView.backgroundColor = backgroundColor
            wkWebView.scrollView.backgroundColor = backgroundColor
            if #available(iOS 15.0, *) {
                wkWebView.underPageBackgroundColor = backgroundColor
            }
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var newOffY = scrollView.contentOffset.y + topLength
        if newOffY < 0 {
            newOffY = 0.0
        }
        if abs(currentOffsetY - newOffY) > 2.0 {
            // ignore tiny changes
            currentOffsetY = newOffY
            psDelegate?.scrollHappened(self, newOffsetY: currentOffsetY)
        }

        // PULL_THRESHOLD retained for parity with the original (unused, as in the .mm).
        var pullThreshold = PSWebView.pullThresholdIPhone - topLength
        if PSResizing.iPad() {
            pullThreshold = PSWebView.pullThresholdIPad - topLength
        }
        _ = pullThreshold
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        var pullThreshold = PSWebView.pullThresholdIPhone
        if PSResizing.iPad() {
            pullThreshold = PSWebView.pullThresholdIPad
        }
        _ = pullThreshold
        let reloadTriggered = false

        if !reloadTriggered {
            if autoFullscreenMode {
                psDelegate?.switchToFullscreen()
            }
        }
    }

    // MARK: - Refresh handling

    @objc(setupRefreshViews:bottom:)
    func setupRefreshViews(_ top: CGFloat, bottom: CGFloat) {
        topLength = top
        bottomLength = bottom
    }

    @objc(removeRefreshViews)
    func removeRefreshViews() {
        topLength = 0.0
        bottomLength = 0.0
    }

    @objc(dataSourceDidFinishLoadingNewData)
    func dataSourceDidFinishLoadingNewData() {
        let currentScrollView = wkWebView.scrollView

        reloading = false

        UIView.animate(withDuration: 0.3) {
            currentScrollView.contentInset = UIEdgeInsets(top: self.topLength, left: 0.0, bottom: self.bottomLength, right: 0.0)
            currentScrollView.scrollIndicatorInsets = UIEdgeInsets(top: self.topLength, left: 0.0, bottom: self.bottomLength, right: 0.0)
        }
    }

    private func tableViewHeight() -> Float {
        return cachedHeight
    }

    private func endOfTableView(_ scrollView: UIScrollView) -> Float {
        let svBounds = scrollView.bounds
        let bSize = svBounds.size
        let bOrigin = svBounds.origin
        return tableViewHeight() - Float(bSize.height) - Float(bOrigin.y)
    }
}
