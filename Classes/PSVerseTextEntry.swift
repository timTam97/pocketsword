//
//  PSVerseTextEntry.swift
//  PocketSword
//
//  A reference plus its text: what a search result row and a cached search-history
//  row are made of.
//
//  SWORD_REMOVAL_PLAN.md Phase 5 step 5. This replaces `SwordModuleTextEntry`
//  (`Classes/SwordModuleTextEntry.{h,m}`), which was the one clean Obj-C DTO left
//  in the tree — a two-property `NSString` box that existed only because it had to
//  cross the Swift/Obj-C++ boundary. There is no boundary any more, so it becomes a
//  Swift type and the Obj-C pair is deleted in step 7.
//
//  Three deliberate carry-overs from the class it replaces, because
//  `PSModuleSearchController` depends on each:
//
//   * It is a **class, not a struct.** `results` is an `NSMutableArray` of these and
//     `tableView(_:cellForRowAt:)` mutates `entry.text` in place when a legacy
//     history row arrives with no text (see `PSModuleSearchController`'s
//     lazy-fill). With a struct that write would land on a copy and the fill would
//     silently never stick.
//   * `text` is **var, `key` is `let`.** That is exactly the old mutability: the
//     old class declared `key` `readonly` and `text` `readwrite`.
//   * Both are **Optional**. The old initialiser took two nullable `NSString *`s
//     and a nil `text` is the signal that means "not cached, go fetch it".
//
//  Not `@objc`: nothing in Obj-C constructs or reads one any more. `PSSearchEngine`
//  hands back `PSSearchResult` (already Swift) and the search controller is Swift.
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
