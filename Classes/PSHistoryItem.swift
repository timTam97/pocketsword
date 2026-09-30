//
//  PSHistoryItem.swift
//  PocketSword
//
//  Created by Nic Carter on 22/01/13.
//  Copyright (c) 2013 CrossWire Bible Society. All rights reserved.
//
//  PERSISTED value type: `array` / `init(array:)` define the positional layout
//  stored under PSHistoryName == "bibleHistory" in BOTH UserDefaults and
//  NSUbiquitousKeyValueStore, locked byte-for-byte by PersistedFormatTests.
//  The read/write asymmetries are deliberate — do NOT "fix" them:
//
//    WRITE order (idx 0..3):
//      [bibleReference, "0" (scroll HARDCODED — the live scrollAmount is
//       intentionally NOT persisted), moduleName, dateAdded (NSDate)]
//
//    READ tolerances:
//      count >= 2 : bibleReference <- idx0, scrollAmount <- idx1;
//                   count <  3 -> moduleName <- DefaultsLastBible pref, else idx2;
//                   count <  4 -> dateAdded  <- NSDate.distantPast,      else idx3.
//      count <  2 : seed from PSModuleController.getFirstRefAvailable / scroll "0"
//                   / DefaultsLastBible / distantPast.
//
//  The 100-entry cap lives in HistoryStore, not here.
//

import Foundation

@objc(PSHistoryItemAge)
enum PSHistoryItemAge: Int {
    case older = 0      // PSHistoryItemOlder
    case equal          // PSHistoryItemEqual
    case newer          // PSHistoryItemNewer
    case invalidAge     // PSHistoryItemInvalidAge
}

@objc(PSHistoryItem)
final class PSHistoryItem: NSObject {

    @objc var bibleReference: String?
    @objc var scrollAmount: String?
    @objc var moduleName: String?
    @objc var dateAdded: Date?

    @objc(initWithReference:scrollAmount:moduleName:dateAdded:)
    init?(reference ref: String?,
          scrollAmount scrollString: String?,
          moduleName mod: String?,
          dateAdded da: Date?) {
        super.init()
        self.bibleReference = ref
        self.scrollAmount = scrollString
        self.moduleName = mod
        self.dateAdded = da
    }

    @objc(initWithArray:)
    init?(array historyArray: [Any]?) {
        super.init()
        if let historyArray = historyArray, historyArray.count >= 2 {
            self.bibleReference = historyArray[0] as? String
            self.scrollAmount = historyArray[1] as? String
            if historyArray.count < 3 {
                self.moduleName = UserDefaults.standard.string(forKey: Defaults.lastBible)
            } else {
                self.moduleName = historyArray[2] as? String
            }
            if historyArray.count < 4 {
                self.dateAdded = Date.distantPast
            } else {
                self.dateAdded = historyArray[3] as? Date
            }
        } else {
            self.bibleReference = PSModuleController.getFirstRefAvailable()
            self.scrollAmount = "0"
            self.moduleName = UserDefaults.standard.string(forKey: Defaults.lastBible)
            self.dateAdded = Date.distantPast
        }
    }

    @objc func array() -> [Any] {
        // WRITE order: [bibleReference, "0" (scroll hardcoded), moduleName, dateAdded].
        // Truncates the tail at the first nil (NSArray arrayWithObjects: semantics).
        var arr: [Any] = []
        let ordered: [Any?] = [bibleReference, "0" /*scroll*/, moduleName, dateAdded]
        for element in ordered {
            guard let element = element else { break }
            arr.append(element)
        }
        return arr
    }

    // NSString/NSDate isEqual nil semantics: comparing with nil is always false.
    // Swift's Optional `==` makes nil == nil true, which would make two items
    // with a nil moduleName compare EQUAL and silently drop history on iCloud
    // reconcile.
    private static func objcEqual(_ a: String?, _ b: String?) -> Bool {
        guard let a = a, let b = b else { return false }
        return a == b
    }

    private static func objcEqual(_ a: Date?, _ b: Date?) -> Bool {
        guard let a = a, let b = b else { return false }
        return a == b
    }

    @objc(isEqualToHistoryItem:)
    func isEqual(to otherHistoryItem: PSHistoryItem?) -> Bool {
        guard let otherHistoryItem = otherHistoryItem else { return false }

        if PSHistoryItem.objcEqual(bibleReference, otherHistoryItem.bibleReference)
            && PSHistoryItem.objcEqual(moduleName, otherHistoryItem.moduleName)
            && PSHistoryItem.objcEqual(dateAdded, otherHistoryItem.dateAdded) {
            return true
        }
        return false
    }

    /// determines if self is older than otherHistoryItem
    @objc(ageComparisonToHistoryItem:)
    func ageComparison(to otherHistoryItem: PSHistoryItem?) -> PSHistoryItemAge {
        guard let otherHistoryItem = otherHistoryItem,
              let selfDate = dateAdded,
              let otherDate = otherHistoryItem.dateAdded else {
            return .invalidAge
        }

        let timeInterval = selfDate.timeIntervalSince(otherDate)

        if timeInterval < 0 {
            // self is before otherHistoryItem
            return .older
        } else if timeInterval == 0 {
            // should be equal?
            return .equal
        } else {
            // self is after otherHistoryItem
            return .newer
        }
    }

    @objc class func parseHistoryArrayArray(_ arrays: [Any]?) -> [Any]? {
        guard let arrays = arrays else { return nil }

        var returnArray: [Any] = []
        returnArray.reserveCapacity(arrays.count)
        for item in arrays {
            if let historyItem = PSHistoryItem(array: item as? [Any]) {
                returnArray.append(historyItem)
            }
        }
        return returnArray
    }

    @objc class func arrayArray(fromHistoryItems arrayOfHistoryItems: [Any]?) -> [Any]? {
        guard let arrayOfHistoryItems = arrayOfHistoryItems else { return nil }

        var returnArray: [Any] = []
        returnArray.reserveCapacity(arrayOfHistoryItems.count)
        for item in arrayOfHistoryItems {
            if let item = item as? PSHistoryItem {
                returnArray.append(item.array())
            }
        }
        return returnArray
    }

    @objc class func arraysAreEqual(_ firstArray: [Any]?, secondArray: [Any]?) -> Bool {
        let firstArray = firstArray ?? []
        let secondArray = secondArray ?? []
        if firstArray.count != secondArray.count {
            return false
        }

        for i in 0..<firstArray.count {
            guard let firstHI = firstArray[i] as? PSHistoryItem,
                  let secondHI = secondArray[i] as? PSHistoryItem else {
                return false
            }
            // Same nil semantics, so a nil ref/module never reads as "equal".
            if !PSHistoryItem.objcEqual(firstHI.bibleReference, secondHI.bibleReference)
                || !PSHistoryItem.objcEqual(firstHI.moduleName, secondHI.moduleName) {
                return false
            }
        }
        return true
    }
}
