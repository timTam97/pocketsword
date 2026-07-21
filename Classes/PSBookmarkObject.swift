//
//  PSBookmarkObject.swift
//  PocketSword
//
//  Swift migration step 1.1 — bookmark inheritance chain (ATOMIC, §2A Rule 3).
//  Port of PSBookmarkObject.{h,m}. The four-class chain
//  (PSBookmarkObject <- PSBookmark / PSBookmarkFolder <- PSBookmarks) migrates
//  together in one PR because a Swift base with Obj-C subclass headers cannot
//  compile.
//
//  Exposes @objc members wherever Obj-C callers (the .mm view controllers, the
//  XCTest persisted-format guard) reference them.
//

import Foundation
import UIKit

@objc(PSBookmarkObject)
class PSBookmarkObject: NSObject {

    @objc var name: String?
    @objc var dateAdded: Date?
    @objc var dateLastAccessed: Date?

    // `folder` is read-only to Obj-C (the original @property (readonly) BOOL folder),
    // set internally by the subclass initializers / the original -init.
    @objc private(set) var folder: Bool = false

    // rgbHexString is only used for a folder. Bookmarks inherit it from their
    // containing folder at read time (see PSBookmarkFolder.getBookmarks…).
    @objc var rgbHexString: String?

    @objc override init() {
        // Mirrors the Obj-C -init: folder defaults to NO.
        self.folder = false
        super.init()
    }

    @objc init(name n: String?, dateAdded da: Date?, dateLastAccessed dla: Date?) {
        super.init()
        self.name = n
        self.dateAdded = da
        self.dateLastAccessed = dla
    }

    // Internal hook so subclasses (PSBookmarkFolder) can flip the read-only flag,
    // matching the original `folder = YES;` assignments inside the subclass -init.
    func setFolderFlag(_ value: Bool) {
        self.folder = value
    }
}
