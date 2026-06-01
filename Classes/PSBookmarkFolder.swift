//
//  PSBookmarkFolder.swift
//  PocketSword
//
//  Swift migration step 1.1 — bookmark inheritance chain (ATOMIC, §2A Rule 3).
//  Port of PSBookmarkFolder.{h,m}. Behaviour preserved byte-for-byte, including
//  the hex/rgb string formatting and the children traversal used by the bible
//  view's verse-highlight path.
//

import Foundation
import UIKit

@objc(PSBookmarkFolder)
class PSBookmarkFolder: PSBookmarkObject {

    @objc var children: [Any]?

    // MARK: - Colour helpers (class methods, called from .mm callers + self)

    @objc(hexStringFromColor:)
    class func hexString(from color: UIColor) -> String {
        let c = color.cgColor.components ?? [0, 0, 0]
        var r: CGFloat = c.count > 0 ? c[0] : 0
        var g: CGFloat = c.count > 1 ? c[1] : 0
        var b: CGFloat = c.count > 2 ? c[2] : 0

        // Fix range if needed
        if r < 0.0 { r = 0.0 }
        if g < 0.0 { g = 0.0 }
        if b < 0.0 { b = 0.0 }

        if r > 1.0 { r = 1.0 }
        if g > 1.0 { g = 1.0 }
        if b > 1.0 { b = 1.0 }

        // Convert to hex string between 0x00 and 0xFF
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    @objc(colorFromHexString:)
    class func color(fromHexString hexString: String?) -> UIColor {
        guard let hexString = hexString, hexString.count >= 7 else {
            return UIColor.clear
        }
        let ns = hexString as NSString
        let rString = "0x" + ns.substring(with: NSRange(location: 1, length: 2))
        var r: Float = 0, g: Float = 0, b: Float = 0
        Scanner(string: rString).scanHexFloat(&r)
        let gString = "0x" + ns.substring(with: NSRange(location: 3, length: 2))
        Scanner(string: gString).scanHexFloat(&g)
        let bString = "0x" + ns.substring(with: NSRange(location: 5, length: 2))
        Scanner(string: bString).scanHexFloat(&b)

        return UIColor(red: CGFloat(r / 255.0), green: CGFloat(g / 255.0), blue: CGFloat(b / 255.0), alpha: 0.8)
    }

    @objc(rgbStringFromHexString:)
    class func rgbString(fromHexString hexString: String?) -> String {
        guard let hexString = hexString, hexString.count >= 7 else {
            return "transparent"
        }
        let ns = hexString as NSString
        let rString = "0x" + ns.substring(with: NSRange(location: 1, length: 2))
        var r: Float = 0, g: Float = 0, b: Float = 0
        Scanner(string: rString).scanHexFloat(&r)
        let gString = "0x" + ns.substring(with: NSRange(location: 3, length: 2))
        Scanner(string: gString).scanHexFloat(&g)
        let bString = "0x" + ns.substring(with: NSRange(location: 5, length: 2))
        Scanner(string: bString).scanHexFloat(&b)

        return String(format: "rgba(%d,%d,%d,0.8)", Int(r), Int(g), Int(b))
    }

    // MARK: - Init

    @objc override init() {
        super.init()
        setFolderFlag(true)
    }

    @objc init(name n: String?, dateAdded da: Date?, dateLastAccessed dla: Date?, rgbHexString rgb: String?, children c: [Any]?) {
        super.init(name: n, dateAdded: da, dateLastAccessed: dla)
        self.rgbHexString = rgb
        self.children = c
        setFolderFlag(true)
    }

    // MARK: - Children management

    @objc(addChild:)
    func addChild(_ child: PSBookmarkObject) {
        var tmpArray: [Any] = []
        if let children = children {
            tmpArray.append(contentsOf: children)
        }
        tmpArray.append(child)
        self.children = tmpArray
    }

    @objc(addChildren:)
    func addChildren(_ kids: [Any]) {
        var tmpArray: [Any] = []
        if let children = children {
            tmpArray.append(contentsOf: children)
        }
        tmpArray.append(contentsOf: kids)
        self.children = tmpArray
    }

    @objc func folders() -> [Any] {
        var ret: [Any] = []
        for obj in children ?? [] {
            if let bm = obj as? PSBookmarkObject, bm.folder {
                ret.append(bm)
            }
        }
        return ret
    }

    @objc(getHighlightRGBColourStringForBookAndChapterRef:withVerse:)
    func getHighlightRGBColourString(forBookAndChapterRef bookAndChapterRef: String, withVerse verse: String) -> String? {
        let possibleBookmarks = getBookmarks(forBookAndChapterRef: bookAndChapterRef)
        if possibleBookmarks.count > 0 {
            for case let bookmark as PSBookmark in possibleBookmarks {
                if bookmark.rgbHexString != nil {
                    let components = (bookmark.ref ?? "").components(separatedBy: ":")
                    // Mirrors the original objectAtIndex:1 — out-of-range would crash
                    // in Obj-C; the data always carries a "book chap:verse" ref here.
                    let v = components[1]
                    if v == verse {
                        return PSBookmarkFolder.rgbString(fromHexString: bookmark.rgbHexString)
                    }
                }
            }
        }
        return nil
    }

    @objc(getBookmarksForBookAndChapterRef:)
    func getBookmarks(forBookAndChapterRef bookAndChapterRef: String) -> NSMutableArray {
        let ret = NSMutableArray()
        for case let bookmarkObject as PSBookmarkObject in (children ?? []) {
            if type(of: bookmarkObject) == PSBookmark.self {
                // tis a bookmark
                let bm = bookmarkObject as! PSBookmark
                let refString = (bm.ref ?? "") as NSString
                let colonLocation = refString.range(of: ":")
                if colonLocation.location != NSNotFound {
                    let bookmarkBookAndChapterRef = refString.substring(to: colonLocation.location)
                    if bookmarkBookAndChapterRef == bookAndChapterRef {
                        // tmp set the colour hex string to the colour of the enclosing folder (us/self!).
                        bookmarkObject.rgbHexString = self.rgbHexString
                        ret.add(bookmarkObject)
                    }
                }
            } else if let folder = bookmarkObject as? PSBookmarkFolder {
                // or could either be a PSBookmarkFolder or the PSBookmarks
                ret.addObjects(from: folder.getBookmarks(forBookAndChapterRef: bookAndChapterRef) as [AnyObject])
            }
        }
        return ret
    }
}
