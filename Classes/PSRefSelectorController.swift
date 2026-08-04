//
//  PSRefSelectorController.swift
//  PocketSword
//
//  Ported to Swift (Wave 3). The root list of the reference selector: one
//  section per book of the current versification system. Tapping a book pushes
//  a PSChapterSelectorController (its Swift sibling, Wave 2); tapping the per-row
//  "1:1" accessory button jumps the primary Bible straight to verse 1 of that
//  book via NotificationUpdateSelectedReference.
//
//  SWORD_REMOVAL_PLAN.md Phase 4: the book list now comes from the baked
//  Resources/Versification-KJV.json via PSBookOSISResolver, not from
//  +[SwordManager booksForVersificationSystem:] over a live
//  sword::VersificationMgr. `PSVersificationBook` replaces `SwordBook` directly
//  with no adapter type: the table reproduces all five consumed members
//  byte-exactly (asserted 66/66 in PSRefSemanticsTests), so nothing is re-munged
//  here.
//
//  The versification *system* lookup is gone with it. The app ships exactly one
//  Bible and one commentary, both KJV-versified, and the old seam already fell
//  back to "KJV" for anything it could not resolve — so the primary module's
//  -versification() was only ever confirming the single table this app has.
//
//  Originally created by Nic Carter on 3/04/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSRefSelectorController)
final class PSRefSelectorController: UITableViewController {

    private var refSelectorBooks: [PSVersificationBook] = []
    private var refSelectorBooksIndex: [String] = []
    private var currentlyViewedBookName: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(resetBooks(_:)),
                                               name: .refSelectorResetBooks,
                                               object: nil)
        preferredContentSize = CGSize(width: 540.0, height: 1100.0)
    }

    @objc func resetBooks(_ notification: Notification) {
        refSelectorBooks = []
    }

    @objc func dismissNavigation() {
        NotificationCenter.default.post(name: .toggleNavigation, object: nil)
    }

    @objc func setupNavigation() {
        updateRefSelectorBooks()
        tableView.reloadData()
        navigationItem.title = NSLocalizedString("RefSelectorBookTitle", comment: "Book")
        navigationController?.popToRootViewController(animated: false)
        navigationItem.leftBarButtonItem = nil
        tableView.backgroundColor = .systemBackground
        if PSResizing.iPad() {
            // the iPad doesn't want the cancel button
            return
        }
        let cancel = UIBarButtonItem(barButtonSystemItem: .cancel,
                                     target: self,
                                     action: #selector(dismissNavigation))
        navigationItem.leftBarButtonItem = cancel
    }

    @objc func willShowNavigation() {
        var ip: IndexPath? = nil
        for i in 0..<refSelectorBooks.count {
            if currentlyViewedBookName == refSelectorBooks[i].name {
                ip = IndexPath(row: 0, section: i)
            }
        }
        if let ip = ip {
            tableView.scrollToRow(at: ip, at: .middle, animated: false)
        }
    }

    @objc func updateRefSelectorBooks() {
        autoreleasepool {
            let books = PSBookOSISResolver.shared?.books ?? []

            // The section-index strip, built exactly as before: a short name is
            // added only if no EARLIER book already used it. That dedups 66 books
            // to 64 titles, and the two dropped ones are intentional — "Jud"
            // belongs to Judges (not Jude) and "Phi" to Philippians (not Philemon),
            // so tapping them scrolls to the first-occurrence book. That is today's
            // visible behaviour and the strip is deliberately left alone; the same
            // first-writer-wins rule is what PSBookOSISResolver's spelling index
            // applies, and PSRefSemanticsTests pins the "Jud" case.
            var booksIndex: [String] = []
            var booksFullIndex: [String] = []
            for book in books {
                let short = book.shortName
                if !booksFullIndex.contains(short) {
                    booksIndex.append(short)
                }
                booksFullIndex.append(short)
            }

            var currentBook = PSModuleController.getCurrentBibleRef() ?? ""
            currentBook = currentBook.components(separatedBy: ":")[0]
            if let spaceRange = currentBook.range(of: " ", options: .backwards) {
                currentBook = String(currentBook[..<spaceRange.lowerBound])
            }

            refSelectorBooks = books
            refSelectorBooksIndex = booksIndex
            currentlyViewedBookName = currentBook
        }
    }

    // MARK: - Table view methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return refSelectorBooks.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")

        let name = bookName(indexPath.section)
        cell.textLabel?.text = name
        if currentlyViewedBookName == name {
            cell.textLabel?.textColor = .systemBlue
        } else {
            cell.textLabel?.textColor = .label
        }
        cell.accessoryType = .detailDisclosureButton

        let jumpButton = UIButton(type: .system)
        jumpButton.frame = CGRect(x: 0, y: 0, width: 60, height: 30)
        jumpButton.setTitle("1:1", for: .normal)
        jumpButton.tag = 1000 + indexPath.section
        jumpButton.addTarget(self, action: #selector(accessoryButtonPressed(_:)), for: .touchUpInside)
        cell.accessoryView = jumpButton

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .systemBackground
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let chapterSelectorController = PSChapterSelectorController(style: .plain)
        chapterSelectorController.setBookAndInit(refSelectorBooks[indexPath.section])
        navigationController?.pushViewController(chapterSelectorController, animated: true)
    }

    private func jumpToVerseOne(_ bookIndex: Int) {
        NotificationCenter.default.post(name: .toggleNavigation, object: nil)
        var bcvDict: [String: String] = [:]
        bcvDict[AppConstants.bookNameString] = refSelectorBooks[bookIndex].name
        bcvDict[AppConstants.chapterString] = "1"
        bcvDict[AppConstants.verseString] = "1"
        NotificationCenter.default.post(name: .updateSelectedReference, object: bcvDict)
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // jump to ch1, v1 of that book.
        jumpToVerseOne(indexPath.section)
    }

    @objc func accessoryButtonPressed(_ sender: Any) {
        let bookIndex = (sender as! UIView).tag - 1000
        jumpToVerseOne(bookIndex)
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return refSelectorBooksIndex
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        for i in 0..<refSelectorBooks.count {
            if bookShortName(i) == refSelectorBooksIndex[index] {
                return i
            }
        }
        return 0
    }

    // The notification dict carries `name` — "1 Corinthians", "Revelation" —
    // unchanged. PSTabBarControllerDelegate builds lastRef straight from it, and
    // bookmarks / history / the headings table are all keyed on that form, so this
    // is deliberately NOT "improved" to OSIS.
    private func bookName(_ bookIndex: Int) -> String {
        return refSelectorBooks[bookIndex].name
    }

    private func bookShortName(_ bookIndex: Int) -> String {
        return refSelectorBooks[bookIndex].shortName
    }
}
