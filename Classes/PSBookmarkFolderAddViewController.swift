//
//  PSBookmarkFolderAddViewController.swift
//  PocketSword
//
//  Ported to Swift (Wave 2). Grouped form for adding or editing a bookmark
//  folder:
//    section 0: name (a UITextField hosted in the cell)
//    section 1: highlight colour (defaults to "None >"; tap to pick a colour)
//    section 2: (edit mode only) created date
//  The right nav-bar item is a Save button.
//
//  Behaviour preserved byte-for-byte from PSBookmarkFolderAddViewController.{h,m}.
//  Consumes the Swift PSBookmarkFolderColourSelectorViewController (Wave 2) and
//  conforms to its (@objc) PSBookmarkFolderColourSelectorDelegate, plus the Swift
//  PSBookmarkFolder / PSBookmarks model (Wave 1). The remaining Obj-C caller
//  (PSBookmarksNavigatorController.mm) creates this VC via
//  -initWithParentFolder:bookmarkFolderToEdit: through PocketSword-Swift.h, so the
//  public initializer keeps its original selector.
//
//  Originally created by Nic Carter on 14/01/11.
//  Copyright 2011 CrossWire Bible Society. All rights reserved.
//

import UIKit

@objc(PSBookmarkFolderAddViewController)
final class PSBookmarkFolderAddViewController: UITableViewController, PSBookmarkFolderColourSelectorDelegate, UITextFieldDelegate {

    @objc var parentFolder: String?
    @objc var rgbHexString: String?
    @objc var bookmarkFolderBeingEdited: PSBookmarkFolder?

    private var nameTextField: UITextField!

    // MARK: - Initialization

    // if bookmarkFolder is nil, we're creating a new folder,
    // otherwise, we're editing an existing folder.
    @objc(initWithParentFolder:bookmarkFolderToEdit:)
    init(parentFolder folder: String?, bookmarkFolderToEdit bookmarkFolder: PSBookmarkFolder?) {
        super.init(style: .grouped)
        self.parentFolder = folder
        self.bookmarkFolderBeingEdited = bookmarkFolder
        if let bookmarkFolder = bookmarkFolder {
            self.rgbHexString = bookmarkFolder.rgbHexString
        } else {
            self.rgbHexString = nil
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveButtonPressed))
        navigationItem.rightBarButtonItem = saveButton

        var fieldFrames = CGRect(x: 20, y: 12, width: 280, height: 25)
        if PSResizing.iPad() {
            // different frames for the iPad
            fieldFrames = CGRect(x: 60, y: 12, width: 560, height: 25)
        }

        nameTextField = UITextField(frame: fieldFrames)
        nameTextField.placeholder = ""
        nameTextField.autocapitalizationType = .sentences
        nameTextField.delegate = self
        nameTextField.keyboardType = .default
        nameTextField.returnKeyType = .done
        if let bookmarkFolderBeingEdited = bookmarkFolderBeingEdited {
            nameTextField.text = bookmarkFolderBeingEdited.name
            navigationItem.title = NSLocalizedString("BookmarksEditFolderTitle", comment: "Edit Folder")
        } else {
            navigationItem.title = NSLocalizedString("BookmarksAddFolderButton", comment: "Add Folder")
        }
    }

    @objc func saveButtonPressed() {
        let folderName = nameTextField.text ?? ""
        // check for a duplicate folder name:
        let parentFolderObject = PSBookmarks.getBookmarkFolder(forFolderString: self.parentFolder)
        var valid = true
        if let bookmarkFolderBeingEdited = bookmarkFolderBeingEdited, bookmarkFolderBeingEdited.name == folderName {
            // tis ok.
        } else {
            for case let childFolder as PSBookmarkFolder in (parentFolderObject.children ?? []) {
                if childFolder.name == folderName {
                    valid = false
                    break
                }
            }
        }
        if !valid {
            let alert = UIAlertController(title: NSLocalizedString("BookmarksDuplicateFolderTitle", comment: ""), message: NSLocalizedString("BookmarksDuplicateFolderMessage", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: "Ok"), style: .cancel) { [weak self] _ in
                self?.nameTextField.becomeFirstResponder()
            })
            present(alert, animated: true, completion: nil)
            return
        }
        // check for an invalid folder name (ie: contains PSFolderSeparatorString):
        let position = (folderName as NSString).range(of: AppConstants.folderSeparatorString)
        if position.location != NSNotFound {
            let alert = UIAlertController(title: NSLocalizedString("BookmarksInvalidFolderTitle", comment: ""), message: NSLocalizedString("BookmarksInvalidFolderMessage", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: "Ok"), style: .cancel) { [weak self] _ in
                self?.nameTextField.becomeFirstResponder()
            })
            present(alert, animated: true, completion: nil)
            return
        }

        if let bookmarkFolderBeingEdited = bookmarkFolderBeingEdited {
            // save the edited details of the bookmark folder.
            bookmarkFolderBeingEdited.name = folderName
            bookmarkFolderBeingEdited.rgbHexString = self.rgbHexString
            _ = PSBookmarks.saveBookmarksToFile()
        } else {
            // add new folder to the bookmarks.
            let folder = PSBookmarkFolder(name: folderName, dateAdded: Date(), dateLastAccessed: Date(), rgbHexString: rgbHexString, children: nil)
            _ = PSBookmarks.addBookmarkObject(folder, withFolderString: self.parentFolder)
        }
        navigationController?.popViewController(animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        if bookmarkFolderBeingEdited != nil {
            return 3
        } else {
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("BookmarksAddFolderFolderName", comment: "")
        case 1:
            return NSLocalizedString("BookmarksAddFolderHighlightColour", comment: "")
        case 2:
            return NSLocalizedString("BookmarksCreatedTitle", comment: "")
        default:
            break
        }
        return ""
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 1, let rgbHexString = rgbHexString {
            cell.backgroundColor = PSBookmarkFolder.color(fromHexString: rgbHexString)
        } else {
            cell.backgroundColor = UIColor.systemBackground
        }
    }

    // Customize the appearance of table view cells.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cellIdentifier = "Cell-\(indexPath.section)"

        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
            if indexPath.section == 0 {
                cell?.addSubview(nameTextField)
            }
        }

        // Configure the cell...
        if indexPath.section == 0 {
            cell?.selectionStyle = .none
        } else if indexPath.section == 1 {
            if rgbHexString != nil {
                cell?.textLabel?.text = ""
            } else {
                cell?.textLabel?.text = NSLocalizedString("None", comment: "None")
            }
            cell?.accessoryType = .disclosureIndicator
        } else if indexPath.section == 2 {

            var dateString = ""
            if let bookmarkFolderBeingEdited = bookmarkFolderBeingEdited, let dateAdded = bookmarkFolderBeingEdited.dateAdded {
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = .short
                dateFormatter.dateStyle = .full
                dateString = dateFormatter.string(from: dateAdded)
            }
            cell?.textLabel?.text = dateString
            cell?.selectionStyle = .none
        }

        return cell!
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            nameTextField.becomeFirstResponder()
        } else if indexPath.section == 1 {
            nameTextField.resignFirstResponder()
            let csvc = PSBookmarkFolderColourSelectorViewController(colorString: self.rgbHexString, delegate: self)
            navigationController?.pushViewController(csvc, animated: true)
        }
    }

    func rgbHexColorStringDidChange(_ newColorHexString: String?) {
        self.rgbHexString = newColorHexString
        tableView.reloadData()
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Memory management

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
