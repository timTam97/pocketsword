//
//  PSBookmark.swift
//  PocketSword
//
//  Swift migration step 1.1 — bookmark inheritance chain (ATOMIC, §2A Rule 3).
//  Port of PSBookmark.{h,m}.
//

import Foundation

@objc(PSBookmark)
class PSBookmark: PSBookmarkObject {

    @objc var ref: String?

    @objc init(name n: String?, dateAdded da: Date?, dateLastAccessed dla: Date?, bibleReference r: String?) {
        super.init(name: n, dateAdded: da, dateLastAccessed: dla)
        self.ref = r
    }
}
