//
//  PSSearchHistoryItem.swift
//  PocketSword
//
//  Created by Nic Carter on 1/02/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//
//  PERSISTED value type: `searchHistoryItemArray` / `init(array:)` define the
//  positional layout in UserDefaults, locked byte-for-byte by
//  PersistedFormatTests, including the read SKEW:
//
//    WRITE order (idx 0..5):
//      [searchTermToDisplay, strongs("Y"/"N"), fuzzy("Y"/"N"),
//       searchType(%d), searchRange(%d), bookName]
//
//    READ (DELIBERATELY ASYMMETRIC — do NOT "fix"):
//      strongsSearch <- idx1, fuzzySearch <- idx1 (BOTH from index 1),
//      searchType    <- idx2, searchRange  <- idx3, bookName <- idx4.
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
        // bookName may be nil; the array is truncated at the first nil
        // (NSArray arrayWithObjects: semantics), producing a SHORTER array.
        var arr: [Any] = []
        let ordered: [Any?] = [searchTermToDisplay, strongs, fuzzy, sType, sRange, bookName]
        for element in ordered {
            guard let element = element else { break }
            arr.append(element)
        }
        return arr
    }

    /// Returns searchTermToDisplay with CLucene-era operators stripped (lemma:
    /// prefix, && / || boolean operators), which entries saved by old versions can
    /// carry.
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

// MARK: - Lenient NSString boolValue / intValue parsing
//
// Swift's Bool(_:) / Int(_:) are stricter (they reject "Y"/"YES" and trailing
// junk), so reproduce NSString's lenient semantics to keep the persisted-format
// round-trip byte-for-byte.

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
