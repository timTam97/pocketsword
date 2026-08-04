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
    private(set) var dictionaryModule: String?
    private(set) var dictionaryKeys: [String] = []
    private(set) var visibleDictionaryKeys: [String] = []
    var dictionaryQuery = "" {
        didSet {
            guard dictionaryQuery != oldValue else { return }
            filterDictionaryKeys()
        }
    }

    @ObservationIgnored private let bookmarkStore: BookmarkStore
    @ObservationIgnored private let historyStore: HistoryStore
    @ObservationIgnored private let dictionaryStore: DictionaryStore

    init(
        bookmarkStore: BookmarkStore = BookmarkStore(),
        historyStore: HistoryStore = HistoryStore(),
        dictionaryStore: DictionaryStore = DictionaryStore()
    ) {
        self.bookmarkStore = bookmarkStore
        self.historyStore = historyStore
        self.dictionaryStore = dictionaryStore
        self.bookmarks = bookmarkStore.snapshot()
        self.history = historyStore.snapshot()
    }

    func reloadBookmarks() {
        bookmarks = bookmarkStore.snapshot()
    }

    func reloadHistory() {
        history = historyStore.snapshot()
    }

    func bookmarkNode(id: UUID) -> BookmarkNode? {
        findBookmark(id: id, in: bookmarks)
    }

    func bookmarkChildren(in parentID: UUID?) -> [BookmarkNode] {
        guard let parentID,
              let parent = findBookmark(id: parentID, in: bookmarks),
              case .folder(_, let children) = parent.kind else {
            return parentID == nil ? bookmarks : []
        }
        return children
    }

    func addBookmarkFolder(
        name: String,
        color: BookmarkColor?,
        parentID: UUID?
    ) throws {
        try bookmarkStore.addFolder(name: name, color: color, to: parentID)
        reloadBookmarks()
    }

    func renameBookmark(id: UUID, to name: String) throws {
        try bookmarkStore.rename(id: id, to: name)
        reloadBookmarks()
    }

    func updateBookmarkFolder(
        id: UUID,
        name: String,
        color: BookmarkColor?
    ) throws {
        try bookmarkStore.updateFolder(id: id, name: name, color: color)
        reloadBookmarks()
    }

    func removeBookmark(id: UUID) {
        guard bookmarkStore.remove(id: id) else { return }
        reloadBookmarks()
    }

    func reorderBookmarks(
        parentID: UUID?,
        sources: [UUID],
        before destinationID: UUID?
    ) {
        guard bookmarkStore.reorder(
            parentID: parentID,
            sources: sources,
            before: destinationID
        ) else {
            return
        }
        reloadBookmarks()
    }

    func openBookmark(id: UUID) -> String? {
        guard let reference = bookmarkStore.markAccessed(id: id) else {
            return nil
        }
        reloadBookmarks()
        return reference
    }

    func removeHistory(id: HistoryEntry.ID) {
        guard historyStore.remove(id: id) else { return }
        reloadHistory()
    }

    func clearHistory() {
        historyStore.clear()
        reloadHistory()
    }

    func reloadDictionary() {
        apply(dictionaryStore.snapshot())
    }

    func selectDictionary(module: String) {
        dictionaryQuery = ""
        apply(dictionaryStore.select(module: module))
    }

    func dictionaryEntry(key: String) -> DictionaryEntryDocument? {
        guard let dictionaryModule else { return nil }
        return dictionaryStore.entry(module: dictionaryModule, key: key)
    }

    func dictionaryEntry(
        module: String,
        key: String
    ) -> DictionaryEntryDocument {
        dictionaryStore.entry(module: module, key: key)
    }

    private func apply(_ snapshot: DictionarySnapshot) {
        dictionaryModule = snapshot.module
        dictionaryKeys = snapshot.keys
        filterDictionaryKeys()
    }

    private func filterDictionaryKeys() {
        guard !dictionaryQuery.isEmpty else {
            visibleDictionaryKeys = dictionaryKeys
            return
        }
        visibleDictionaryKeys = dictionaryKeys.filter {
            $0.range(of: dictionaryQuery, options: .caseInsensitive) != nil
        }
    }

    private func findBookmark(
        id: UUID,
        in nodes: [BookmarkNode]
    ) -> BookmarkNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if case .folder(_, let children) = node.kind,
               let match = findBookmark(id: id, in: children) {
                return match
            }
        }
        return nil
    }
}

struct SearchResultRow: Identifiable, Equatable {
    var id: String { reference }

    let reference: String
    let text: String?
    let strongsHighlightWords: [String]
}

struct SearchModuleChoice: Identifiable, Equatable {
    let id: String
    let kind: ReadingMode
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
    typealias QueryOperation = (
        _ module: String,
        _ expression: String,
        _ range: PSSearchRange,
        _ bookName: String?,
        _ strongsTokens: [String]?
    ) -> [PSSearchResult]

    var query = ""
    var expression: String?
    var module: String?
    var strongsSearch = false
    var fuzzySearch: Bool
    var matchType: PSSearchType
    var range: PSSearchRange
    var bookName: String?
    var results: [SearchResultRow] = []
    private(set) var modules: [SearchModuleChoice] = []
    private(set) var moduleKind: ReadingMode = .bible
    private(set) var strongsAvailable = false
    private(set) var isSearching = false
    private(set) var highlightTerms: [String] = []

    @ObservationIgnored private let optionsStore: SearchOptionsStore
    @ObservationIgnored let indexCoordinator: SearchIndexCoordinator
    @ObservationIgnored private let queryOperation: QueryOperation
    @ObservationIgnored private let featureProvider: (String, String) -> Bool
    @ObservationIgnored private let debounceInterval: TimeInterval
    @ObservationIgnored private let indexBuildStarted: (String) -> Void
    @ObservationIgnored private let indexBuildFinished: (String) -> Void
    @ObservationIgnored private var debounceTimer: Timer?
    @ObservationIgnored private var queryGeneration: UInt = 0
    @ObservationIgnored var onHistoryChange: (
        @MainActor (PSSearchHistoryItem?) -> Void
    )?

    init(
        optionsStore: SearchOptionsStore = SearchOptionsStore(),
        indexCoordinator: SearchIndexCoordinator? = nil,
        debounceInterval: TimeInterval = 0.25,
        featureProvider: @escaping (String, String) -> Bool = {
            PSContentStore.shared?.moduleHasFeature($0, $1) ?? false
        },
        queryOperation: @escaping QueryOperation = {
            module,
            expression,
            range,
            bookName,
            strongsTokens in
            PSSearchEngine.engine(forModuleName: module).runQuery(
                expression,
                scope: range,
                bookName: bookName,
                limit: 1000,
                strongsTokens: strongsTokens
            )
        },
        indexBuildStarted: @escaping (String) -> Void = { _ in },
        indexBuildFinished: @escaping (String) -> Void = { _ in }
    ) {
        self.optionsStore = optionsStore
        self.indexCoordinator = indexCoordinator ?? SearchIndexCoordinator()
        self.debounceInterval = debounceInterval
        self.featureProvider = featureProvider
        self.queryOperation = queryOperation
        self.indexBuildStarted = indexBuildStarted
        self.indexBuildFinished = indexBuildFinished
        let options = optionsStore.snapshot()
        self.fuzzySearch = options.fuzzy
        self.matchType = options.matchType
        self.range = options.range
    }

    func configure(
        modules: [SearchModuleChoice],
        preferredModule: String?,
        currentBookName: String?,
        restoring historyItem: PSSearchHistoryItem?
    ) {
        self.modules = modules

        let selected = modules.first(where: { $0.id == module })
            ?? modules.first(where: { $0.id == preferredModule })
            ?? modules.first
        if let selected {
            applyModule(selected, clearExistingResults: module != selected.id)
        } else {
            module = nil
            indexCoordinator.refresh(module: nil)
        }

        if let historyItem {
            restore(historyItem, currentBookName: currentBookName)
        } else {
            updateBookName(currentBookName)
            if !query.isEmpty {
                scheduleSearch(immediate: true)
            }
        }
    }

    func selectModule(_ choice: SearchModuleChoice) {
        guard module != choice.id else { return }
        applyModule(choice, clearExistingResults: true)
        if !query.isEmpty, indexCoordinator.state == .ready {
            scheduleSearch(immediate: true)
        }
    }

    func queryDidChange() {
        scheduleSearch()
    }

    func optionsDidChange(currentBookName: String?) {
        if strongsSearch && !strongsAvailable {
            strongsSearch = false
        }
        updateBookName(currentBookName)
        persistOptions()
        scheduleSearch()
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
        debounceTimer?.invalidate()
        debounceTimer = nil
        queryGeneration &+= 1
        isSearching = false
        expression = nil
        results = []
        highlightTerms = []
    }

    func searchNow() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        runSearch()
    }

    func startIndexBuild() {
        guard let module else { return }
        indexBuildStarted(module)
        indexCoordinator.onCompletion = { [weak self] success, _ in
            guard let self else { return }
            self.indexBuildFinished(module)
            if success {
                self.scheduleSearch(immediate: true)
            }
        }
        indexCoordinator.build(module: module)
    }

    func cancelIndexBuild() {
        indexCoordinator.cancel()
    }

    func historyItem() -> PSSearchHistoryItem? {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return nil }

        let item = PSSearchHistoryItem(
            searchTermToDisplay: query,
            strongs: strongsSearch,
            fuzzy: fuzzySearch,
            type: matchType,
            range: range,
            book: range == .BookRange ? bookName : nil
        )
        let entries = NSMutableArray(capacity: results.count)
        for result in results {
            entries.add(
                PSVerseTextEntry(
                    key: result.reference,
                    text: result.text
                )
            )
        }
        item?.results = entries
        return item
    }

    static func highlightTerms(
        query: String,
        matchType: PSSearchType,
        strongs: Bool
    ) -> [String] {
        guard !strongs, !query.isEmpty else { return [] }
        if matchType == .ExactSearch {
            return query.count >= 2 ? [query] : []
        }

        var terms: [String] = []
        let characters = Array(query.utf16)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == 0x20 || character == 0x09 || character == 0x0A {
                index += 1
                continue
            }
            if character == 0x22 {
                index += 1
                let start = index
                while index < characters.count, characters[index] != 0x22 {
                    index += 1
                }
                let phrase = String(
                    utf16CodeUnits: Array(characters[start..<index]),
                    count: index - start
                )
                if index < characters.count {
                    index += 1
                }
                if phrase.utf16.count >= 2 {
                    terms.append(phrase)
                }
            } else {
                let start = index
                while index < characters.count {
                    let value = characters[index]
                    if value == 0x20 || value == 0x09
                        || value == 0x0A || value == 0x22 {
                        break
                    }
                    index += 1
                }
                let word = String(
                    utf16CodeUnits: Array(characters[start..<index]),
                    count: index - start
                )
                if word.utf16.count >= 2 {
                    terms.append(word)
                }
            }
        }
        return terms
    }

    private func applyModule(
        _ choice: SearchModuleChoice,
        clearExistingResults: Bool
    ) {
        module = choice.id
        moduleKind = choice.kind
        strongsAvailable = featureProvider(choice.id, "Strongs")
            || featureProvider(choice.id, "StrongsNumbers")
        if !strongsAvailable {
            strongsSearch = false
        }
        if clearExistingResults {
            clearResults()
        }
        indexCoordinator.refresh(module: choice.id)
    }

    private func restore(
        _ historyItem: PSSearchHistoryItem,
        currentBookName: String?
    ) {
        query = historyItem.cleanedDisplayTerm()
        fuzzySearch = historyItem.fuzzySearch
        matchType = historyItem.searchType
        range = historyItem.searchRange
        strongsSearch = historyItem.strongsSearch && strongsAvailable
        bookName = range == .BookRange
            ? (historyItem.bookName ?? currentBookName)
            : nil

        let restoredRows: [SearchResultRow] = historyItem.results?.compactMap {
            element -> SearchResultRow? in
            guard let entry = element as? PSVerseTextEntry,
                  let reference = entry.key else {
                return nil
            }
            return SearchResultRow(
                reference: reference,
                text: entry.text,
                strongsHighlightWords: []
            )
        } ?? []
        results = restoredRows
        expression = PSSearchQuery.fts5Expression(
            fromUserInput: query,
            matchType: matchType,
            fuzzy: fuzzySearch,
            strongs: strongsSearch
        )
        highlightTerms = Self.highlightTerms(
            query: query,
            matchType: matchType,
            strongs: strongsSearch
        )
        persistOptions()

        if !query.isEmpty, indexCoordinator.state == .ready {
            scheduleSearch(immediate: true)
        }
    }

    private func updateBookName(_ currentBookName: String?) {
        bookName = range == .BookRange ? currentBookName : nil
    }

    private func scheduleSearch(immediate: Bool = false) {
        debounceTimer?.invalidate()
        debounceTimer = nil
        queryGeneration &+= 1

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            expression = nil
            results = []
            highlightTerms = []
            onHistoryChange?(nil)
            return
        }
        guard indexCoordinator.state == .ready else {
            isSearching = false
            return
        }
        if immediate || debounceInterval == 0 {
            runSearch()
            return
        }

        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.runSearch()
            }
        }
    }

    private func runSearch() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        guard let module, indexCoordinator.state == .ready else {
            isSearching = false
            return
        }

        if strongsSearch && !Self.inputLooksLikeStrongs(query) {
            strongsSearch = false
        }
        guard let expression = PSSearchQuery.fts5Expression(
            fromUserInput: query,
            matchType: matchType,
            fuzzy: fuzzySearch,
            strongs: strongsSearch
        ), !expression.isEmpty else {
            clearResults()
            return
        }

        self.expression = expression
        highlightTerms = Self.highlightTerms(
            query: query,
            matchType: matchType,
            strongs: strongsSearch
        )
        let capturedRange = range
        let capturedBookName = bookName
        let capturedStrongsTokens = strongsSearch
            ? PSSearchQuery.strongsTokens(fromUserInput: query)
            : nil
        let operation = queryOperation

        queryGeneration &+= 1
        let generation = queryGeneration
        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rawResults = operation(
                module,
                expression,
                capturedRange,
                capturedBookName,
                capturedStrongsTokens
            )
            DispatchQueue.main.async {
                guard let self, self.queryGeneration == generation else {
                    return
                }
                self.isSearching = false
                self.setResults(rawResults)
                self.onHistoryChange?(self.historyItem())
            }
        }
    }

    private static func inputLooksLikeStrongs(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        for token in trimmed.components(separatedBy: .whitespaces) {
            let units = Array(token.utf16)
            guard units.count >= 2 else { continue }
            let prefix = units[0]
            guard prefix == 0x48 || prefix == 0x47
                    || prefix == 0x68 || prefix == 0x67 else {
                continue
            }
            if units.dropFirst().allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) {
                return true
            }
        }
        return false
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
