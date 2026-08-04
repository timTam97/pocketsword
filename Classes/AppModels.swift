import Foundation
import Observation

enum Workspace: String, CaseIterable, Equatable {
    case read
    case search
    case library
    case settings
}

enum ReadingMode: String, CaseIterable, Equatable {
    case bible
    case commentary
}

@MainActor
@Observable
final class ReadingModel {
    var mode: ReadingMode
    var reference: BibleReference?
    var bibleModule: String
    var commentaryModule: String
    var bibleVerse: Int
    var commentaryVerse: Int

    init(
        mode: ReadingMode = .bible,
        reference: BibleReference? = nil,
        bibleModule: String = BundledModules.bible,
        commentaryModule: String = BundledModules.commentary,
        bibleVerse: Int = 1,
        commentaryVerse: Int = 1
    ) {
        self.mode = mode
        self.reference = reference
        self.bibleModule = bibleModule
        self.commentaryModule = commentaryModule
        self.bibleVerse = bibleVerse
        self.commentaryVerse = commentaryVerse
    }

    func apply(_ route: URLRoute) {
        reference = route.reference
        let verse = Int(route.versePosition) ?? 1

        switch route.destination {
        case .bible(let module):
            mode = .bible
            bibleVerse = verse
            if let module {
                bibleModule = module
            }
        case .commentary(let module):
            mode = .commentary
            bibleVerse = verse
            commentaryVerse = verse
            if let module {
                commentaryModule = module
            }
        }
    }

    func apply(_ snapshot: ReadingSnapshot) {
        reference = snapshot.reference
        bibleModule = snapshot.bibleModule
        commentaryModule = snapshot.commentaryModule
        bibleVerse = snapshot.bibleVerse
        commentaryVerse = snapshot.commentaryVerse
    }
}

@MainActor
@Observable
final class SettingsModel {
    var fontName: String {
        didSet {
            guard !isReloading, fontName != oldValue else { return }
            store.saveFontName(fontName)
            onReadingAppearanceChanged?()
        }
    }
    var fontSize: Int {
        didSet {
            guard !isReloading, fontSize != oldValue else { return }
            store.saveFontSize(fontSize)
            onReadingAppearanceChanged?()
        }
    }
    var keepScreenAwake: Bool {
        didSet {
            guard !isReloading, keepScreenAwake != oldValue else { return }
            store.saveKeepScreenAwake(keepScreenAwake)
            onKeepScreenAwakeChanged?(keepScreenAwake)
        }
    }
    var rotationLock: RotationLock {
        didSet {
            guard !isReloading, rotationLock != oldValue else { return }
            store.saveRotationLock(rotationLock)
        }
    }
    var automaticFullscreen: Bool {
        didSet {
            guard !isReloading, automaticFullscreen != oldValue else { return }
            store.saveAutomaticFullscreen(automaticFullscreen)
        }
    }
    var fontSizeValue: Double {
        get { Double(fontSize) }
        set { fontSize = Int(newValue) }
    }

    subscript(rotationLockedFor currentOrientation: RotationLock) -> Bool {
        get { rotationLock != .unlocked }
        set {
            rotationLock = newValue ? currentOrientation : .unlocked
        }
    }

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var isReloading = false
    @ObservationIgnored var onReadingAppearanceChanged: (@MainActor () -> Void)?
    @ObservationIgnored var onKeepScreenAwakeChanged: (@MainActor (Bool) -> Void)?

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        let snapshot = store.snapshot()
        self.fontName = snapshot.fontName
        self.fontSize = snapshot.fontSize
        self.keepScreenAwake = snapshot.keepScreenAwake
        self.rotationLock = snapshot.rotationLock
        self.automaticFullscreen = snapshot.automaticFullscreen
    }

    func ensureFontSizeDefault() {
        store.ensureFontSizeDefault()
    }

    func reload() {
        let snapshot = store.snapshot()
        isReloading = true
        fontName = snapshot.fontName
        fontSize = snapshot.fontSize
        keepScreenAwake = snapshot.keepScreenAwake
        rotationLock = snapshot.rotationLock
        automaticFullscreen = snapshot.automaticFullscreen
        isReloading = false
    }
}

@MainActor
@Observable
final class LibraryModel {
    var bookmarks: [BookmarkNode]
    var history: [HistoryEntry]

    @ObservationIgnored private let bookmarkStore: BookmarkStore
    @ObservationIgnored private let historyStore: HistoryStore

    init(
        bookmarkStore: BookmarkStore = BookmarkStore(),
        historyStore: HistoryStore = HistoryStore()
    ) {
        self.bookmarkStore = bookmarkStore
        self.historyStore = historyStore
        self.bookmarks = bookmarkStore.snapshot()
        self.history = historyStore.snapshot()
    }

    func reloadBookmarks() {
        bookmarks = bookmarkStore.snapshot()
    }

    func reloadHistory() {
        history = historyStore.snapshot()
    }
}

struct SearchResultRow: Identifiable, Equatable {
    var id: String { reference }

    let reference: String
    let text: String?
    let strongsHighlightWords: [String]
}

enum SearchIndexState: Equatable {
    case unavailable
    case ready
    case building(progress: Float)
    case cancelling
    case cancelled
    case failed
}

private final class SearchIndexCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

@MainActor
@Observable
final class SearchIndexCoordinator {
    typealias FreshnessProvider = (String) -> Bool
    typealias BuildOperation = (String, PSSearchProgressBlock?) throws -> Void

    private(set) var state: SearchIndexState = .unavailable {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }

    @ObservationIgnored private let freshnessProvider: FreshnessProvider
    @ObservationIgnored private let buildOperation: BuildOperation
    @ObservationIgnored private var cancellation: SearchIndexCancellation?
    @ObservationIgnored private var operationID: UUID?
    @ObservationIgnored var onStateChange: (@MainActor (SearchIndexState) -> Void)?
    @ObservationIgnored var onCompletion: (@MainActor (Bool, Bool) -> Void)?

    init(
        freshnessProvider: @escaping FreshnessProvider = {
            PSSearchEngine.engine(forModuleName: $0).indexIsFresh()
        },
        buildOperation: @escaping BuildOperation = { module, progress in
            try PSSearchEngine.engine(forModuleName: module).build(progress: progress)
        }
    ) {
        self.freshnessProvider = freshnessProvider
        self.buildOperation = buildOperation
    }

    func refresh(module: String?) {
        guard let module else {
            state = .unavailable
            return
        }
        state = freshnessProvider(module) ? .ready : .unavailable
    }

    func build(module: String) {
        guard operationID == nil else { return }
        let id = UUID()
        let cancellation = SearchIndexCancellation()
        let operation = buildOperation
        operationID = id
        self.cancellation = cancellation
        state = .building(progress: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buildError: Error?
            do {
                try operation(module) { fraction, cancel in
                    cancel = cancellation.isCancelled
                    DispatchQueue.main.async { [weak self] in
                        self?.updateProgress(fraction, operationID: id)
                    }
                }
            } catch {
                buildError = error
            }

            let wasCancelled = cancellation.isCancelled
            DispatchQueue.main.async { [weak self] in
                self?.finish(
                    operationID: id,
                    error: buildError,
                    cancelled: wasCancelled
                )
            }
        }
    }

    func cancel() {
        guard cancellation != nil else { return }
        cancellation?.cancel()
        state = .cancelling
    }

    private func updateProgress(_ progress: Float, operationID: UUID) {
        guard self.operationID == operationID, state != .cancelling else {
            return
        }
        state = .building(progress: progress)
    }

    private func finish(
        operationID: UUID,
        error: Error?,
        cancelled: Bool
    ) {
        guard self.operationID == operationID else { return }
        self.operationID = nil
        cancellation = nil

        if cancelled {
            state = .cancelled
            onCompletion?(false, true)
        } else if let error {
            alog("SearchIndexCoordinator: build failed: \(error)")
            state = .failed
            onCompletion?(false, false)
        } else {
            state = .ready
            onCompletion?(true, false)
        }
    }
}

@MainActor
@Observable
final class SearchModel {
    var query = ""
    var expression: String?
    var module: String?
    var strongsSearch = false
    var fuzzySearch: Bool
    var matchType: PSSearchType
    var range: PSSearchRange
    var bookName: String?
    var results: [SearchResultRow] = []

    @ObservationIgnored private let optionsStore: SearchOptionsStore
    @ObservationIgnored let indexCoordinator: SearchIndexCoordinator

    init(
        optionsStore: SearchOptionsStore = SearchOptionsStore(),
        indexCoordinator: SearchIndexCoordinator? = nil
    ) {
        self.optionsStore = optionsStore
        self.indexCoordinator = indexCoordinator ?? SearchIndexCoordinator()
        let options = optionsStore.snapshot()
        self.fuzzySearch = options.fuzzy
        self.matchType = options.matchType
        self.range = options.range
    }

    func persistOptions() {
        optionsStore.save(
            SearchOptionsSnapshot(
                fuzzy: fuzzySearch,
                matchType: matchType,
                range: range
            )
        )
    }

    func setResults(_ rawResults: [PSSearchResult]) {
        results = rawResults.map {
            SearchResultRow(
                reference: $0.reference,
                text: $0.fullText,
                strongsHighlightWords: $0.strongsHighlightWords ?? []
            )
        }
    }

    func clearResults() {
        expression = nil
        results = []
    }
}

@MainActor
@Observable
final class AppSession {
    var selectedWorkspace: Workspace
    var lastOpenedURL: URL?
    @ObservationIgnored let reading: ReadingModel
    @ObservationIgnored let settings: SettingsModel
    @ObservationIgnored let library: LibraryModel
    @ObservationIgnored let search: SearchModel

    init(
        selectedWorkspace: Workspace = .read,
        lastOpenedURL: URL? = nil,
        reading: ReadingModel? = nil,
        settings: SettingsModel? = nil,
        library: LibraryModel? = nil,
        search: SearchModel? = nil
    ) {
        self.selectedWorkspace = selectedWorkspace
        self.lastOpenedURL = lastOpenedURL
        self.reading = reading ?? ReadingModel()
        self.settings = settings ?? SettingsModel()
        self.library = library ?? LibraryModel()
        self.search = search ?? SearchModel()
    }

    func apply(_ route: URLRoute) {
        selectedWorkspace = .read
        lastOpenedURL = route.sourceURL
        reading.apply(route)
    }
}
