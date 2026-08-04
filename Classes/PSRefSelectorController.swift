//
//  PSRefSelectorController.swift
//  PocketSword
//
//  Temporary UIKit host for the SwiftUI reference picker. The surrounding tab
//  coordinator remains UIKit until the app-lifecycle cutover, while the picker
//  owns book, chapter, and verse navigation in SwiftUI.
//

import SwiftUI
import UIKit

@objc(PSRefSelectorController)
@MainActor
final class PSRefSelectorController: UIHostingController<ReferencePickerView> {
    private let model: ReferencePickerModel

    init() {
        let model = ReferencePickerModel()
        self.model = model
        super.init(rootView: ReferencePickerView(model: model))
        configureModelCallbacks()
        configureNotifications()
    }

    required init?(coder: NSCoder) {
        let model = ReferencePickerModel()
        self.model = model
        super.init(
            coder: coder,
            rootView: ReferencePickerView(model: model)
        )
        configureModelCallbacks()
        configureNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func resetBooks(_ notification: Notification) {
        model.clearBooks()
    }

    @objc func dismissNavigation() {
        NotificationCenter.default.post(name: .toggleNavigation, object: nil)
    }

    @objc func setupNavigation() {
        preferredContentSize = CGSize(width: 540, height: 1100)
        model.showsCancel = !PSResizing.iPad()
        reloadBooksAndSelection()
    }

    @objc func willShowNavigation() {
        model.updateCurrentReference(
            PSModuleController.getCurrentBibleRef()
        )
    }

    private func configureNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetBooks(_:)),
            name: .refSelectorResetBooks,
            object: nil
        )
    }

    private func configureModelCallbacks() {
        model.onCancel = { [weak self] in
            self?.dismissNavigation()
        }
        model.onSelection = { [weak self] selection in
            self?.select(selection)
        }
    }

    private func reloadBooksAndSelection() {
        let books = (PSBookOSISResolver.shared?.books ?? [])
            .map(ReferencePickerBook.init)
        model.reload(
            books: books,
            currentReference: PSModuleController.getCurrentBibleRef()
        )
    }

    private func select(_ selection: ReferencePickerSelection) {
        NotificationCenter.default.post(name: .toggleNavigation, object: nil)
        let payload = [
            AppConstants.bookNameString: selection.bookName,
            AppConstants.chapterString: String(selection.chapter),
            AppConstants.verseString: String(selection.verse),
        ]
        NotificationCenter.default.post(
            name: .updateSelectedReference,
            object: payload
        )
    }
}
