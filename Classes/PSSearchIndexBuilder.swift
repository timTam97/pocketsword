//
//  PSSearchIndexBuilder.swift
//  PocketSword
//
//  Ported to Swift (Wave 3). Modal sheet that builds the FTS5 search index for
//  a module. Replaces the crosswire.org-download flow that used to live in
//  PSIndexController.
//
//  This VC owns the progress UI and a UIBackgroundTask; the sqlite3 / FTS5
//  index-build itself is PSSearchEngine's job (`build(progress:)`). That engine was
//  Obj-C++ when this file was written and the Swift-migration plan expected it to
//  stay that way; SWORD_REMOVAL_PLAN.md Phase 5 step 8 ported it, so the whole path
//  is Swift now.
//
//  The public surface is preserved verbatim from the Obj-C original: the @objc class
//  name PSSearchIndexBuilder, the -initWithModuleName: / -presentFromViewController:
//  methods, the readonly `moduleName` property, and the @objc
//  PSSearchIndexBuilderDelegate protocol (kept @objc per migration-plan risk R11).
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

    private let indexCoordinator: SearchIndexCoordinator
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var buildFinished = false

    private var titleLabel: UILabel!
    private var moduleLabel: UILabel!
    private var progressView: UIProgressView!
    private var cancelButton: UIButton!

    @objc convenience init(moduleName: String) {
        self.init(
            moduleName: moduleName,
            indexCoordinator: SearchIndexCoordinator()
        )
    }

    init(
        moduleName: String,
        indexCoordinator: SearchIndexCoordinator
    ) {
        self.moduleName = moduleName
        self.indexCoordinator = indexCoordinator
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
        indexCoordinator.cancel()
        cancelButton.isEnabled = false
        titleLabel.text = NSLocalizedString("SearchBuildingCancellingLabel", comment: "Cancelling…")
    }

    private func startBuild() {
        // Register a background task so iOS gives us ~30s to finish if the user
        // backgrounds the app mid-build. Expiration flips the cancel flag so we
        // tear down cleanly rather than getting killed with a half-written DB.
        bgTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            DispatchQueue.main.async {
                self?.indexCoordinator.cancel()
            }
        }

        indexCoordinator.onStateChange = { [weak self] state in
            guard let self else { return }
            if case .building(let progress) = state {
                self.progressView.progress = progress
            }
        }
        indexCoordinator.onCompletion = { [weak self] success, cancelled in
            self?.finish(success: success, cancelled: cancelled)
        }
        indexCoordinator.build(module: moduleName)
    }

    private func finish(success: Bool, cancelled: Bool) {
        if buildFinished { return }
        buildFinished = true

        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        let delegate = self.delegate
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            delegate?.indexBuilder(self, didFinishWithSuccess: success, cancelled: cancelled)
        }
    }
}
