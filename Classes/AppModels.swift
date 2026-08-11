import Foundation
import Observation
import UIKit

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

/// The session's mirror of the reading position: the reference, the two module
/// names and the two verse positions.
///
/// **Nothing in the app reads it.** The reader takes its position from
/// `UserDefaults` — `PSModuleController.getCurrentBibleRef()` and the
/// `Defaults{Bible,Commentary}VersePosition` keys, through `ReaderPaneModel` —
/// and the pane switch is `ReadingWorkspaceModel.mode`, which mirrors INTO this
/// object rather than out of it. What this type is for is being the assertable
/// statement of what a launch restore and an accepted `sword://` route did:
/// `URLRouterTests.testAppSessionMirrorsAcceptedRoute` and
/// `AppStateStoresTests.testSessionStartRestoresReadingStateAndWiresSettingsEffects`
/// and
/// `AppStateStoresTests.testAppStateResetReloadsTheModelsThatCachedRemovedPreferences`
/// are its only readers.
///
/// `AppSession.handleAppStateReset()` also re-applies the store snapshot into it
/// after a preferences reset — a WRITE, not a read. That write can interleave
/// with the rest of `LaunchCoordinator.prepare()` at launch, and it is harmless
/// only because nothing in the app reads this object. Giving it a production
/// reader would turn that interleave into a real race.
///
/// So keep it a faithful mirror of `ReadingStateStore` — including the arm
/// asymmetry in `apply(_ route:)` below, which looks like a bug and is not — and
/// do not give it a production reader without first deciding which of it and
/// `UserDefaults` is authoritative.
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
            // Only the Bible verse. The asymmetry with the `.commentary` arm below
            // is deliberate and mirrors `ReadingStateStore.persist(_:)`, which
            // writes `bibleVersePosition` for every route but
            // `commentaryVersePosition` only for a commentary destination: a
            // bible route leaves the commentary's own verse position alone, in
            // the defaults and therefore here.
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
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(
        bookmarkStore: BookmarkStore = BookmarkStore(),
        historyStore: HistoryStore = HistoryStore(),
        dictionaryStore: DictionaryStore = DictionaryStore(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.bookmarkStore = bookmarkStore
        self.historyStore = historyStore
        self.dictionaryStore = dictionaryStore
        self.notificationCenter = notificationCenter
        self.bookmarks = bookmarkStore.snapshot()
        self.history = historyStore.snapshot()
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// Starts refreshing on the two notifications that change this model's data
    /// from outside it: `bookmarksChanged` (the bookmark editor, and the store's
    /// own mutations) and `historyChanged` (a new entry, a clear, or an iCloud
    /// merge).
    ///
    /// `LegacyStateBridge` used to do this, as part of mirroring UIKit state into
    /// `AppSession`. That was the right place while a UIKit controller owned the
    /// lists; now that the lists are SwiftUI reading straight off this model, the
    /// model is the right place, and the bridge is deleted.
    func startObservingChanges() {
        guard observers.isEmpty else { return }
        for (name, handler) in [
            (Notification.Name.bookmarksChanged, { [weak self] in
                self?.reloadBookmarks()
            }),
            (Notification.Name.historyChanged, { [weak self] in
                self?.reloadHistory()
            }),
        ] as [(Notification.Name, @MainActor () -> Void)] {
            let observer = notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated { handler() }
            }
            observers.append(observer)
        }
    }

    func reloadBookmarks() {
        bookmarks = bookmarkStore.snapshot()
    }

    func reloadHistory() {
        history = historyStore.snapshot()
    }

    /// Records the reference currently being read. The store posts
    /// `historyChanged`, which refreshes `history` through the observer above.
    func recordHistory(mode: ReadingMode) {
        historyStore.addEntry(mode: mode)
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

    /// The `[BookmarkNode]` twin of `BookmarkStore.findObject(id:in:)`.
    ///
    /// Deliberately NOT shared. This walks the immutable `BookmarkNode` PROJECTION
    /// this model already published, so a view resolves an id against exactly the tree
    /// it is rendering; the store's walks the live `PSBookmarkFolder` object graph it
    /// is about to mutate. Routing this through the store would re-read
    /// `PSBookmarks.default()` mid-render and could answer from a tree the view has not
    /// seen yet. The two representations cannot share code without one of them
    /// changing — and the store's is the byte-locked persisted chain.
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
    /// Announced when a search settles on a new result set, or clears it.
    ///
    /// **Deliberately unwired in production, and that is a decision rather than an
    /// omission.** Wave 7 hooked this up from `PSTabBarControllerDelegate` to keep
    /// the reader's `savedSearchHistoryItem` fresh, which mattered because the
    /// UIKit search UI was rebuilt on every present and therefore re-ran
    /// `configure(...)` every time. The SwiftUI Search workspace is persistent:
    /// this model keeps its own query and results, and `SearchView` calls
    /// `configure(...)` once per launch behind `@State configured`, so refreshing
    /// the reader's copy could not change anything the user sees. The seam is kept
    /// because `AppStateStoresTests.testSearchModelRejectsAStaleCompletion` uses
    /// it as its completion signal for the stale-query race. Wire it only
    /// alongside a consumer that actually reads the result.
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

    /// Seeds a Strong's query from outside the search UI and runs it.
    ///
    /// This is the "Find all occurrences" path, and it exists because
    /// `configure(...)` is **not** re-entrant in practice: `SearchView` runs it once
    /// behind a `@State` guard, so on the second and subsequent Strong's searches
    /// the seeded history item was never applied and the workspace kept showing the
    /// *previous* term's results. Tapping H1254 showed H430's 1,000 rows —
    /// reproduced on iOS 27 and reported from a device.
    ///
    /// Unlike `restore(_:)` this deliberately does NOT read persisted match/fuzzy
    /// options: a Strong's lookup is an exact lemma query, and inheriting a stale
    /// "any word" or fuzzy setting from the user's last free-text search is what
    /// makes a lemma query return the wrong thing. It sets the three options the
    /// query needs and leaves the rest alone.
    func startStrongsQuery(_ term: String, currentBookName: String?) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        query = trimmed

        // Strong's mode is ON by definition: the term IS a Strong's number, and
        // with the mode off the query searches for the literal text "H430" and
        // finds nothing.
        //
        // Do NOT gate this on `strongsAvailable`. That flag is only resolved by
        // `applyModule`, which runs from `configure(...)` — and the reader can call
        // this BEFORE the Search workspace has ever appeared, when the flag is
        // still its `false` default. Reading it then turns the mode off and the
        // search silently returns nothing, which is exactly what a device report
        // showed: the field filled in with `H430`, Strong's Numbers unchecked, "No
        // Results".
        //
        // The module's real capability is still honoured, from whichever side knows
        // it: if the module is already resolved we check it here, and if it is not,
        // `applyModule`'s own `if !strongsAvailable { strongsSearch = false }`
        // clears the mode during `configure(...)` before the search runs.
        strongsSearch = true
        if module != nil, !strongsAvailable {
            strongsSearch = false
        }

        updateBookName(currentBookName)
        // Re-check freshness: the index may have been built (or dropped) since the
        // last time this model looked, and `scheduleSearch` refuses to run unless
        // the coordinator says `.ready`.
        indexCoordinator.refresh(module: module)
        scheduleSearch(immediate: true)
    }

    func selectModule(_ choice: SearchModuleChoice) {
        guard module != choice.id else { return }
        applyModule(choice, clearExistingResults: true)
        if !query.isEmpty, indexCoordinator.state == .ready {
            scheduleSearch(immediate: true)
        }
    }

    func queryDidChange() {
        // SwiftUI delivers this for the model's own writes too. `startStrongsQuery`
        // sets `query` and runs the search itself; the echo that follows must not
        // bump `queryGeneration` and discard that search. See `SearchInputs`.
        guard !inputsMatchScheduled else { return }
        scheduleSearch()
    }

    func optionsDidChange(currentBookName: String?) {
        // Same echo guard as `queryDidChange`, and nothing below it is lost on an
        // echo: by definition no input changed, so the capability check has already
        // run on the write that produced these values (or will run in `applyModule`),
        // `persistOptions` would rewrite byte-identical values — `SearchOptionsSnapshot`
        // carries only fuzzy/matchType/range, none of which this class writes without
        // persisting — and `scheduleSearch` would throw away the search these values
        // were scheduled for.
        guard !inputsMatchScheduled else { return }

        // `module != nil` is load-bearing, for the same reason it is in
        // `startStrongsQuery`: `strongsAvailable` is only resolved once
        // `applyModule` has run, so before then it is `false` and this would clear
        // a mode the caller just deliberately set. `SearchView` calls this from
        // `.onChange(of: search.strongsSearch)`, so it fires on exactly that write.
        if strongsSearch, module != nil, !strongsAvailable {
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
            // Ours, not the user's: absorb the echo. `selectModule` may skip
            // `scheduleSearch` (empty query, or an index that is not ready), so the
            // sync cannot be left to it.
            syncScheduledInputs()
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
        // `restore` writes all five inputs at once and may NOT schedule (an index
        // that is not fresh), so it absorbs its own echoes here. This also stops the
        // `.onChange(of: search.range)` echo from calling `updateBookName` and
        // replacing the restored item's own book scope with whatever book the reader
        // happens to be on — a restored BookRange search now keeps its book.
        syncScheduledInputs()

        if !query.isEmpty, indexCoordinator.state == .ready {
            scheduleSearch(immediate: true)
        }
    }

    private func updateBookName(_ currentBookName: String?) {
        bookName = range == .BookRange ? currentBookName : nil
    }

    // MARK: - onChange echo suppression

    /// The five observable inputs a scheduled search was built from.
    ///
    /// `SearchView` schedules a search from `.onChange(of: search.query)` and from
    /// four more hooks on the options, and SwiftUI delivers those for **this model's
    /// own writes** exactly as it does for the user's. Three writes here are the
    /// model's own: `startStrongsQuery` seeds `query` + `strongsSearch` and then runs
    /// the search itself, `runSearch` clears sticky Strong's mode when the text
    /// stopped looking like a lemma, and `applyModule` clears it for a module that
    /// has no lemmas. Each echoed back as another `scheduleSearch()`, which bumps
    /// `queryGeneration` and therefore threw away the very search that caused it: the
    /// FTS query ran twice per action and the results only landed on the second,
    /// debounced one.
    ///
    /// Recording what was last scheduled makes the echo recognisable without a
    /// "seeding" flag whose lifetime would depend on how many deliveries SwiftUI makes.
    /// An echo always matches the snapshot; a user edit normally does not, because the
    /// field the user changed differs from the last scheduled tuple.
    ///
    /// **The recognition is by VALUE, not by provenance, and that bounds what this can
    /// promise.** If one of this class's own syncs lands between a user's binding write
    /// and SwiftUI's delivery of the matching `.onChange`, that delivery is
    /// indistinguishable from an echo and is absorbed — skipping `persistOptions()` and
    /// `updateBookName()` along with the search. Both known routes to that are narrow
    /// (they need a debounced `runSearch` to clear sticky Strong's mode in the same
    /// window) and neither loses persisted state permanently, since the next genuine
    /// option change rewrites it. Provenance-tagging the writes would remove the hole
    /// and needs a different design than a value snapshot.
    ///
    /// **Invariant, and the whole guard rests on it:** every write to one of these five
    /// properties from inside this class must be followed by `syncScheduledInputs()`, or
    /// by `scheduleSearch(...)` which syncs first. Break it and a user edit that happens
    /// to restore the last scheduled tuple is swallowed. `init` is the one deliberate
    /// exception — it seeds three of the five from the persisted options while
    /// `scheduledInputs` is still nil, and nil matches nothing, so the first real change
    /// always schedules. Do NOT "fix" `init` by adding a sync there: that would make the
    /// user's first option change look like an echo and drop it.
    private struct SearchInputs: Equatable {
        let query: String
        let strongsSearch: Bool
        let fuzzySearch: Bool
        let matchType: PSSearchType
        let range: PSSearchRange
    }

    @ObservationIgnored private var scheduledInputs: SearchInputs?

    private var currentInputs: SearchInputs {
        SearchInputs(
            query: query,
            strongsSearch: strongsSearch,
            fuzzySearch: fuzzySearch,
            matchType: matchType,
            range: range
        )
    }

    /// True when the inputs are exactly what the last scheduled search was built
    /// from — i.e. this callback is an echo of one of this model's own writes.
    private var inputsMatchScheduled: Bool {
        scheduledInputs == currentInputs
    }

    private func syncScheduledInputs() {
        scheduledInputs = currentInputs
    }

    private func scheduleSearch(immediate: Bool = false) {
        // Record the inputs this search is being scheduled for BEFORE the guards
        // below can return: the echo arrives whether or not a query actually ran.
        syncScheduledInputs()
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

        // Sticky Strong's mode, cleared when the text stopped looking like a lemma
        // (ported from `PSModuleSearchController.runSearchForCurrentText`: a plain
        // word searched with the mode on hits the lemmas column and returns zero
        // rows). This is OUR write, not the user's, so absorb the `.onChange` echo —
        // otherwise it bumps `queryGeneration` and discards the query this very call
        // is about to dispatch.
        if strongsSearch && !Self.inputLooksLikeStrongs(query) {
            strongsSearch = false
            syncScheduledInputs()
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
    /// The last `sword://` URL this session accepted.
    ///
    /// **Write-only in production, and kept deliberately.** `ReadingWorkspaceModel.start()`
    /// used to branch on it to choose a verse restore over a scroll restore, but that
    /// branch could never fire — `start()` runs before `replayPendingURL()`, and
    /// `open(_:)` returns at `guard isReady` before assigning this — so it was deleted
    /// along with the `= nil` that reset it. What remains is the assertable record of
    /// what a route did, which is what `URLRouterTests.testAppSessionMirrorsAcceptedRoute`
    /// reads. It therefore LATCHES the most recent URL for the rest of the session; do
    /// not give it a production reader without first deciding when it should be cleared.
    var lastOpenedURL: URL?
    @ObservationIgnored let reading: ReadingModel
    @ObservationIgnored let settings: SettingsModel
    @ObservationIgnored let library: LibraryModel
    @ObservationIgnored let search: SearchModel

    /// The reading workspace, wired in once it exists. Weak because the workspace
    /// holds the session; this is the back-edge.
    @ObservationIgnored weak var readingWorkspace: ReadingWorkspaceModel?

    @ObservationIgnored private let readingStore: ReadingStateStore
    /// A `sword://` URL that arrived before launch preparation finished, replayed
    /// from `replayPendingURL()`.
    ///
    /// The old scene delegate cached this in `_pendingLaunchURL` for the same
    /// reason: a URL can be delivered with the scene-connection options, before
    /// the reader exists to navigate. `onOpenURL` can likewise fire while
    /// `LaunchPhase` is still `.preparing`, and routing then would render a
    /// chapter that the `DefaultsLastRefValidated` migration is about to rewrite.
    @ObservationIgnored private var pendingURL: URL?
    @ObservationIgnored private var isReady = false
    /// The `.appStateDidReset` observer. Held so it can be removed, and so a
    /// second `start()` cannot register a second handler.
    @ObservationIgnored private var resetObserver: NSObjectProtocol?

    init(
        selectedWorkspace: Workspace = .read,
        lastOpenedURL: URL? = nil,
        reading: ReadingModel? = nil,
        settings: SettingsModel? = nil,
        library: LibraryModel? = nil,
        search: SearchModel? = nil,
        readingStore: ReadingStateStore = ReadingStateStore()
    ) {
        self.selectedWorkspace = selectedWorkspace
        self.lastOpenedURL = lastOpenedURL
        self.reading = reading ?? ReadingModel()
        self.settings = settings ?? SettingsModel()
        self.library = library ?? LibraryModel()
        self.search = search ?? SearchModel()
        self.readingStore = readingStore
    }

    deinit {
        if let resetObserver {
            NotificationCenter.default.removeObserver(resetObserver)
        }
    }

    /// Wires the side effects that `LegacyStateBridge` used to mirror through
    /// `NotificationCenter`.
    ///
    /// The bridge existed so a SwiftUI settings change could reach the UIKit
    /// render path it did not know about. Both ends are SwiftUI now, so these are
    /// direct: a font/size change posts the redisplay the reader observes, and the
    /// keep-awake toggle sets the idle timer. `LegacyStateBridge` itself is
    /// deleted — its notification *observers* were mirroring UIKit state into
    /// `AppSession`, and there is no UIKit state left to mirror.
    func start() {
        settings.onReadingAppearanceChanged = {
            NotificationCenter.default.post(
                name: .resetBibleAndCommentaryView,
                object: nil
            )
        }
        settings.onKeepScreenAwakeChanged = { value in
            UIApplication.shared.isIdleTimerDisabled = value
        }
        // Materializes the font-size default (12) so the Settings slider has a
        // value to sit at rather than snapping from 0 on first drag. The deleted
        // `PSPreferencesController` did this lazily from its cell builder, which
        // meant the key only appeared once the user visited Preferences.
        settings.ensureFontSizeDefault()
        library.startObservingChanges()
        reading.apply(readingStore.snapshot())
        observeAppStateReset()
    }

    /// Starts listening for `LaunchCoordinator.resetPreferences()`.
    ///
    /// `.appStateDidReset` had **no production observer at all** — only a test — so
    /// a reset flipped in the iOS Settings bundle removed `fontNamePreference`,
    /// `fontSizePreference`, `insomniaPreference` and `bibleHistory` out from under
    /// models that had already cached them, and nothing told them. The Settings
    /// screen went on showing the pre-reset font and size, the Library went on
    /// listing history rows that no longer existed, and the idle timer stayed
    /// disabled for the rest of the session.
    ///
    /// Two things about the wiring are load-bearing:
    ///
    ///  - **The `.appStateDidReset` post comes after every removal** in
    ///    `resetPreferences()` and after the module selections are re-resolved (only
    ///    the `.redisplayPrimaryBible` post follows it), so this handler reads
    ///    post-reset state and needs no ordering of its own. At launch the
    ///    *remaining* migrations in `prepare()` still run alongside it on the
    ///    detached task; none of them touches what this re-reads, and `lastRef`
    ///    resolves to "Genesis 1" either way.
    ///  - **`queue: .main`.** The launch path runs `prepare()` — and therefore
    ///    `resetPreferences()` — off the main actor in a detached task, while
    ///    everything reloaded here is `@MainActor`. `queue: nil` would run the block
    ///    synchronously on that background thread, where none of this is legal.
    ///
    /// `start()` runs from `didFinishLaunching`, which precedes `RootView`'s
    /// `.task`, so the observer is always in place before a reset can post.
    private func observeAppStateReset() {
        guard resetObserver == nil else { return }
        resetObserver = NotificationCenter.default.addObserver(
            forName: .appStateDidReset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleAppStateReset()
            }
        }
    }

    /// Re-reads every cached preference the reset cleared.
    ///
    /// **`SettingsModel.reload()` rather than five assignments, and that is what
    /// keeps this from undoing the reset.** Each of those properties persists itself
    /// from `didSet`; `reload()` brackets the writes with `isReloading` so none of
    /// them writes back. Assigning them one by one would re-create exactly the keys
    /// the reset had just deleted.
    ///
    /// The corollary is that `onKeepScreenAwakeChanged` is suppressed along with the
    /// saves, so the idle timer is applied here explicitly — otherwise a user who
    /// had "keep the screen awake" on keeps a screen that never sleeps, with the
    /// preference gone and the toggle reading off.
    func handleAppStateReset() {
        // Re-materializes the font-size default exactly as `start()` does, so the
        // post-reset state equals the fresh-install state rather than "no key at
        // all". Both readers now resolve an absent key to
        // `AppConstants.defaultFontSize` — they used to disagree, 12 in the store
        // against 14 in the renderer — so this is about the Settings slider having
        // a value to sit at rather than about the two sides agreeing.
        settings.ensureFontSizeDefault()
        settings.reload()
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake

        // `bibleHistory` was removed and nothing posts `historyChanged` for it;
        // `lastDictionary` was removed and the primary dictionary cleared; `lastRef`
        // / `lastBible` / `lastCommentary` were removed under `reading`.
        library.reloadHistory()
        library.reloadDictionary()
        reading.apply(readingStore.snapshot())

        // The per-module display toggles went too, and the chrome MIRRORS their
        // values (`ReaderChromeModel.displayToggleValues`) rather than reading them
        // live, so the overflow menu would keep showing checkmarks for prefs that no
        // longer exist. `redisplayPrimaryBible` — which `resetPreferences()` also
        // posts — re-renders the text but does not rebuild the rows.
        readingWorkspace?.bible.refreshForModuleChange()
        readingWorkspace?.commentary.refreshForModuleChange()
    }

    /// Routes an incoming `sword://` URL, or defers it if launch is still running.
    ///
    /// This is `-application:handleOpenURL:options:` minus the delegate. The
    /// behaviour is unchanged, including the two things that look incidental and
    /// are not:
    ///
    ///  - **A URL the parser cannot resolve is ignored**, not guessed at: no
    ///    navigation, no history entry, one `alog` line from `URLRouter`. This is
    ///    the only reference the app does not itself generate, which is why
    ///    `PSRefParser` exists.
    ///  - **The persist happens before the redisplay, and the pane switch drops the
    ///    target pane's stale deferral.** `readingStore.persist` writes `lastRef` and
    ///    the verse position; `redisplayPrimary*` renders from them and
    ///    `HistoryStore.addEntry` reads `lastRef` back. Reversing the order renders
    ///    the previous chapter — and so does a bare `mode` flip, because `mode`'s
    ///    `didSet` drains the target pane's `refToShow` and `ReaderPaneModel.render`
    ///    rewrites `lastRef` from it. That is what `showRoutedMode(_:)` prevents; do
    ///    not shorten it back to `mode = …`.
    @discardableResult
    func open(_ url: URL?) -> Bool {
        guard isReady else {
            pendingURL = url
            return false
        }
        guard let route = URLRouter()?.route(for: url) else {
            return false
        }

        lastOpenedURL = route.sourceURL
        selectedWorkspace = .read
        reading.apply(route)
        readingStore.persist(route)

        switch route.destination {
        case .bible(let module):
            if let module {
                PSModuleController.default()?.loadPrimaryBible(module)
            }
            readingWorkspace?.showRoutedMode(.bible)
            NotificationCenter.default.post(
                name: .redisplayPrimaryBible,
                object: nil
            )
            library.recordHistory(mode: .bible)
        case .commentary(let module):
            if let module {
                PSModuleController.default()?.loadPrimaryCommentary(module)
            }
            readingWorkspace?.showRoutedMode(.commentary)
            NotificationCenter.default.post(
                name: .redisplayPrimaryCommentary,
                object: nil
            )
            library.recordHistory(mode: .commentary)
        }

        return true
    }

    /// Opens the launch URL held back during preparation, if there was one. Called
    /// once, from the `.ready` transition.
    func replayPendingURL() {
        isReady = true
        guard let url = pendingURL else { return }
        pendingURL = nil
        open(url)
    }

    func apply(_ route: URLRoute) {
        selectedWorkspace = .read
        lastOpenedURL = route.sourceURL
        reading.apply(route)
    }
}
