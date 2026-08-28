//
//  VoiceReferenceModel.swift
//  PocketSword
//
//  The observable state behind the voice-reference sheet: it maps
//  `PSVoiceRefSession`'s states onto what the view shows, and parses each
//  candidate transcript through `PSVoiceRefParser`.
//
//  Wave 8 renamed this file out of `PSVoiceRefViewController.swift` and deleted the
//  `UIHostingController` subclass that shared it. That subclass did two things —
//  set a 320pt `pageSheet` detent and forward two closures — both of which are
//  modifiers on the `.sheet` in `VoiceReferenceSheet` (SwiftUIStudyViews.swift).
//  The session and the parser are untouched.
//

import Foundation
import Observation
import SwiftUI

enum VoiceReferenceStatus: Equatable {
    case none
    case prompt
    case listening
    case downloading
    case noMatch
    case microphoneDenied
    case unavailable

    var text: LocalizedStringResource? {
        switch self {
        case .none:
            nil
        case .prompt:
            "VoiceRefPrompt"
        case .listening:
            "VoiceRefListening"
        case .downloading:
            "VoiceRefDownloadingModel"
        case .noMatch:
            "VoiceRefNoMatch"
        case .microphoneDenied:
            "VoiceRefMicDenied"
        case .unavailable:
            "VoiceRefUnavailable"
        }
    }
}

enum VoiceReferenceTranscript: Equatable {
    case empty
    case prompt
    case value(String)
}

enum VoiceReferenceAction: Equatable {
    case none
    case done
    case tryAgain
    case openSettings

    var title: LocalizedStringResource? {
        switch self {
        case .none:
            nil
        case .done:
            "Done"
        case .tryAgain:
            "VoiceRefTryAgain"
        case .openSettings:
            "VoiceRefOpenSettings"
        }
    }
}

@MainActor
@Observable
final class VoiceReferenceModel: PSVoiceRefSessionDelegate {
    typealias SessionFactory = @MainActor ([String]) -> PSVoiceRefSession

    private(set) var status: VoiceReferenceStatus = .prompt
    private(set) var transcript: VoiceReferenceTranscript = .empty
    private(set) var preview = ""
    private(set) var downloadProgress: Progress?
    private(set) var isListening = false
    private(set) var action: VoiceReferenceAction = .none
    private(set) var isActionEnabled = true
    private(set) var showsCancel = true

    @ObservationIgnored var onCancel: (() -> Void)?
    @ObservationIgnored var onReferenceResolved: ((PSParsedRef) -> Void)?

    @ObservationIgnored private let parser: PSVoiceRefParser
    @ObservationIgnored private let contextualStrings: [String]
    @ObservationIgnored private let sessionFactory: SessionFactory
    @ObservationIgnored private var session: PSVoiceRefSession?
    @ObservationIgnored private var resolutionTask: Task<Void, Never>?

    init(
        books: [PSVoiceRefBook]? = nil,
        sessionFactory: SessionFactory? = nil
    ) {
        let books = books ?? Self.makeGazetteer()
        self.parser = PSVoiceRefParser(books: books)
        self.contextualStrings = Self.makeContextualStrings(from: books)
        self.sessionFactory = sessionFactory ?? {
            PSVoiceRefSession(contextualStrings: $0)
        }
    }

    func start() {
        guard session == nil else { return }
        let session = sessionFactory(contextualStrings)
        session.delegate = self
        self.session = session
        session.start()
    }

    func cancel() {
        cancelSession()
        onCancel?()
    }

    func cancelSession() {
        resolutionTask?.cancel()
        resolutionTask = nil
        session?.cancel()
        session = nil
    }

    func performPrimaryAction() {
        switch action {
        case .done:
            isActionEnabled = false
            session?.finish()
        case .tryAgain:
            retry()
        case .none, .openSettings:
            break
        }
    }

    func voiceRefSession(
        _ session: PSVoiceRefSession,
        didChangeState state: PSVoiceRefSession.State
    ) {
        guard session === self.session else { return }
        apply(state)
    }

    func apply(_ state: PSVoiceRefSession.State) {
        switch state {
        case .requestingPermission, .checkingAssets, .preparing:
            status = .prompt
            transcript = .empty
            preview = ""
            downloadProgress = nil
            isListening = false
            action = .none
            isActionEnabled = true

        case .downloadingModel(let progress):
            status = .downloading
            transcript = .empty
            preview = ""
            downloadProgress = progress
            isListening = false
            action = .none
            isActionEnabled = true

        case .listening(let volatileText):
            status = .listening
            transcript = volatileText.isEmpty
                ? .prompt
                : .value(volatileText)
            preview = formattedPreview(for: volatileText)
            downloadProgress = nil
            isListening = true
            action = volatileText.isEmpty ? .none : .done
            isActionEnabled = true

        case .finalizing:
            isListening = false
            isActionEnabled = false

        case .finished(let candidates):
            isListening = false
            isActionEnabled = true
            handleFinished(candidates: candidates)

        case .failed(let error):
            isListening = false
            isActionEnabled = true
            show(error: error)
        }
    }

    private func retry() {
        session?.cancel()
        session = nil
        resetForListening()
        start()
    }

    private func resetForListening() {
        status = .prompt
        transcript = .empty
        preview = ""
        downloadProgress = nil
        isListening = false
        action = .none
        isActionEnabled = true
        showsCancel = true
    }

    private func formattedPreview(for candidate: String) -> String {
        guard !candidate.isEmpty,
              let reference = parser.parse(candidate: candidate) else {
            return ""
        }
        return Self.formatted(reference)
    }

    private func handleFinished(candidates: [String]) {
        downloadProgress = nil
        preview = ""

        guard let reference = parser.parse(candidates: candidates) else {
            status = .noMatch
            transcript = candidates.first.map(VoiceReferenceTranscript.value)
                ?? .empty
            action = .tryAgain
            showsCancel = true
            return
        }

        status = .none
        transcript = .value(Self.formatted(reference))
        action = .none
        showsCancel = false
        resolutionTask?.cancel()
        resolutionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.onReferenceResolved?(reference)
        }
    }

    private func show(error: PSVoiceRefError) {
        downloadProgress = nil
        preview = ""
        transcript = .empty
        showsCancel = true

        switch error {
        case .microphoneDenied:
            status = .microphoneDenied
            action = .openSettings

        case .unsupportedLocale, .noAudioInput, .speechAssetsUnavailable:
            status = .unavailable
            action = .none

        case .modelDownloadFailed,
             .audioSessionFailed,
             .recognitionFailed,
             .audioInterrupted:
            status = .unavailable
            action = .tryAgain
        }
    }

    private static func formatted(_ reference: PSParsedRef) -> String {
        "\(reference.displayBookName) \(reference.chapter):\(reference.verse)"
    }

    private static func makeGazetteer() -> [PSVoiceRefBook] {
        guard let resolver = PSBookOSISResolver.shared else { return [] }
        return resolver.books.compactMap { book in
            guard !book.name.isEmpty else { return nil }
            let names = [book.name, book.shortName, book.osisName]
                .filter { !$0.isEmpty }
            return PSVoiceRefBook(
                names: names,
                displayName: book.name,
                chapters: book.chapterCount,
                versesInChapter: { chapter in
                    resolver.verseMax(book: book, chapter: chapter) ?? 0
                }
            )
        }
    }

    private static func makeContextualStrings(
        from books: [PSVoiceRefBook]
    ) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for book in books {
            let name = book.displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !name.isEmpty,
                  seen.insert(name.lowercased()).inserted else {
                continue
            }
            result.append(name)
        }
        return Array(result.prefix(100))
    }
}
