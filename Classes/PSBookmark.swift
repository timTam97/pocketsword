//
//  PSBookmark.swift
//  PocketSword
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
