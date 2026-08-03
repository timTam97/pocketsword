//
//  PSBookmarksNavigatorController.swift
//  PocketSword
//
//  Created by Nic Carter on 6/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//
//  Swift port (Swift migration Wave 3). Faithful to the original Obj-C++
//  PSBookmarksNavigatorController: a grouped UITableViewController that
//  navigates the bookmarks tree (folders + bookmarks), supports edit mode
//  (reorder / delete / add folder), and on tap either descends into a folder
//  or opens a bookmark's reference in the Bible tab.
//
//  The class is @objc(PSBookmarksNavigatorController) so the Obj-C++ caller
//  (PSTabBarControllerDelegate.mm, via the generated PocketSword-Swift.h) and
//  the Swift add-bookmark VC both keep their existing call sites. It consumes
//  the Swift bookmark chain (PSBookmarks / PSBookmarkFolder / PSBookmark /
//  PSBookmarkObject) + PSBookmarkTableViewCell + PSModuleController.createRefString:
//  directly (same module). No C++ — the engine is reached only through the
//  Foundation-typed PSModuleController / SwordManager facades.
//

import UIKit

@objc(PSBookmarksNavigatorController)
class PSBookmarksNavigatorController: UITableViewController {

    @objc var bookmarkFolder: PSBookmarkFolder?
    @objc var isAddingBookmark: Bool = false
    @objc private(set) var parentFolders: String?

    private var displayAddFolderRow: Bool = false
    private var bookmarksEditing: Bool = false

    // MARK: - Initialization

    @objc(initWithBookmarkFolder:parentFolders:isAddingBookmark:)
    init(bookmarkFolder folder: PSBookmarkFolder?, parentFolders parentFoldersString: String?, isAddingBookmark adding: Bool) {
        super.init(style: .grouped)
        self.bookmarkFolder = folder
        self.isAddingBookmark = adding
        self.isEditing = false
        self.bookmarksEditing = false
        self.parentFolders = parentFoldersString
        self.displayAddFolderRow = false
    }

    override init(style: UITableView.Style) {
        super.init(style: style)
        self.bookmarkFolder = PSBookmarks.default()
        self.isAddingBookmark = false
        self.isEditing = false
        self.bookmarksEditing = false
        self.parentFolders = nil
        self.displayAddFolderRow = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        let editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editButtonPressed))
        self.navigationItem.rightBarButtonItem = editButton
        if let bookmarkFolder = bookmarkFolder {
            self.navigationItem.title = bookmarkFolder.name
        }
        self.tableView.allowsSelectionDuringEditing = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }

    @objc func editButtonPressed() {
        displayAddFolderRow = false
        if !bookmarksEditing {
            displayAddFolderRow = true
            if !self.isAddingBookmark {
                self.tableView.insertSections(IndexSet(integer: 1), with: .fade)
            } else {
                self.tableView.reloadSections(IndexSet(integer: 1), with: .fade)
            }
            // if the user has side-swiped to delete, remove that delete button first.
            self.setEditing(false, animated: false)
            self.setEditing(true, animated: true)
            bookmarksEditing = true
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(editButtonPressed))
            self.navigationItem.setRightBarButton(doneButton, animated: true)
        } else {
            self.setEditing(false, animated: true)
            bookmarksEditing = false
            if !self.isAddingBookmark {
                self.tableView.deleteSections(IndexSet(integer: 1), with: .fade)
            } else {
                self.tableView.reloadSections(IndexSet(integer: 1), with: .fade)
            }
            let editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editButtonPressed))
            self.navigationItem.setRightBarButton(editButton, animated: true)
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let rowObject = rowObject(at: indexPath)
            if let rowObject = rowObject, rowObject.folder,
               let hex = (rowObject as? PSBookmarkFolder)?.rgbHexString {
                cell.backgroundColor = PSBookmarkFolder.color(fromHexString: hex)
            } else {
                cell.backgroundColor = .systemBackground
            }
        } else if indexPath.section == 1 {
            cell.backgroundColor = .systemBackground
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if displayAddFolderRow || self.isAddingBookmark {
            return 2
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if isAddingBookmark {
                return bookmarkFolder?.folders().count ?? 0
            } else {
                return bookmarkFolder?.children?.count ?? 0
            }
        } else if isAddingBookmark || displayAddFolderRow {
            return 1
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "Cell"

        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as? PSBookmarkTableViewCell
        if cell == nil {
            cell = PSBookmarkTableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        }

        // Configure the cell...
        cell?.textLabel?.backgroundColor = .clear
        cell?.detailTextLabel?.backgroundColor = .clear

        if indexPath.section == 0 {
            let rowObject = rowObject(at: indexPath)
            cell?.textLabel?.text = rowObject?.name
            cell?.showsReorderControl = true
            if let rowObject = rowObject, rowObject.folder {
                // tis a folder
                cell?.detailTextLabel?.text = ""
                cell?.accessoryType = .disclosureIndicator
                cell?.imageView?.image = UIImage(named: "folder.png")
            } else {
                // tis a bookmark
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = .none
                dateFormatter.dateStyle = .short

                var dateString = rowObject?.dateLastAccessed.map { dateFormatter.string(from: $0) } ?? ""
                let todayString = dateFormatter.string(from: Date())
                if dateString == todayString {
                    dateString = NSLocalizedString("TodayButtonTitle", comment: "")
                }
                cell?.detailTextLabel?.text = (rowObject as? PSBookmark)?.ref
                cell?.accessoryType = .none
                cell?.imageView?.image = UIImage(named: "bookmark.png")
                cell?.lastAccessedLabel.text = dateString
            }
        } else if indexPath.section == 1 {
            if displayAddFolderRow {
                // add folder row!
                cell?.imageView?.image = UIImage(named: "folder.png")
                cell?.textLabel?.text = NSLocalizedString("BookmarksAddFolderButton", comment: "Add Folder")
            } else {
                cell?.imageView?.image = UIImage(named: "bookmark.png")
                cell?.textLabel?.text = NSLocalizedString("BookmarksAddBookmarkHereButton", comment: "Add Bookmark here")
            }
        }
        return cell!
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 && !self.isAddingBookmark {
            return NSLocalizedString("BookmarksAddBookmarkDescription", comment: "To add a bookmark for a verse, tap on the verse number in the Bible tab and select 'Add Bookmark'")
        } else if !displayAddFolderRow && section == 1 && self.isAddingBookmark {
            return NSLocalizedString("BookmarksAddFolderDescription", comment: "To add a folder, tap on the Edit button")
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if indexPath.section == 0 {
            return .delete
        } else {
            return .insert
        }
    }

    private func insertEditFolderButtonPressed(_ folderToEdit: PSBookmarkFolder?) {
        // create a new folder.
        let favc = PSBookmarkFolderAddViewController(parentFolder: self.parentFolders, bookmarkFolderToEdit: folderToEdit)
        self.navigationController?.pushViewController(favc, animated: true)
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source.
            let rowObject = rowObject(at: indexPath)
            if let rowObject = rowObject, rowObject.folder {
                // Confirm deletion
                let message = String(format: NSLocalizedString("BookmarksConfirmDeleteFolderMessage", comment: ""), rowObject.name ?? "")
                let alert = UIAlertController(title: NSLocalizedString("BookmarksConfirmDeleteFolderTitle", comment: ""), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: "No"), style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: "Yes"), style: .default, handler: { [weak self] _ in
                    self?.deleteChild(at: indexPath)
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                self.deleteChild(at: indexPath)
            }
        } else if editingStyle == .insert {
            self.insertEditFolderButtonPressed(nil)
        }
    }

    @objc(deleteChildAtIndexPath:)
    func deleteChild(at indexPath: IndexPath) {
        guard let bookmarkFolder = bookmarkFolder else { return }
        var array: [Any] = bookmarkFolder.children ?? []
        if isAddingBookmark {
            // need to identify which is the correct child!
            let folders = bookmarkFolder.folders()
            let childName = (folders[indexPath.row] as? PSBookmarkFolder)?.name
            for (idx, obj) in array.enumerated() {
                if let bm = obj as? PSBookmarkObject, bm.name == childName {
                    array.remove(at: idx)
                    break
                }
            }
        } else {
            array.remove(at: indexPath.row)
        }
        bookmarkFolder.children = array
        PSBookmarks.saveBookmarksToFile()
        self.tableView.deleteRows(at: [indexPath], with: .fade)
        NotificationCenter.default.post(name: .bookmarksChanged, object: nil)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard let bookmarkFolder = bookmarkFolder else { return }
        var kids: [Any] = bookmarkFolder.children ?? []
        let obj = kids[sourceIndexPath.row]
        kids.remove(at: sourceIndexPath.row)
        kids.insert(obj, at: destinationIndexPath.row)
        bookmarkFolder.children = kids
        PSBookmarks.saveBookmarksToFile()
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // tapping on the cell in section 1 will:
        if indexPath.section == 1 {
            if bookmarksEditing {
                // add a folder
                self.insertEditFolderButtonPressed(nil)
            } else {
                // save the current folder structure & add a bookmark at this position
                NotificationCenter.default.post(name: .addBookmarkInFolder, object: self.parentFolders)
            }
        } else {
            let rowObject = rowObject(at: indexPath)
            if let rowObject = rowObject, rowObject.folder {
                if bookmarksEditing {
                    // edit this folder:
                    self.insertEditFolderButtonPressed(rowObject as? PSBookmarkFolder)
                } else {
                    // tapping on a folder navigates to that folder.
                    var pfs = rowObject.name ?? ""
                    if let parentFolders = self.parentFolders {
                        pfs = "\(parentFolders)\(AppConstants.folderSeparatorString)\(rowObject.name ?? "")"
                    }
                    let bnc = PSBookmarksNavigatorController(bookmarkFolder: rowObject as? PSBookmarkFolder, parentFolders: pfs, isAddingBookmark: self.isAddingBookmark)
                    self.navigationController?.pushViewController(bnc, animated: true)
                }
            } else {
                if bookmarksEditing {
                    // edit this bookmark:
                    let abc = PSBookmarksAddTableViewController(bookmarkToEdit: rowObject as? PSBookmark, parentFolders: self.parentFolders)
                    self.navigationController?.pushViewController(abc, animated: true)
                } else {
                    // tapping on a bookmark will open the bookmark.
                    (rowObject as? PSBookmark)?.dateLastAccessed = Date()
                    PSBookmarks.saveBookmarksToFile()
                    NotificationCenter.default.post(name: .showBibleTab, object: nil)
                    // The `swordManager.moduleNames()?.count != 0` guard is GONE
                    // (Phase 5 step 5): five modules always ship, there is no UI to
                    // remove one, and the store that provides them is fatal if absent.
                    // So the condition was unconditionally true and is now written that
                    // way rather than asking a manager that is about to be deleted.
                    do {
                        let fullRef = ((rowObject as? PSBookmark)?.ref ?? "").components(separatedBy: ":")
                        let ref = fullRef[0]
                        let defaults = UserDefaults.standard
                        defaults.set(PSModuleController.createRefString(ref), forKey: Defaults.lastRef)
                        if fullRef.count > 1 {
                            let verse = fullRef[1]
                            defaults.set(verse, forKey: Defaults.bibleVersePosition)
                            defaults.synchronize()
                            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
                        } else {
                            defaults.set("1", forKey: Defaults.bibleVersePosition)
                            defaults.synchronize()
                            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
                        }
                        PSHistoryController.addHistoryItem(.BibleTab)
                    }
                }

                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }

    // MARK: - Helpers

    /// Mirrors the original ternary `(isAddingBookmark) ? [bookmarkFolder folders][row]
    /// : [bookmarkFolder.children][row]` used throughout the data source.
    private func rowObject(at indexPath: IndexPath) -> PSBookmarkObject? {
        guard let bookmarkFolder = bookmarkFolder else { return nil }
        if isAddingBookmark {
            return bookmarkFolder.folders()[indexPath.row] as? PSBookmarkObject
        } else {
            return bookmarkFolder.children?[indexPath.row] as? PSBookmarkObject
        }
    }
}
