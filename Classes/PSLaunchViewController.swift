//
//  PSLaunchViewController.swift
//  PocketSword
//
//  Swift port (Wave 4, hub) of the former PSLaunchViewController.{h,mm}. This is
//  the launch view controller: it is installed as the window's root VC while the
//  app initialises, invokes LaunchCoordinator on a background thread, and hands
//  control back to the scene delegate once preparation completes.
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2002-2013 CrossWire Bible Society. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation version 2.
//

import UIKit

// PSLaunchDelegate — the bootstrap-finished handshake the scene delegate conforms
// to. Kept @objc (the still-Obj-C PocketSwordSceneDelegate conforms to it) and
// owned here, mirroring the original PSLaunchViewController.h declaration.
@objc(PSLaunchDelegate)
protocol PSLaunchDelegate: NSObjectProtocol {
    func finishedInitializingPocketSword(_ launchViewController: Any)
}

@objc(PSLaunchViewController)
final class PSLaunchViewController: UIViewController {

    @objc weak var delegate: PSLaunchDelegate?
    private let launchCoordinator: LaunchCoordinator

    init(launchCoordinator: LaunchCoordinator = LaunchCoordinator()) {
        self.launchCoordinator = launchCoordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.launchCoordinator = LaunchCoordinator()
        super.init(coder: coder)
    }

    // MARK: - View

    // Build the view hierarchy programmatically (no nib) — a grey background
    // matching the launch image plus a centred spinner.
    override func loadView() {
        let aiFrame: CGRect
        if PSResizing.iPad() {
            let uiOrientation = PSResizing.currentInterfaceOrientation()
            if uiOrientation == .landscapeLeft || uiOrientation == .landscapeRight {
                aiFrame = CGRect(x: 494, y: 370, width: 37, height: 37)
            } else {
                aiFrame = CGRect(x: 366, y: 499, width: 37, height: 37)
            }
        } else {
            let screenRect = PSResizing.mainScreenBounds()
            aiFrame = CGRect(x: screenRect.size.width / 2.0 - (37.0 / 2.0),
                             y: screenRect.size.height / 2.0 - (37.0 / 2.0),
                             width: 37, height: 37)
        }

        let base = UIView(frame: PSResizing.mainScreenBounds())
        // the same grey as the launch image bg
        base.backgroundColor = UIColor(hue: 202.0 / 360.0, saturation: 0.11, brightness: 0.4, alpha: 1.0)
        let activityInd = UIActivityIndicatorView(style: .large)
        activityInd.hidesWhenStopped = false
        base.addSubview(activityInd)
        activityInd.frame = aiFrame
        activityInd.startAnimating()
        self.view = base
    }

    // MARK: - Reset

    @objc class func resetPreferences() {
        LaunchCoordinator().resetPreferences()
    }

    // MARK: - Bootstrap (runs on a background thread)

    @objc func startInitializingPocketSword() {
        autoreleasepool {
            guard let result = launchCoordinator.prepare(),
                  let delegate else {
                return
            }
            DispatchQueue.main.async {
                if result.shouldDisableIdleTimer {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                delegate.finishedInitializingPocketSword(self)
            }
        }
    }

    // MARK: - Rotation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if !PSResizing.iPad() {
            return .portrait
        }
        return PSResizing.supportedInterfaceOrientations()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        dlog("\nwe are about to rotate the launch view controller...")
    }
}
