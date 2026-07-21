//
//  PSDictionaryOverlayViewController.swift
//  PocketSword
//
//  Created by Nic Carter on 26/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//
//  Swift port (Wave 2) of the former Classes/PSDictionaryOverlayViewController.{h,m}.
//  Zero C++ — a trivial UIViewController leaf that PSDictionaryViewController
//  inserts behind its search bar as a translucent dimming layer. The @objc
//  surface reproduces the original Obj-C public API 1:1: the readwrite
//  `dictionaryViewController` property and a programmatic loadView that builds
//  the half-alpha system-background gray view.
//

import UIKit

@objc(PSDictionaryOverlayViewController)
final class PSDictionaryOverlayViewController: UIViewController {

    @objc var dictionaryViewController: PSDictionaryViewController?

    // Implement loadView to create a view hierarchy programmatically, without using a nib.
    override func loadView() {
        let grayView = UIView(frame: PSResizing.mainScreenBounds())
        grayView.backgroundColor = UIColor.systemBackground
        grayView.alpha = 0.5
        self.view = grayView
    }

    override func didReceiveMemoryWarning() {
        // Releases the view if it doesn't have a superview.
        super.didReceiveMemoryWarning()

        // Release any cached data, images, etc that aren't in use.
    }
}
