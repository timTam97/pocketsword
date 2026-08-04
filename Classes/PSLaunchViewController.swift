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

import SwiftUI
import UIKit

// PSLaunchDelegate — the bootstrap-finished handshake the scene delegate conforms
// to. Kept @objc (the still-Obj-C PocketSwordSceneDelegate conforms to it) and
// owned here, mirroring the original PSLaunchViewController.h declaration.
@objc(PSLaunchDelegate)
protocol PSLaunchDelegate: NSObjectProtocol {
    func finishedInitializingPocketSword(_ launchViewController: Any)
}

@objc(PSLaunchViewController)
final class PSLaunchViewController: UIHostingController<LaunchView> {

    @objc weak var delegate: PSLaunchDelegate?
    private let launchCoordinator: LaunchCoordinator

    init(launchCoordinator: LaunchCoordinator = LaunchCoordinator()) {
        self.launchCoordinator = launchCoordinator
        super.init(rootView: LaunchView())
    }

    required init?(coder: NSCoder) {
        self.launchCoordinator = LaunchCoordinator()
        super.init(coder: coder, rootView: LaunchView())
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
