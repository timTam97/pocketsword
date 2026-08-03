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
//  The bootstrap seeds Documents/ from the bundled Resources zips (KJV / MHCC /
//  Robinson / StrongsRealGreek / StrongsRealHebrew + locales.d) and runs the
//  one-off migrations (DefaultsLuceneSwept / DefaultsSimplifiedCleanupDone /
//  DefaultsModuleChoiceRetired, plus the legacy Documents/Built-in/ path cleanup
//  and the locale install). The migration-flag KEYS are load-bearing — they decide
//  whether bundled modules re-seed on launch, so any drift would re-install or
//  orphan user content.
//
//  NOTE: Documents/Built-in/ is NOT a live install location. The zips all unpack
//  into Documents/ (AppPaths.modulePath); AppPaths.builtinModulePath is referenced
//  only to delete the legacy directory left by old builds.
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
        defaults.removeObject(forKey: "bibleHistory")
        defaults.removeObject(forKey: "commentaryHistory")
        defaults.removeObject(forKey: Defaults.moduleCipherKeysKey)
        defaults.removeObject(forKey: kLocalesVersion)
        defaults.synchronize()
        // Phase 5 step 5: the loop no longer asks SWORD for each module.
        //
        // It used to call two methods per bundled module:
        //
        //  * `-[SwordDictionary removeCache]` deleted the on-disk lexicon key cache.
        //    The reader has no such cache — it reads `dict_keys` straight out of the
        //    store — and any cache left by an older build is already deleted by the
        //    `DefaultsDictKeyCaseFixed` one-shot below. Nothing left to remove.
        //  * `-[SwordModule resetPreferences]` (SwordModule.mm:215-231) removed twelve
        //    per-module `NSUserDefaults` keys. Those are ordinary defaults with no
        //    SWORD involvement, so they are cleared directly below — the same twelve
        //    keys, for the same fixed five modules, in the same order.
        for name in BundledModules.all {
            for pref in [Defaults.redLetterPreference, Defaults.strongsPreference,
                         Defaults.morphPreference, Defaults.greekAccentsPreference,
                         Defaults.hvpPreference, Defaults.hebrewCantillationPreference,
                         Defaults.scriptRefsPreference, Defaults.footnotesPreference,
                         Defaults.headingsPreference, Defaults.glossesPreference,
                         Defaults.fontSizePreference, Defaults.fontNamePreference] {
                defaults.psRemove(pref, forModule: name)
            }
        }
        defaults.synchronize()
        moduleManager.primaryBibleName = nil
        moduleManager.primaryCommentaryName = nil
        moduleManager.primaryDictionaryName = nil
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

            let fm = FileManager.default

            // One-shot un-stick migration for the retirement of module choice.
            //
            // LOAD-BEARING. A user who previously swiped a bundled module away in the
            // (now deleted) module list has a sticky Defaults*Removed flag. With no
            // removal UI they can never clear it, and the seeding below would suppress
            // that module forever. So clear all five flags once, and drop the retired
            // lexicon-role prefs so no stale "None" is left behind.
            //
            // Also deletes any "<pref>_" keys: PSModulePreferencesController derived
            // its per-module key from a nav-item title nothing had set since Apr 2026,
            // so every write it made landed in that bogus domain. Those values are
            // settings the user never saw take effect, so applying them now would be
            // wrong — they are simply removed.
            if !defaults.bool(forKey: Defaults.moduleChoiceRetired) {
                for flag in Defaults.bundledModuleRemovedFlags {
                    defaults.removeObject(forKey: flag)
                }
                for key in Defaults.retiredLexiconKeys {
                    defaults.removeObject(forKey: key)
                }
                for key in defaults.dictionaryRepresentation().keys where key.hasSuffix("_") {
                    dlog("Module-choice retirement: dropping orphaned pref key \(key)")
                    defaults.removeObject(forKey: key)
                }
                defaults.set(true, forKey: Defaults.moduleChoiceRetired)
                defaults.synchronize()
            }

            // One-shot cleanup for the global-font / Module-Maintainer-Mode
            // retirement. The font is now a single GLOBAL setting configured in
            // Preferences, so the per-module "<fontNamePreference>_<mod>" /
            // "<fontSizePreference>_<mod>" / "<fontDefaultsPreference>_<mod>" keys no
            // longer affect rendering — they would just sit in the plist looking
            // authoritative. Drop them, along with the retired Module Maintainer Mode
            // pref, for the five bundled modules.
            if !defaults.bool(forKey: Defaults.globalFontOnly) {
                for name in BundledModules.all {
                    defaults.psRemove(Defaults.fontNamePreference, forModule: name)
                    defaults.psRemove(Defaults.fontSizePreference, forModule: name)
                    defaults.psRemove(Defaults.fontDefaultsPreference, forModule: name)
                }
                defaults.removeObject(forKey: "moduleMaintainerModePreference")
                defaults.set(true, forKey: Defaults.globalFontOnly)
                defaults.synchronize()
            }

            // One-shot validation of the persisted reading position, for the
            // SWORD-removal work (SWORD_REMOVAL_PLAN.md Phase 4).
            //
            // `lastRef` is the one piece of persisted state the pure-Swift reader
            // must be able to resolve, and there are two ways an existing install
            // can be holding one it cannot:
            //
            //   1. A **non-English** user. +initLocale points SWORD's locale
            //      manager at e.g. de.conf, so `-getChapter:` was handed and
            //      persisted a localised ref like "1. Mose 1". VerseKey parsed that;
            //      PSBookOSISResolver, which only knows the English/OSIS spellings
            //      the bake captured, cannot. Today that falls back to SWORD on
            //      every page turn; after Phase 5 there is no fallback and the pane
            //      would be blank.
            //   2. A poisoned ref from the inbound sword:// URL path, which
            //      persisted whatever it decoded without validating until Phase 4
            //      step 2 — `sword://KJV/Nonsense+9:9` wrote "Nonsense 9".
            //
            // Reset to the app's own default once in either case. Deliberately
            // soft: it only fires when the ref genuinely does not resolve, so an
            // English user's position is never touched, and the flag means a user
            // who somehow has an unresolvable ref by other means keeps it rather
            // than being reset on every launch.
            if !defaults.bool(forKey: Defaults.lastRefValidated) {
                let currentRef = PSModuleController.getCurrentBibleRef() ?? ""
                if let resolver = PSBookOSISResolver.shared, resolver.resolve(ref: currentRef) == nil {
                    alog("lastRef '\(currentRef)' does not resolve against the versification table; resetting to Genesis 1")
                    defaults.set("Genesis 1", forKey: Defaults.lastRef)
                    // The verse positions belonged to the old ref, so they are
                    // meaningless against the new one.
                    defaults.set("1", forKey: Defaults.bibleVersePosition)
                    defaults.set("1", forKey: Defaults.commentaryVersePosition)
                }
                defaults.set(true, forKey: Defaults.lastRefValidated)
                defaults.synchronize()
            }

            // One-shot invalidation of the lexicon key caches, for the
            // dictionary-key casing fix (SWORD_REMOVAL_PLAN.md Phase 4 step 9).
            //
            // The Dictionary tab used to display — and re-look-up — a
            // `capitalizedString` of each key, which mangled 1,375 of Robinson's
            // 1,526 keys ("V-PAI-3S" -> "V-Pai-3S"). Both producers now return the
            // true casing, but `-[SwordDictionary readKeys]` returns EARLY on a cache
            // hit, so an existing install would keep showing the mangled keys
            // forever from `<Caches>/cache-<name>-<version>`. Delete those files once
            // so they rebuild.
            //
            // The version in the file name comes from `content_meta`
            // (PSContentStore.moduleVersion), not from a live SwordDictionary — so
            // this needs no SWORD call and survives Phase 5. As a belt-and-braces
            // measure it also globs any other `cache-*` in the same directory, which
            // catches a file left by a version this build does not know about.
            if !defaults.bool(forKey: Defaults.dictKeyCaseFixed) {
                let cacheDir = AppPaths.appSupportPath
                var deleted: [String] = []
                for name in [BundledModules.morphGreek, BundledModules.strongsGreek,
                             BundledModules.strongsHebrew] {
                    let version = PSContentStore.shared?.moduleVersion(name) ?? "0.0"
                    let path = (cacheDir as NSString).appendingPathComponent("cache-\(name)-\(version)")
                    if fm.fileExists(atPath: path) {
                        try? fm.removeItem(atPath: path)
                        deleted.append("cache-\(name)-\(version)")
                    }
                }
                // Any straggler from a version we did not predict.
                if let entries = try? fm.contentsOfDirectory(atPath: cacheDir) {
                    for entry in entries where entry.hasPrefix("cache-") {
                        let path = (cacheDir as NSString).appendingPathComponent(entry)
                        try? fm.removeItem(atPath: path)
                        deleted.append(entry)
                    }
                }
                if !deleted.isEmpty {
                    dlog("Dictionary-key casing fix: cleared key caches \(deleted)")
                }
                defaults.set(true, forKey: Defaults.dictKeyCaseFixed)
                defaults.synchronize()
            }

            // One-shot sweep of everything the SWORD era left in Documents/.
            //
            // SWORD_REMOVAL_PLAN.md Phase 5 step 9. The five module zips are gone from
            // the bundle and nothing unpacks into Documents/ any more, so the trees an
            // existing install is carrying are pure waste — about 18.7 MB of unpacked
            // modules per device. Deleting `Documents/modules` is also what removes the
            // legacy `<AbsoluteDataPath>/**/search/fts.db` indices, since step 6 moved
            // the index to `<Caches>/search/<module>.db`.
            //
            // The four directories are exactly what the SWORD layer created:
            //   mods.d     — module .conf files
            //   modules    — the module data itself (+ legacy lucene/ and search/ trees)
            //   locales.d  — the installed SWORD locale
            //   unused     — where locales.d.zip was staged before install
            // plus <Caches>/InstallMgr, the InstallMgr scratch directory.
            //
            // **PSBookmarks.plist is at the Documents/ ROOT** (PSBookmarks.swift:46),
            // outside all four, so the user's bookmarks are untouched. Verified rather
            // than assumed — it is the one piece of irreplaceable user data down there.
            // Reading history lives in NSUserDefaults, not on disk.
            //
            // The `<Caches>/cache-*` lexicon key caches are NOT swept here: the
            // DefaultsDictKeyCaseFixed one-shot above already deletes them, and doing it
            // twice would just be noise.
            if !defaults.bool(forKey: Defaults.swordRetired) {
                let docs = AppPaths.modulePath
                for dir in ["mods.d", "modules", "locales.d", "unused"] {
                    let path = (docs as NSString).appendingPathComponent(dir)
                    guard fm.fileExists(atPath: path) else { continue }
                    do {
                        try fm.removeItem(atPath: path)
                        dlog("SWORD retirement: removed Documents/\(dir)")
                    } catch {
                        // Logged, not fatal: a failure here wastes disk but breaks
                        // nothing, and the flag is still set so it is not retried on
                        // every launch.
                        alog("SWORD retirement: could not remove Documents/\(dir): \(error)")
                    }
                }
                try? fm.removeItem(atPath: AppPaths.installerPath)
                defaults.set(true, forKey: Defaults.swordRetired)
                defaults.synchronize()
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
