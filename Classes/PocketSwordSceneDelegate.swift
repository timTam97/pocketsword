//
//  PocketSwordSceneDelegate.swift
//  PocketSword
//
//  Swift port (Wave 4, hub) of the former PocketSwordSceneDelegate.{h,mm}. This is
//  the UIWindowSceneDelegate that drives the launch path: on scene connect it
//  installs PSLaunchViewController (Swift, Wave 4) as the window's root VC and
//  kicks off the SWORD bootstrap on a background thread; it caches any sword://
//  launch URL that arrives during init in _pendingLaunchURL; and once the launch
//  VC signals completion via the @objc PSLaunchDelegate handshake
//  (-finishedInitializingPocketSword:) it builds the PSTabBarControllerDelegate
//  coordinator (still Obj-C++), swaps the window's root VC to its tab bar, and
//  replays the pending URL through the app delegate.
//
//  The @objc(PocketSwordSceneDelegate) runtime name is REQUIRED: misc/Info.plist
//  names this class as the scene delegate (UISceneConfigurations →
//  UISceneDelegateClassName = "PocketSwordSceneDelegate") and
//  PocketSwordAppDelegate.mm resolves it via [PocketSwordSceneDelegate class] in
//  -configurationForConnectingSceneSession:. Both must continue to resolve to the
//  same Obj-C runtime name after the Swift rename.
//
//  PSLaunchDelegate conformance was an Obj-C class extension in the old .mm
//  (because the @objc(PSLaunchDelegate) protocol is only visible via
//  PocketSword-Swift.h, which a public .h may not import). In Swift, both this
//  class and the protocol live in the same module, so the conformance is a plain
//  `: PSLaunchDelegate` here. PocketSwordAppDelegate (Obj-C++) is reached via the
//  generated PocketSword-Swift.h; PSTabBarControllerDelegate (Obj-C++) is visible
//  through the bridging header.
//
//  ZERO sword:: — every SWORD touch is funnelled through the still-Obj-C launch /
//  coordinator objects exactly as the original .mm did.
//
//  Copyright 2002-2013 CrossWire Bible Society. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation version 2.
//

import UIKit

@objc(PocketSwordSceneDelegate)
final class PocketSwordSceneDelegate: UIResponder, UIWindowSceneDelegate, PSLaunchDelegate {

    @objc var window: UIWindow?

    // sword:// URL delivered with the scene-connection options before SWORD init
    // has finished — cached here and replayed from finishedInitializingPocketSword:
    // once the tab bar exists.
    private var pendingLaunchURL: URL?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let lVC = PSLaunchViewController()
        lVC.delegate = self

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = UIColor.systemBackground
        window.rootViewController = lVC
        self.window = window

        lVC.performSelector(inBackground: #selector(PSLaunchViewController.startInitializingPocketSword), with: nil)

        window.makeKeyAndVisible()

        pendingLaunchURL = connectionOptions.urlContexts.first?.url
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let appDelegate = PocketSwordAppDelegate.shared() else { return }
        for urlContext in URLContexts {
            _ = appDelegate.application(UIApplication.shared, handleOpen: urlContext.url, options: nil)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        if UserDefaults.standard.bool(forKey: "reset_PocketSword") {
            PSLaunchViewController.resetPreferences()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        UserDefaults.standard.synchronize()
    }

    // MARK: - PSLaunchDelegate

    func finishedInitializingPocketSword(_ launchViewController: Any) {
        guard let appDelegate = PocketSwordAppDelegate.shared() else { return }
        let tbcd = PSTabBarControllerDelegate()
        appDelegate.tabBarControllerDelegate = tbcd

        window?.rootViewController = tbcd.tabBarController

        if let url = pendingLaunchURL {
            pendingLaunchURL = nil
            _ = appDelegate.application(UIApplication.shared, handleOpen: url, options: nil)
        }
    }
}
