//
//  PSLanguageCode.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). The original 8,116-line PSLanguageCode.m carried a
//  static ~8,040-row [code, name] lookup table built in +initLookupTable. That
//  table is now an externalized bundled resource (Resources/LanguageCodes.json)
//  loaded lazily on first lookup. Only the ~40 lines of lookup + -Cyrl/-Latn
//  script-suffix logic live here. Selectors match the original byte-for-byte so
//  the Obj-C++ callers (PocketSwordSceneDelegate.mm, SwordModule.mm,
//  PocketSwordAppDelegate.mm, PSModuleType.mm) bind unchanged.
//
//  Originally created by Nic Carter on 22/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import Foundation

@objc(PSLanguageCode)
final class PSLanguageCode: NSObject {

    @objc var code: String?
    @objc var descr: String?

    // Lazily-loaded lookup table: ordered [code, name] rows mirroring the
    // original static array. Linear scan preserves the source's first-match
    // semantics (e.g. duplicate codes resolve to the earliest entry).
    private static var lookupTable: [[String]]?

    @objc init(code aCode: String?) {
        super.init()
        self.code = aCode
        let loc = Locale.current
        if let aCode = aCode,
           let localeName = (loc as NSLocale).displayName(forKey: .identifier, value: aCode) {
            self.descr = localeName
        } else {
            self.descr = nil
        }
        if self.descr == nil {
            self.descr = PSLanguageCode.lookupLanguageCode(aCode)
        }
        //DLog(@"found a lang %@: %@", lang, displayNameString);
    }

    @objc class func lookupLanguageCode(_ aCode: String?) -> String? {
        guard let aCode = aCode else { return nil }

        if lookupTable == nil {
            initLookupTable()
        }
        let table = lookupTable ?? []

        let end = table.count
        var i = 0
        while i < end {
            let row = table[i]
            if row.count >= 2 && aCode == row[0] {
                return row[1]
            }
            i += 1
        }

        if aCode.count > 3 {
            //NSLog(@"code > 3 : %@", aCode);
            let prefix = (aCode as NSString).substring(to: 3)
            let codeName = lookupLanguageCode(prefix)
            var cRange = (aCode as NSString).range(of: "-Cyrl")
            if cRange.location != NSNotFound && cRange.location != 0 {
                //This is a (Cyrillic) script
                return String(format: "%@ (Cyrillic)", codeName ?? "")
            }
            cRange = (aCode as NSString).range(of: "-Latn")
            if cRange.location != NSNotFound && cRange.location != 0 {
                //This is a (Latin) script
                return String(format: "%@ (Latin)", codeName ?? "")
            }
            return codeName
        }
        return aCode
    }

    @objc class func initLookupTable() {
        if lookupTable != nil { return }
        guard let url = Bundle.main.url(forResource: "LanguageCodes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String]] else {
            alog("PSLanguageCode: failed to load LanguageCodes.json from bundle")
            lookupTable = []
            return
        }
        lookupTable = parsed
    }

    //This should be called by the app delegate
    @objc class func doneWithLookupTable() {
        lookupTable = nil
    }
}
