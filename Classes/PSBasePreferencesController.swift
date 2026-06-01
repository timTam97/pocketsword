//
//  PSBasePreferencesController.swift
//  PocketSword
//
//  Created by Nic Carter on 17/12/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//
//  Swift migration (Wave 3, prefs-cluster). Faithful port of
//  PSBasePreferencesController.{h,m}. The base is a near-empty UITableViewController
//  that declares two override points (fontNameChanged: / hideFontTableView) which the
//  two concrete preferences controllers (PSPreferencesController,
//  PSModulePreferencesController) override and which the still-Obj-C font / module
//  selector table view controllers invoke through a weak base-typed back-pointer.
//
//  The original Obj-C method bodies were empty no-ops; preserved verbatim. The
//  base + its two subclasses migrate together as one atomic PR (§2A Rule 3): a Swift
//  base under an Obj-C subclass header cannot compile.
//
//  The original header gratuitously #imported PSPreferencesFontTableViewController.h;
//  the base never used that type, so the import is simply dropped here. The font /
//  module-selector table VCs stay Obj-C++ — they reference the (now Swift) prefs
//  controllers only as weak pointers and see them via PocketSword-Swift.h in their .mm.
//

import UIKit

@objc(PSBasePreferencesController)
class PSBasePreferencesController: UITableViewController {

    @objc func fontNameChanged(_ newFont: String) {}

    @objc func hideFontTableView() {}
}
