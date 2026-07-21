//
//  PSDictionaryViewController.swift
//  PocketSword
//
//  The Dictionary tab: a UITableViewController that browses every key in the
//  primary dictionary and offers an incremental, case-insensitive substring
//  filter over those keys via a UISearchBar header. Tapping a key renders that
//  entry's HTML and pushes a PSDictionaryEntryViewController. The right bar
//  button forwards to the coordinator (PSTabBarControllerDelegate) to open the
//  module-selector list.
//
//  Swift port (Wave 3) of the former Classes/PSDictionaryViewController.{h,mm}.
//  Zero C++ — it reaches the SWORD engine only through the Foundation-only
//  facades (PSModuleController.primaryDictionary -> SwordDictionary) and the
//  PSModuleController HTML helpers, all visible via the bridging header. The
//  @objc PSDictionaryViewControllerDelegate protocol is preserved verbatim so
//  the still-Obj-C++ coordinator can conform to it (forward-declared as
//  @protocol in PSTabBarControllerDelegate.h, resolved via the generated
//  PocketSword-Swift.h in its .mm). MBProgressHUD (Obj-C, UIKit-only) is reached
//  through the bridging header.
//
//  Created by Nic Carter on 21/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSDictionaryViewControllerDelegate)
protocol PSDictionaryViewControllerDelegate: NSObjectProtocol {
    // Selector pinned to the original Obj-C name -toggleModulesListFromButton:
    // so the still-Obj-C++ coordinator (PSTabBarControllerDelegate.mm) keeps
    // satisfying the conformance with its existing method implementation.
    @objc(toggleModulesListFromButton:)
    func toggleModulesList(fromButton sender: Any?)
}

@objc(PSDictionaryViewController)
final class PSDictionaryViewController: UITableViewController, UISearchBarDelegate, MBProgressHUDDelegate {

    // SWMOD_CONF_FEATURE_IMAGES from SwordManager.h — an Obj-C `#define @"Images"`
    // string macro, which does NOT import into Swift, so the literal is mirrored
    // here verbatim. It must stay byte-identical to SwordManager.h.
    private static let swModConfFeatureImages = "Images"

    @objc weak var delegate: PSDictionaryViewControllerDelegate?
    @objc var dictionarySearchBar: UISearchBar?

    private var searching = false
    private var letUserSelectRow = true
    private var searchResults: [String] = []
    private var dictionaryEnabled = false
    private var overlayViewController: PSDictionaryOverlayViewController?

    private var primaryDictionary: SwordDictionary? {
        PSModuleController.default()?.primaryDictionary as? SwordDictionary
    }

    // MARK: - Lifecycle

    @objc private func dictionaryModuleSelectorButtonPressed(_ sender: Any?) {
        delegate?.toggleModulesList(fromButton: sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("TabBarTitleDictionary", comment: "Dictionary")

        let dictButton = UIBarButtonItem(title: NSLocalizedString("None", comment: "None"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(dictionaryModuleSelectorButtonPressed(_:)))
        navigationItem.rightBarButtonItem = dictButton

        let dSB = UISearchBar(frame: CGRect(x: 0, y: 0, width: PSResizing.mainScreenBounds().size.width, height: 44))
        dSB.delegate = self
        dSB.placeholder = NSLocalizedString("DictionarySearchPlaceholderText", comment: "Search Dictionary")
        dictionarySearchBar = dSB

        tableView.tableHeaderView = dictionarySearchBar
        searching = false
        letUserSelectRow = true
        dictionaryEnabled = false
        searchResults = []

        NotificationCenter.default.addObserver(self, selector: #selector(primaryDictionaryChanged), name: .primaryDictionaryChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDictionaryData as () -> Void), name: .reloadDictionaryData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setDictionaryTitleViaNotification), name: .newPrimaryDictionary, object: nil)
    }

    @objc private func primaryDictionaryChanged() {
        navigationItem.rightBarButtonItem?.title = NSLocalizedString("None", comment: "None")
    }

    @objc func reloadDictionaryData() {
        reloadDictionaryData(true)
    }

    @objc func setDictionaryTitleViaNotification() {
        autoreleasepool {
            if let primaryDictionary = primaryDictionary {
                let newText = primaryDictionary.name ?? ""
                let i = (newText.count > 8) ? 8 : newText.count
                // ".." is the equiv of another char, so if length <= 9, use the
                // full name. e.g. "Swe1917Of" should display the full name.
                let newTitle = (newText.count <= 9) ? newText : "\(newText.prefix(i)).."
                navigationItem.rightBarButtonItem?.title = newTitle
            } else {
                navigationItem.rightBarButtonItem?.title = NSLocalizedString("None", comment: "None")
            }
        }
    }

    @objc func reloadDictionaryData(_ reloadData: Bool) {
        if primaryDictionary == nil {
            let lastDictionary = UserDefaults.standard.string(forKey: Defaults.lastDictionary)

            if let lastDictionary = lastDictionary {
                PSModuleController.default()?.loadPrimaryDictionary(lastDictionary)
            } else {
                navigationItem.rightBarButtonItem?.title = NSLocalizedString("None", comment: "None")
                dictionarySearchBar?.isUserInteractionEnabled = false
                dictionaryEnabled = false
                tableView.reloadData()
                return
            }
        }

        if let primaryDictionary = primaryDictionary {
            if !primaryDictionary.keysLoaded() {
                if !primaryDictionary.keysCached() {
                    // ask whether to cache the keys now or another time
                    let cacheTitle = "\(primaryDictionary.name ?? "") \(NSLocalizedString("CacheDictionaryKeysTitle", comment: "Cache?"))"
                    let alert = UIAlertController(title: cacheTitle,
                                                  message: NSLocalizedString("CacheDictionaryKeysMsg", comment: "Cache the keys?"),
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: "No"), style: .cancel) { [weak self] _ in
                        guard let self = self else { return }
                        self.dictionarySearchBar?.isUserInteractionEnabled = false
                        self.dictionaryEnabled = false
                        self.tableView.reloadData()
                    })
                    alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: "Yes"), style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
                        self.view.addSubview(hud)
                        hud.delegate = self
                        DispatchQueue.global(qos: .userInitiated).async {
                            _ = self.primaryDictionary?.allKeys()
                            DispatchQueue.main.async {
                                hud.hide(animated: true)
                            }
                        }
                        self.dictionaryEnabled = true
                        self.dictionarySearchBar?.isUserInteractionEnabled = true
                    })
                    present(alert, animated: true, completion: nil)
                    return
                } else {
                    // need to load it
                    let hud = MBProgressHUD.showAdded(to: view, animated: true)
                    view.addSubview(hud)

                    // Register for HUD callbacks so we can remove it from the window at the right time
                    hud.delegate = self
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        _ = self?.primaryDictionary?.allKeys()
                        DispatchQueue.main.async {
                            hud.hide(animated: true)
                        }
                    }
                }
            }
        }
        dictionarySearchBar?.isUserInteractionEnabled = true
        dictionaryEnabled = true
    }

    func hudWasHidden(_ hud: MBProgressHUD) {
        // Remove HUD from screen when the HUD was hidden
        hud.removeFromSuperview()
        if searching {
            searchDictionaryEntries()
        }
        tableView.reloadData()
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searching {
            return searchResults.count
        } else if dictionaryEnabled {
            return Int(primaryDictionary?.entryCount() ?? 0)
        } else {
            return 0
        }
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
        if searching {
            cell.textLabel?.text = searchResults[indexPath.row]
        } else if dictionaryEnabled {
            cell.textLabel?.text = (primaryDictionary?.allKeys() as? [String])?[indexPath.row]
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dictionarySearchBar?.resignFirstResponder()
        guard let t = self.tableView(tableView, cellForRowAt: indexPath).textLabel?.text else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        let rawDescr = primaryDictionary?.entry(forKey: t) ?? ""
        let body = "<div style=\"-webkit-text-size-adjust: none;\"><b>\(t)</b><br /><p>\(rawDescr)</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p></div>"
        let descr = PSModuleController.createInfoHTMLString(body, usingModuleForPreferences: primaryDictionary?.name)

        let entryVC = PSDictionaryEntryViewController(nibName: nil, bundle: nil)
        entryVC.setDictionaryEntryTitle(t)
        entryVC.setDictionaryEntryText(descr)
        if primaryDictionary?.hasFeature(Self.swModConfFeatureImages) == true {
            entryVC.setScalesPageToFit(true)
        } else {
            entryVC.setScalesPageToFit(false)
        }
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
        let keys = (primaryDictionary?.allKeys() as? [String]) ?? []

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
