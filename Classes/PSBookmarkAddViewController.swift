//
//  PSBookmarkAddViewController.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). Grouped form for adding or editing a bookmark:
//    add mode (3 sections):  verse / description / folder
//    edit mode (5 sections): ref / description / folder / created / last-accessed
//  The right nav-bar item is a Save button; in add mode a Cancel button is also
//  shown on the left.
//
//  Behaviour preserved from PSBookmarkAddViewController.{h,mm}. Consumes the Wave 1
//  Swift PSBookmark / PSBookmarkFolder / PSBookmarks model and the Swift
//  PSBookmarksNavigatorController (created when the user taps the folder row).
//  The remaining Obj-C++ caller (PSModuleViewController.mm) creates this VC via
//  -initWithBookmarkToEdit:parentFolders: and
//  -initWithBookAndChapterRef:andVerse: through PocketSword-Swift.h, so the public
//  initializers keep their original selectors and the class keeps its Obj-C name
//  PSBookmarksAddTableViewController.
//
//  Originally created by Nic Carter on 10/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSBookmarksAddTableViewController)
final class PSBookmarksAddTableViewController: UITableViewController, UITextFieldDelegate {

    @objc var bookAndChapterRef: String?
    @objc var verse: String?
    @objc var folder: String?
    @objc var originalFolder: String?
    @objc var bookmarkBeingEdited: PSBookmark?

    private var descriptionTextField: UITextField!

    // MARK: - Initialization

    // used to add a bookmark:
    @objc(initWithBookAndChapterRef:andVerse:)
    init(bookAndChapterRef ref: String?, andVerse v: String?) {
        super.init(style: .grouped)
        self.bookAndChapterRef = ref
        self.verse = v
        self.folder = nil
        self.originalFolder = nil
        self.bookmarkBeingEdited = nil
    }

    // used to edit a bookmark:
    @objc(initWithBookmarkToEdit:parentFolders:)
    init(bookmarkToEdit: PSBookmark?, parentFolders folders: String?) {
        super.init(style: .grouped)
        self.bookAndChapterRef = nil
        self.verse = nil
        self.folder = folders
        self.originalFolder = folders
        self.bookmarkBeingEdited = bookmarkToEdit
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        var fieldFrames = CGRect(x: 20, y: 12, width: 280, height: 25)
        if PSResizing.iPad() {
            // different frames for the iPad
            fieldFrames = CGRect(x: 60, y: 12, width: 560, height: 25)
        }

        descriptionTextField = UITextField(frame: fieldFrames)
        descriptionTextField.placeholder = ""
        descriptionTextField.autocapitalizationType = .sentences
        descriptionTextField.delegate = self
        descriptionTextField.keyboardType = .default
        descriptionTextField.returnKeyType = .done
        if let bookmarkBeingEdited = bookmarkBeingEdited {
            descriptionTextField.text = bookmarkBeingEdited.name
        }

        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveButtonPressed))
        navigationItem.rightBarButtonItem = saveButton
        if bookmarkBeingEdited == nil {
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
            navigationItem.leftBarButtonItem = cancelButton
            navigationItem.title = NSLocalizedString("VerseContextualMenuAddBookmark", comment: "Add Bookmark")
        } else {
            navigationItem.title = NSLocalizedString("BookmarkEditBookmarkTitle", comment: "Edit Bookmark")
        }

        NotificationCenter.default.addObserver(self, selector: #selector(folderUpdated(_:)), name: NSNotification.Name(NotificationAddBookmarkInFolder), object: nil)
    }

    @objc func cancelButtonPressed() {
        // this button only exists if we're adding a bookmark, so it's ok to only do this.
        dismiss(animated: true, completion: nil)
    }

    @objc func saveButtonPressed() {
        var valid = true
        if let bookmarkBeingEdited = bookmarkBeingEdited, bookmarkBeingEdited.name == descriptionTextField.text {
            // tis ok.
        } else {
            for case let childFolder as PSBookmarkFolder in (PSBookmarks.getBookmarkFolder(forFolderString: self.folder).children ?? []) {
                if childFolder.name == descriptionTextField.text {
                    valid = false
                    break
                }
            }
        }
        if !valid {
            let alert = UIAlertController(title: NSLocalizedString("BookmarksDuplicateBookmarkTitle", comment: ""), message: NSLocalizedString("BookmarksDuplicateBookmarkMessage", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: "Ok"), style: .cancel) { [weak self] _ in
                self?.descriptionTextField.becomeFirstResponder()
            })
            present(alert, animated: true, completion: nil)
            return
        }

        if let bookmarkBeingEdited = bookmarkBeingEdited {
            var description = descriptionTextField.text ?? ""
            if description == "" {
                description = bookmarkBeingEdited.ref ?? ""
            }
            let newBookmark = PSBookmark(name: description, dateAdded: bookmarkBeingEdited.dateAdded, dateLastAccessed: Date(), bibleReference: bookmarkBeingEdited.ref)
            PSBookmarks.deleteBookmark(bookmarkBeingEdited.name ?? "", fromFolderString: self.originalFolder)
            _ = PSBookmarks.addBookmarkObject(newBookmark, withFolderString: self.folder)

            let fullRef = (bookmarkBeingEdited.ref ?? "").components(separatedBy: ":")
            let ref = fullRef.first ?? ""
            if PSModuleController.createRefString(PSModuleController.getCurrentBibleRef()) == ref {
                NotificationCenter.default.post(name: NSNotification.Name(NotificationBookmarksChanged), object: nil)
            }

            navigationController?.popViewController(animated: true)
        } else {
            let ref = "\(bookAndChapterRef ?? ""):\(verse ?? "")"
            var description = ref
            if let text = descriptionTextField.text, text != "" {
                description = text
            }
            _ = PSBookmarks.addBookmark(withRef: ref, name: description, folderString: folder)
            if PSModuleController.createRefString(PSModuleController.getCurrentBibleRef()) == bookAndChapterRef {
                NotificationCenter.default.post(name: NSNotification.Name(NotificationBookmarksChanged), object: nil)
            }
            dismiss(animated: true, completion: nil)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @objc func folderUpdated(_ notification: Notification) {
        //DLog(@"%@", [notification object]);
        self.folder = notification.object as? String
        tableView.reloadSections(IndexSet(integer: 2), with: .fade)
        navigationController?.popToViewController(self, animated: true)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        if bookmarkBeingEdited != nil {
            return 5
        } else {
            return 3
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("BookmarksAddBookmarkVerseTitle", comment: "")
        case 1:
            return NSLocalizedString("BookmarksAddBookmarkDescriptionTitle", comment: "")
        case 2:
            return NSLocalizedString("BookmarksAddBookmarkFolderTitle", comment: "")
        case 3:
            return NSLocalizedString("BookmarksCreatedTitle", comment: "")
        case 4:
            return NSLocalizedString("BookmarksLastAccessedTitle", comment: "")
        default:
            break
        }
        return ""
    }

    // Customize the appearance of table view cells.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cellIdentifier = "Cell-\(indexPath.section)"

        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
            if indexPath.section == 1 {
                cell?.addSubview(descriptionTextField)
            }
        }

        // Configure the cell...
        switch indexPath.section {
        case 0:
            if let bookmarkBeingEdited = bookmarkBeingEdited {
                cell?.textLabel?.text = bookmarkBeingEdited.ref
            } else {
                cell?.textLabel?.text = "\(bookAndChapterRef ?? ""):\(verse ?? "")"
            }
            cell?.selectionStyle = .none
        case 1:
            if let bookmarkBeingEdited = bookmarkBeingEdited {
                descriptionTextField.placeholder = bookmarkBeingEdited.ref
            } else {
                descriptionTextField.placeholder = "\(bookAndChapterRef ?? ""):\(verse ?? "")"
            }
            cell?.selectionStyle = .none
        case 2:
            if let folder = folder {
                cell?.textLabel?.lineBreakMode = .byTruncatingHead
                cell?.textLabel?.text = folder.replacingOccurrences(of: AppConstants.folderSeparatorString, with: "/")
            } else {
                cell?.textLabel?.text = NSLocalizedString("BookmarksTitle", comment: "")
            }
            cell?.accessoryType = .disclosureIndicator
        case 3:
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .full
            if let dateAdded = bookmarkBeingEdited?.dateAdded {
                cell?.textLabel?.text = dateFormatter.string(from: dateAdded)
            }
            cell?.selectionStyle = .none
        case 4:
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .full
            if let dateLastAccessed = bookmarkBeingEdited?.dateLastAccessed {
                cell?.textLabel?.text = dateFormatter.string(from: dateLastAccessed)
            }
            cell?.selectionStyle = .none
        default:
            break
        }

        return cell!
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            descriptionTextField.becomeFirstResponder()
        } else if indexPath.section == 2 {
            if folder == nil {
                let bnc = PSBookmarksNavigatorController(bookmarkFolder: PSBookmarks.default(), parentFolders: nil, isAddingBookmark: true)
                navigationController?.pushViewController(bnc, animated: true)
            } else {
                let components = (folder ?? "").components(separatedBy: AppConstants.folderSeparatorString)
                // push the root of our bookmarks:
                var bnc = PSBookmarksNavigatorController(bookmarkFolder: PSBookmarks.default(), parentFolders: nil, isAddingBookmark: true)
                navigationController?.pushViewController(bnc, animated: false)
                let currentFolder = NSMutableString(string: components[0])
                var i = 0
                while i < components.count {
                    var animate = false
                    if i == (components.count - 1) {
                        animate = true
                    }
                    bnc = PSBookmarksNavigatorController(bookmarkFolder: PSBookmarks.getBookmarkFolder(forFolderString: currentFolder as String), parentFolders: currentFolder as String, isAddingBookmark: true)
                    navigationController?.pushViewController(bnc, animated: animate)
                    i += 1
                    if i < components.count {
                        currentFolder.appendFormat("%@%@", AppConstants.folderSeparatorString, components[i])
                    }
                }
                self.folder = nil // reset the folder to the root.
            }
        }
    }

    // MARK: - Memory management

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
