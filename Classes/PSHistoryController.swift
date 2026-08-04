/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2010 CrossWire Bible Society

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

//
//  PSHistoryController.swift
//  PocketSword
//
//  Swift port (Swift migration Wave 3) of the Obj-C++ PSHistoryController.{h,mm}.
//
//  This is a HIGH-RISK file (R1 - silent data / iCloud corruption). It owns:
//    - the reading-history list UI (a UITableViewController shown in the multi-list),
//    - the [ref, "0"(scroll), mod, NSDate] array schema persisted under
//      PSHistoryName == "bibleHistory" in BOTH NSUserDefaults and
//      NSUbiquitousKeyValueStore,
//    - the add-history path and its 100-entry cap.
//
//  HistoryStore now owns cloud notification handling, merge, deduplication, and
//  persistence for the SwiftUI migration.
//
//  The class is @objc(PSHistoryController) so the still-Obj-C++ callers
//  (PocketSwordAppDelegate.mm, PSModuleViewController.mm, PSTabBarControllerDelegate.mm,
//  via the generated PocketSword-Swift.h) keep their existing selectors:
//    +addHistoryItem:  (ShownTab)
//    -setListType:     (ShownTab)
//    -init / -closeButtonPressed / -trashButtonPressed
//    -removeHistoryItem:forTab:
//  Swift callers (PSModuleSearchController.swift, PSBookmarksNavigatorController.swift)
//  reference it in-module directly: PSHistoryController.addHistoryItem(.BibleTab).
//
//  PSHistoryItem (the value leaf) is already Swift (Wave 1.2) — we call its
//  -array / +parseHistoryArrayArray: / +arrayArrayFromHistoryItems: /
//  +arraysAreEqual:secondArray: / -isEqualToHistoryItem: / -ageComparisonToHistoryItem:
//  here, exactly as the .mm did.
//
//  KVS: the original .mm guarded NSUbiquitousKeyValueStore behind
//  NSClassFromString(@"NSUbiquitousKeyValueStore"); on every supported iOS the
//  framework class is always present, so Swift uses NSUbiquitousKeyValueStore.default
//  directly (per the plan).
//

import UIKit

@objc(PSHistoryController)
class PSHistoryController: UITableViewController {

    private var listType: ShownTab = .BibleTab

    // MARK: - Initialization

    @objc init() {
        super.init(nibName: nil, bundle: nil)
        let tBI = UITabBarItem(tabBarSystemItem: .history, tag: 0)
        self.tabBarItem = tBI
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc func closeButtonPressed() {
        NotificationCenter.default.post(name: .toggleMultiList, object: nil)
    }

    @objc(setListType:)
    func setListType(_ listT: ShownTab) {
        listType = listT
    }

    // used for iCloud sync just in case our history changes while we're viewing it.
    @objc func reloadTableViewFromNotification() {
        self.tableView.reloadData()
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("CloseButtonTitle", comment: "Close"), style: .plain, target: self, action: #selector(closeButtonPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("HistoryClearButtonTitle", comment: "Clear"), style: .plain, target: self, action: #selector(trashButtonPressed))
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableViewFromNotification), name: .historyChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.backgroundColor = .systemBackground
        self.navigationItem.title = NSLocalizedString("HistoryTitle", comment: "History")
        self.tableView.reloadData()

        if self.tableView.numberOfSections > 0 && self.tableView.numberOfRows(inSection: 0) > 0 {
            let ip = IndexPath(row: 0, section: 0)
            self.tableView.scrollToRow(at: ip, at: .top, animated: false)
        }
    }

    // MARK: - Add history item

    // This should be called just AFTER:
    //    "nextChapter".
    //    or "prevChapter".
    //    or navigation to a new ref from the refPicker.
    //    or when the user selects a new module to view.
    //    or when the user selects a bookmark.
    //    or when the user selects a search result.
    @objc(addHistoryItem:)
    class func addHistoryItem(_ tabForHistory: ShownTab) {
        let defaults = UserDefaults.standard
        var verse: String?
        var mod: String?
        var history = defaults.array(forKey: AppConstants.historyName).map { NSMutableArray(array: $0) }
        var valid = false

        if tabForHistory == .BibleTab {
            verse = defaults.string(forKey: Defaults.bibleVersePosition)
            if let primaryBible = PSModuleController.default().primaryBibleName {
                valid = true
                mod = primaryBible
            }
        } else if tabForHistory == .CommentaryTab {
            verse = defaults.string(forKey: Defaults.commentaryVersePosition)
            if let primaryCommentary = PSModuleController.default().primaryCommentaryName {
                valid = true
                mod = primaryCommentary
            }
        } else {
            alog("\nWe don't know which tab we're on!  :(")
        }

        if valid {
            // [NSString stringWithFormat:@"%@:%@", createRefString(getCurrentBibleRef), verse]
            let refString: String = PSModuleController.createRefString(PSModuleController.getCurrentBibleRef()) ?? ""
            let ref = "\(refString):\(verse ?? "")"

            // [ref, "0"(scroll), mod, NSDate] — exactly as -[NSArray arrayWithObjects:...]
            // truncated at the first nil; here mod is always non-nil when valid.
            var historyItem: [Any] = [ref, "0" /*scroll*/]
            if let mod = mod { historyItem.append(mod) }
            historyItem.append(Date())

            if history == nil {
                history = NSMutableArray()

                let bundleId = Bundle.main.bundleIdentifier ?? ""
                var prefs = defaults.persistentDomain(forName: bundleId) ?? [:]
                prefs[AppConstants.historyName] = history
                defaults.setPersistentDomain(prefs, forName: bundleId)
            } else if let history = history {
                // check for duplicates:
                for ii in 0..<history.count {
                    guard let existingItem = history[ii] as? [Any], existingItem.count > 0 else { continue }
                    let existingRef = existingItem[0] as? String
                    if ref == existingRef {
                        // if the references are the same,
                        var existingMod: String? = nil
                        if existingItem.count > 2 {
                            existingMod = existingItem[2] as? String
                        }
                        if existingMod == nil || mod == existingMod {
                            // if the mods are the same, or it's an OLD history item without a mod, delete it
                            history.removeObject(at: ii)
                            break
                        }
                    }
                }
            }

            guard let history = history else { return }
            history.insert(historyItem, at: 0)
            if history.count >= AppConstants.historyMaxEntries {
                history.removeLastObject()
            }

            defaults.set(history, forKey: AppConstants.historyName)
            defaults.synchronize()

            // synchronize with iCloud as well:
            NSUbiquitousKeyValueStore.default.set(history, forKey: AppConstants.historyName)
            NotificationCenter.default.post(name: .historyChanged, object: nil)
        }
    }

    @objc func trashButtonPressed() {
        let alert = UIAlertController(title: NSLocalizedString("HistoryClearConfirmationTitle", comment: "Clear All History?"), message: NSLocalizedString("HistoryClearConfirmationMessage", comment: "Are you sure?"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: "No"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: "Yes"), style: .default, handler: { [weak self] _ in
            HistoryStore().clear()
            self?.tableView.reloadData()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    @objc(removeHistoryItem:forTab:)
    func removeHistoryItem(_ historyIndex: Int, forTab tabForHistory: ShownTab) {
        guard HistoryStore().remove(at: historyIndex, notify: false) else { return }
        let indexPath = IndexPath(row: historyIndex, section: 0)
        self.tableView.deleteRows(at: [indexPath], with: .middle)
        NotificationCenter.default.post(name: .historyChanged, object: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let history = UserDefaults.standard.array(forKey: AppConstants.historyName) {
            return history.count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theIdentifier = "id-mod"

        // Try to recover a cell from the table view with the given identifier, this is for performance
        var cell = tableView.dequeueReusableCell(withIdentifier: theIdentifier) as? PSBookmarkTableViewCell

        // If no cell is available, create a new one using the given identifier -
        if cell == nil {
            cell = PSBookmarkTableViewCell(style: .subtitle, reuseIdentifier: theIdentifier)
        }

        let history = UserDefaults.standard.array(forKey: AppConstants.historyName) ?? []

        let obj = history[indexPath.row] as? [Any] ?? []
        cell?.textLabel?.text = obj.count > 0 ? (obj[0] as? String) : nil
        if obj.count > 2 {
            cell?.detailTextLabel?.text = obj[2] as? String
        } else {
            cell?.detailTextLabel?.text = ""
        }
        if obj.count > 3, let date = obj[3] as? Date {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .short

            let dateString = dateFormatter.string(from: date)
            cell?.lastAccessedLabel.text = dateString
        } else {
            cell?.lastAccessedLabel.text = ""
        }

        cell?.textLabel?.textColor = .label
        cell?.detailTextLabel?.textColor = .label
        return cell!
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemBackground
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var moduleIsCommentary = false
        let history = UserDefaults.standard.array(forKey: AppConstants.historyName) ?? []
        let rowArray = history[indexPath.row] as? [Any] ?? []
        let firstString = (rowArray.count > 0 ? rowArray[0] as? String : nil) ?? ""
        let components = firstString.components(separatedBy: ":")
        let ref = components.count > 0 ? components[0] : ""
        let verse = components.count > 1 ? components[1] : ""
        var mod: String?
        if rowArray.count > 2 {
            mod = rowArray[2] as? String
            // The module's type from content_meta (Phase 5 step 5). A nil type means
            // the history row names a module we do not ship — same fallback to
            // lastBible as when SwordManager could not find it.
            let type = mod.flatMap { PSContentStore.shared?.moduleMeta($0, key: "type") }
            if type == nil {
                mod = UserDefaults.standard.string(forKey: Defaults.lastBible)
            } else if type == "Commentaries" {
                moduleIsCommentary = true
            }
            if moduleIsCommentary {
                PSModuleController.default().loadPrimaryCommentary(mod)
            } else {
                PSModuleController.default().loadPrimaryBible(mod)
            }
        }
        UserDefaults.standard.set(PSModuleController.createRefString(ref), forKey: Defaults.lastRef)
        if moduleIsCommentary {
            UserDefaults.standard.set(verse, forKey: Defaults.commentaryVersePosition)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
            NotificationCenter.default.post(name: .showCommentaryTab, object: nil)
            PSHistoryController.addHistoryItem(.CommentaryTab)
        } else {
            UserDefaults.standard.set(verse, forKey: Defaults.bibleVersePosition)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
            NotificationCenter.default.post(name: .showBibleTab, object: nil)
            PSHistoryController.addHistoryItem(.BibleTab)
        }
        NotificationCenter.default.post(name: .toggleMultiList, object: nil)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.removeHistoryItem(indexPath.row, forTab: listType)
        }
    }

}
