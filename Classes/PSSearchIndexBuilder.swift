//
//  PSSearchIndexBuilder.swift
//  PocketSword
//
//  Ported to Swift (Wave 3). Modal sheet that builds the FTS5 search index for
//  a module. Replaces the crosswire.org-download flow that used to live in
//  PSIndexController.
//
//  This VC owns the progress UI and a UIBackgroundTask; it drives the
//  still-Obj-C++ PSSearchEngine via its clean Foundation-only facade
//  (-buildWithProgress:error:). The C++ / sqlite3 / FTS5 index-build path stays
//  in PSSearchEngine.mm permanently per the migration plan.
//
//  The public surface is preserved verbatim for the (still Obj-C++) consumer
//  PSModuleSearchController: the @objc class name PSSearchIndexBuilder, the
//  -initWithModuleName: / -presentFromViewController: methods, the readonly `moduleName`
//  property, and the @objc PSSearchIndexBuilderDelegate protocol (kept @objc so
//  the Obj-C conformer binds, per migration-plan risk R11).
//

import UIKit

@objc(PSSearchIndexBuilderDelegate)
protocol PSSearchIndexBuilderDelegate: NSObjectProtocol {
    @objc func indexBuilder(_ builder: PSSearchIndexBuilder, didFinishWithSuccess success: Bool, cancelled: Bool)
}

@objc(PSSearchIndexBuilder)
final class PSSearchIndexBuilder: UIViewController {

    @objc weak var delegate: PSSearchIndexBuilderDelegate?
    /// The module being indexed, as a **name** (Phase 5 step 5). It was a
    /// `SwordModule`, used only for its `name` (the sheet's subtitle) and to key the
    /// search engine — both of which take a name now.
    @objc private(set) var moduleName: String

    // Set from the main thread (cancel button / bg-task expiration) and read
    // from the build worker thread inside the progress block. Guarded by a lock
    // to replace the original `volatile BOOL` with a memory-safe equivalent.
    private let cancelLock = NSLock()
    private var _cancelRequested = false
    private var cancelRequested: Bool {
        get { cancelLock.lock(); defer { cancelLock.unlock() }; return _cancelRequested }
        set { cancelLock.lock(); _cancelRequested = newValue; cancelLock.unlock() }
    }

    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var buildFinished = false

    private var titleLabel: UILabel!
    private var moduleLabel: UILabel!
    private var progressView: UIProgressView!
    private var cancelButton: UIButton!

    @objc init(moduleName: String) {
        self.moduleName = moduleName
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
        self.isModalInPresentation = true // disallow pull-to-dismiss mid-build
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        view.addSubview(stack)

        titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("SearchBuildingIndexTitle", comment: "Building search index…")
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        moduleLabel = UILabel()
        moduleLabel.text = moduleName
        moduleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        moduleLabel.textColor = .secondaryLabel
        moduleLabel.textAlignment = .center
        stack.addArrangedSubview(moduleLabel)

        progressView = UIProgressView(progressViewStyle: .default)
        stack.addArrangedSubview(progressView)

        cancelButton = UIButton(type: .system)
        cancelButton.setTitle(NSLocalizedString("CancelButtonTitle", comment: "Cancel"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        stack.addArrangedSubview(cancelButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
    }

    /// Presents the builder modally over `presenter` as a medium-detent sheet
    /// and starts the background build.
    @objc(presentFromViewController:) func present(from presenter: UIViewController) {
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
        }
        presenter.present(self, animated: true) { [weak self] in
            self?.startBuild()
        }
    }

    @objc private func cancelTapped() {
        cancelRequested = true
        cancelButton.isEnabled = false
        titleLabel.text = NSLocalizedString("SearchBuildingCancellingLabel", comment: "Cancelling…")
    }

    private func startBuild() {
        // Register a background task so iOS gives us ~30s to finish if the user
        // backgrounds the app mid-build. Expiration flips the cancel flag so we
        // tear down cleanly rather than getting killed with a half-written DB.
        bgTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.cancelRequested = true
        }

        let engine = PSSearchEngine(forModuleName: moduleName)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var err: NSError?
            let ok: Bool
            do {
                try engine.build(progress: { fraction, cancel in
                    cancel.pointee = ObjCBool(self?.cancelRequested ?? true)
                    DispatchQueue.main.async {
                        self?.progressView.progress = fraction
                    }
                })
                ok = true
            } catch let buildErr as NSError {
                err = buildErr
                ok = false
            }

            let cancelled = self?.cancelRequested ?? true
            DispatchQueue.main.async {
                self?.finish(success: ok, cancelled: cancelled, error: err)
            }
        }
    }

    private func finish(success: Bool, cancelled: Bool, error: NSError?) {
        if buildFinished { return }
        buildFinished = true

        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        if !success && !cancelled, let error = error {
            alog("PSSearchIndexBuilder: build failed: \(error)")
        }

        let delegate = self.delegate
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            delegate?.indexBuilder(self, didFinishWithSuccess: success, cancelled: cancelled)
        }
    }
}
