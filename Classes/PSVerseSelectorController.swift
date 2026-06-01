//
//  PSVerseSelectorController.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). A grouped list of the verses of one chapter of a
//  SwordBook; selecting a verse posts NotificationUpdateSelectedReference (and
//  toggles navigation off) so the coordinator jumps the primary Bible there.
//  Public API matches the original PSVerseSelectorController.{h,mm}
//  byte-for-byte so its Swift sibling caller (PSChapterSelectorController) and
//  any Obj-C++ caller bind unchanged: it exposes a `book` (SwordBook) and a
//  `chapter` (NSInteger) property. SwordBook resolves as a Swift type via the
//  bridging header (clean Foundation-only facade after Wave 0e).
//
//  Originally created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSVerseSelectorController)
final class PSVerseSelectorController: UITableViewController {

    @objc var book: SwordBook?
    @objc var chapter: NSInteger = 0

    override func viewWillAppear(_ animated: Bool) {
        tableView.backgroundColor = .systemBackground
        navigationItem.title = String(format: "%@ %d", book?.name() ?? "", Int32(chapter))
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view methods

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let verses = Int(book?.verses(chapter) ?? 0)
        if verses < 10 {
            return nil
        }
        var array: [String] = []
        var i = 1
        while i <= verses {
            array.append(String(format: "%d", i))
            i += 1
        }
        return array
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return book?.verses(chapter) ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "Cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)

        cell.textLabel?.text = String(format: NSLocalizedString("RefSelectorVerseTitle", comment: "Verse"), indexPath.section + 1)
        cell.textLabel?.textColor = .label

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemBackground
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        NotificationCenter.default.post(name: .toggleNavigation, object: nil)
        var bcvDict: [String: String] = [:]
        bcvDict[AppConstants.bookNameString] = book?.name() ?? ""
        bcvDict[AppConstants.chapterString] = String(format: "%d", Int32(chapter))
        bcvDict[AppConstants.verseString] = String(format: "%d", Int32(indexPath.section + 1))
        NotificationCenter.default.post(name: .updateSelectedReference, object: bcvDict)
    }
}
