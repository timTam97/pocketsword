//
//  PSVerseTextEntry.swift
//  PocketSword
//
//  A reference plus its text: what a search result row and a cached
//  search-history row are made of.
//
//  Deliberately a class (the lazy text fill mutates `text` in place; on a
//  struct the write would land on a copy), with `key` immutable and both
//  Optional — a nil `text` means "not cached, go fetch it".
//

import Foundation

final class PSVerseTextEntry {

    /// The reference, as the module keys it ("Genesis 1:1").
    let key: String?

    /// The verse text. `nil` means "not loaded" rather than "empty" — a
    /// search-history row cached by an older build carries the key only, and the
    /// display path fills this in on demand from the content store.
    var text: String?

    init(key: String?, text: String?) {
        self.key = key
        self.text = text
    }
}
