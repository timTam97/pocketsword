//
//  PSLaunchViewController.swift
//  PocketSword
//
//  Swift port (Wave 4, hub) of the former PSLaunchViewController.{h,mm}. This is
//  the first-run bootstrap view controller: it is installed as the window's root
//  VC while the app initialises, runs the SWORD bootstrap on a background thread
//  (-startInitializingPocketSword), and hands control back to the scene delegate
//  via the PSLaunchDelegate handshake (-finishedInitializingPocketSword:) once
//  init finishes — at which point the scene delegate swaps the root VC to the
//  tab bar.
//
//  The bootstrap seeds Documents/Built-in/ from the bundled Resources zips (KJV /
//  MHCC / Robinson / StrongsRealGreek / StrongsRealHebrew + locales.d) and runs
//  the one-off migrations (DefaultsLuceneSwept / DefaultsSimplifiedCleanupDone,
//  plus the legacy built-in-module-path move and the locale install). The
//  migration-flag KEYS and the seeding gates are preserved BYTE-FOR-BYTE from the
//  original .mm — they decide whether bundled modules re-seed on launch, so any
//  drift would re-install or orphan user content.
//
//  ZERO sword:: — every SWORD touch goes through the Foundation @objc facades
//  (PSModuleController / SwordManager / SwordModule / SwordDictionary), exactly as
//  the original .mm did.
//
//  Created by Nic Carter on 27/01/11.
//  Copyright 2002-2013 CrossWire Bible Society. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation version 2.
//

import UIKit

// Local migration-flag wire strings, preserved verbatim from the original .mm
// (#define LOCALES_VERSION / STRONGS_REAL_GREEK_VERSION / KJV_VERSION). These are
// persisted NSUserDefaults keys — do NOT change the right-hand values.
private let kLocalesVersion        = "loadedSWORDLocales-130708"
private let kStrongsRealGreekVersion = "loadedBundledStrongsRealGreek-v1.5-150704"
private let kKJVVersion            = "loadedKJV-v2.9"

// SWMOD_CATEGORY_DICTIONARIES is an @"literal" #define in SwordManager.h that
// Swift cannot see; mirror its value verbatim (matches PSModuleController.swift /
// PSModuleSelectorController.swift).
private let kCategoryDictionaries  = "Lexicons / Dictionaries"

// PSLaunchDelegate — the bootstrap-finished handshake the scene delegate conforms
// to. Kept @objc (the still-Obj-C PocketSwordSceneDelegate conforms to it) and
// owned here, mirroring the original PSLaunchViewController.h declaration.
@objc(PSLaunchDelegate)
protocol PSLaunchDelegate: NSObjectProtocol {
    func finishedInitializingPocketSword(_ launchViewController: Any)
}

@objc(PSLaunchViewController)
final class PSLaunchViewController: UIViewController {

    @objc weak var delegate: PSLaunchDelegate?

    // MARK: - View

    // Build the view hierarchy programmatically (no nib) — a grey background
    // matching the launch image plus a centred spinner.
    override func loadView() {
        let aiFrame: CGRect
        if PSResizing.iPad() {
            let uiOrientation = PSResizing.currentInterfaceOrientation()
            if uiOrientation == .landscapeLeft || uiOrientation == .landscapeRight {
                aiFrame = CGRect(x: 494, y: 370, width: 37, height: 37)
            } else {
                aiFrame = CGRect(x: 366, y: 499, width: 37, height: 37)
            }
        } else {
            let screenRect = PSResizing.mainScreenBounds()
            aiFrame = CGRect(x: screenRect.size.width / 2.0 - (37.0 / 2.0),
                             y: screenRect.size.height / 2.0 - (37.0 / 2.0),
                             width: 37, height: 37)
        }

        let base = UIView(frame: PSResizing.mainScreenBounds())
        // the same grey as the launch image bg
        base.backgroundColor = UIColor(hue: 202.0 / 360.0, saturation: 0.11, brightness: 0.4, alpha: 1.0)
        let activityInd = UIActivityIndicatorView(style: .large)
        activityInd.hidesWhenStopped = false
        base.addSubview(activityInd)
        activityInd.frame = aiFrame
        activityInd.startAnimating()
        self.view = base
    }

    // MARK: - Reset

    @objc class func resetPreferences() {
        let defaults = UserDefaults.standard
        guard let moduleManager = PSModuleController.default() else { return }
        dlog("\nResetting PocketSword")
        defaults.removeObject(forKey: "reset_PocketSword")
        defaults.removeObject(forKey: Defaults.lastRef)
        defaults.removeObject(forKey: Defaults.lastBible)
        defaults.removeObject(forKey: Defaults.lastCommentary)
        defaults.removeObject(forKey: Defaults.lastDictionary)
        defaults.removeObject(forKey: Defaults.fontNamePreference)
        defaults.removeObject(forKey: Defaults.fontSizePreference)
        defaults.removeObject(forKey: Defaults.vplPreference)
        defaults.removeObject(forKey: Defaults.redLetterPreference)
        defaults.removeObject(forKey: Defaults.insomniaPreference)
        defaults.removeObject(forKey: Defaults.moduleMaintainerModePreference)
        defaults.removeObject(forKey: "bibleHistory")
        defaults.removeObject(forKey: "commentaryHistory")
        defaults.removeObject(forKey: Defaults.moduleCipherKeysKey)
        defaults.removeObject(forKey: kLocalesVersion)
        defaults.removeObject(forKey: Defaults.kjvRemoved)
        defaults.removeObject(forKey: Defaults.mhccRemoved)
        defaults.removeObject(forKey: Defaults.strongsRealGreekRemoved)
        defaults.removeObject(forKey: Defaults.strongsRealHebrewRemoved)
        defaults.removeObject(forKey: Defaults.robinsonRemoved)
        defaults.synchronize()
        if let dicts = moduleManager.swordManager?.modules(forType: kCategoryDictionaries) as? [SwordDictionary] {
            for dict in dicts {
                dict.removeCache()
            }
        }
        if let moduleList = moduleManager.swordManager?.listModules() as? [SwordModule] {
            for mod in moduleList {
                mod.resetPreferences()
            }
        }
        moduleManager.primaryBible = nil
        moduleManager.primaryCommentary = nil
        moduleManager.primaryDictionary = nil
        NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
    }

    // MARK: - Bootstrap (runs on a background thread)

    @objc func startInitializingPocketSword() {
        autoreleasepool {
            guard let moduleManager = PSModuleController.default() else { return }
            let defaults = UserDefaults.standard

            // testing unlocking mechanism:
            //defaults.removeObject(forKey: Defaults.moduleCipherKeysKey)
            //defaults.synchronize()

            if defaults.bool(forKey: "reset_PocketSword") {
                PSLaunchViewController.resetPreferences()
            }

            var kjv = defaults.bool(forKey: kKJVVersion)
            let loadedLocales = defaults.bool(forKey: kLocalesVersion)
            var strongsAndMorph = defaults.bool(forKey: "loadedBundledStrongsAndMorph")
            var strongsRealGreek = defaults.bool(forKey: kStrongsRealGreekVersion)
            let removeModulePrefs = defaults.bool(forKey: "removedModulePreferences")

            let fm = FileManager.default

            if fm.fileExists(atPath: AppPaths.builtinModulePath) {
                // getting rid of the built-in module path, as it seems to cause broken
                let kjvConf = (AppPaths.builtinModulePath as NSString).appendingPathComponent("mods.d/kjv.conf")
                if fm.fileExists(atPath: kjvConf) {
                    let kjvExtension = "modules/texts/ztext/kjv"
                    let luceneExtension = (kjvExtension as NSString).appendingPathComponent("lucene")
                    let kjvLucene = (AppPaths.builtinModulePath as NSString).appendingPathComponent(luceneExtension)
                    if fm.fileExists(atPath: kjvLucene) {
                        // to be nice, let's move their kjv lucene index across for them :P
                        let kjvNewLucene = (AppPaths.modulePath as NSString).appendingPathComponent(luceneExtension)
                        try? fm.createDirectory(atPath: (AppPaths.modulePath as NSString).appendingPathComponent(kjvExtension),
                                                withIntermediateDirectories: true, attributes: nil)
                        try? fm.moveItem(atPath: kjvLucene, toPath: kjvNewLucene)
                    }
                }

                // delete this old folder
                try? fm.removeItem(atPath: AppPaths.builtinModulePath)
                moduleManager.reload()
                kjv = false
                strongsAndMorph = false
                strongsRealGreek = false
            }

            if !kjv {
                defaults.synchronize()
                if let kjvModule = moduleManager.swordManager?.module(withName: "KJV") {
                    // if it's already installed, remove the search index because it will now be out of date
                    kjvModule.deleteSearchIndex()
                }
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "KJV", ofType: "zip"),
                                                    ofType: bible, removeZip: false, internalModule: true)
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "MHCC", ofType: "zip"),
                                                    ofType: commentary, removeZip: false, internalModule: true)
                defaults.set(true, forKey: kKJVVersion)
            }

            if !strongsAndMorph {
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "strongsrealhebrew", ofType: "zip"),
                                                    ofType: dictionary, removeZip: false, internalModule: true)
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "Robinson", ofType: "zip"),
                                                    ofType: dictionary, removeZip: false, internalModule: true)
                defaults.set("Robinson", forKey: Defaults.morphGreekModule)
                defaults.set("StrongsRealHebrew", forKey: Defaults.strongsHebrewModule)
                defaults.set(true, forKey: "loadedBundledStrongsAndMorph")
                defaults.synchronize()
            }

            if !strongsRealGreek {
                // remove existing module, if it exists:
                if moduleManager.swordManager?.isModuleInstalled("StrongsRealGreek") == true {
                    dlog("\nRemoving existing StrongsRealGreek module & updating...")
                    moduleManager.removeModule("StrongsRealGreek")
                } else {
                    dlog("\nInstalling StrongsRealGreek for the first time...")
                }
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "strongsrealgreek", ofType: "zip"),
                                                    ofType: dictionary, removeZip: false, internalModule: true)
                defaults.set(true, forKey: kStrongsRealGreekVersion)
                let curSGM = defaults.string(forKey: Defaults.strongsGreekModule)
                if curSGM == nil || curSGM == NSLocalizedString("None", comment: "None") {
                    defaults.set("StrongsRealGreek", forKey: Defaults.strongsGreekModule)
                    defaults.synchronize()
                }
            }

            // Test if we need to reinstall the built-in modules?
            let kjvModule = moduleManager.swordManager?.isModuleInstalled("KJV") ?? false
            let kjvModuleRemoved = defaults.bool(forKey: Defaults.kjvRemoved)

            let mhccModule = moduleManager.swordManager?.isModuleInstalled("MHCC") ?? false
            let mhccModuleRemoved = defaults.bool(forKey: Defaults.mhccRemoved)

            let robinsonModule = moduleManager.swordManager?.isModuleInstalled("Robinson") ?? false
            let robinsonModuleRemoved = defaults.bool(forKey: Defaults.robinsonRemoved)

            let strongsrealhebrewModule = moduleManager.swordManager?.isModuleInstalled("StrongsRealHebrew") ?? false
            let strongsrealhebrewModuleRemoved = defaults.bool(forKey: Defaults.strongsRealHebrewRemoved)

            let strongsrealgreekModule = moduleManager.swordManager?.isModuleInstalled("StrongsRealGreek") ?? false
            let strongsrealgreekModuleRemoved = defaults.bool(forKey: Defaults.strongsRealGreekRemoved)

            if !kjvModule && !kjvModuleRemoved {
                // reinstall the kjv module!
                dlog("reinstalling KJV")
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "KJV", ofType: "zip"),
                                                    ofType: bible, removeZip: false, internalModule: true)
            }
            if !mhccModule && !mhccModuleRemoved {
                // reinstall the mhcc module!
                dlog("reinstalling MHCC")
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "MHCC", ofType: "zip"),
                                                    ofType: commentary, removeZip: false, internalModule: true)
            }
            if !robinsonModule && !robinsonModuleRemoved {
                dlog("reinstalling Robinson")
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "Robinson", ofType: "zip"),
                                                    ofType: dictionary, removeZip: false, internalModule: true)
            }
            if !strongsrealgreekModule && !strongsrealgreekModuleRemoved {
                dlog("reinstalling StrongsRealGreek")
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "strongsrealgreek", ofType: "zip"),
                                                    ofType: dictionary, removeZip: false, internalModule: true)
            }
            if !strongsrealhebrewModule && !strongsrealhebrewModuleRemoved {
                dlog("reinstalling StrongsRealHebrew")
                moduleManager.installModulesFromZip(Bundle.main.path(forResource: "strongsrealhebrew", ofType: "zip"),
                                                    ofType: dictionary, removeZip: false, internalModule: true)
            }

            if !removeModulePrefs {
                if let moduleList = moduleManager.swordManager?.listModules() as? [SwordModule] {
                    for mod in moduleList {
                        mod.resetPreferences()
                    }
                }
                defaults.set(true, forKey: "removedModulePreferences")
                defaults.synchronize()
            }

            // One-time wipe of modules that the user previously downloaded from
            // CrossWire (or sideloaded). The simplified build ships the five
            // bundled modules and nothing else; any extras become orphaned.
            if !defaults.bool(forKey: Defaults.simplifiedCleanupDone) {
                let bundled: Set<String> = ["KJV", "MHCC", "Robinson",
                                            "StrongsRealHebrew",
                                            "StrongsRealGreek"]
                let installed = (moduleManager.swordManager?.listModules() as? [SwordModule]) ?? []
                // snapshot names up front because removeModule: reloads the manager
                var toRemove: [String] = []
                for mod in installed {
                    if let name = mod.name, !bundled.contains(name) {
                        toRemove.append(name)
                    }
                }
                for name in toRemove {
                    dlog("Simplified-cleanup: removing non-bundled module \(name)")
                    moduleManager.removeModule(name)
                }
                // Drop any primary* prefs that pointed at a removed module.
                if let lastBible = defaults.string(forKey: Defaults.lastBible), !bundled.contains(lastBible) {
                    defaults.removeObject(forKey: Defaults.lastBible)
                }
                if let lastCom = defaults.string(forKey: Defaults.lastCommentary), !bundled.contains(lastCom) {
                    defaults.removeObject(forKey: Defaults.lastCommentary)
                }
                if let lastDict = defaults.string(forKey: Defaults.lastDictionary), !bundled.contains(lastDict) {
                    defaults.removeObject(forKey: Defaults.lastDictionary)
                }
                // Stale devotional key from the removed feature.
                defaults.removeObject(forKey: "lastDevotional")
                // Remove the old InstallMgr scratch dir if it still exists from
                // pre-simplification builds.
                try? fm.removeItem(atPath: AppPaths.installerPath)
                defaults.set(true, forKey: Defaults.simplifiedCleanupDone)
                defaults.synchronize()
            }

            // One-time sweep of the legacy CLucene index directories that were
            // written by pre-FTS5 versions. New indices live at
            // <AbsoluteDataPath>/search/fts.db, so the old lucene/ dirs are
            // orphaned and just waste disk. Guarded so we don't re-scan on
            // every launch.
            if !defaults.bool(forKey: Defaults.luceneSwept) {
                let modsForSweep = (moduleManager.swordManager?.listModules() as? [SwordModule]) ?? []
                for mod in modsForSweep {
                    guard let dataPath = mod.configEntry(forKey: "AbsoluteDataPath"), !dataPath.isEmpty else { continue }
                    let legacy = (dataPath as NSString).appendingPathComponent("lucene")
                    if fm.fileExists(atPath: legacy) {
                        try? fm.removeItem(atPath: legacy)
                    }
                }
                defaults.set(true, forKey: Defaults.luceneSwept)
                defaults.synchronize()
            }

            let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let swLocales = ((docPath as NSString).appendingPathComponent("unused") as NSString).appendingPathComponent("locales.d")
            // "install" the l10n strings into SWORD for the current locale.
            let localePath = (docPath as NSString).appendingPathComponent("locales.d")

            // if there's an update for the locales or if iOS has removed our locales:
            if !loadedLocales || !fm.fileExists(atPath: (docPath as NSString).appendingPathComponent("unused")) {
                if let localesZIP = Bundle.main.path(forResource: "locales.d", ofType: "zip") {
                    dlog("\n\n\(localesZIP)\n\n")
                    try? fm.removeItem(atPath: swLocales)   // delete it if it already exists
                    try? fm.removeItem(atPath: localePath)  // delete the currently installed ones, too.

                    // unzip the archive
                    SSZipArchive.unzipFile(atPath: localesZIP, toDestination: swLocales)

                    defaults.set(true, forKey: kLocalesVersion)
                    defaults.synchronize()

                    // make sure we're not backing up this folder, now that we're installing stuff in here...
                    PSResizing.addSkipBackupAttribute(toItemAtPath: (docPath as NSString).appendingPathComponent("unused"))
                }
            }

            let availLocales = NSLocale.preferredLanguages                                   // the iPhone locale
            let currentlyInstalledStrings = (try? fm.contentsOfDirectory(atPath: localePath)) // currently installed SWORD locale
            var lang: String? = nil   // language we're going to use this time around
            var haveLocale = false
            var alreadyInstalled = false

            if availLocales.first == "en" {
                // do nothing if it's English.
                lang = "en"
                alreadyInstalled = true
                haveLocale = true
            } else if let installedStrings = currentlyInstalledStrings,
                      let first = availLocales.first,
                      installedStrings.contains("\(first)-utf8.conf") {
                // do nothing if it's the non-English locale we used last time.
                alreadyInstalled = true
                haveLocale = true
                lang = availLocales.first
            }

            let availStrings = (try? fm.contentsOfDirectory(atPath: swLocales)) ?? []
            var iter = availLocales.makeIterator()
            while !haveLocale, var loc = iter.next() {

                // replace "-" with "_" as SWORD and iOS use different ways of signifying locales...
                loc = loc.replacingOccurrences(of: "-", with: "_")

                if loc == "en" {
                    lang = loc
                    alreadyInstalled = true
                    break // default, do nothing.
                }

                if let installedStrings = currentlyInstalledStrings,
                   installedStrings.contains("\(loc)-utf8.conf") {
                    // we do this because it could be the non-primary iPhone locale...
                    alreadyInstalled = true
                    lang = loc
                    break
                }
                // check if this locale is available in SWORD
                for swLoc in availStrings {
                    if swLoc.hasPrefix(loc) {
                        haveLocale = true
                        lang = swLoc
                        break
                    }
                }
                if !haveLocale {
                    // perhaps we have something else we can fall back on?
                    if let dashRange = loc.range(of: "_") {
                        loc = String(loc[loc.startIndex..<dashRange.lowerBound])
                        // check if this modified locale is available in SWORD
                        for swLoc in availStrings {
                            if swLoc.hasPrefix(loc) {
                                haveLocale = true
                                lang = swLoc
                                break
                            }
                        }
                    }
                }
            }
            if !alreadyInstalled {
                try? fm.removeItem(atPath: localePath)
                try? fm.createDirectory(atPath: localePath, withIntermediateDirectories: false, attributes: nil)
                if haveLocale, let lang = lang {
                    let srcLocale = (swLocales as NSString).appendingPathComponent(lang)
                    let dstLocale = (localePath as NSString).appendingPathComponent(lang)
                    try? fm.copyItem(atPath: srcLocale, toPath: dstLocale)
                    SwordManager.initLocale()
                    moduleManager.reload()
                }
            }

            if defaults.bool(forKey: Defaults.insomniaPreference) {
                UIApplication.shared.isIdleTimerDisabled = true
            }

            try? fm.removeItem(atPath: AppPaths.mmmPath) // delete our normal tmp folder...

            if let delegate = delegate {
                DispatchQueue.main.async {
                    delegate.finishedInitializingPocketSword(self)
                }
            }
        }
    }

    // MARK: - Rotation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if !PSResizing.iPad() {
            return .portrait
        }
        return PSResizing.supportedInterfaceOrientations()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        dlog("\nwe are about to rotate the launch view controller...")
    }
}
