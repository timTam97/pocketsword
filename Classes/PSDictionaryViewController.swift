//
//  PSDictionaryViewController.swift
//  PocketSword
//
//  The Dictionary tab: a UITableViewController that browses every key in the
//  primary dictionary and offers an incremental, case-insensitive substring
//  filter over those keys via a UISearchBar header. Tapping a key renders that
//  entry's HTML and pushes a PSDictionaryEntryViewController. The right bar
//  button is a fixed 3-way UIMenu over the bundled lexicons (Strong's Greek /
//  Strong's Hebrew / Robinson) — there is no module list to open.
//
//  Swift port (Wave 3) of the former Classes/PSDictionaryViewController.{h,mm}.
//  Zero C++ — it reaches the SWORD engine only through the Foundation-only
//  facades (PSModuleController.primaryDictionaryName) and the
//  PSModuleController HTML helpers, all visible via the bridging header.
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSDictionaryViewController)
final class PSDictionaryViewController: UITableViewController, UISearchBarDelegate {

    // SWMOD_CONF_FEATURE_IMAGES — an Obj-C `#define @"Images"` string macro (now in
    // globals.h, moved there by Phase 5 step 2), which does NOT import into Swift, so
    // the literal is mirrored here verbatim. It must stay byte-identical, because it
    // is the key the baked feature set is queried with.
    private static let swModConfFeatureImages = "Images"

    /// Display titles for the three fixed-role bundled lexicons, keyed by module
    /// name. The roles come from each module's .conf (GreekDef / HebrewDef /
    /// GreekParse) and are not interchangeable — see `BundledModules`.
    private static let lexiconTitles: [String: String] = [
        BundledModules.strongsGreek: "Strong's Greek",
        BundledModules.strongsHebrew: "Strong's Hebrew",
        BundledModules.morphGreek: "Robinson",
    ]

    @objc var dictionarySearchBar: UISearchBar?

    private var searching = false
    private var letUserSelectRow = true
    private var searchResults: [String] = []
    private var dictionaryEnabled = false
    private var overlayViewController: PSDictionaryOverlayViewController?

    /// The lexicon currently being browsed, by name (Phase 5 step 7 — it was a
    /// `SwordDictionary`, read only for its `name`).
    private var primaryDictionaryName: String? {
        PSModuleController.default()?.primaryDictionaryName
    }

    // MARK: - Lifecycle

    /// Rebuilds the fixed 3-way lexicon menu, checkmarking whichever lexicon is
    /// currently loaded as the primary dictionary.
    private func rebuildLexiconMenu() {
        let currentName = primaryDictionaryName
        let actions: [UIMenuElement] = BundledModules.lexicons.map { modName in
            let action = UIAction(title: Self.lexiconTitles[modName] ?? modName,
                                  image: nil,
                                  identifier: UIAction.Identifier("dictionary.\(modName)")) { [weak self] _ in
                guard let self = self else { return }
                PSModuleController.default()?.loadPrimaryDictionary(modName)
                self.reloadDictionaryData(true)
                self.rebuildLexiconMenu()
                self.tableView.reloadData()
            }
            action.state = (modName == currentName) ? .on : .off
            return action
        }
        navigationItem.rightBarButtonItem?.menu = UIMenu(title: "", children: actions)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("TabBarTitleDictionary", comment: "Dictionary")

        let dictButton = UIBarButtonItem(title: NSLocalizedString("None", comment: "None"),
                                         style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = dictButton
        rebuildLexiconMenu()

        let dSB = UISearchBar(frame: CGRect(x: 0, y: 0, width: PSResizing.mainScreenBounds().size.width, height: 44))
        dSB.delegate = self
        dSB.placeholder = NSLocalizedString("DictionarySearchPlaceholderText", comment: "Search Dictionary")
        dictionarySearchBar = dSB

        tableView.tableHeaderView = dictionarySearchBar
        searching = false
        letUserSelectRow = true
        dictionaryEnabled = false
        searchResults = []

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDictionaryData as () -> Void), name: .reloadDictionaryData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setDictionaryTitleViaNotification), name: .newPrimaryDictionary, object: nil)
    }

    @objc func reloadDictionaryData() {
        reloadDictionaryData(true)
    }

    @objc func setDictionaryTitleViaNotification() {
        autoreleasepool {
            if let primaryDictionaryName {
                let newText = primaryDictionaryName
                let i = (newText.count > 8) ? 8 : newText.count
                // ".." is the equiv of another char, so if length <= 9, use the
                // full name. e.g. "Swe1917Of" should display the full name.
                let newTitle = (newText.count <= 9) ? newText : "\(newText.prefix(i)).."
                navigationItem.rightBarButtonItem?.title = newTitle
            } else {
                navigationItem.rightBarButtonItem?.title = NSLocalizedString("None", comment: "None")
            }
            rebuildLexiconMenu()
        }
    }

    @objc func reloadDictionaryData(_ reloadData: Bool) {
        if primaryDictionaryName == nil {
            // Only a lexicon we actually SHIP may be restored.
            //
            // A `lastDictionary` naming anything else — a module sideloaded before the
            // module list was retired — would otherwise be loaded anyway, leaving
            // `dictionaryEnabled` true over an empty key list. That is a blank tab
            // whose header says nothing is wrong (`titleForHeaderInSection` only
            // reports "none loaded" when `dictionaryEnabled` is false), and with no
            // removal UI the user's only way out is the `▾` menu.
            //
            // The `DefaultsSimplifiedCleanupDone` migration used to clear such a value
            // at launch, and it went with the SWORD-era seeding it was wrapped in. The
            // check belongs here regardless: `reloadLastBible` / `reloadLastCommentary`
            // validate their own persisted names against `content_meta` for the same
            // reason, and doing it at the READ means a stale value cannot come back
            // from a path that has not been written yet.
            let stored = UserDefaults.standard.string(forKey: Defaults.lastDictionary)
            let lastDictionary = stored.flatMap { BundledModules.lexicons.contains($0) ? $0 : nil }

            if let lastDictionary = lastDictionary {
                PSModuleController.default()?.loadPrimaryDictionary(lastDictionary)
            } else {
                // Drop a name we are never going to honour, so it stops being read on
                // every appearance. A no-op when there was nothing stored.
                if stored != nil {
                    dlog("Dictionary: dropping unshippable lastDictionary '\(stored ?? "")'")
                    UserDefaults.standard.removeObject(forKey: Defaults.lastDictionary)
                }
                navigationItem.rightBarButtonItem?.title = NSLocalizedString("None", comment: "None")
                dictionarySearchBar?.isUserInteractionEnabled = false
                dictionaryEnabled = false
                tableView.reloadData()
                return
            }
        }

        // SWORD_REMOVAL_PLAN.md Phase 5 step 1: **there is nothing to wait for.**
        //
        // What used to be here was a "cache this lexicon's keys?" prompt, a
        // MBProgressHUD, a background -allKeys walk and an MBProgressHUDDelegate
        // callback — all of it because `-[SwordDictionary allKeys]` walked the module
        // from TOP and was slow enough to need a progress indicator and an opt-in
        // on-disk key cache. The baked store keeps the keys in an UNCOMPRESSED index
        // precisely so that is unnecessary, and Phase 3 already skipped the whole
        // dance whenever the reader was active. With the engine gone the other branch
        // is unreachable, so it is deleted rather than left as dead code.
        //
        // That prompt was also a real bug, found by driving the simulator rather than
        // by any test: answering "No" left the tab showing "No dictionary loaded"
        // for ever, even though the keys were in hand.
        if primaryDictionaryName != nil {
            dictionarySearchBar?.isUserInteractionEnabled = true
            dictionaryEnabled = true
            if reloadData { tableView.reloadData() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDictionaryData(false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            NotificationCenter.default.post(name: .rotateInfoPane, object: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - UITableViewDataSource / Delegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    /// The number of rows the table has, from the same two sources `key(at:)` reads.
    private var rowCount: Int {
        if searching {
            return searchResults.count
        } else if dictionaryEnabled {
            return PSContentReader.entryCount(module: primaryDictionaryName ?? "")
        } else {
            return 0
        }
    }

    /// **The single source of truth for "which key is at this row".**
    ///
    /// SWORD_REMOVAL_PLAN.md Phase 4 step 9. `didSelectRowAt` used to recover the
    /// tapped key by re-reading `cellForRowAt(indexPath).textLabel?.text` — asking
    /// the data source to build a cell just to read back a string it had itself
    /// written a moment earlier. That coupling of *display* to *lookup* is what made
    /// the capitalisation bug user-visible in the first place, so it goes with it.
    ///
    /// The branch matters and is easy to get wrong: this table has **two** sources.
    /// While searching, row N is `searchResults[N]`; otherwise it is key N of the
    /// whole lexicon. Indexing the full key list unconditionally would open the
    /// **wrong entry for every search result** — a silent mis-navigation that no
    /// existing test covers, which is why the simulator check for step 9 explicitly
    /// searches and then taps a result.
    private func key(at indexPath: IndexPath) -> String? {
        if searching {
            guard indexPath.row < searchResults.count else { return nil }
            return searchResults[indexPath.row]
        }
        guard dictionaryEnabled else { return nil }
        let keys = PSContentReader.allKeys(module: primaryDictionaryName ?? "")
        guard indexPath.row < keys.count else { return nil }
        return keys[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rowCount
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if searching && searchResults.count > 0 {
            return "\(searchResults.count) \(NSLocalizedString("SearchResults", comment: "results"))"
        } else if !dictionaryEnabled {
            return NSLocalizedString("DictionaryNoneLoaded", comment: "DictionaryNoneLoaded")
        } else {
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "dict-id")
            ?? UITableViewCell(style: .default, reuseIdentifier: "dict-id")
        cell.textLabel?.text = key(at: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dictionarySearchBar?.resignFirstResponder()
        // Read the key from the data source, NOT back off the cell's label.
        guard let t = key(at: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        let rawDescr = PSContentReader.entry(module: primaryDictionaryName ?? "", key: t) ?? ""
        let body = "<div style=\"-webkit-text-size-adjust: none;\"><b>\(t)</b><br /><p>\(rawDescr)</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>"
        let descr = PSModuleController.createInfoHTMLString(body, usingModuleForPreferences: primaryDictionaryName)

        let entryVC = PSDictionaryEntryViewController(nibName: nil, bundle: nil)
        entryVC.setDictionaryEntryTitle(t)
        entryVC.setDictionaryEntryText(descr)
        // The Images gate, from the baked feature set (Phase 5 step 5). No bundled
        // lexicon declares `Feature=Images`, so this is always the `false` arm — the
        // branch is kept, and driven from real data, rather than being collapsed to a
        // constant: a lexicon that DID declare it would need the `true` arm, and
        // hardcoding would make that a silent behaviour change.
        let name = primaryDictionaryName ?? ""
        let hasImages = PSContentStore.shared?.moduleHasFeature(name, Self.swModConfFeatureImages) ?? false
        entryVC.setScalesPageToFit(hasImages)
        if let navigationController = navigationController {
            navigationController.pushViewController(entryVC, animated: true)
        } else {
            present(entryVC, animated: true, completion: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ theTableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        letUserSelectRow ? indexPath : nil
    }

    // MARK: - UISearchBarDelegate

    func searchBarTextDidBeginEditing(_ theSearchBar: UISearchBar) {
        // Add the overlay view.
        if overlayViewController == nil {
            let overlay = PSDictionaryOverlayViewController(nibName: nil, bundle: nil)

            let yaxis = tableView.tableHeaderView?.frame.size.height ?? 0
            let width = view.frame.size.width
            let height = view.frame.size.height

            // Parameters x = origin on x-axis, y = origin on y-axis.
            overlay.view.frame = CGRect(x: 0, y: yaxis, width: width, height: height)
            overlay.dictionaryViewController = self
            overlayViewController = overlay
        }

        searching = true

        if (dictionarySearchBar?.text?.count ?? 0) <= 0 {
            if let overlayView = overlayViewController?.view, let parentView = parent?.view {
                tableView.insertSubview(overlayView, aboveSubview: parentView)
            }
            letUserSelectRow = false
            tableView.isScrollEnabled = false
        } else {
            letUserSelectRow = true
            tableView.isScrollEnabled = true
        }

        dictionarySearchBar?.setShowsCancelButton(true, animated: true)
        searchDictionaryEntries()
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchResults.removeAll()

        if searchText.count > 0 {
            overlayViewController?.view.removeFromSuperview()
            tableView.separatorStyle = .singleLine
            searching = true
            letUserSelectRow = true
            tableView.isScrollEnabled = true
            searchDictionaryEntries()
        } else {
            if let overlayView = overlayViewController?.view, let parentView = parent?.view {
                tableView.insertSubview(overlayView, aboveSubview: parentView)
            }
            tableView.separatorStyle = .none
            searching = true
            letUserSelectRow = false
            tableView.isScrollEnabled = false
        }

        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        tableView.tableHeaderView = dictionarySearchBar
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        if dictionarySearchBar?.isFirstResponder == true {
            dictionarySearchBar?.resignFirstResponder()
        }

        letUserSelectRow = true
        searching = false
        tableView.isScrollEnabled = true

        overlayViewController?.view.removeFromSuperview()
        overlayViewController = nil
        dictionarySearchBar?.setShowsCancelButton(false, animated: true)

        tableView.separatorStyle = .singleLine
        searchResults.removeAll()
        tableView.reloadData()
        dictionarySearchBar?.text = ""
    }

    @objc func searchDictionaryEntries() {
        searchResults.removeAll()
        let searchText = dictionarySearchBar?.text ?? ""
        let keys = PSContentReader.allKeys(module: primaryDictionaryName ?? "")

        for t in keys {
            if t.range(of: searchText, options: .caseInsensitive) != nil {
                searchResults.append(t)
            }
        }
    }

    @objc func hideDescription(_ sender: Any?) {
        NotificationCenter.default.post(name: .hideInfoPane, object: nil)
        dismiss(animated: true, completion: nil)
    }
}
