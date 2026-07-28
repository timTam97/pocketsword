//
//  PSVoiceRefViewController.swift
//  PocketSword
//

import UIKit

@MainActor
final class PSVoiceRefViewController: UIViewController, PSVoiceRefSessionDelegate {
    var onReferenceResolved: ((PSParsedRef) -> Void)?

    private let parser: PSVoiceRefParser
    private let contextualStrings: [String]
    private var session: PSVoiceRefSession?
    private var hasStarted = false
    private var pendingReference: PSParsedRef?

    private let micImageView = UIImageView(
        image: UIImage(systemName: "microphone",
                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 38,
                                                                      weight: .medium))
    )
    private let statusLabel = UILabel()
    private let transcriptLabel = UILabel()
    private let previewLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let actionButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    init() {
        let books = Self.makeGazetteer()
        parser = PSVoiceRefParser(books: books)
        contextualStrings = Self.makeContextualStrings(from: books)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        preferredContentSize = CGSize(width: 420, height: 280)
    }

    required init?(coder: NSCoder) {
        let books = Self.makeGazetteer()
        parser = PSVoiceRefParser(books: books)
        contextualStrings = Self.makeContextualStrings(from: books)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureViews()
        configureLayout()
        resetForListening()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        beginSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.cancel()
        session = nil
    }

    func voiceRefSession(_ session: PSVoiceRefSession,
                         didChangeState state: PSVoiceRefSession.State) {
        guard session === self.session else { return }

        switch state {
        case .requestingPermission, .checkingAssets, .preparing:
            stopListeningAnimation()
            statusLabel.text = NSLocalizedString("VoiceRefPrompt", comment: "")
            transcriptLabel.text = ""
            previewLabel.text = ""
            progressView.isHidden = true
            actionButton.isHidden = true

        case .downloadingModel(let progress):
            stopListeningAnimation()
            statusLabel.text = NSLocalizedString("VoiceRefDownloadingModel", comment: "")
            transcriptLabel.text = ""
            previewLabel.text = ""
            progressView.observedProgress = progress
            progressView.isHidden = false
            actionButton.isHidden = true

        case .listening(let volatileText):
            startListeningAnimation()
            statusLabel.text = NSLocalizedString("VoiceRefListening", comment: "")
            transcriptLabel.text = volatileText.isEmpty
                ? NSLocalizedString("VoiceRefPrompt", comment: "")
                : volatileText
            updatePreview(for: volatileText)
            progressView.isHidden = true
            configureAction(title: NSLocalizedString("Done", comment: ""),
                            selector: #selector(doneTapped),
                            visible: !volatileText.isEmpty)

        case .finalizing:
            stopListeningAnimation()
            statusLabel.text = NSLocalizedString("VoiceRefListening", comment: "")
            actionButton.isEnabled = false

        case .finished(let candidates):
            stopListeningAnimation()
            actionButton.isEnabled = true
            handleFinished(candidates: candidates)

        case .failed(let error):
            stopListeningAnimation()
            actionButton.isEnabled = true
            show(error: error)
        }
    }

    private func configureViews() {
        micImageView.tintColor = .systemBlue
        micImageView.contentMode = .scaleAspectFit
        micImageView.setContentHuggingPriority(.required, for: .vertical)
        micImageView.isAccessibilityElement = false

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontForContentSizeCategory = true

        transcriptLabel.font = .preferredFont(forTextStyle: .headline)
        transcriptLabel.textColor = .label
        transcriptLabel.textAlignment = .center
        transcriptLabel.numberOfLines = 2
        transcriptLabel.adjustsFontForContentSizeCategory = true

        previewLabel.font = .preferredFont(forTextStyle: .subheadline)
        previewLabel.textColor = .systemGreen
        previewLabel.textAlignment = .center
        previewLabel.numberOfLines = 1
        previewLabel.adjustsFontForContentSizeCategory = true

        progressView.isHidden = true

        var actionConfiguration = UIButton.Configuration.filled()
        actionConfiguration.cornerStyle = .small
        actionButton.configuration = actionConfiguration
        actionButton.isHidden = true

        var cancelConfiguration = UIButton.Configuration.plain()
        cancelConfiguration.title = NSLocalizedString("Cancel", comment: "")
        cancelConfiguration.cornerStyle = .small
        cancelButton.configuration = cancelConfiguration
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func configureLayout() {
        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, actionButton])
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12

        let stack = UIStackView(arrangedSubviews: [
            micImageView,
            statusLabel,
            transcriptLabel,
            previewLabel,
            progressView,
            buttonStack
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 9
        stack.setCustomSpacing(14, after: progressView)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                                           constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                                            constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                       constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                                          constant: -16),
            micImageView.heightAnchor.constraint(equalToConstant: 44),
            transcriptLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 42),
            previewLabel.heightAnchor.constraint(equalToConstant: 20),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            buttonStack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func beginSession() {
        let session = PSVoiceRefSession(contextualStrings: contextualStrings)
        session.delegate = self
        self.session = session
        session.start()
    }

    private func resetForListening() {
        pendingReference = nil
        stopListeningAnimation()
        statusLabel.text = NSLocalizedString("VoiceRefPrompt", comment: "")
        transcriptLabel.text = ""
        previewLabel.text = ""
        previewLabel.textColor = .systemGreen
        progressView.observedProgress = nil
        progressView.isHidden = true
        actionButton.isEnabled = true
        actionButton.isHidden = true
    }

    private func updatePreview(for transcript: String) {
        guard !transcript.isEmpty,
              let parsed = parser.parse(candidate: transcript) else {
            previewLabel.text = ""
            return
        }
        previewLabel.text = formatted(parsed)
    }

    private func handleFinished(candidates: [String]) {
        guard let parsed = parser.parse(candidates: candidates) else {
            statusLabel.text = NSLocalizedString("VoiceRefNoMatch", comment: "")
            transcriptLabel.text = candidates.first ?? ""
            previewLabel.text = ""
            progressView.isHidden = true
            configureAction(title: NSLocalizedString("VoiceRefTryAgain", comment: ""),
                            selector: #selector(tryAgainTapped),
                            visible: true)
            return
        }

        pendingReference = parsed
        statusLabel.text = ""
        transcriptLabel.text = formatted(parsed)
        previewLabel.text = ""
        progressView.isHidden = true
        actionButton.isHidden = true
        cancelButton.isHidden = true

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, let reference = self.pendingReference else { return }
            self.dismiss(animated: true) {
                self.onReferenceResolved?(reference)
            }
        }
    }

    private func show(error: PSVoiceRefError) {
        progressView.observedProgress = nil
        progressView.isHidden = true
        previewLabel.text = ""

        switch error {
        case .microphoneDenied:
            statusLabel.text = NSLocalizedString("VoiceRefMicDenied", comment: "")
            transcriptLabel.text = ""
            configureAction(title: NSLocalizedString("VoiceRefOpenSettings", comment: ""),
                            selector: #selector(openSettingsTapped),
                            visible: true)

        case .unsupportedLocale, .noAudioInput, .speechAssetsUnavailable:
            statusLabel.text = NSLocalizedString("VoiceRefUnavailable", comment: "")
            transcriptLabel.text = ""
            actionButton.isHidden = true

        case .modelDownloadFailed, .audioSessionFailed, .recognitionFailed, .audioInterrupted:
            statusLabel.text = NSLocalizedString("VoiceRefUnavailable", comment: "")
            transcriptLabel.text = ""
            configureAction(title: NSLocalizedString("VoiceRefTryAgain", comment: ""),
                            selector: #selector(tryAgainTapped),
                            visible: true)
        }
    }

    private func configureAction(title: String, selector: Selector, visible: Bool) {
        actionButton.removeTarget(nil, action: nil, for: .allEvents)
        actionButton.configuration?.title = title
        actionButton.addTarget(self, action: selector, for: .touchUpInside)
        actionButton.isHidden = !visible
    }

    private func formatted(_ reference: PSParsedRef) -> String {
        "\(reference.displayBookName) \(reference.chapter):\(reference.verse)"
    }

    private func startListeningAnimation() {
        guard micImageView.layer.animation(forKey: "voiceRefPulse") == nil else { return }
        micImageView.addSymbolEffect(.variableColor.iterative,
                                     options: .repeat(.continuous))
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.94
        pulse.toValue = 1.06
        pulse.duration = 0.75
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        micImageView.layer.add(pulse, forKey: "voiceRefPulse")
    }

    private func stopListeningAnimation() {
        micImageView.removeAllSymbolEffects()
        micImageView.layer.removeAnimation(forKey: "voiceRefPulse")
    }

    @objc private func doneTapped() {
        actionButton.isEnabled = false
        session?.finish()
    }

    @objc private func cancelTapped() {
        session?.cancel()
        dismiss(animated: true)
    }

    @objc private func tryAgainTapped() {
        session?.cancel()
        session = nil
        cancelButton.isHidden = false
        resetForListening()
        beginSession()
    }

    @objc private func openSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// SWORD_REMOVAL_PLAN.md Phase 4: the gazetteer is built from the baked
    /// versification table rather than from `+[SwordManager
    /// booksForVersificationSystem:]` over a live `sword::VersificationMgr`. The
    /// same three name forms per book, in the same order, so the parser's alias
    /// table is unchanged.
    ///
    /// Two things this fixes for free, both consequences of `PSVersificationBook`
    /// being a value type where `SwordBook` was a reference:
    ///
    ///  - **Lifetime.** `versesInChapter` is an escaping closure that used to
    ///    capture the `SwordBook` object and, through it, a raw
    ///    `const VersificationMgr::Book *` ivar whose lifetime nothing here owned.
    ///    A struct capture has no such hazard.
    ///  - **Bounds.** `-verses:` answered SWORD's **-1** sentinel for an
    ///    out-of-range chapter, and `PSVoiceRefParser` tests that count with
    ///    `verseCount > 0, (1...verseCount).contains(verse)` — so -1 was already
    ///    rejected, but only by accident of the comparison. Returning 0 makes the
    ///    reject explicit (PSVoiceRefParser.swift:96 treats 0 as reject).
    private static func makeGazetteer() -> [PSVoiceRefBook] {
        guard let resolver = PSBookOSISResolver.shared else { return [] }
        return resolver.books.compactMap { book in
            let displayName = book.name
            guard !displayName.isEmpty else { return nil }
            let names = [book.name, book.shortName, book.osisName]
                .filter { !$0.isEmpty }
            return PSVoiceRefBook(
                names: names,
                displayName: displayName,
                chapters: book.chapterCount,
                versesInChapter: { chapter in
                    resolver.verseMax(book: book, chapter: chapter) ?? 0
                }
            )
        }
    }

    // Bias the recognizer toward the spoken book names. We deliberately use the
    // full display names only — abbreviations ("SongSol", "1Jn") aren't spoken
    // words, and number words are already in the system vocabulary, so neither
    // helps as a contextual hint. Apple recommends keeping the list under 100
    // phrases; the canon fits well within that.
    private static func makeContextualStrings(from books: [PSVoiceRefBook]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for book in books {
            let name = book.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            result.append(name)
        }
        return Array(result.prefix(100))
    }
}
