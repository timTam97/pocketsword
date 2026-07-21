//
//  PSPreferencesController.swift
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//
//  Swift migration (Wave 3, prefs-cluster). Faithful port of
//  PSPreferencesController.{h,mm} — the global (app-wide) preferences table.
//
//  Behaviour preserved byte-for-byte:
//   * section ordinals (DISPLAY=0, STRONGS=1, MORPH=2, DEVICE=3, MODULE=4, LANG=44)
//     and the 5-section total, exactly as the Obj-C #defines;
//   * every NSUserDefaults wire key (mirrored in AppConstants Defaults) and the
//     ROTATION_LOCK_POSITION RotationPosition enum values;
//   * every NSLocalizedString key;
//   * the NotificationResetBibleAndCommentaryView posts on each pref change;
//   * pushes the still-Obj-C PSPreferencesFontTableViewController /
//     PSPreferencesModuleSelectorTableViewController (visible to Swift via the
//     bridging header) and the Swift PSModuleSelectorController.
//

import UIKit

@objc(PSPreferencesController)
class PSPreferencesController: PSBasePreferencesController {

    // sections (verbatim ordinals from the Obj-C #defines)
    private let DISPLAY_SECTION = 0
    private let MODULE_SECTION  = 4
    private let STRONGS_SECTION = 1
    private let MORPH_SECTION   = 2
    private let LANG_SECTION    = 44
    private let DEVICE_SECTION  = 3
    private let PREF__SECTIONS  = 5 // total sections in table

    // rows in DISPLAY section
    private let FONT_SIZE_ROW = 0
    private let FONT_NAME_ROW = 1
    private let MOD_BLURB_ROW = 2
    private let DISPLAY__ROWS = 3 // total rows in section

    // rows in the MODULE section
    private let RED_LETTER_NOTE_ROW = 0
    private let MODULE__ROWS         = 1

    // rows in STRONGS section
    private let STRONGS_DISPLAY_ROW = -1
    private let STRONGS_G_ROW       = 0
    private let STRONGS_H_ROW       = 1
    private let STRONGS__ROWS       = 2 // total rows in section

    // rows in MORPH section
    private let MORPH_DISPLAY_ROW = -1
    private let MORPH_G_ROW       = 0
    private let MORPH__ROWS       = 1 // total rows in section

    // rows in LANG section
    private let LANG_GREEKACC_ROW   = 0
    private let LANG_HEBREWPTS_ROW  = 1
    private let LANG_HEBREWCANT_ROW = 2
    private let LANG__ROWS          = 3 // total rows in section

    // rows in DEVICE section
    private let INSOMNIA_ROW        = 0
    private let ROTATION_LOCK_ROW   = 1
    private let FULLSCREEN_MODE_ROW = 2
    private let FULLSCREEN_NOTE_ROW = 3
    private let MMM_ROW             = 4
    private let MMM_NOTE_ROW        = 5
    private let DEVICE__ROWS        = 6 // total rows in section

    private var fontSizeLabel: UILabel!

    private var moduleController: PSModuleController { PSModuleController.default()! }

    // RotationPosition NS_ENUM ordinals (globals.h). Mirrored as raw Int constants —
    // exactly as PSResizing.swift does — because the Clang importer renames the cases
    // (common-prefix stripping) and the persisted value is the raw NSInteger ordinal.
    private let kRotationEnabled = 0
    private let kRotationLockedInPortrait = 1
    private let kRotationLockedInLandscape = 2

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("PreferencesTitle", comment: "Preferences")
        fontSizeLabel = UILabel(frame: CGRect(x: 140.0, y: 2.0, width: 20.0, height: 42.0))
        fontSizeLabel.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        fontSizeLabel.textColor = UIColor.label
        fontSizeLabel.backgroundColor = UIColor.clear
        fontSizeLabel.text = "12"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.tableView.reloadData()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return PREF__SECTIONS
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case DISPLAY_SECTION:
            return DISPLAY__ROWS
        case MODULE_SECTION:
            return MODULE__ROWS
        case STRONGS_SECTION:
            return STRONGS__ROWS
        case MORPH_SECTION:
            return MORPH__ROWS
        case LANG_SECTION:
            return LANG__ROWS
        case DEVICE_SECTION:
            return DEVICE__ROWS
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case DISPLAY_SECTION:
            return NSLocalizedString("PreferencesDisplayPreferencesTitle", comment: "Display Preferences")
        case MODULE_SECTION:
            return NSLocalizedString("PreferencesModulePreferencesTitle", comment: "Module Preferences")
        case STRONGS_SECTION:
            return NSLocalizedString("PreferencesStrongsPreferencesTitle", comment: "Strong's Preferences")
        case MORPH_SECTION:
            return NSLocalizedString("PreferencesMorphologyPreferencesTitle", comment: "Morphology Preferences")
        case LANG_SECTION:
            return NSLocalizedString("PreferencesOriginalLanguagePreferencesTitle", comment: "Original Language")
        case DEVICE_SECTION:
            return NSLocalizedString("PreferencesDevicePreferencesTitle", comment: "Device Preferences")
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case MOD_BLURB_ROW:
                return 100
            default:
                return 45
            }
        case DEVICE_SECTION:
            switch indexPath.row {
            case FULLSCREEN_NOTE_ROW:
                return 75
            case MMM_NOTE_ROW:
                return 110
            default:
                return 45
            }
        default:
            return 45
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let CellIdentifierPlain  = "prefs-plain"
        let CellIdentifierStyled = "prefs-styled"
        let CellIdentifierFS     = "prefs-fs"
        let CellIdenfifierSub    = "prefs-subtitle"

        var cell: UITableViewCell! = nil
        var resetCell = true
        var xx: CGFloat = 0.0
        let deviceIsPad = PSResizing.iPad()
        let interfaceOrientation = PSResizing.currentInterfaceOrientation()
        if interfaceOrientation == .landscapeLeft || interfaceOrientation == .landscapeRight {
            xx = 160.0
            if deviceIsPad {
                xx += 95.0
            }
        }
        if deviceIsPad {
            xx += 420.0
        }

        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case FONT_SIZE_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierFS)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierFS)
                    var fssX: CGFloat = 170.0
                    if deviceIsPad {
                        fssX = 135.0
                    }
                    let fontSizeSlider = UISlider(frame: CGRect(x: fssX, y: 0, width: 125, height: 50))
                    fontSizeSlider.autoresizingMask = .flexibleLeftMargin
                    fontSizeSlider.minimumValue = 10.0
                    if PSResizing.iPad() {
                        fontSizeSlider.maximumValue = 36.0
                    } else {
                        fontSizeSlider.maximumValue = 20.0
                    }
                    let fontSize = UserDefaults.standard.integer(forKey: Defaults.fontSizePreference)
                    if fontSize != 0 { // defaults default to 0 if it's not previously set...
                        fontSizeSlider.value = Float(fontSize)
                    } else {
                        fontSizeSlider.value = 12.0
                        UserDefaults.standard.set(12, forKey: Defaults.fontSizePreference)
                        UserDefaults.standard.synchronize()
                    }
                    fontSizeSlider.isContinuous = true
                    fontSizeSlider.addTarget(self, action: #selector(fontSizeChanged(_:)), for: .valueChanged)
                    cell.addSubview(fontSizeSlider)
                    cell.addSubview(fontSizeLabel)
                }
                resetCell = false
            case FONT_NAME_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierStyled)
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifierStyled)
                }
            case MOD_BLURB_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdenfifierSub)
                if cell == nil {
                    cell = UITableViewCell(style: .subtitle, reuseIdentifier: CellIdenfifierSub)
                }
            default:
                break
            }
        case MODULE_SECTION:
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdenfifierSub)
            if cell == nil {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: CellIdenfifierSub)
            }
        case STRONGS_SECTION:
            switch indexPath.row {
            case STRONGS_DISPLAY_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
                }
            case STRONGS_G_ROW, STRONGS_H_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierStyled)
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifierStyled)
                }
            default:
                break
            }
        case MORPH_SECTION:
            switch indexPath.row {
            case MORPH_DISPLAY_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
                }
            case MORPH_G_ROW:
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierStyled)
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifierStyled)
                }
            default:
                break
            }
        case LANG_SECTION, DEVICE_SECTION:
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
            }
        default:
            break
        }

        cell.selectionStyle = .none
        cell.accessoryType = .none
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 12.0)
        cell.textLabel?.textColor = UIColor.label

        if resetCell {
            cell.accessoryView = nil
            for subv in cell.subviews {
                if subv.isMember(of: UISlider.self) || subv.isMember(of: UISwitch.self) {
                    subv.removeFromSuperview()
                }
            }
        }

        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case FONT_SIZE_ROW:
                break
            case FONT_NAME_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesFontTitle", comment: "Font")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
            case MOD_BLURB_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesModuleSectionNote", comment: "")
                cell.textLabel?.lineBreakMode = .byWordWrapping
                cell.textLabel?.numberOfLines = 7
                cell.textLabel?.textColor = UIColor.secondaryLabel
                cell.textLabel?.font = UIFont.systemFont(ofSize: 12.0)
                cell.detailTextLabel?.text = ""
            default:
                break
            }
        case MODULE_SECTION:
            cell.selectionStyle = .blue
            cell.accessoryType = .disclosureIndicator
            // all Bibles are available for setting prefs:
            cell.textLabel?.text = NSLocalizedString("PreferencesModulePreferencesTitle", comment: "Module Preferences")
            cell.detailTextLabel?.text = nil
        case STRONGS_SECTION:
            switch indexPath.row {
            case STRONGS_DISPLAY_ROW:
                let strongsSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayStrongs = UserDefaults.standard.bool(forKey: Defaults.strongsPreference)
                strongsSwitch.isOn = displayStrongs
                strongsSwitch.addTarget(self, action: #selector(displayStrongsChanged(_:)), for: .valueChanged)
                cell.addSubview(strongsSwitch)
                cell.textLabel?.text = NSLocalizedString("PreferencesDisplayTitle", comment: "Display")
            case STRONGS_G_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesGreekModuleTitle", comment: "Greek module")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
            case STRONGS_H_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesHebrewModuleTitle", comment: "Hebrew module")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
            default:
                break
            }
        case MORPH_SECTION:
            switch indexPath.row {
            case MORPH_DISPLAY_ROW:
                let morphSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayMorph = UserDefaults.standard.bool(forKey: Defaults.morphPreference)
                morphSwitch.isOn = displayMorph
                morphSwitch.addTarget(self, action: #selector(displayMorphChanged(_:)), for: .valueChanged)
                cell.addSubview(morphSwitch)
                cell.textLabel?.text = NSLocalizedString("PreferencesDisplayTitle", comment: "Display")
            case MORPH_G_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesGreekModuleTitle", comment: "Greek module")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
            default:
                break
            }
        case LANG_SECTION:
            switch indexPath.row {
            case LANG_GREEKACC_ROW:
                let greekAccentsSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayGreekAccents = UserDefaults.standard.bool(forKey: Defaults.greekAccentsPreference)
                greekAccentsSwitch.isOn = displayGreekAccents
                greekAccentsSwitch.addTarget(self, action: #selector(displayGreekAccentsChanged(_:)), for: .valueChanged)
                cell.addSubview(greekAccentsSwitch)
                cell.textLabel?.text = NSLocalizedString("PreferencesGreekAccentsTitle", comment: "Greek Accents")
            case LANG_HEBREWPTS_ROW:
                let hvpSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayHVP = UserDefaults.standard.bool(forKey: Defaults.hvpPreference)
                hvpSwitch.isOn = displayHVP
                hvpSwitch.addTarget(self, action: #selector(displayHVPChanged(_:)), for: .valueChanged)
                cell.addSubview(hvpSwitch)
                cell.textLabel?.text = NSLocalizedString("PreferencesHVPTitle", comment: "Hebrew Vowel Points")
                cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 10.0)
            case LANG_HEBREWCANT_ROW:
                let hebrewCantillationSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayHebrewCantillation = UserDefaults.standard.bool(forKey: Defaults.hebrewCantillationPreference)
                hebrewCantillationSwitch.isOn = displayHebrewCantillation
                hebrewCantillationSwitch.addTarget(self, action: #selector(displayHebrewCantillationChanged(_:)), for: .valueChanged)
                cell.addSubview(hebrewCantillationSwitch)
                cell.textLabel?.text = NSLocalizedString("PreferencesHebrewCantillationTitle", comment: "Hebrew Cantillation")
            default:
                break
            }
        case DEVICE_SECTION:
            switch indexPath.row {
            case INSOMNIA_ROW:
                let insomniaSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let insomniaMode = UserDefaults.standard.bool(forKey: Defaults.insomniaPreference)
                insomniaSwitch.isOn = insomniaMode
                insomniaSwitch.addTarget(self, action: #selector(insomniaModeChanged(_:)), for: .valueChanged)
                cell.accessoryView = insomniaSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesDisableAutoLockTitle", comment: "")
            case ROTATION_LOCK_ROW:
                let rotationLockSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let rotationLockPosition = UserDefaults.standard.integer(forKey: Defaults.rotationLockPosition)
                if rotationLockPosition == kRotationEnabled {
                    rotationLockSwitch.isOn = false
                } else {
                    rotationLockSwitch.isOn = true
                }
                rotationLockSwitch.addTarget(self, action: #selector(rotationLockChanged(_:)), for: .valueChanged)
                cell.accessoryView = rotationLockSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesRotationLock", comment: "Rotation Lock")
            case FULLSCREEN_MODE_ROW:
                let fullscreenModeSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let fullscreenMode = UserDefaults.standard.bool(forKey: Defaults.fullscreenModePreference)
                fullscreenModeSwitch.isOn = fullscreenMode
                fullscreenModeSwitch.addTarget(self, action: #selector(fullscreenModeChanged(_:)), for: .valueChanged)
                cell.accessoryView = fullscreenModeSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesFullscreenModeTitle", comment: "Fullscreen Mode")
                cell.textLabel?.lineBreakMode = .byWordWrapping
                cell.textLabel?.numberOfLines = 2
            case FULLSCREEN_NOTE_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesFullscreenNote", comment: "With fullscreen mode disabled, you can still switch to and from fullscreen with a 2-finger tap in the Bible and Commentary tabs.")
                cell.textLabel?.lineBreakMode = .byWordWrapping
                cell.textLabel?.numberOfLines = 4
                cell.textLabel?.textColor = UIColor.secondaryLabel
                cell.textLabel?.font = UIFont.systemFont(ofSize: 12.0)
            case MMM_ROW:
                let manualInstallSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let manualInstallEnabled = UserDefaults.standard.bool(forKey: Defaults.moduleMaintainerModePreference)
                manualInstallSwitch.isOn = manualInstallEnabled
                manualInstallSwitch.addTarget(self, action: #selector(moduleMaintainerModeChanged(_:)), for: .valueChanged)
                cell.accessoryView = manualInstallSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesModuleMaintainerModeTitle", comment: "Module Maintainer Mode")
                cell.textLabel?.lineBreakMode = .byWordWrapping
                cell.textLabel?.numberOfLines = 2
                cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 10.0)
            case MMM_NOTE_ROW:
                cell.textLabel?.text = NSLocalizedString("PreferencesModuleMaintainerModeNote", comment: "")
                cell.textLabel?.lineBreakMode = .byWordWrapping
                cell.textLabel?.numberOfLines = 7
                cell.textLabel?.font = UIFont.systemFont(ofSize: 12.0)
                cell.textLabel?.textColor = UIColor.secondaryLabel
            default:
                break
            }
        default:
            break
        }

        // some of the cells can be changed from elsewhere, so we now need to set the text for some cell labels:
        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case FONT_SIZE_ROW:
                let fontSize = UserDefaults.standard.integer(forKey: Defaults.fontSizePreference)
                cell.textLabel?.text = String(format: "%@:", NSLocalizedString("PreferencesFontSizeTitle", comment: "Font Size"))
                fontSizeLabel.text = String(format: "%ld", fontSize)
            case FONT_NAME_ROW:
                var font = UserDefaults.standard.string(forKey: Defaults.fontNamePreference)
                if font == nil {
                    font = AppConstants.defaultFontName
                }
                cell.detailTextLabel?.text = font
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            default:
                break
            }
        case STRONGS_SECTION:
            switch indexPath.row {
            case STRONGS_G_ROW:
                var module = UserDefaults.standard.string(forKey: Defaults.strongsGreekModule)
                if module == nil {
                    module = NSLocalizedString("None", comment: "None")
                }
                cell.detailTextLabel?.text = module
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            case STRONGS_H_ROW:
                var module = UserDefaults.standard.string(forKey: Defaults.strongsHebrewModule)
                if module == nil {
                    module = NSLocalizedString("None", comment: "None")
                }
                cell.detailTextLabel?.text = module
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            default:
                break
            }
        case MORPH_SECTION:
            switch indexPath.row {
            case MORPH_G_ROW:
                var module = UserDefaults.standard.string(forKey: Defaults.morphGreekModule)
                if module == nil {
                    module = NSLocalizedString("None", comment: "None")
                }
                cell.detailTextLabel?.text = module
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            default:
                break
            }
        default:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case FONT_NAME_ROW:
                let fontTableViewController = PSPreferencesFontTableViewController(style: .grouped)
                fontTableViewController.moduleName = nil
                fontTableViewController.preferencesController = self
                self.navigationController?.pushViewController(fontTableViewController, animated: true)
            default:
                break
            }
        case STRONGS_SECTION:
            switch indexPath.row {
            case STRONGS_G_ROW:
                // strongs greek
                let moduleSelectorTableViewController = PSPreferencesModuleSelectorTableViewController(style: .grouped)
                moduleSelectorTableViewController.preferencesController = self
                moduleSelectorTableViewController.setTableType(.StrongsGreek)
                self.navigationController?.pushViewController(moduleSelectorTableViewController, animated: true)
            case STRONGS_H_ROW:
                // strongs hebrew
                let moduleSelectorTableViewController = PSPreferencesModuleSelectorTableViewController(style: .grouped)
                moduleSelectorTableViewController.preferencesController = self
                moduleSelectorTableViewController.setTableType(.StrongsHebrew)
                self.navigationController?.pushViewController(moduleSelectorTableViewController, animated: true)
            default:
                break
            }
        case MORPH_SECTION:
            switch indexPath.row {
            case MORPH_G_ROW:
                // greek morphology
                let moduleSelectorTableViewController = PSPreferencesModuleSelectorTableViewController(style: .grouped)
                moduleSelectorTableViewController.preferencesController = self
                moduleSelectorTableViewController.setTableType(.MorphGreek)
                self.navigationController?.pushViewController(moduleSelectorTableViewController, animated: true)
            default:
                break
            }
        case MODULE_SECTION:
            let moduleSelectorViewController = PSModuleSelectorController(nibName: nil, bundle: nil)
            moduleSelectorViewController.listType = .PreferencesTab
            self.navigationController?.pushViewController(moduleSelectorViewController, animated: true)
        default:
            break
        }
    }

    override func hideFontTableView() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func rotationLockChanged(_ sender: UISwitch) {
        let interfaceOrientation = PSResizing.currentInterfaceOrientation()

        if sender.isOn {
            let locked = (interfaceOrientation == .landscapeLeft || interfaceOrientation == .landscapeRight)
                ? kRotationLockedInLandscape
                : kRotationLockedInPortrait
            UserDefaults.standard.setValue(NSNumber(value: Int32(locked)), forKey: Defaults.rotationLockPosition)
        } else {
            UserDefaults.standard.setValue(NSNumber(value: Int32(kRotationEnabled)), forKey: Defaults.rotationLockPosition)
        }
        UserDefaults.standard.synchronize()
    }

    @objc func fullscreenModeChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.fullscreenModePreference)
        UserDefaults.standard.synchronize()
    }

    @objc func displayStrongsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.strongsPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func displayMorphChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.morphPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func displayGreekAccentsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.greekAccentsPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func displayHVPChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.hvpPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func displayHebrewCantillationChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.hebrewCantillationPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func morphGreekModuleChanged(_ newModule: String) {
        UserDefaults.standard.set(newModule, forKey: Defaults.morphGreekModule)
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
    }

    @objc func strongsGreekModuleChanged(_ newModule: String) {
        UserDefaults.standard.set(newModule, forKey: Defaults.strongsGreekModule)
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
    }

    @objc func strongsHebrewModuleChanged(_ newModule: String) {
        UserDefaults.standard.set(newModule, forKey: Defaults.strongsHebrewModule)
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
    }

    @objc func xrefChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.scriptRefsPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func footnotesChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.footnotesPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func headingsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.headingsPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func fontSizeChanged(_ sender: UISlider) {
        let f = Int(sender.value)
        UserDefaults.standard.set(f, forKey: Defaults.fontSizePreference)
        UserDefaults.standard.synchronize()
        fontSizeLabel.text = String(format: "%ld", f)
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func redLetterChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.redLetterPreference)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func vplChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.vplPreference)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    override func fontNameChanged(_ newFont: String) {
        UserDefaults.standard.set(newFont, forKey: Defaults.fontNamePreference)
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
        NotificationCenter.default.post(name: .resetBibleAndCommentaryView, object: nil)
    }

    @objc func insomniaModeChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.insomniaPreference)
        UserDefaults.standard.synchronize()
        UIApplication.shared.isIdleTimerDisabled = n
    }

    @objc func moduleMaintainerModeChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.set(n, forKey: Defaults.moduleMaintainerModePreference)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .moduleMaintainerModeChanged, object: nil)
    }
}
