//
//  PSResizing.swift
//  PocketSword
//
//  Created by Nic Carter on 1/10/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//
//  Swift port (migration step 0d) of the former Classes/PSResizing.{h,m}.
//  Pure UIKit geometry / orientation / window helpers, no app-internal deps.
//  The @objc surface reproduces the original Obj-C public API 1:1 so that the
//  26 Obj-C bodies and the one header importer bind unchanged.
//

import UIKit

private let TOP_BAR_LANDSCAPE_HEIGHT: CGFloat = 32.0
private let TOP_BAR_PORTRAIT_HEIGHT: CGFloat = 44.0
private let BOTTOM_BAR_LANDSCAPE_HEIGHT: CGFloat = 32.0
private let BOTTOM_BAR_PORTRAIT_HEIGHT: CGFloat = 44.0

// Rotation-lock ordinals. Mirror of the `RotationPosition` NS_ENUM in
// globals.h (RotationEnabled = 0, RotationLockedInPortrait = 1,
// RotationLockedInLandscape = 2). That enum is NOT in the Swift bridging
// header (per 0b, globals.h is mirrored into AppConstants.swift rather than
// bridged), so we reproduce the load-bearing ordinals here. Keep byte-identical
// to globals.h until that enum is fully owned by Swift.
private let kRotationEnabled = 0
private let kRotationLockedInPortrait = 1
private let kRotationLockedInLandscape = 2

@objc(PSResizing)
final class PSResizing: NSObject {

    @objc(resizeViewsOnAppearWithTabBarController:topBar:mainView:useStatusBar:)
    class func resizeViewsOnAppear(withTabBarController tabBarController: UITabBarController?,
                                   topBar: UIView?,
                                   mainView: UIView?,
                                   useStatusBar: Bool) {
        PSResizing.resizeViewsOnAppear(withTabBarController: tabBarController,
                                       topBar: topBar,
                                       mainView: mainView,
                                       bottomBar: nil,
                                       useStatusBar: useStatusBar)
    }

    @objc(resizeViewsOnAppearWithTabBarController:topBar:mainView:bottomBar:useStatusBar:)
    class func resizeViewsOnAppear(withTabBarController tabBarController: UITabBarController?,
                                   topBar: UIView?,
                                   mainView: UIView?,
                                   bottomBar: UIView?,
                                   useStatusBar: Bool) {
        let screen = PSResizing.mainScreenBounds().size
        var topBarHeight: CGFloat = 0.0
        var bottomBarHeight: CGFloat = 0.0
        var viewHeight: CGFloat = 0.0
        var width: CGFloat = 0.0
        let tabBarHeight: CGFloat = (tabBarController != nil) ? tabBarController!.tabBar.frame.size.height : 0.0
        var redrawInNewFrames = false

        let interfaceOrientation = PSResizing.currentInterfaceOrientation()
        let statusBarSize = PSResizing.statusBarHeight()
        if interfaceOrientation == .landscapeLeft || interfaceOrientation == .landscapeRight {
            redrawInNewFrames = true
            bottomBarHeight = (bottomBar != nil) ? BOTTOM_BAR_LANDSCAPE_HEIGHT : 0.0
            width = screen.height
            topBarHeight = PSResizing.iPad() ? TOP_BAR_PORTRAIT_HEIGHT : TOP_BAR_LANDSCAPE_HEIGHT
            viewHeight = screen.width - topBarHeight - tabBarHeight - bottomBarHeight
            if useStatusBar {
                viewHeight -= statusBarSize
            }
        } else if interfaceOrientation == .portrait || interfaceOrientation == .portraitUpsideDown {
            redrawInNewFrames = true
            bottomBarHeight = (bottomBar != nil) ? BOTTOM_BAR_PORTRAIT_HEIGHT : 0.0
            width = screen.width
            topBarHeight = TOP_BAR_PORTRAIT_HEIGHT
            viewHeight = screen.height - topBarHeight - tabBarHeight - bottomBarHeight
            if useStatusBar {
                viewHeight -= statusBarSize
            }
        }
        if redrawInNewFrames {
            topBar?.frame = CGRect(x: 0.0, y: 0.0, width: width, height: topBarHeight)
            topBar?.layoutIfNeeded()
            topBar?.setNeedsDisplay()
            if let bottomBar = bottomBar {
                bottomBar.frame = CGRect(x: 0.0, y: (topBarHeight + viewHeight), width: width, height: bottomBarHeight)
                bottomBar.layoutIfNeeded()
                bottomBar.setNeedsDisplay()
            }
            mainView?.frame = CGRect(x: 0.0, y: topBarHeight, width: width, height: viewHeight)
        }
    }

    @objc(resizeViewsOnRotateWithTabBarController:topBar:mainView:fromOrientation:toOrientation:)
    class func resizeViewsOnRotate(withTabBarController tabBarController: UITabBarController?,
                                   topBar: UIView?,
                                   mainView: UIView?,
                                   fromOrientation fromInterfaceOrientation: UIInterfaceOrientation,
                                   toOrientation toInterfaceOrientation: UIInterfaceOrientation) {
        PSResizing.resizeViewsOnRotate(withTabBarController: tabBarController,
                                       topBar: topBar,
                                       mainView: mainView,
                                       bottomBar: nil,
                                       fromOrientation: fromInterfaceOrientation,
                                       toOrientation: toInterfaceOrientation)
    }

    @objc(resizeViewsOnRotateWithTabBarController:topBar:mainView:bottomBar:fromOrientation:toOrientation:)
    class func resizeViewsOnRotate(withTabBarController tabBarController: UITabBarController?,
                                   topBar: UIView?,
                                   mainView: UIView?,
                                   bottomBar: UIView?,
                                   fromOrientation fromInterfaceOrientation: UIInterfaceOrientation,
                                   toOrientation toInterfaceOrientation: UIInterfaceOrientation) {
        if PSResizing.iPad() {
            return
        }
        let screen = PSResizing.mainScreenBounds().size
        var topBarHeight: CGFloat = 0.0
        var bottomBarHeight: CGFloat = 0.0
        var viewHeight: CGFloat = 0.0
        var width: CGFloat = 0.0
        var bottomBarY: CGFloat = 0.0
        let tabBarHeight: CGFloat = (tabBarController != nil) ? tabBarController!.tabBar.frame.size.height : 0.0
        var redrawInNewFrames = false
        let statusBarSize = PSResizing.statusBarHeight()
        let toLandscape = (toInterfaceOrientation == .landscapeLeft || toInterfaceOrientation == .landscapeRight)
        let fromLandscape = (fromInterfaceOrientation == .landscapeLeft || fromInterfaceOrientation == .landscapeRight)
        let toPortrait = (toInterfaceOrientation == .portrait || toInterfaceOrientation == .portraitUpsideDown)
        let fromPortrait = (fromInterfaceOrientation == .portrait || fromInterfaceOrientation == .portraitUpsideDown)
        if toLandscape && !fromLandscape {
            width = screen.width
            bottomBarHeight = (bottomBar != nil) ? BOTTOM_BAR_LANDSCAPE_HEIGHT : 0.0
            bottomBarY = screen.height - statusBarSize - (bottomBarHeight / 2.0)
            topBarHeight = TOP_BAR_LANDSCAPE_HEIGHT
            viewHeight = screen.height - topBarHeight - tabBarHeight - bottomBarHeight - statusBarSize
            redrawInNewFrames = true
        } else if toPortrait && !fromPortrait {
            width = screen.height
            bottomBarHeight = (bottomBar != nil) ? BOTTOM_BAR_PORTRAIT_HEIGHT : 0.0
            bottomBarY = screen.width - statusBarSize - (bottomBarHeight / 2.0)
            topBarHeight = TOP_BAR_PORTRAIT_HEIGHT
            viewHeight = screen.width - topBarHeight - tabBarHeight - bottomBarHeight - statusBarSize
            redrawInNewFrames = true
        }
        if redrawInNewFrames {
            topBar?.frame = CGRect(x: 0.0, y: 0.0, width: width, height: topBarHeight)
            mainView?.center = CGPoint(x: (width / 2.0), y: ((viewHeight / 2.0) + topBarHeight))
            mainView?.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: viewHeight)
            if let bottomBar = bottomBar {
                bottomBar.center = CGPoint(x: (width / 2.0), y: bottomBarY)
                bottomBar.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: bottomBarHeight)
            }
        }
    }

    @objc(getOrientationRect:)
    class func getOrientationRect(_ interfaceOrientation: UIInterfaceOrientation) -> CGRect {
        let screen = PSResizing.mainScreenBounds().size
        return CGRect(x: 0.0, y: 0.0, width: screen.width, height: screen.height)
    }

    @objc(currentWindowScene)
    class func currentWindowScene() -> UIWindowScene? {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                return windowScene
            }
        }
        return nil
    }

    @objc(keyWindow)
    class func keyWindow() -> UIWindow? {
        if let windowScene = PSResizing.currentWindowScene() {
            for window in windowScene.windows where window.isKeyWindow {
                return window
            }
            return windowScene.windows.first
        }
        return nil
    }

    @objc(mainScreenBounds)
    class func mainScreenBounds() -> CGRect {
        if let windowScene = PSResizing.currentWindowScene() {
            return windowScene.screen.bounds
        }
        // Fallback only when no window scene is connected yet (pre-scene launch).
        // UIScreen.main is deprecated in iOS 26 but has no context-free replacement
        // for bounds — a trait collection carries displayScale, not point bounds.
        return UIScreen.main.bounds
    }

    @objc(mainScreenScale)
    class func mainScreenScale() -> CGFloat {
        if let windowScene = PSResizing.currentWindowScene() {
            return windowScene.screen.scale
        }
        // UIScreen.main.scale is deprecated in iOS 26; the recommended replacement
        // is the current trait collection's displayScale.
        return UITraitCollection.current.displayScale
    }

    @objc(currentInterfaceOrientation)
    class func currentInterfaceOrientation() -> UIInterfaceOrientation {
        if let windowScene = PSResizing.currentWindowScene() {
            return windowScene.effectiveGeometry.interfaceOrientation
        }
        return .portrait
    }

    @objc(statusBarHeight)
    class func statusBarHeight() -> CGFloat {
        if let windowScene = PSResizing.currentWindowScene(),
           let statusBarManager = windowScene.statusBarManager {
            return statusBarManager.statusBarFrame.size.height
        }
        return 0.0
    }

    @objc(supportedInterfaceOrientations)
    class func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        let rotationLockPosition = UserDefaults.standard.integer(forKey: Defaults.rotationLockPosition)
        switch rotationLockPosition {
        case kRotationEnabled:
            if PSResizing.iPad() {
                return .all
            } else {
                return .allButUpsideDown
            }
        case kRotationLockedInLandscape:
            return .landscape
        case kRotationLockedInPortrait:
            if PSResizing.iPad() {
                return [.portrait, .portraitUpsideDown]
            } else {
                return .portrait
            }
        default:
            return .all
        }
    }

    @objc(iPad)
    class func iPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom != .phone
    }

    @objc(addSkipBackupAttributeToItemAtPath:)
    @discardableResult
    class func addSkipBackupAttribute(toItemAtPath path: String) -> Bool {
        // make sure we're not backing up this folder!
        dlog("Don't Backup:\n---\n\(path)\n---\n")

        let url = URL(fileURLWithPath: path, isDirectory: true)

        assert(FileManager.default.fileExists(atPath: url.path))

        do {
            var mutableURL = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)
            return true
        } catch {
            alog("Error excluding \(url.lastPathComponent) from backup \(error)")
            return false
        }
    }
}
