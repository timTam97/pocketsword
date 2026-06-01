//
//  PSBookmarkTableViewCell.swift
//  PocketSword
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//
//  Swift port (Swift migration step 1.1b). Faithful to the original
//  Obj-C PSBookmarkTableViewCell: a UITableViewCell subclass that adds a
//  right-aligned "last accessed" label and hides it while editing.
//

import UIKit

@objc(PSBookmarkTableViewCell)
class PSBookmarkTableViewCell: UITableViewCell {

    @objc var lastAccessedLabel: UILabel

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        lastAccessedLabel = UILabel(frame: CGRect(x: 170, y: 25, width: 105, height: 15))
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        lastAccessedLabel.autoresizingMask = .flexibleLeftMargin
        lastAccessedLabel.textColor = .lightGray
        lastAccessedLabel.font = .systemFont(ofSize: 12.0)
        lastAccessedLabel.textAlignment = .right
        lastAccessedLabel.backgroundColor = .clear
        contentView.addSubview(lastAccessedLabel)
    }

    required init?(coder: NSCoder) {
        lastAccessedLabel = UILabel(frame: CGRect(x: 170, y: 25, width: 105, height: 15))
        super.init(coder: coder)
        lastAccessedLabel.autoresizingMask = .flexibleLeftMargin
        lastAccessedLabel.textColor = .lightGray
        lastAccessedLabel.font = .systemFont(ofSize: 12.0)
        lastAccessedLabel.textAlignment = .right
        lastAccessedLabel.backgroundColor = .clear
        contentView.addSubview(lastAccessedLabel)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        lastAccessedLabel.isHidden = editing
        super.setEditing(editing, animated: animated)
    }
}
