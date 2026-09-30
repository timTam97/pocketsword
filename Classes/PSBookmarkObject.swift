//
//  PSBookmarkObject.swift
//  PocketSword
//
//  Base of the bookmark chain:
//  PSBookmarkObject <- PSBookmark / PSBookmarkFolder <- PSBookmarks.
//

import Foundation
import UIKit

@objc(PSBookmarkObject)
class PSBookmarkObject: NSObject, Identifiable {

    let id = UUID()
    @objc var name: String?
    @objc var dateAdded: Date?
    @objc var dateLastAccessed: Date?

    // Read-only outside the chain; set by the subclass initializers.
    @objc private(set) var folder: Bool = false

    // rgbHexString is only used for a folder. Bookmarks inherit it from their
    // containing folder at read time (see PSBookmarkFolder.getBookmarks…).
    @objc var rgbHexString: String?

    @objc override init() {
        self.folder = false
        super.init()
    }

    @objc init(name n: String?, dateAdded da: Date?, dateLastAccessed dla: Date?) {
        super.init()
        self.name = n
        self.dateAdded = da
        self.dateLastAccessed = dla
    }

    // Lets subclasses (PSBookmarkFolder) flip the read-only flag.
    func setFolderFlag(_ value: Bool) {
        self.folder = value
    }
}
