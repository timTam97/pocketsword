//
//  PSBibleViewController.swift
//  PocketSword
//
//  Swift port (Wave 4, render-path cluster) of the former PSBibleViewController.{h,mm}.
//  Thin subclass of PSModuleViewController that pins tabType to the Bible tab and
//  holds a weak back-reference to the paired commentary view (used by the verse
//  context menu's "show in commentary" action). Migrated ATOMICALLY with its base
//  PSModuleViewController per §2A Rule 3.
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSBibleViewController)
final class PSBibleViewController: PSModuleViewController {

    @objc weak var commentaryView: PSCommentaryViewController?

    @objc override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        tabType = .BibleTab
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        tabType = .BibleTab
    }
}
