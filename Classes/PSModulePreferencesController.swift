//
//  PSModulePreferencesController.swift
//  PocketSword
//
//  Created by Nic Carter on 2/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//
//  Swift migration (Wave 3, prefs-cluster). Faithful port of
//  PSModulePreferencesController.{h,mm} — the PER-MODULE preferences table built
//  dynamically from a module's features.
//
//  Behaviour preserved byte-for-byte:
//   * the dynamic section/row indexing scheme (sections and rows are assigned
//     incrementally in displayPrefsForModule: depending on which features the
//     module advertises, then read back in the data-source methods);
//   * EVERY per-module pref read/write uses the "<pref>_<mod>" composite key via
//     the UserDefaults.ps* helpers in AppConstants — byte-identical to the Obj-C
//     Get/SetBoolPrefForMod / Get/SetIntegerPrefForMod / GetStringPrefForMod /
//     SetObjectPrefForMod / RemovePrefForMod macros (R1: persisted format guard);
//   * SWMOD_FEATURE_* / SWMOD_CONF_FEATURE_* are @"literal" NSString #defines in
//     SwordManager.h that Swift cannot import — mirrored inline as the exact same
//     string literals (gotcha (3) from prior steps);
//   * the redisplay notifications keyed on listType, including the dead
//     Devotional/Downloads placeholders falling through to no-op.
//
//  Instantiates the still-Obj-C PSPreferencesFontTableViewController (visible to
//  Swift via the bridging header). PSModulePreferencesController + its base +
//  PSPreferencesController migrate together as one atomic PR (§2A Rule 3).
//

import UIKit

@objc(PSModulePreferencesController)
class PSModulePreferencesController: PSBasePreferencesController {

    // Mirror of the SWMOD_FEATURE_* / SWMOD_CONF_FEATURE_* NSString #defines from
    // SwordManager.h (Swift can't import @"literal" macros). Byte-identical strings.
    private let SWMOD_FEATURE_HEADINGS       = "Headings"
    private let SWMOD_FEATURE_FOOTNOTES      = "Footnotes"
    private let SWMOD_FEATURE_SCRIPTREF      = "Scripref"
    private let SWMOD_FEATURE_REDLETTERWORDS = "RedLetterWords"
    private let SWMOD_FEATURE_STRONGS        = "Strongs"
    private let SWMOD_CONF_FEATURE_STRONGS   = "StrongsNumbers"
    private let SWMOD_FEATURE_MORPH          = "Morph"
    private let SWMOD_FEATURE_GREEKACCENTS   = "GreekAccents"
    private let SWMOD_FEATURE_HEBREWPOINTS   = "HebrewPoints"
    private let SWMOD_FEATURE_CANTILLATION   = "Cantillation"

    @objc var hackTableView: Bool = false
    @objc var listType: ShownTab = .BibleTab

    private var fontSizeLabel: UILabel!

    // sections
    private var DisplaySection = -1, ModuleSection = -1, StrongsSection = -1, MorphSection = -1, LangSection = -1
    private var Sections = 0 // total sections

    // rows in DISPLAY section
    private var FontDefaultsRow = -1, FontSizeRow = -1, FontNameRow = -1
    private var DisplayRows = 0 // total rows in section

    // rows in the MODULE section
    private var VPLRow = -1, XrefRow = -1, FootnotesRow = -1, HeadingsRow = -1, RedLetterRow = -1
    private var ModuleRows = 0 // total rows in section

    // rows in STRONGS section
    private var StrongsToggleRow = -1, StrongsGreekRow = -1, StrongsHebrewRow = -1
    private var StrongsRows = 0 // total rows in section

    // rows in MORPH section
    private var MorphToggleRow = -1, MorphGreekRow = -1
    private var MorphRows = 0 // total rows in section

    // rows in LANG section
    private var LangGreekAccentsRow = -1, LangHebrewPointsRow = -1, LangHebrewCantillationRow = -1
    private var LangRows = 0 // total rows in section

    private var moduleController: PSModuleController { PSModuleController.default()! }

    /// `self.tabBarController.navigationItem.title` — the per-module key the Obj-C
    /// original threads through every pref read/write. Force-unwrap mirrors the
    /// original `self.tabBarController.navigationItem.title` direct messaging.
    private var moduleKey: String { self.tabBarController?.navigationItem.title ?? "" }

    override func viewDidLoad() {
        super.viewDidLoad()
        fontSizeLabel = UILabel(frame: CGRect(x: 140.0, y: 2.0, width: 20.0, height: 42.0))
        fontSizeLabel.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        fontSizeLabel.textColor = UIColor.label
        fontSizeLabel.text = "12"
        fontSizeLabel.backgroundColor = UIColor.clear
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hackTableView {
            var topLength: CGFloat = 0
            topLength = self.view.safeAreaInsets.top
            if topLength == 0.0 || topLength == 20.0 {
                topLength += self.navigationController?.navigationBar.frame.size.height ?? 0
            }
            self.tableView.contentSize = PSResizing.mainScreenBounds().size
            self.tableView.contentInset = UIEdgeInsets(top: topLength, left: 0.0, bottom: 0.0, right: 0.0)
        }
    }

    @objc(displayPrefsForModule:)
    func displayPrefs(for swordModule: SwordModule!) {
        // set title to the module name
        let tbi = UITabBarItem(
            title: String(format: "%@ %@", swordModule.name, NSLocalizedString("TabBarTitlePreferences", comment: "")),
            image: UIImage(named: "gear-24.png"),
            tag: 101)
        self.tabBarItem = tbi

        // init sections
        DisplaySection = -1; ModuleSection = -1; StrongsSection = -1; MorphSection = -1; LangSection = -1
        Sections = 0

        // init row totals
        DisplayRows = 0; ModuleRows = 0; StrongsRows = 0; MorphRows = 0; LangRows = 0

        // init row indices
        FontDefaultsRow = -1; FontSizeRow = -1; FontNameRow = -1
        VPLRow = -1; XrefRow = -1; FootnotesRow = -1; HeadingsRow = -1; RedLetterRow = -1
        StrongsToggleRow = -1; StrongsGreekRow = -1; StrongsHebrewRow = -1
        MorphToggleRow = -1; MorphGreekRow = -1
        LangGreekAccentsRow = -1; LangHebrewPointsRow = -1; LangHebrewCantillationRow = -1

        // Display section:
        DisplaySection = Sections; Sections += 1
        FontDefaultsRow = DisplayRows; DisplayRows += 1
        let fontDefaults = UserDefaults.standard.psBool(Defaults.fontDefaultsPreference, forModule: swordModule.name)
        if fontDefaults {
            FontSizeRow = DisplayRows; DisplayRows += 1
            FontNameRow = DisplayRows; DisplayRows += 1
        }

        // Module section:
        // always show the VPL option for Bibles
        if swordModule.type == bible {
            VPLRow = ModuleRows; ModuleRows += 1
        }
        if swordModule.hasFeature(SWMOD_FEATURE_HEADINGS) {
            HeadingsRow = ModuleRows; ModuleRows += 1
        }
        if swordModule.hasFeature(SWMOD_FEATURE_FOOTNOTES) {
            FootnotesRow = ModuleRows; ModuleRows += 1
        }
        if swordModule.hasFeature(SWMOD_FEATURE_SCRIPTREF) {
            XrefRow = ModuleRows; ModuleRows += 1
        }
        if swordModule.hasFeature(SWMOD_FEATURE_REDLETTERWORDS) {
            RedLetterRow = ModuleRows; ModuleRows += 1
        }
        if ModuleRows > 0 {
            ModuleSection = Sections; Sections += 1
        }

        // Strongs section:
        if swordModule.hasFeature(SWMOD_FEATURE_STRONGS) || swordModule.hasFeature(SWMOD_CONF_FEATURE_STRONGS) {
            StrongsToggleRow = StrongsRows; StrongsRows += 1
            StrongsSection = Sections; Sections += 1
        }

        // Morph section:
        if swordModule.hasFeature(SWMOD_FEATURE_MORPH) {
            MorphToggleRow = MorphRows; MorphRows += 1
            MorphSection = Sections; Sections += 1
        }

        // Lang section:
        if swordModule.hasFeature(SWMOD_FEATURE_GREEKACCENTS) {
            LangGreekAccentsRow = LangRows; LangRows += 1
        }
        if swordModule.hasFeature(SWMOD_FEATURE_HEBREWPOINTS) {
            LangHebrewPointsRow = LangRows; LangRows += 1
        }
        if swordModule.hasFeature(SWMOD_FEATURE_CANTILLATION) {
            LangHebrewCantillationRow = LangRows; LangRows += 1
        }
        if LangRows > 0 {
            LangSection = Sections; Sections += 1
        }
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
        return Sections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == DisplaySection {
            return DisplayRows
        } else if section == ModuleSection {
            return ModuleRows
        } else if section == StrongsSection {
            return StrongsRows
        } else if section == MorphSection {
            return MorphRows
        } else if section == LangSection {
            return LangRows
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == DisplaySection {
            return NSLocalizedString("PreferencesDisplayPreferencesTitle", comment: "Display Preferences")
        } else if section == ModuleSection {
            return NSLocalizedString("PreferencesModulePreferencesTitle", comment: "Module Preferences")
        } else if section == StrongsSection {
            return NSLocalizedString("PreferencesStrongsPreferencesTitle", comment: "Strong's Preferences")
        } else if section == MorphSection {
            return NSLocalizedString("PreferencesMorphologyPreferencesTitle", comment: "Morphology Preferences")
        } else if section == LangSection {
            return NSLocalizedString("PreferencesOriginalLanguagePreferencesTitle", comment: "Original Language")
        } else {
            return ""
        }
    }

    // yes, this method is kinda out of control.  *sigh*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let CellIdentifierPlain  = "prefs-plain"
        let CellIdentifierStyled = "prefs-styled"
        let CellIdentifierFS     = "prefs-fs"

        var cell: UITableViewCell! = nil
        let resetCell = true

        if indexPath.section == DisplaySection {
            if indexPath.row == FontDefaultsRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
                }
            } else if indexPath.row == FontSizeRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierFS)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierFS)
                    cell.addSubview(fontSizeLabel)
                }
            } else if indexPath.row == FontNameRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierStyled)
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifierStyled)
                }
            }
        } else if indexPath.section == ModuleSection {
            if indexPath.row == VPLRow || indexPath.row == XrefRow || indexPath.row == FootnotesRow || indexPath.row == HeadingsRow || indexPath.row == RedLetterRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
                }
            }
        } else if indexPath.section == StrongsSection {
            if indexPath.row == StrongsToggleRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
                }
            } else if indexPath.row == StrongsGreekRow || indexPath.row == StrongsHebrewRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierStyled)
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifierStyled)
                }
            }
        } else if indexPath.section == MorphSection {
            if indexPath.row == MorphToggleRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
                }
            } else if indexPath.row == MorphGreekRow {
                cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierStyled)
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: CellIdentifierStyled)
                }
            }
        } else if indexPath.section == LangSection {
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifierPlain)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: CellIdentifierPlain)
            }
        }

        cell.selectionStyle = .none
        cell.accessoryType = .none
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 12.0)
        cell.textLabel?.textColor = UIColor.label

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
            xx += 220.0 // was 420.0 before we moved this to the popover...
        }

        if resetCell {
            for subv in cell.subviews {
                if subv.isMember(of: UISlider.self) || subv.isMember(of: UISwitch.self) {
                    subv.removeFromSuperview()
                }
            }
            cell.accessoryView = nil
        }

        if indexPath.section == DisplaySection {

            if indexPath.row == FontDefaultsRow {
                let fontDefaultsSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let fontDefaults = UserDefaults.standard.psBool(Defaults.fontDefaultsPreference, forModule: moduleKey)
                fontDefaultsSwitch.isOn = fontDefaults
                fontDefaultsSwitch.addTarget(self, action: #selector(fontDefaultsChanged(_:)), for: .valueChanged)
                cell.accessoryView = fontDefaultsSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesFontDefaultTitle", comment: "Verse Per Line")
            } else if indexPath.row == FontSizeRow {
                let fontSizeSlider = UISlider(frame: CGRect(x: xx + 170, y: 0, width: 125, height: 50))
                fontSizeSlider.minimumValue = 10.0
                if PSResizing.iPad() {
                    fontSizeSlider.maximumValue = 36.0
                } else {
                    fontSizeSlider.maximumValue = 20.0
                }
                var fontSize = UserDefaults.standard.psInteger(Defaults.fontSizePreference, forModule: moduleKey)
                if fontSize != 0 { // defaults default to 0 if it's not previously set...
                    fontSizeSlider.value = Float(fontSize)
                } else {
                    fontSize = UserDefaults.standard.integer(forKey: Defaults.fontSizePreference)
                    if fontSize != 0 {
                        fontSizeSlider.value = Float(fontSize)
                        UserDefaults.standard.psSet(fontSize, forPref: Defaults.fontSizePreference, module: moduleKey)
                    } else {
                        fontSizeSlider.value = 12.0
                        UserDefaults.standard.psSet(12, forPref: Defaults.fontSizePreference, module: moduleKey)
                        UserDefaults.standard.set(12, forKey: Defaults.fontSizePreference)
                        UserDefaults.standard.synchronize()
                    }
                }
                fontSizeSlider.isContinuous = true
                fontSizeSlider.addTarget(self, action: #selector(fontSizeChanged(_:)), for: .valueChanged)
                cell.addSubview(fontSizeSlider)

                cell.textLabel?.text = String(format: "%@:", NSLocalizedString("PreferencesFontSizeTitle", comment: "Font Size"))
                // Cast to "int" to account for 64bit "long" version of NSInteger.
                fontSizeLabel.text = String(format: "%d", Int32(fontSize))
            } else if indexPath.row == FontNameRow {
                cell.textLabel?.text = NSLocalizedString("PreferencesFontTitle", comment: "Font")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
                var font = UserDefaults.standard.psString(Defaults.fontNamePreference, forModule: moduleKey)
                if font == nil {
                    font = AppConstants.defaultFontName
                }
                cell.detailTextLabel?.text = font
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            }

        } else if indexPath.section == ModuleSection {

            if indexPath.row == VPLRow {
                let vplSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let vpl = UserDefaults.standard.psBool(Defaults.vplPreference, forModule: moduleKey)
                vplSwitch.isOn = vpl
                vplSwitch.addTarget(self, action: #selector(vplChanged(_:)), for: .valueChanged)
                cell.accessoryView = vplSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesVPLTitle", comment: "Verse Per Line")
            } else if indexPath.row == XrefRow {
                let xrefSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let xrefMode = UserDefaults.standard.psBool(Defaults.scriptRefsPreference, forModule: moduleKey)
                xrefSwitch.isOn = xrefMode
                xrefSwitch.addTarget(self, action: #selector(xrefChanged(_:)), for: .valueChanged)
                cell.accessoryView = xrefSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesCrossReferencesTitle", comment: "Cross-references")
            } else if indexPath.row == FootnotesRow {
                let footnotesSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let footnotesMode = UserDefaults.standard.psBool(Defaults.footnotesPreference, forModule: moduleKey)
                footnotesSwitch.isOn = footnotesMode
                footnotesSwitch.addTarget(self, action: #selector(footnotesChanged(_:)), for: .valueChanged)
                cell.accessoryView = footnotesSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesFootnotesTitle", comment: "Footnotes")
            } else if indexPath.row == HeadingsRow {
                let headingsSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let headingsMode = UserDefaults.standard.psBool(Defaults.headingsPreference, forModule: moduleKey)
                headingsSwitch.isOn = headingsMode
                headingsSwitch.addTarget(self, action: #selector(headingsChanged(_:)), for: .valueChanged)
                cell.accessoryView = headingsSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesHeadingsTitle", comment: "Headings")
            } else if indexPath.row == RedLetterRow {
                let redLetterModeSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let redLetterMode = UserDefaults.standard.psBool(Defaults.redLetterPreference, forModule: moduleKey)
                redLetterModeSwitch.isOn = redLetterMode
                redLetterModeSwitch.addTarget(self, action: #selector(redLetterChanged(_:)), for: .valueChanged)
                cell.accessoryView = redLetterModeSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesRedLetterTitle", comment: "Red Letter")
            }

        } else if indexPath.section == StrongsSection {

            if indexPath.row == StrongsToggleRow {
                let strongsSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayStrongs = UserDefaults.standard.psBool(Defaults.strongsPreference, forModule: moduleKey)
                strongsSwitch.isOn = displayStrongs
                strongsSwitch.addTarget(self, action: #selector(displayStrongsChanged(_:)), for: .valueChanged)
                cell.accessoryView = strongsSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesDisplayTitle", comment: "Display")
            } else if indexPath.row == StrongsGreekRow {
                cell.textLabel?.text = NSLocalizedString("PreferencesGreekModuleTitle", comment: "Greek module")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
                var module = UserDefaults.standard.psString(Defaults.strongsGreekModule, forModule: moduleKey)
                if module == nil {
                    module = NSLocalizedString("None", comment: "None")
                }
                cell.detailTextLabel?.text = module
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            } else if indexPath.row == StrongsHebrewRow {
                cell.textLabel?.text = NSLocalizedString("PreferencesHebrewModuleTitle", comment: "Hebrew module")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
                var module = UserDefaults.standard.psString(Defaults.strongsHebrewModule, forModule: moduleKey)
                if module == nil {
                    module = NSLocalizedString("None", comment: "None")
                }
                cell.detailTextLabel?.text = module
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            }

        } else if indexPath.section == MorphSection {

            if indexPath.row == MorphToggleRow {
                let morphSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayMorph = UserDefaults.standard.psBool(Defaults.morphPreference, forModule: moduleKey)
                morphSwitch.isOn = displayMorph
                morphSwitch.addTarget(self, action: #selector(displayMorphChanged(_:)), for: .valueChanged)
                cell.accessoryView = morphSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesDisplayTitle", comment: "Display")
            } else if indexPath.row == MorphGreekRow {
                cell.textLabel?.text = NSLocalizedString("PreferencesGreekModuleTitle", comment: "Greek module")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .blue
                var module = UserDefaults.standard.psString(Defaults.morphGreekModule, forModule: moduleKey)
                if module == nil {
                    module = NSLocalizedString("None", comment: "None")
                }
                cell.detailTextLabel?.text = module
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.0)
            }

        } else if indexPath.section == LangSection {

            if indexPath.row == LangGreekAccentsRow {
                let greekAccentsSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayGreekAccents = UserDefaults.standard.psBool(Defaults.greekAccentsPreference, forModule: moduleKey)
                greekAccentsSwitch.isOn = displayGreekAccents
                greekAccentsSwitch.addTarget(self, action: #selector(displayGreekAccentsChanged(_:)), for: .valueChanged)
                cell.accessoryView = greekAccentsSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesGreekAccentsTitle", comment: "Greek Accents")
            } else if indexPath.row == LangHebrewPointsRow {
                let hvpSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayHVP = UserDefaults.standard.psBool(Defaults.hvpPreference, forModule: moduleKey)
                hvpSwitch.isOn = displayHVP
                hvpSwitch.addTarget(self, action: #selector(displayHVPChanged(_:)), for: .valueChanged)
                cell.accessoryView = hvpSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesHVPTitle", comment: "Hebrew Vowel Points")
                cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 10.0)
            } else if indexPath.row == LangHebrewCantillationRow {
                let hebrewCantillationSwitch = UISwitch(frame: CGRect(x: xx + 200, y: 10, width: 0, height: 0))
                let displayHebrewCantillation = UserDefaults.standard.psBool(Defaults.hebrewCantillationPreference, forModule: moduleKey)
                hebrewCantillationSwitch.isOn = displayHebrewCantillation
                hebrewCantillationSwitch.addTarget(self, action: #selector(displayHebrewCantillationChanged(_:)), for: .valueChanged)
                cell.accessoryView = hebrewCantillationSwitch
                cell.textLabel?.text = NSLocalizedString("PreferencesHebrewCantillationTitle", comment: "Hebrew Cantillation")
            }

        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == DisplaySection && indexPath.row == FontNameRow {

            let fontTableViewController = PSPreferencesFontTableViewController(style: .grouped)
            fontTableViewController.moduleName = self.tabBarController?.navigationItem.title
            fontTableViewController.preferencesController = self
            self.navigationController?.pushViewController(fontTableViewController, animated: true)

        } else if indexPath.section == StrongsSection {

            if indexPath.row == StrongsGreekRow {
                // strongs greek
            } else if indexPath.row == StrongsHebrewRow {
                // strongs hebrew
            }

        } else if indexPath.section == MorphSection && indexPath.row == MorphGreekRow {

            // greek morphology

        }
    }

    override func hideFontTableView() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func fontDefaultsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.fontDefaultsPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        if n {
            // we now need to add the additional rows
            FontSizeRow = DisplayRows; DisplayRows += 1
            FontNameRow = DisplayRows; DisplayRows += 1
            let rowOne = IndexPath(row: FontSizeRow, section: DisplaySection)
            let rowTwo = IndexPath(row: FontNameRow, section: DisplaySection)
            let indexPaths = [rowOne, rowTwo]
            self.tableView.insertRows(at: indexPaths, with: .top)
        } else {
            let rowOne = IndexPath(row: FontSizeRow, section: DisplaySection)
            let rowTwo = IndexPath(row: FontNameRow, section: DisplaySection)
            let indexPaths = [rowOne, rowTwo]
            DisplayRows -= 2
            FontSizeRow = -1
            FontNameRow = -1
            UserDefaults.standard.psRemove(Defaults.fontSizePreference, forModule: moduleKey)
            UserDefaults.standard.psRemove(Defaults.fontNamePreference, forModule: moduleKey)
            self.tableView.deleteRows(at: indexPaths, with: .top)
            redisplayFromButtonPress()
        }
    }

    @objc func displayStrongsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.strongsPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func displayMorphChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.morphPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func displayGreekAccentsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.greekAccentsPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func displayHVPChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.hvpPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func displayHebrewCantillationChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.hebrewCantillationPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
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
        UserDefaults.standard.psSet(n, forPref: Defaults.scriptRefsPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func footnotesChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.footnotesPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func headingsChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.headingsPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func fontSizeChanged(_ sender: UISlider) {
        let f = Int(sender.value)
        UserDefaults.standard.psSet(f, forPref: Defaults.fontSizePreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        fontSizeLabel.text = String(format: "%d", Int32(f))
        redisplayFromButtonPress()
    }

    @objc func redLetterChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.redLetterPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        moduleController.setPreferences()
        redisplayFromButtonPress()
    }

    @objc func vplChanged(_ sender: UISwitch) {
        let n = sender.isOn
        UserDefaults.standard.psSet(n, forPref: Defaults.vplPreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        redisplayFromButtonPress()
    }

    override func fontNameChanged(_ newFont: String) {
        UserDefaults.standard.psSet(newFont as Any?, forPref: Defaults.fontNamePreference, module: moduleKey)
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
        redisplayFromButtonPress()
    }

    @objc func redisplayFromButtonPress() {
        switch listType {
        case .BibleTab:
            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
        case .CommentaryTab:
            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
        default:
            // DictionaryTab / DevotionalTab / DownloadsTab / PreferencesTab: no-op
            break
        }
    }
}
