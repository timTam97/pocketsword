//
//  PSModuleSelectorController.swift
//  PocketSword
//
//  The module picker for the Commentary / Dictionary tabs and the Preferences
//  "Module Preferences" list: a single-section UITableView of the installed
//  modules of one ShownTab's category. Tapping a row loads that module as the
//  primary commentary/dictionary (or, in Preferences mode, drills into its
//  per-module prefs); the accessory button / a locked module pushes the
//  PSModulePreferencesController. Swipe-to-delete removes a module.
//
//  Migrated from PSModuleSelectorController.{h,mm} (Swift migration Wave 3). The
//  former .mm contained ZERO sword:: usage — it lists modules purely through the
//  clean Foundation-only SwordManager / SwordModule facades and drives
//  PSModuleController. The still-Obj-C++ PSTabBarControllerDelegate and
//  PSPreferencesController instantiate this VC via the generated
//  PocketSword-Swift.h; PSModulePreferencesController stays Obj-C++ for now and is
//  reached through the bridging header.
//
//  BibleTab / DevotionalTab / DownloadsTab are dead ShownTab placeholders kept
//  only so persisted raw-int tab prefs do not shift (see globals.h); they render
//  an empty list, matching the original .mm.
//

import UIKit

@objc(PSModuleSelectorController)
final class PSModuleSelectorController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // SWMOD_CATEGORY_* live in SwordManager.h as @"literal" #defines that Swift
    // cannot import; mirror the wire values here byte-for-byte (these are SWORD
    // category strings consumed by -[SwordManager modulesForType:] — do not "fix").
    private static let categoryCommentaries = "Commentaries"            // SWMOD_CATEGORY_COMMENTARIES
    private static let categoryDictionaries = "Lexicons / Dictionaries" // SWMOD_CATEGORY_DICTIONARIES

    private static let cellIdentifier = "id-mod"

    @objc var listType: ShownTab = .BibleTab
    @objc var modulesListTable: UITableView?

    // +[PSModuleController defaultModuleController] imports as a nullable
    // PSModuleController? but is the never-nil app singleton (the original Obj-C
    // dereferenced it unconditionally), so force-unwrap once here to keep the call
    // sites faithful to the .mm.
    private var moduleController: PSModuleController { PSModuleController.default()! }
    private var swordManager: SwordManager { moduleController.swordManager }

    // MARK: - View lifecycle

    override func loadView() {
        let screenBounds = PSResizing.mainScreenBounds()
        let viewWidth = screenBounds.size.width
        let viewHeight = screenBounds.size.height

        let baseView = UIView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        baseView.backgroundColor = .systemBackground

        let listTable = UITableView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight), style: .plain)
        listTable.delegate = self
        listTable.dataSource = self
        listTable.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        baseView.addSubview(listTable)
        self.modulesListTable = listTable

        self.view = baseView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        var moduleCount = 0

        if listType != .PreferencesTab && !PSResizing.iPad() {
            let modulesCloseButton = UIBarButtonItem(title: NSLocalizedString("CloseButtonTitle", comment: ""),
                                                     style: .plain,
                                                     target: self,
                                                     action: #selector(dismissModuleSelector))
            self.navigationItem.leftBarButtonItem = modulesCloseButton
        }

        modulesListTable?.backgroundColor = .systemBackground

        var ip: IndexPath? = nil // default value
        if listType == .CommentaryTab {
            self.navigationItem.title = NSLocalizedString(PSModuleSelectorController.categoryCommentaries, comment: "")
            let array = swordManager.modules(forType: PSModuleSelectorController.categoryCommentaries) ?? []
            moduleCount = array.count
            var pos = 0
            while pos < array.count {
                if let mod = array[pos] as? SwordModule, mod.name == moduleController.primaryCommentary?.name {
                    break
                }
                pos += 1
            }
            if pos < array.count {
                ip = IndexPath(row: pos, section: 0)
            }
        } else if listType == .DictionaryTab {
            self.navigationItem.title = NSLocalizedString(PSModuleSelectorController.categoryDictionaries, comment: "")
            let array = swordManager.modules(forType: PSModuleSelectorController.categoryDictionaries) ?? []
            moduleCount = array.count
            var pos = 0
            while pos < array.count {
                if let mod = array[pos] as? SwordModule, mod.name == moduleController.primaryDictionary?.name {
                    break
                }
                pos += 1
            }
            if pos < array.count {
                ip = IndexPath(row: pos, section: 0)
            }
        } else if listType == .PreferencesTab {
            self.navigationItem.title = NSLocalizedString("PreferencesModulePreferencesTitle", comment: "Module Preferences")
            ip = nil
        }

        modulesListTable?.reloadData()
        if let ip = ip {
            modulesListTable?.scrollToRow(at: ip, at: .middle, animated: false)
        }

        var height: CGFloat = 0.0
        height += self.navigationController?.navigationBar.frame.size.height ?? 0.0
        height += CGFloat(moduleCount) * 44.0
        self.preferredContentSize = CGSize(width: 540.0, height: height)
    }

    @objc func dismissModuleSelector() {
        NotificationCenter.default.post(name: .toggleModuleList, object: nil)
    }

    // MARK: - Helpers

    /// Returns the SwordModule backing `indexPath` for the current listType, or nil
    /// for the dead placeholder tabs (matching the original switch fall-through).
    private func moduleForRow(at indexPath: IndexPath) -> SwordModule? {
        let manager = swordManager
        switch listType {
        case .CommentaryTab:
            let array = manager.modules(forType: PSModuleSelectorController.categoryCommentaries) ?? []
            guard indexPath.row < array.count else { return nil }
            return array[indexPath.row] as? SwordModule
        case .DictionaryTab:
            let array = manager.modules(forType: PSModuleSelectorController.categoryDictionaries) ?? []
            guard indexPath.row < array.count else { return nil }
            return array[indexPath.row] as? SwordModule
        case .PreferencesTab:
            let array = manager.listModules() ?? []
            guard indexPath.row < array.count else { return nil }
            return array[indexPath.row] as? SwordModule
        default:
            return nil
        }
    }

    // MARK: - UITableViewDataSource / UITableViewDelegate

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let manager = swordManager
        switch listType {
        case .CommentaryTab:
            return (manager.modules(forType: PSModuleSelectorController.categoryCommentaries) ?? []).count
        case .DictionaryTab:
            return (manager.modules(forType: PSModuleSelectorController.categoryDictionaries) ?? []).count
        case .PreferencesTab:
            return (manager.moduleNames() ?? []).count
        // BibleTab, DevotionalTab and DownloadsTab are dead placeholders kept only
        // so that the ShownTab enum values in globals.h do not shift (which would
        // break any persisted raw-int tab prefs). The Bible-tab module picker is
        // gone because KJV is the only Bible module; devotional and downloads were
        // removed earlier.
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PSModuleSelectorController.cellIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: PSModuleSelectorController.cellIdentifier)

        var locked = false
        if let currentModule = moduleForRow(at: indexPath) {
            cell.textLabel?.text = currentModule.name
            cell.detailTextLabel?.text = currentModule.descr()
            locked = currentModule.isLocked()
        }

        if listType != .PreferencesTab,
           let label = cell.textLabel?.text,
           moduleController.isLoaded(label) {
            cell.textLabel?.textColor = .systemBlue
            cell.detailTextLabel?.textColor = .systemBlue
        } else if locked {
            cell.textLabel?.textColor = .systemBrown
            cell.detailTextLabel?.textColor = .systemBrown
        } else {
            cell.textLabel?.textColor = .label
            cell.detailTextLabel?.textColor = .label
        }

        if listType == .PreferencesTab {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .detailDisclosureButton
        }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemBackground
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if listType == .PreferencesTab {
            self.tableView(tableView, accessoryButtonTappedForRowWith: indexPath)
            return
        }

        let newModule = self.tableView(tableView, cellForRowAt: indexPath).textLabel?.text
        if let newModule = newModule,
           (moduleController.primaryCommentary != nil && newModule == moduleController.primaryCommentary?.name) ||
           (moduleController.primaryDictionary != nil && newModule == moduleController.primaryDictionary?.name) {
            tableView.deselectRow(at: indexPath, animated: true)
            self.dismissModuleSelector()
            return // do nothing, because we selected the currently loaded module, but close the view & return to viewing the module.
        }
        // Update the module list to reflect the current module
        tableView.reloadData()
        var locked = false
        let iPad = PSResizing.iPad()
        switch listType {
        case .CommentaryTab:
            moduleController.loadPrimaryCommentary(newModule)
            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
            PSHistoryController.addHistoryItem(.CommentaryTab)
            if moduleController.primaryCommentary?.isLocked() == true {
                locked = true
            }
        case .DictionaryTab:
            moduleController.loadPrimaryDictionary(newModule)
            if iPad {
                NotificationCenter.default.post(name: .reloadDictionaryData, object: nil)
            }
            if moduleController.primaryDictionary?.isLocked() == true {
                locked = true
            }
        default:
            // Dead placeholders (bible picker moved to dropdown menu; devotional/downloads removed).
            break
        }
        if locked {
            self.tableView(tableView, accessoryButtonTappedForRowWith: indexPath)
        } else {
            self.dismissModuleSelector()
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        autoreleasepool {
            if editingStyle == .delete {
                let module = tableView.cellForRow(at: indexPath)?.textLabel?.text
                moduleController.removeModule(module)
                if listType == .DictionaryTab {
                    NotificationCenter.default.post(name: .reloadDictionaryData, object: nil)
                }
                tableView.deleteRows(at: [indexPath], with: .top)
            }
        }
    }

    @objc(tableView:accessoryButtonTappedForRowWithIndexPath:)
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let mod = swordManager.module(withName: tableView.cellForRow(at: indexPath)?.textLabel?.text)

        let preferencesViewController = PSModulePreferencesController(style: .grouped)
        preferencesViewController.listType = self.listType
        preferencesViewController.hackTableView = (listType != .PreferencesTab)
        preferencesViewController.displayPrefs(for: mod)
        var contentSize = self.preferredContentSize
        contentSize.height = 2200
        preferencesViewController.preferredContentSize = contentSize
        self.navigationController?.pushViewController(preferencesViewController, animated: true)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }
}
