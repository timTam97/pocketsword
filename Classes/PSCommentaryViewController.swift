//
//  PSCommentaryViewController.swift
//  PocketSword
//
//  Swift port (Wave 4, render-path cluster) of the former PSCommentaryViewController.{h,mm}.
//  Thin subclass of PSModuleViewController that pins tabType to the Commentary tab.
//  Migrated ATOMICALLY with its base PSModuleViewController per §2A Rule 3.
//
//  Created by Nic Carter on 6/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSCommentaryViewController)
final class PSCommentaryViewController: PSModuleViewController {

    @objc override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        tabType = .CommentaryTab
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        tabType = .CommentaryTab
    }
}
