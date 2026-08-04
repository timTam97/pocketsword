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
//   * every NSUserDefaults wire key (mirrored in AppConstants Defaults) and the
//     ROTATION_LOCK_POSITION RotationPosition enum values;
//   * every NSLocalizedString key;
//   * the NotificationResetBibleAndCommentaryView posts on each pref change;
//   * pushes PSPreferencesFontTableViewController for the global font.
//
//  The former STRONGS / MORPH / MODULE sections are gone: the three lexicon roles
//  are hardcoded (see BundledModules) and the per-module display prefs now live in
//  the per-tab `▾` settings menus (PSModuleViewController.rebuildSettingsMenu).
//  LANG_SECTION stays deliberately out of range (44 >= PREF__SECTIONS), as it has
//  been since before the Swift port — the Greek/Hebrew script options are inert
//  with an English-only reading text.
//

import UIKit

private final class PSFontSizePreferenceCell: UITableViewCell {

    let slider = UISlider()

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let minimumSizeLabel = UILabel()
    private let maximumSizeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14,
            leading: 16,
            bottom: 16,
            trailing: 16
        )

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .secondaryLabel
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        minimumSizeLabel.text = "A"
        minimumSizeLabel.font = .preferredFont(forTextStyle: .caption2)
        minimumSizeLabel.adjustsFontForContentSizeCategory = true
        minimumSizeLabel.textColor = .secondaryLabel

        maximumSizeLabel.text = "A"
        maximumSizeLabel.font = .preferredFont(forTextStyle: .title3)
        maximumSizeLabel.adjustsFontForContentSizeCategory = true
        maximumSizeLabel.textColor = .secondaryLabel

        slider.isContinuous = true

        let heading = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        heading.axis = .horizontal
        heading.alignment = .firstBaseline
        heading.spacing = 12

        let control = UIStackView(arrangedSubviews: [minimumSizeLabel, slider, maximumSizeLabel])
        control.axis = .horizontal
        control.alignment = .center
        control.spacing = 12

        let stack = UIStackView(arrangedSubviews: [heading, control])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, value: Int, maximumValue: Float) {
        titleLabel.text = title
        slider.minimumValue = 10
        slider.maximumValue = maximumValue
        slider.value = Float(value)
        slider.accessibilityLabel = title
        updateValue(value)
    }

    func updateValue(_ value: Int) {
        valueLabel.text = String(value)
        slider.accessibilityValue = String(value)
    }
}

@objc(PSPreferencesController)
class PSPreferencesController: PSBasePreferencesController {

    // sections
    private let DISPLAY_SECTION = 0
    private let DEVICE_SECTION  = 1
    private let LANG_SECTION    = 44 // deliberately out of range: unreachable
    private let PREF__SECTIONS  = 2  // total sections in table

    // rows in DISPLAY section
    private let FONT_SIZE_ROW = 0
    private let FONT_NAME_ROW = 1
    private let DISPLAY__ROWS = 2 // total rows in section

    // rows in LANG section
    private let LANG_GREEKACC_ROW   = 0
    private let LANG_HEBREWPTS_ROW  = 1
    private let LANG_HEBREWCANT_ROW = 2
    private let LANG__ROWS          = 3 // total rows in section

    // rows in DEVICE section
    private let INSOMNIA_ROW        = 0
    private let ROTATION_LOCK_ROW   = 1
    private let FULLSCREEN_MODE_ROW = 2
    private let DEVICE__ROWS        = 3 // total rows in section

    private static let fontSizeCellIdentifier = "prefs-font-size"
    private static let fontNameCellIdentifier = "prefs-font-name"
    private static let switchCellIdentifier = "prefs-switch"

    private var moduleController: PSModuleController { PSModuleController.default()! }

    // RotationPosition NS_ENUM ordinals (globals.h). Mirrored as raw Int constants —
    // exactly as PSResizing.swift does — because the Clang importer renames the cases
    // (common-prefix stripping) and the persisted value is the raw NSInteger ordinal.
    private let kRotationEnabled = 0
    private let kRotationLockedInPortrait = 1
    private let kRotationLockedInLandscape = 2

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("PreferencesTitle", comment: "Preferences")
        navigationItem.largeTitleDisplayMode = .never

        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.register(
            PSFontSizePreferenceCell.self,
            forCellReuseIdentifier: Self.fontSizeCellIdentifier
        )
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
        case LANG_SECTION:
            return NSLocalizedString("PreferencesOriginalLanguagePreferencesTitle", comment: "Original Language")
        case DEVICE_SECTION:
            return NSLocalizedString("PreferencesDevicePreferencesTitle", comment: "Device Preferences")
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == DEVICE_SECTION {
            return NSLocalizedString(
                "PreferencesFullscreenNote",
                comment: "How to enter and leave full screen manually"
            )
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case FONT_SIZE_ROW:
                guard let cell = tableView.dequeueReusableCell(
                    withIdentifier: Self.fontSizeCellIdentifier,
                    for: indexPath
                ) as? PSFontSizePreferenceCell else {
                    return UITableViewCell()
                }
                let fontSize = preferredFontSize()
                cell.configure(
                    title: NSLocalizedString("PreferencesFontSizeTitle", comment: "Text Size"),
                    value: fontSize,
                    maximumValue: PSResizing.iPad() ? 36 : 20
                )
                cell.slider.removeTarget(nil, action: nil, for: .valueChanged)
                cell.slider.addTarget(
                    self,
                    action: #selector(fontSizeChanged(_:)),
                    for: .valueChanged
                )
                return cell
            case FONT_NAME_ROW:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: Self.fontNameCellIdentifier
                ) ?? UITableViewCell(style: .value1, reuseIdentifier: Self.fontNameCellIdentifier)
                configureTextCell(cell)
                cell.textLabel?.text = NSLocalizedString("PreferencesFontTitle", comment: "Font")
                cell.detailTextLabel?.text =
                    UserDefaults.standard.string(forKey: Defaults.fontNamePreference)
                    ?? AppConstants.defaultFontName
                cell.detailTextLabel?.font = .preferredFont(forTextStyle: .subheadline)
                cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
                cell.detailTextLabel?.textColor = .secondaryLabel
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                return cell
            default:
                return UITableViewCell()
            }
        case DEVICE_SECTION:
            switch indexPath.row {
            case INSOMNIA_ROW:
                return switchCell(
                    tableView,
                    title: NSLocalizedString("PreferencesDisableAutoLockTitle", comment: "Keep Screen Awake"),
                    isOn: UserDefaults.standard.bool(forKey: Defaults.insomniaPreference),
                    action: #selector(insomniaModeChanged(_:))
                )
            case ROTATION_LOCK_ROW:
                let rotationLockPosition = UserDefaults.standard.integer(forKey: Defaults.rotationLockPosition)
                return switchCell(
                    tableView,
                    title: NSLocalizedString("PreferencesRotationLock", comment: "Lock Rotation"),
                    isOn: rotationLockPosition != kRotationEnabled,
                    action: #selector(rotationLockChanged(_:))
                )
            case FULLSCREEN_MODE_ROW:
                return switchCell(
                    tableView,
                    title: NSLocalizedString(
                        "PreferencesFullscreenModeTitle",
                        comment: "Automatic Full Screen"
                    ),
                    isOn: UserDefaults.standard.bool(forKey: Defaults.fullscreenModePreference),
                    action: #selector(fullscreenModeChanged(_:))
                )
            default:
                return UITableViewCell()
            }
        default:
            return UITableViewCell()
        }
    }

    private func preferredFontSize() -> Int {
        let savedValue = UserDefaults.standard.integer(forKey: Defaults.fontSizePreference)
        guard savedValue == 0 else {
            return savedValue
        }

        let defaultValue = 12
        UserDefaults.standard.set(defaultValue, forKey: Defaults.fontSizePreference)
        return defaultValue
    }

    private func configureTextCell(_ cell: UITableViewCell) {
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.textColor = .label
        cell.textLabel?.numberOfLines = 0
    }

    private func switchCell(
        _ tableView: UITableView,
        title: String,
        isOn: Bool,
        action: Selector
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.switchCellIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: Self.switchCellIdentifier)
        configureTextCell(cell)
        cell.selectionStyle = .none
        cell.textLabel?.text = title

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.accessibilityLabel = title
        toggle.addTarget(self, action: action, for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch indexPath.section {
        case DISPLAY_SECTION:
            switch indexPath.row {
            case FONT_NAME_ROW:
                let fontTableViewController = PSPreferencesFontTableViewController(style: .insetGrouped)
                fontTableViewController.preferencesController = self
                self.navigationController?.pushViewController(fontTableViewController, animated: true)
            default:
                break
            }
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

    // The NINE per-module display handlers that were here are GONE
    // (SWORD_REMOVAL_PLAN.md Phase 5 step 7), along with the
    // `moduleController.setPreferences()` each of them called.
    //
    // `setPreferences` read the per-module prefs and pushed them into SWORD as global
    // options; with no SWORD there is nothing to push, and nothing read the result.
    // The handlers went with it, and the split is worth recording because it is not
    // what it looks like:
    //
    //  * SIX were already dead code — displayStrongsChanged, displayMorphChanged,
    //    xrefChanged, footnotesChanged, headingsChanged, redLetterChanged. No
    //    `addTarget` referenced any of them (verified: zero `#selector` uses), and
    //    `cellForRowAt` never builds a row that would install one.
    //  * THREE were wired — displayGreekAccentsChanged, displayHVPChanged,
    //    displayHebrewCantillationChanged — but only from rows in
    //    `LANG_SECTION = 44`, which is deliberately >= `PREF__SECTIONS = 2` and so
    //    is never asked for by `numberOfSections`. Unreachable in practice.
    //
    // The LIVE per-module toggles are the per-tab `▾` menu in
    // PSModuleViewController.rebuildSettingsMenu, which writes the same
    // NSUserDefaults keys directly and is unaffected. Its `pushesToSword:` parameter
    // is dropped in this commit for the same reason.









    @objc func fontSizeChanged(_ sender: UISlider) {
        let f = Int(sender.value)
        UserDefaults.standard.set(f, forKey: Defaults.fontSizePreference)
        UserDefaults.standard.synchronize()
        if let cell = tableView.cellForRow(
            at: IndexPath(row: FONT_SIZE_ROW, section: DISPLAY_SECTION)
        ) as? PSFontSizePreferenceCell {
            cell.updateValue(f)
        }
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

}
