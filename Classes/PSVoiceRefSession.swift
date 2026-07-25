//
//  PSVoiceRefSession.swift
//  PocketSword
//

@preconcurrency import AVFoundation
import Foundation
import Speech

enum PSVoiceRefError: Error {
    case microphoneDenied
    case unsupportedLocale
    case noAudioInput
    case speechAssetsUnavailable
    case modelDownloadFailed(String)
    case audioSessionFailed(String)
    case recognitionFailed(String)
    case audioInterrupted
}

@MainActor
protocol PSVoiceRefSessionDelegate: AnyObject {
    func voiceRefSession(_ session: PSVoiceRefSession,
                         didChangeState state: PSVoiceRefSession.State)
}

@MainActor
final class PSVoiceRefSession {
    enum Availability {
        case available(Locale)
        case unsupportedLocale
        case noHardware
    }

    enum State {
        case requestingPermission
        case checkingAssets
        case downloadingModel(Progress)
        case preparing
        case listening(volatileText: String)
        case finalizing
        case finished(candidates: [String])
        case failed(PSVoiceRefError)
    }

    private enum Phase {
        case idle
        case running
        case finalizing
        case finished
        case cancelled
    }

    private static var cachedAvailability: Availability?

    weak var delegate: PSVoiceRefSessionDelegate?

    // Phrases to bias recognition toward (Bible book names). Fed to the analyzer
    // as an AnalysisContext so distinctive words the general model tends to
    // mis-hear ("Habakkuk", "Colossians", "Philemon") are far more likely to
    // land. Empty is fine — recognition just runs unbiased.
    private let contextualStrings: [String]

    init(contextualStrings: [String] = []) {
        self.contextualStrings = contextualStrings
    }

    private var phase: Phase = .idle
    private var runTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    private var analyzer: SpeechAnalyzer?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var installedInputTap = false
    private var finalSegments: [String] = []
    private var alternativeTranscripts: [String] = []
    private var latestVolatileText = ""
    private var observingAudioInterruptions = false

    static func availability() async -> Availability {
        if let cachedAvailability {
            return cachedAvailability
        }

#if targetEnvironment(simulator)
        let result: Availability = .noHardware
#else
        let result: Availability
        guard SpeechTranscriber.isAvailable,
              AVAudioSession.sharedInstance().isInputAvailable else {
            result = .noHardware
            cachedAvailability = result
            return result
        }

        if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) {
            result = .available(locale)
        } else {
            result = .unsupportedLocale
        }
#endif

        cachedAvailability = result
        return result
    }

    func start() {
        guard phase == .idle else { return }
        phase = .running
        runTask = Task { [weak self] in
            await self?.run()
        }
    }

    func finish() {
        guard phase == .running else { return }
        phase = .finalizing
        silenceTask?.cancel()
        silenceTask = nil
        emit(.finalizing)
        stopAudioInput()

        runTask = Task { [weak self] in
            await self?.finalize()
        }
    }

    func cancel() {
        guard phase != .cancelled, phase != .finished else { return }
        phase = .cancelled
        runTask?.cancel()
        silenceTask?.cancel()
        stopAudioInput()

        let analyzer = self.analyzer
        analysisTask?.cancel()
        resultsTask?.cancel()
        clearSpeechObjects()
        deactivateAudioSession()

        Task {
            await analyzer?.cancelAndFinishNow()
        }
    }

    deinit {
        runTask?.cancel()
        analysisTask?.cancel()
        resultsTask?.cancel()
        silenceTask?.cancel()
        if installedInputTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        inputContinuation?.finish()
        if observingAudioInterruptions {
            NotificationCenter.default.removeObserver(self,
                                                      name: AVAudioSession.interruptionNotification,
                                                      object: nil)
        }
        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
    }

    private func run() async {
        do {
            emit(.requestingPermission)
            guard await AVAudioApplication.requestRecordPermission() else {
                throw PSVoiceRefError.microphoneDenied
            }
            try Task.checkCancellation()

            let availability = await Self.availability()
            let locale: Locale
            switch availability {
            case .available(let supportedLocale):
                locale = supportedLocale
            case .unsupportedLocale:
                throw PSVoiceRefError.unsupportedLocale
            case .noHardware:
                throw PSVoiceRefError.noAudioInput
            }

            let transcriber = Self.makeTranscriber(locale: locale)
            emit(.checkingAssets)
            try await ensureAssets(for: transcriber)
            try Task.checkCancellation()

            emit(.preparing)
            try activateAudioSession()
            try await beginRecognition(with: transcriber)
        } catch is CancellationError {
            return
        } catch let error as PSVoiceRefError {
            fail(error)
        } catch {
            fail(.recognitionFailed(error.localizedDescription))
        }
    }

    private static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .alternativeTranscriptions],
            attributeOptions: []
        )
    }

    private func ensureAssets(for transcriber: SpeechTranscriber) async throws {
        let modules: [any SpeechModule] = [transcriber]
        switch await AssetInventory.status(forModules: modules) {
        case .installed:
            return
        case .unsupported:
            throw PSVoiceRefError.speechAssetsUnavailable
        case .supported, .downloading:
            do {
                guard let request = try await AssetInventory.assetInstallationRequest(
                    supporting: modules
                ) else {
                    if await AssetInventory.status(forModules: modules) == .installed {
                        return
                    }
                    throw PSVoiceRefError.speechAssetsUnavailable
                }
                emit(.downloadingModel(request.progress))
                try await request.downloadAndInstall()
            } catch let error as PSVoiceRefError {
                throw error
            } catch {
                throw PSVoiceRefError.modelDownloadFailed(error.localizedDescription)
            }
        @unknown default:
            throw PSVoiceRefError.speechAssetsUnavailable
        }
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        guard session.isInputAvailable else {
            throw PSVoiceRefError.noAudioInput
        }
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(audioSessionInterrupted(_:)),
                name: AVAudioSession.interruptionNotification,
                object: session
            )
            observingAudioInterruptions = true
        } catch {
            throw PSVoiceRefError.audioSessionFailed(error.localizedDescription)
        }
    }

    private func beginRecognition(with transcriber: SpeechTranscriber) async throws {
        let modules: [any SpeechModule] = [transcriber]
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: modules
        ) else {
            throw PSVoiceRefError.speechAssetsUnavailable
        }

        let analyzer = SpeechAnalyzer(modules: modules)
        self.analyzer = analyzer
        if !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings = [.general: contextualStrings]
            try await analyzer.setContext(context)
        }
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try Task.checkCancellation()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0,
              inputFormat.sampleRate > 0,
              let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
            throw PSVoiceRefError.noAudioInput
        }

        var continuation: AsyncStream<AnalyzerInput>.Continuation?
        let inputStream = AsyncStream<AnalyzerInput> { continuation = $0 }
        guard let continuation else {
            throw PSVoiceRefError.recognitionFailed("Unable to create the audio stream.")
        }
        inputContinuation = continuation
        audioEngine = engine

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    self.consume(result)
                }
            } catch is CancellationError {
                return
            } catch {
                self?.runtimeFailure(error)
            }
        }

        analysisTask = Task { [weak self] in
            do {
                try await analyzer.start(inputSequence: inputStream)
            } catch is CancellationError {
                return
            } catch {
                self?.runtimeFailure(error)
            }
        }

        inputNode.installTap(onBus: 0,
                             bufferSize: 4096,
                             format: inputFormat) { [weak self] buffer, _ in
            do {
                if let converted = try Self.convert(
                    buffer,
                    using: converter,
                    outputFormat: analyzerFormat
                ) {
                    continuation.yield(AnalyzerInput(buffer: converted))
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.runtimeFailure(error)
                }
            }
        }
        installedInputTap = true

        engine.prepare()
        try engine.start()
        emit(.listening(volatileText: ""))
    }

    private static func convert(_ input: AVAudioPCMBuffer,
                                using converter: AVAudioConverter,
                                outputFormat: AVAudioFormat) throws -> AVAudioPCMBuffer? {
        let sampleRateRatio = outputFormat.sampleRate / input.format.sampleRate
        let estimatedFrames = AVAudioFrameCount(
            max(1, ceil(Double(input.frameLength) * sampleRateRatio))
        )
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                            frameCapacity: estimatedFrames) else {
            return nil
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: output,
                                       error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return input
        }

        if let conversionError {
            throw conversionError
        }
        guard status == .haveData || status == .inputRanDry,
              output.frameLength > 0 else {
            return nil
        }
        return output
    }

    private func consume(_ result: SpeechTranscriber.Result) {
        guard phase == .running || phase == .finalizing else { return }
        let text = String(result.text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.isFinal {
            // The transcriber commits stable prefixes as separate final results
            // (e.g. "hebrews" then "7 5"). Keep them ordered so the full utterance
            // can be reassembled; a lone leading segment like "hebrews" would
            // otherwise parse on its own to chapter 1.
            appendSegment(text)
            for alternative in result.alternatives {
                appendAlternative(
                    String(alternative.characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } else {
            latestVolatileText = text
            emit(.listening(volatileText: text))
            if !text.isEmpty {
                restartSilenceTimer()
            }
        }
    }

    private func appendSegment(_ segment: String) {
        guard !segment.isEmpty else { return }
        finalSegments.append(segment)
    }

    private func appendAlternative(_ alternative: String) {
        guard !alternative.isEmpty, !alternativeTranscripts.contains(alternative) else { return }
        alternativeTranscripts.append(alternative)
    }

    // The joined utterance is parsed first so a full "hebrews 7 5" wins over its
    // individual committed segments; per-segment and alternative transcripts are
    // kept only as fallbacks.
    private func makeCandidates() -> [String] {
        var candidates: [String] = []
        func add(_ candidate: String) {
            guard !candidate.isEmpty, !candidates.contains(candidate) else { return }
            candidates.append(candidate)
        }

        add(finalSegments.joined(separator: " "))
        alternativeTranscripts.forEach(add)
        finalSegments.forEach(add)
        return candidates
    }

    private func restartSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled else { return }
                self?.finish()
            } catch {
                return
            }
        }
    }

    private func finalize() async {
        guard let analyzer else {
            fail(.recognitionFailed("Speech analysis did not start."))
            return
        }

        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            if let resultsTask {
                await resultsTask.value
            }
            guard phase == .finalizing else { return }

            phase = .finished
            let candidates = makeCandidates()
            clearSpeechObjects()
            deactivateAudioSession()
            emit(.finished(candidates: candidates))
        } catch is CancellationError {
            return
        } catch {
            fail(.recognitionFailed(error.localizedDescription))
        }
    }

    private func stopAudioInput() {
        if installedInputTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
            installedInputTap = false
        }
        audioEngine?.stop()
        inputContinuation?.finish()
        inputContinuation = nil
    }

    private func clearSpeechObjects() {
        stopAudioInput()
        analysisTask = nil
        resultsTask = nil
        analyzer = nil
        audioEngine = nil
    }

    private func deactivateAudioSession() {
        if observingAudioInterruptions {
            NotificationCenter.default.removeObserver(
                self,
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            observingAudioInterruptions = false
        }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func runtimeFailure(_ error: Error) {
        guard phase == .running else { return }
        fail(.recognitionFailed(error.localizedDescription))
    }

    private func fail(_ error: PSVoiceRefError) {
        guard phase != .finished, phase != .cancelled else { return }
        phase = .finished
        runTask?.cancel()
        silenceTask?.cancel()
        stopAudioInput()

        let analyzer = self.analyzer
        analysisTask?.cancel()
        resultsTask?.cancel()
        clearSpeechObjects()
        deactivateAudioSession()
        emit(.failed(error))

        Task {
            await analyzer?.cancelAndFinishNow()
        }
    }

    private func emit(_ state: State) {
        delegate?.voiceRefSession(self, didChangeState: state)
    }

    @objc private func audioSessionInterrupted(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: rawType) == .began else {
            return
        }
        fail(.audioInterrupted)
    }
}
