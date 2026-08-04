//
//  PSPreferencesFontTableViewController.swift
//  PocketSword
//
//  Created by Nic Carter on 9/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//
//  The Preferences "Font" picker: a single-section UITableView listing the
//  available font-family names, each rendered in its own face, with a checkmark
//  on the currently selected font. Tapping a row reports the new font name back
//  to the owning PSBasePreferencesController (fontNameChanged:) and dismisses the
//  picker (hideFontTableView).
//
//  Migrated from PSPreferencesFontTableViewController.{h,mm} (Swift migration
//  Wave 3). The former .mm contained ZERO sword:: usage — it is a pure
//  Foundation/UIKit leaf. Font selection is read/written via the Swift pref-key
//  helpers (UserDefaults.standard.string(forKey:) globally, .psString(_:forModule:)
//  per-module) mirroring the old GetStringPrefForMod / stringForKey path
//  byte-for-byte. preferencesController is the now-Swift PSBasePreferencesController
//  held as a weak back-pointer; both PSPreferencesController.swift and
//  PSModulePreferencesController.swift instantiate this VC directly (same module),
//  so no Obj-C importer remains.
//
//  The font-name list is preserved verbatim from the original .mm (commented-out
//  entries dropped — they were never in the live array).
//

import UIKit

@objc(PSPreferencesFontTableViewController)
final class PSPreferencesFontTableViewController: UITableViewController {

    private static let cellIdentifier = "fontPreferencesTable"

    @objc weak var preferencesController: PSBasePreferencesController?

    private var fontStrings: [String]?

    private func reloadFontStrings() {
        if fontStrings == nil {
            fontStrings = [
                //"Zapfino",
                //"Snell Roundhand",
                //"Academy Engraved LET",
                //"Charis SIL",
                //"Padauk",
                //"DB LCD Temp",
                //"Marker Felt",
                //"Bradley Hand",
                //"Baskerville",
                //"Copperplate",
                "American Typewriter",
                "Arial",
                "Courier",
                "Helvetica Neue",
                "HelveticaNeue-Light",
                "Times New Roman",
                // specialist ones:
                "Code2000",
                "Gentium Plus",
                "Ezra SIL",
                //the more weird ones....
                "AppleGothic",
                "Arial Hebrew",
                "Arial Rounded MT Bold",
                "Arial Unicode MS",
                "Bangla Sangam MN",
                "Bodoni 72",
                "Cochin",
                "Courier New",
                "Damascus",
                "Devanagari Sangam MN",
                "Geeza Pro",
                "Georgia",
                "Gill Sans",
                "Gurmukhi MN",
                "Gujarati Sangam MN",
                "Heiti J",
                "Heiti K",
                "Heiti SC",
                "Heiti TC",
                "Helvetica",
                "Hiragino Kaku Gothic ProN",
                "Hoefler Text",
                "Kailasa",
                "Kannada Sangam MN",
                "Malayalam Sangam MN",
                "Marion",
                "Menlo",
                "Optima",
                "Oriya Sangam MN",
                "Sinhala Sangam MN",
                "Tamil Sangam MN",
                "Telugu Sangam MN",
                "Thonburi",
                "Trebuchet MS",
                "Verdana",
            ]
        }
    }

    // The selected font: the single global pref, falling back to the default font.
    // (The former per-module override went away when the font picker moved out of
    // the per-tab display-settings menus and into Preferences.)
    private func selectedFontName() -> String {
        UserDefaults.standard.string(forKey: Defaults.fontNamePreference) ?? AppConstants.defaultFontName
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("FontPreferenceTitle", comment: "Font")
        reloadFontStrings()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if fontStrings == nil {
            reloadFontStrings()
        }
        tableView.reloadData()
        let font = selectedFontName()
        if let pos = fontStrings?.firstIndex(of: font) {
            let ip = IndexPath(row: pos, section: 0)
            tableView.scrollToRow(at: ip, at: .middle, animated: false)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        fontStrings = nil
    }

    // MARK: - Table view methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontStrings?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let font = selectedFontName()

        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: Self.cellIdentifier)

        let fontName = fontStrings?[indexPath.row]
        cell.textLabel?.text = fontName
        if let fontName = fontName {
            cell.textLabel?.font = UIFont(name: fontName, size: 15.0)
        }

        if font == cell.textLabel?.text {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let fontName = fontStrings?[indexPath.row] {
            preferencesController?.fontNameChanged(fontName)
        }
        preferencesController?.hideFontTableView()
    }
}
