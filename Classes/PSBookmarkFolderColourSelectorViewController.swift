//
//  PSBookmarkFolderColourSelectorViewController.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). A grouped list of selectable highlight colours for
//  a bookmark folder. Row 0 is "None" (white / clear); the remaining rows are
//  fixed colour swatches. Selecting a row reports the rgb hex string back through
//  the (preserved @objc) PSBookmarkFolderColourSelectorDelegate; the first row
//  reports nil ("None"). Public API matches the original
//  PSBookmarkFolderColourSelectorViewController.{h,m} byte-for-byte so the Obj-C
//  caller (PSBookmarkFolderAddViewController, via PocketSword-Swift.h) binds
//  unchanged: it conforms to PSBookmarkFolderColourSelectorDelegate and creates
//  this VC via -initWithColorString:delegate:.
//
//  Colour hex strings are produced by PSBookmarkFolder (Swift, Wave 1) so the
//  comparison against the persisted currentSelectedColor stays identical.
//
//  Originally created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

/* possible new colours (20130701)
 Blue: BBDDFF
 Brown: AA8866
 Green: BBFFBB
 Orange: FFCC99
 Pink: FFBBDD
 Purple: CCAAFF
 Red: FF7777 (1.0, 0.47, 0.47, 0.8)
 Turquoise: 99DDDD
 Yellow: FFFFCC (1.0, 1.0, 0.8, 0.8)
*/

import UIKit

@objc protocol PSBookmarkFolderColourSelectorDelegate: NSObjectProtocol {
    func rgbHexColorStringDidChange(_ newColorHexString: String?)
}

@objc(PSBookmarkFolderColourSelectorViewController)
final class PSBookmarkFolderColourSelectorViewController: UITableViewController {

    @objc weak var delegate: PSBookmarkFolderColourSelectorDelegate?
    @objc var currentSelectedColor: String?
    @objc var selectableColours: [UIColor]

    private static let cellIdentifier = "Cell"

    @objc(initWithColorString:delegate:)
    init(colorString rgbHexString: String?, delegate del: Any?) {
        currentSelectedColor = rgbHexString
        selectableColours = [
            UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8), // red
            UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8), // green
            UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.8), // blue
            UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.8), // Turquoise
            UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.8), // yellow
            UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.8), // pink
            UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8), // orange
            UIColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 0.8), // magenta?/purple
            UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.8), // brown
        ]
        super.init(style: .grouped)
        delegate = del as? PSBookmarkFolderColourSelectorDelegate
        var ourTitle = NSLocalizedString("BookmarksAddFolderHighlightColour", comment: "")
        if ourTitle.hasSuffix(":") {
            ourTitle = String(ourTitle.dropLast())
        }
        navigationItem.title = ourTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectableColours.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = selectableColours[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PSBookmarkFolderColourSelectorViewController.cellIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: PSBookmarkFolderColourSelectorViewController.cellIdentifier)

        // Configure the cell...
        let rowHex = PSBookmarkFolder.hexString(from: selectableColours[indexPath.row])
        let whiteHex = PSBookmarkFolder.hexString(from: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        if rowHex == whiteHex {
            cell.textLabel?.text = NSLocalizedString("None", comment: "None")
        } else {
            cell.textLabel?.text = ""
        }

        if (currentSelectedColor == nil && indexPath.row == 0) || rowHex == currentSelectedColor {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row != 0 {
            delegate?.rgbHexColorStringDidChange(PSBookmarkFolder.hexString(from: selectableColours[indexPath.row]))
        } else {
            delegate?.rgbHexColorStringDidChange(nil)
        }
    }

    // MARK: - Memory management

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
