//
//  PSPreferencesModuleSelectorTableViewController.swift
//  PocketSword
//
//  The Preferences "Strong's / Morphology lexicon" picker: a single-section
//  UITableView listing the installed modules that advertise a given SWORD
//  feature (GreekDef / HebrewDef / GreekParse), plus a leading "None" row, with
//  a checkmark on the currently selected module. Tapping a row reports the new
//  module name back to the owning PSPreferencesController via the selector
//  captured in -setTableType: (strongsGreekModuleChanged: / strongsHebrew
//  ModuleChanged: / morphGreekModuleChanged:), then pops.
//
//  Migrated from PSPreferencesModuleSelectorTableViewController.{h,mm} (Swift
//  migration Wave 3). The former .mm contained ZERO sword:: usage — it lists
//  modules purely through the clean Foundation-only SwordManager / SwordModule
//  facades and drives the now-Swift PSPreferencesController held as a weak
//  back-pointer. PSPreferencesController.swift instantiates this VC and calls
//  setTableType(_:) directly (same module); no Obj-C importer remains.
//
//  ModuleFeatureRequired (Strong's Greek / Strong's Hebrew / Morph Greek / Morph
//  Hebrew) was a bare `typedef enum` in the old header; it is now an @objc enum
//  so the still-Obj-C++ TUs that consume the generated PocketSword-Swift.h keep
//  seeing it. MorphHebrew is carried for parity with the original enum but, as in
//  the .mm, has no live viewWillAppear branch (the feature was never wired up).
//

import UIKit

@objc enum ModuleFeatureRequired: Int {
    case StrongsGreek = 0
    case StrongsHebrew
    case MorphGreek
    case MorphHebrew
}

@objc(PSPreferencesModuleSelectorTableViewController)
final class PSPreferencesModuleSelectorTableViewController: UITableViewController {

    // SWORD feature keys consumed by -[SwordManager modulesForFeature:]. These
    // are bare wire strings (no globals.h #define) — keep byte-for-byte.
    private static let featureGreekDef = "GreekDef"
    private static let featureHebrewDef = "HebrewDef"
    private static let featureGreekParse = "GreekParse"

    private static let cellIdentifier = "Cell"

    @objc weak var preferencesController: PSPreferencesController?

    @objc var moduleList: [SwordModule]?
    @objc var currentModule: String?

    private var tableType: ModuleFeatureRequired = .StrongsGreek
    private var moduleChanged: Selector?

    @objc func setTableType(_ feature: ModuleFeatureRequired) {
        tableType = feature
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let manager = PSModuleController.default()?.swordManager
        let defaults = UserDefaults.standard

        switch tableType {
        case .StrongsGreek:
            moduleList = manager?.modules(forFeature: Self.featureGreekDef) as? [SwordModule]
            currentModule = defaults.string(forKey: Defaults.strongsGreekModule)
            if currentModule == nil {
                currentModule = NSLocalizedString("None", comment: "None")
            }
            navigationItem.title = NSLocalizedString("PreferencesGreekModuleTitle", comment: "Greek module")
            moduleChanged = #selector(PSPreferencesController.strongsGreekModuleChanged(_:))
            tableView.reloadData()
        case .StrongsHebrew:
            moduleList = manager?.modules(forFeature: Self.featureHebrewDef) as? [SwordModule]
            currentModule = defaults.string(forKey: Defaults.strongsHebrewModule)
            if currentModule == nil {
                currentModule = NSLocalizedString("None", comment: "None")
            }
            navigationItem.title = NSLocalizedString("PreferencesHebrewModuleTitle", comment: "Hebrew module")
            moduleChanged = #selector(PSPreferencesController.strongsHebrewModuleChanged(_:))
            tableView.reloadData()
        case .MorphGreek:
            moduleList = manager?.modules(forFeature: Self.featureGreekParse) as? [SwordModule]
            currentModule = defaults.string(forKey: Defaults.morphGreekModule)
            if currentModule == nil {
                currentModule = NSLocalizedString("None", comment: "None")
            }
            navigationItem.title = NSLocalizedString("PreferencesGreekModuleTitle", comment: "Greek module")
            moduleChanged = #selector(PSPreferencesController.morphGreekModuleChanged(_:))
            tableView.reloadData()
        case .MorphHebrew:
            break
        }
    }

    // MARK: - Table view methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let moduleList = moduleList {
            return moduleList.count + 1
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch tableType {
        case .StrongsGreek:
            return NSLocalizedString("PreferencesGreekStrongsLexiconTitle", comment: "Greek Strong's lexicon")
        case .StrongsHebrew:
            return NSLocalizedString("PreferencesHebrewStrongsLexiconTitle", comment: "Hebrew Strong's lexicon")
        case .MorphGreek:
            return NSLocalizedString("PreferencesGreekMorphLexiconTitle", comment: "Greek Morphological lexicon")
        case .MorphHebrew:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: Self.cellIdentifier)

        if indexPath.row == 0 {
            cell.textLabel?.text = NSLocalizedString("None", comment: "None")
            cell.detailTextLabel?.text = ""
        } else if let module = moduleList?[indexPath.row - 1] {
            cell.textLabel?.text = module.name
            cell.detailTextLabel?.text = module.descr()
        }

        if cell.textLabel?.text == currentModule {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mod: String?
        if indexPath.row == 0 {
            mod = NSLocalizedString("None", comment: "None")
        } else {
            mod = moduleList?[indexPath.row - 1].name
        }

        if let moduleChanged = moduleChanged {
            _ = preferencesController?.perform(moduleChanged, with: mod)
        }
        navigationController?.popViewController(animated: true)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }
}
