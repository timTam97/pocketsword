//
//  PSChapterSelectorController.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). A grouped list of the chapters of one SwordBook.
//  Tapping a chapter pushes a PSVerseSelectorController (its Swift sibling,
//  migrated in the same step); tapping the per-row "N:1" accessory button jumps
//  the primary Bible straight to verse 1 of that chapter via
//  NotificationUpdateSelectedReference. Public API matches the original
//  PSChapterSelectorController.{h,mm} byte-for-byte so the Obj-C++ caller
//  (PSRefSelectorController.mm, via PocketSword-Swift.h) binds unchanged: it
//  exposes a `book` (SwordBook) property and a -setBookAndInit: method.
//  SwordBook resolves as a Swift type via the bridging header (clean
//  Foundation-only facade after Wave 0e).
//
//  Originally created by Nic Carter on 8/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSChapterSelectorController)
final class PSChapterSelectorController: UITableViewController {

    @objc var book: SwordBook?

    private var currentChapter: Int = 0
    private var needToScroll: Bool = false

    @objc(setBookAndInit:)
    func setBookAndInit(_ newBook: SwordBook?) {
        book = newBook
        needToScroll = true
    }

    override func viewDidAppear(_ animated: Bool) {
        if needToScroll && currentChapter > 0 {
            let ip = IndexPath(row: 0, section: currentChapter - 1)
            tableView.scrollToRow(at: ip, at: .middle, animated: true)
            needToScroll = false
        }
        super.viewDidAppear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.backgroundColor = .systemBackground
        navigationItem.title = book?.name()
        var currentBook = UserDefaults.standard.string(forKey: Defaults.lastRef) ?? ""
        currentBook = currentBook.components(separatedBy: ":")[0]
        if let spaceRange = currentBook.range(of: " ", options: .backwards) {
            let chapterPart = String(currentBook[spaceRange.lowerBound...])
            currentChapter = Int((chapterPart as NSString).intValue)
            currentBook = String(currentBook[..<spaceRange.lowerBound])
        }
        if book?.name() != currentBook {
            currentChapter = 0
        }
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view methods

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let chapters = Int(book?.chapters() ?? 0)
        if chapters < 10 {
            return nil
        }
        var array: [String] = []
        var i = 1
        while i <= chapters {
            array.append(String(format: "%d", i))
            i += 1
        }
        return array
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return book?.chapters() ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "Cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)

        cell.textLabel?.text = String(format: NSLocalizedString("RefSelectorChapterTitle", comment: "Chapter"), indexPath.section + 1)
        if (indexPath.section + 1) == currentChapter {
            cell.textLabel?.textColor = .systemBlue
        } else {
            cell.textLabel?.textColor = .label
        }
        cell.accessoryType = .detailDisclosureButton

        let jumpButton = UIButton(type: .system)
        let buttonString = String(format: "%ld:1", Int(indexPath.section + 1))
        jumpButton.frame = CGRect(x: 0, y: 0, width: 60, height: 30)
        jumpButton.setTitle(buttonString, for: .normal)
        jumpButton.tag = 1000 + indexPath.section
        jumpButton.addTarget(self, action: #selector(accessoryButtonPressed(_:)), for: .touchUpInside)
        cell.accessoryView = jumpButton

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemBackground
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let verseSelectorController = PSVerseSelectorController(style: .plain)
        verseSelectorController.book = book
        verseSelectorController.chapter = indexPath.section + 1
        navigationController?.pushViewController(verseSelectorController, animated: true)
    }

    private func jumpToVerseOne(_ chapterIndex: Int) {
        NotificationCenter.default.post(name: .toggleNavigation, object: nil)
        var bcvDict: [String: String] = [:]
        bcvDict[AppConstants.bookNameString] = book?.name() ?? ""
        bcvDict[AppConstants.chapterString] = String(format: "%ld", Int(chapterIndex + 1))
        bcvDict[AppConstants.verseString] = "1"
        NotificationCenter.default.post(name: .updateSelectedReference, object: bcvDict)
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // jump to v1 of that book & ch.
        jumpToVerseOne(indexPath.section)
    }

    @objc func accessoryButtonPressed(_ sender: Any) {
        let chapterIndex = (sender as! UIView).tag - 1000
        jumpToVerseOne(chapterIndex)
    }
}
