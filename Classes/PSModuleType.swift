//
//  PSModuleType.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). Groups a flat list of SwordModule objects by
//  language for the module selector. Public API matches the original
//  PSModuleType.{h,mm} byte-for-byte so the Obj-C++ caller (SwordManager.mm)
//  binds unchanged: it allocates a PSModuleType per module-type, KVC-sorts the
//  resulting array on the `moduleType` key, and reads `modules` /
//  `moduleLanguages` / `moduleList` from the selector UI. References to
//  SwordModule resolve as Swift types via the bridging header; PSLanguageCode
//  is a sibling Swift type (same module, migrated alongside in Wave 2).
//
//  Originally created by Nic Carter on 7/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import Foundation

@objc(PSModuleType)
final class PSModuleType: NSObject {

    @objc var moduleType: String?
    // `modules` is a list-of-lists: one inner array of SwordModule per language,
    // index-aligned with `moduleLanguages`. Recomputed by setModules(_:).
    // Backing store for `modules`. Kept non-@objc so Swift does NOT synthesize a
    // `setModules:` setter selector — that would collide with the explicit
    // -setModules: method below (which reproduces the original readonly-property
    // + custom-setter shape from PSModuleType.h).
    private var _modules: [Any] = []
    @objc var modules: [Any] { _modules }
    @objc var moduleLanguages: [Any] = []
    @objc var moduleList: [Any] = []

    @objc init(modules mods: [Any], withModuleType modType: String?) {
        super.init()
        setModules(mods)
        moduleType = modType
    }

    private func getAvailableLanguages(_ mods: [Any]) -> [Any] {
        let ret = NSMutableArray(capacity: 10)
        var seen = Set<String>()

        for case let mod as SwordModule in mods {
            let lang = mod.lang() ?? ""
            if !seen.contains(lang) {
                let langCode = PSLanguageCode(code: mod.lang())
                ret.add(langCode)
                seen.insert(lang)
            }
        }

        // sort by the localized description, preserving the original
        // NSSortDescriptor(key:"descr") behaviour
        let sortDescriptor = NSSortDescriptor(key: "descr", ascending: true)
        ret.sort(using: [sortDescriptor])

        return ret as [AnyObject]
    }

    private func getModulesByLanguage(_ lang: String?, fromModuleArray mods: [Any]) -> [Any] {
        let ret = NSMutableArray(capacity: 10)
        for case let mod as SwordModule in mods {
            if mod.lang() == lang {
                ret.add(mod)
            }
        }
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        ret.sort(using: [sortDescriptor])
        return ret as [AnyObject]
    }

    @objc func setModules(_ mods: [Any]) {
        var modList: [Any] = []
        // we accept a list of mods and need to create a list of mods per language.
        moduleLanguages = getAvailableLanguages(mods)
        for case let lang as PSLanguageCode in moduleLanguages {
            modList.append(getModulesByLanguage(lang.code, fromModuleArray: mods))
        }
        _modules = modList
        moduleList = mods
    }
}
