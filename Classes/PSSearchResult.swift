//
//  PSSearchResult.swift
//  PocketSword
//
//  Value type for a single FTS5 search hit: the verse reference plus the raw
//  snippet string (containing [[HL]]…[[/HL]] delimiters to be rendered into an
//  attributed string by the UI layer).
//
//  Pure in-memory DTO produced by PSSearchEngine and consumed by
//  PSModuleSearchController. It is never persisted, so there is no positional
//  array (de)serialization to preserve.
//
//  Migrated from PSSearchResult.{h,m} (Swift migration PR 1.2). The @objc annotations
//  were for the then-Obj-C++ callers (PSSearchEngine.mm and SwordModule.mm) and are
//  vestigial now that both are gone — the property/initializer surface still matches
//  the former Obj-C class byte-for-byte.
//

import Foundation

@objc(PSSearchResult)
final class PSSearchResult: NSObject {

    @objc var reference: String

    /// Full plain-text of the verse, exactly as stored in FTS5's text_plain column.
    @objc var fullText: String?

    /// For Strong's searches, the English surface word(s) in this verse that mapped
    /// to the searched Strong's number(s). nil for text searches. Order-preserving
    /// and de-duped.
    @objc var strongsHighlightWords: [String]?

    @objc(initWithReference:fullText:)
    init(reference: String, fullText: String?) {
        self.reference = reference
        self.fullText = fullText
        super.init()
    }

    @objc(resultWithReference:fullText:)
    class func result(withReference reference: String, fullText: String?) -> PSSearchResult {
        return PSSearchResult(reference: reference, fullText: fullText)
    }
}
