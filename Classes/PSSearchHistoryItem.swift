//
//  PSSearchHistoryItem.swift
//  PocketSword
//
//  Created by Nic Carter on 1/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//
//  Migrated from PSSearchHistoryItem.{h,m} (Swift migration PR 1.2).
//
//  This is a PERSISTED value leaf: -searchHistoryItemArray / -initWithArray:
//  define a positional array layout that older builds wrote into NSUserDefaults
//  and that PersistedFormatTests locks byte-for-byte (risk R1). The Swift port
//  reproduces that layout EXACTLY, including the long-standing read SKEW in
//  -initWithArray::
//
//    WRITE -searchHistoryItemArray order (idx 0..5):
//      [searchTermToDisplay, strongs("Y"/"N"), fuzzy("Y"/"N"),
//       searchType(%d), searchRange(%d), bookName]
//
//    READ -initWithArray: (DELIBERATELY ASYMMETRIC — do NOT "fix"):
//      strongsSearch <- idx1, fuzzySearch <- idx1 (BOTH from index 1),
//      searchType    <- idx2, searchRange  <- idx3, bookName <- idx4.
//
//  Exposed to the still-Obj-C++ callers (PSModuleSearchController.mm,
//  PSTabBarControllerDelegate.{h,mm}) via @objc; the property / initializer
//  surface matches the former Obj-C class byte-for-byte. The two Obj-C
//  initializers returned `id`, so they import as failable init?.
//

import Foundation

@objc(PSSearchHistoryItem)
final class PSSearchHistoryItem: NSObject {

    @objc var searchTerm: String?
    @objc var searchTermToDisplay: String?

    @objc var strongsSearch: Bool = false
    @objc var fuzzySearch: Bool = false
    @objc var searchType: PSSearchType = .AndSearch
    @objc var searchRange: PSSearchRange = .AllRange
    /// if searchRange == BookRange, we need to save which book we're interested in!
    @objc var bookName: String?

    @objc var results: NSMutableArray?
    @objc var savedTablePosition: NSArray?

    @objc override init() {
        self.searchTerm = nil
        self.searchTermToDisplay = nil
        self.strongsSearch = false
        self.fuzzySearch = false
        self.searchType = .AndSearch
        self.searchRange = .AllRange
        self.bookName = nil
        self.results = nil
        self.savedTablePosition = nil
        super.init()
    }

    @objc(initWithSearchTermToDisplay:strongs:fuzzy:type:range:book:)
    init?(searchTermToDisplay sTerm: String?,
          strongs: Bool,
          fuzzy: Bool,
          type sType: PSSearchType,
          range sRange: PSSearchRange,
          book bName: String?) {
        super.init()
        self.searchTermToDisplay = sTerm
        self.strongsSearch = strongs
        self.fuzzySearch = fuzzy
        self.searchType = sType
        self.searchRange = sRange
        self.bookName = bName
    }

    @objc(initWithArray:)
    init?(array: [Any]?) {
        super.init()
        guard let array = array else { return }

        if array.count > 0 {
            self.searchTermToDisplay = array[0] as? String
        } else {
            self.searchTermToDisplay = nil
        }
        if array.count > 1 {
            self.strongsSearch = (array[1] as? String)?.psBoolValue ?? false
        }
        if array.count > 2 {
            // READ SKEW (preserved byte-for-byte): fuzzy is read from idx1, NOT idx2.
            self.fuzzySearch = (array[1] as? String)?.psBoolValue ?? false
        }
        if array.count > 3 {
            // READ SKEW: searchType is read from idx2, NOT idx3.
            self.searchType = PSSearchType(rawValue: (array[2] as? String)?.psIntValue ?? 0) ?? .AndSearch
        }
        if array.count > 4 {
            // READ SKEW: searchRange is read from idx3, NOT idx4.
            self.searchRange = PSSearchRange(rawValue: (array[3] as? String)?.psIntValue ?? 0) ?? .AllRange
        }
        if array.count > 5 {
            // READ SKEW: bookName is read from idx4, NOT idx5.
            self.bookName = array[4] as? String
        } else {
            self.bookName = nil
        }
    }

    @objc func searchHistoryItemArray() -> [Any] {
        let strongs = strongsSearch ? "Y" : "N"
        let fuzzy = fuzzySearch ? "Y" : "N"
        let sType = String(format: "%d", searchType.rawValue)
        let sRange = String(format: "%d", searchRange.rawValue)
        // NOTE: bookName may be nil; NSArray drops the tail at the first nil, so
        // the original -arrayWithObjects: produced a SHORTER array when bookName
        // was nil. Reproduce that truncation-at-nil semantics byte-for-byte.
        var arr: [Any] = []
        let ordered: [Any?] = [searchTermToDisplay, strongs, fuzzy, sType, sRange, bookName]
        for element in ordered {
            guard let element = element else { break }
            arr.append(element)
        }
        return arr
    }

    /// Returns searchTermToDisplay with legacy CLucene-era operators stripped
    /// (lemma: prefix, && / || boolean operators). Entries saved by older
    /// versions occasionally leaked those tokens into the user-visible field;
    /// this lets the search bar show a clean term on replay.
    @objc func cleanedDisplayTerm() -> String {
        guard let searchTermToDisplay = searchTermToDisplay, !searchTermToDisplay.isEmpty else {
            return ""
        }
        // Drop "lemma:" prefixes wherever they appear.
        let s = searchTermToDisplay.replacingOccurrences(of: "lemma:", with: "")
        // Tokenise on whitespace, drop standalone boolean operator tokens.
        let tokens = s.components(separatedBy: .whitespaces)
        var kept: [String] = []
        for tok in tokens {
            if tok.isEmpty { continue }
            if tok == "&&" || tok == "||" { continue }
            kept.append(tok)
        }
        return kept.joined(separator: " ")
    }
}

// MARK: - Obj-C -boolValue / -intValue parity helpers
//
// The original Obj-C read path did [(NSString*)x boolValue] / [(NSString*)x
// intValue]. Swift's Bool(_:) / Int(_:) are stricter (they reject "Y"/"YES" and
// trailing junk), so we reproduce NSString's lenient semantics exactly to keep
// the persisted-format round-trip byte-for-byte.

private extension String {
    /// Mirrors -[NSString boolValue]: leading whitespace + optional sign, then
    /// "Y"/"y"/"T"/"t" or a non-zero integer prefix => true.
    var psBoolValue: Bool {
        return (self as NSString).boolValue
    }

    /// Mirrors -[NSString intValue]: leading whitespace + optional sign + leading
    /// decimal digits (trailing junk ignored); non-numeric => 0.
    var psIntValue: Int {
        return Int((self as NSString).intValue)
    }
}
