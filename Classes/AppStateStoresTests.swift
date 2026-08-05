import XCTest
import Observation
import UIKit
@testable import PocketSword

/// Collects the FTS5 expressions a `SearchModel` actually queried with.
///
/// `SearchModel.runSearch` dispatches to a global queue, so a test cannot read a
/// plain captured array immediately after calling in — that races, and reads 1
/// where it wants 2. This holds them behind a lock and lets the test await a
/// count.
private final class ExpressionCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var expressions: [String] = []

    func record(_ expression: String) {
        lock.lock()
        expressions.append(expression)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return expressions
    }

    func wait(forCount count: Int, in testCase: XCTestCase) async {
        let reached = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in
                (self?.snapshot().count ?? 0) >= count
            },
            object: nil
        )
        await testCase.fulfillment(of: [reached], timeout: 5)
    }
}

private final class HistoryCloudStoreStub: HistoryCloudStoring {
    private(set) var values: [String: Any] = [:]

    func array(forKey defaultName: String) -> [Any]? {
        values[defaultName] as? [Any]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }
}

final class AppStateStoresTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "AppStateStoresTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try super.tearDownWithError()
    }

    func testSettingsStoreUsesLegacyKeysAndDefaults() {
        let store = SettingsStore(defaults: defaults)

        let initial = store.snapshot()

        XCTAssertEqual(initial.fontName, AppConstants.defaultFontName)
        XCTAssertEqual(initial.fontSize, 12)
        XCTAssertFalse(initial.keepScreenAwake)
        XCTAssertEqual(initial.rotationLock, .unlocked)
        XCTAssertFalse(initial.automaticFullscreen)
        XCTAssertNil(defaults.object(forKey: Defaults.fontSizePreference))

        store.ensureFontSizeDefault()

        XCTAssertEqual(defaults.integer(forKey: Defaults.fontSizePreference), 12)
    }

    @MainActor
    func testSettingsModelPersistsMutationsAndRunsSideEffects() {
        let model = SettingsModel(store: SettingsStore(defaults: defaults))
        var appearanceChanges = 0
        var idleTimerValues: [Bool] = []
        model.onReadingAppearanceChanged = {
            appearanceChanges += 1
        }
        model.onKeepScreenAwakeChanged = {
            idleTimerValues.append($0)
        }

        model.fontName = "Gentium Plus"
        model.fontSize = 18
        model.keepScreenAwake = true
        model.rotationLock = .landscape
        model.automaticFullscreen = true

        XCTAssertEqual(
            defaults.string(forKey: Defaults.fontNamePreference),
            "Gentium Plus"
        )
        XCTAssertEqual(defaults.integer(forKey: Defaults.fontSizePreference), 18)
        XCTAssertTrue(defaults.bool(forKey: Defaults.insomniaPreference))
        XCTAssertEqual(
            defaults.integer(forKey: Defaults.rotationLockPosition),
            RotationLock.landscape.rawValue
        )
        XCTAssertTrue(defaults.bool(forKey: Defaults.fullscreenModePreference))
        XCTAssertEqual(appearanceChanges, 2)
        XCTAssertEqual(idleTimerValues, [true])
    }

    @MainActor
    func testSettingsModelSwiftUIBindingsPreserveLegacyValues() {
        let model = SettingsModel(store: SettingsStore(defaults: defaults))

        model.fontSizeValue = 19
        model[rotationLockedFor: .landscape] = true

        XCTAssertEqual(model.fontSize, 19)
        XCTAssertEqual(model.rotationLock, .landscape)
        XCTAssertEqual(defaults.integer(forKey: Defaults.fontSizePreference), 19)
        XCTAssertEqual(
            defaults.integer(forKey: Defaults.rotationLockPosition),
            RotationLock.landscape.rawValue
        )

        model[rotationLockedFor: .portrait] = false

        XCTAssertEqual(model.rotationLock, .unlocked)
        XCTAssertEqual(
            defaults.integer(forKey: Defaults.rotationLockPosition),
            RotationLock.unlocked.rawValue
        )
    }

    func testAboutFeedbackUsesMailtoWithoutMessageUI() throws {
        let information = AboutInformation.current()
        let components = try XCTUnwrap(
            URLComponents(url: information.feedbackURL, resolvingAgainstBaseURL: false)
        )

        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, "pocketsword@icloud.com")
        XCTAssertTrue(
            components.queryItems?.contains {
                $0.name == "subject"
                    && ($0.value?.hasPrefix("PocketSword Feedback") ?? false)
            } ?? false
        )
    }

    @MainActor
    func testReferencePickerUsesStableBookIDsAndValidatedSelection() {
        let genesis = ReferencePickerBook(
            id: "Gen",
            name: "Genesis",
            shortName: "Gen",
            verseCounts: [31, 25]
        )
        let john = ReferencePickerBook(
            id: "John",
            name: "John",
            shortName: "Joh",
            verseCounts: [51, 25, 36]
        )
        let model = ReferencePickerModel(
            books: [genesis, john],
            currentReference: "John 3:16"
        )
        var selection: ReferencePickerSelection?
        model.onSelection = {
            selection = $0
        }

        XCTAssertEqual(model.currentBookID, "John")
        XCTAssertEqual(model.currentChapter, 3)
        XCTAssertEqual(
            model.indexEntries,
            [
                ReferencePickerIndexEntry(
                    shortName: "Gen",
                    bookID: "Gen"
                ),
                ReferencePickerIndexEntry(
                    shortName: "Joh",
                    bookID: "John"
                ),
            ]
        )

        model.openChapters(for: "John")
        model.openVerses(for: "John", chapter: 3)
        XCTAssertEqual(
            model.path,
            [
                .chapters(bookID: "John"),
                .verses(bookID: "John", chapter: 3),
            ]
        )

        model.select(bookID: "John", chapter: 3, verse: 16)
        XCTAssertEqual(
            selection,
            ReferencePickerSelection(
                bookName: "John",
                chapter: 3,
                verse: 16
            )
        )

        model.select(bookID: "John", chapter: 4, verse: 1)
        XCTAssertEqual(selection?.chapter, 3)
    }

    @MainActor
    func testVoiceReferenceModelMapsSessionStatesForSwiftUI() {
        let john = PSVoiceRefBook(
            names: ["John"],
            displayName: "John",
            chapters: 21,
            versesInChapter: { chapter in
                chapter == 3 ? 36 : 1
            }
        )
        let model = VoiceReferenceModel(books: [john])

        model.apply(.listening(volatileText: "John 3 16"))

        XCTAssertEqual(model.status, .listening)
        XCTAssertEqual(model.transcript, .value("John 3 16"))
        XCTAssertEqual(model.preview, "John 3:16")
        XCTAssertEqual(model.action, .done)
        XCTAssertTrue(model.isListening)

        model.apply(.finished(candidates: ["not a reference"]))

        XCTAssertEqual(model.status, .noMatch)
        XCTAssertEqual(model.transcript, .value("not a reference"))
        XCTAssertEqual(model.action, .tryAgain)
        XCTAssertTrue(model.showsCancel)

        model.apply(.failed(.microphoneDenied))

        XCTAssertEqual(model.status, .microphoneDenied)
        XCTAssertEqual(model.action, .openSettings)
        XCTAssertEqual(model.transcript, .empty)
    }

    func testReadingStateStoreLoadsLegacyPositionAndModules() throws {
        defaults.set("John 3", forKey: Defaults.lastRef)
        defaults.set("KJV-Test", forKey: Defaults.lastBible)
        defaults.set("MHCC-Test", forKey: Defaults.lastCommentary)
        defaults.set("16", forKey: Defaults.bibleVersePosition)
        defaults.set("17", forKey: Defaults.commentaryVersePosition)
        let store = ReadingStateStore(defaults: defaults)

        let snapshot = store.snapshot()

        XCTAssertEqual(snapshot.reference?.chapterRef, "John 3")
        XCTAssertEqual(snapshot.bibleModule, "KJV-Test")
        XCTAssertEqual(snapshot.commentaryModule, "MHCC-Test")
        XCTAssertEqual(snapshot.bibleVerse, 16)
        XCTAssertEqual(snapshot.commentaryVerse, 17)
    }

    func testReadingStateStorePersistsRouteWithoutChangingWireTypes() throws {
        let router = try XCTUnwrap(URLRouter())
        let store = ReadingStateStore(defaults: defaults)
        defaults.set("9", forKey: Defaults.commentaryVersePosition)

        let bibleRoute = try XCTUnwrap(router.route(
            for: URL(string: "sword://KJV/John+3:16")
        ))
        store.persist(bibleRoute)

        XCTAssertEqual(defaults.string(forKey: Defaults.lastRef), "John 3")
        XCTAssertEqual(
            defaults.string(forKey: Defaults.bibleVersePosition),
            "16"
        )
        XCTAssertEqual(
            defaults.string(forKey: Defaults.commentaryVersePosition),
            "9"
        )

        let commentaryRoute = try XCTUnwrap(router.route(
            for: URL(string: "sword://MHCC/Psalms+23:4")
        ))
        store.persist(commentaryRoute)

        XCTAssertEqual(defaults.string(forKey: Defaults.lastRef), "Psalms 23")
        XCTAssertEqual(
            defaults.string(forKey: Defaults.bibleVersePosition),
            "4"
        )
        XCTAssertEqual(
            defaults.string(forKey: Defaults.commentaryVersePosition),
            "4"
        )
    }

    func testBookmarkRuntimeIdentityIsExcludedFromPersistedSchema() throws {
        let bookmark = PSBookmark(
            name: "Hope",
            dateAdded: Date(timeIntervalSince1970: 10),
            dateLastAccessed: Date(timeIntervalSince1970: 20),
            bibleReference: "Romans 5:5"
        )

        let persisted = try XCTUnwrap(PSBookmarks.parseBookmarkObject(bookmark))
        let decoded = try XCTUnwrap(
            PSBookmarks.default().parseArray(persisted as? [Any]) as? PSBookmark
        )

        XCTAssertEqual(persisted.count, 5)
        XCTAssertNotEqual(decoded.id, bookmark.id)
        XCTAssertEqual(decoded.ref, bookmark.ref)
    }

    func testBookmarkStoreBuildsStableTypedTreeAndColor() throws {
        let bookmark = PSBookmark(
            name: "Hope",
            dateAdded: nil,
            dateLastAccessed: nil,
            bibleReference: "Romans 5:5"
        )
        let folder = PSBookmarkFolder(
            name: "Study",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: "#12ABEF",
            children: [bookmark]
        )
        let root = PSBookmarkFolder(
            name: "Bookmarks",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: [folder]
        )
        let store = BookmarkStore(rootProvider: { root })

        let first = try XCTUnwrap(store.snapshot().first)
        let second = try XCTUnwrap(store.snapshot().first)

        XCTAssertEqual(first.id, folder.id)
        XCTAssertEqual(second.id, first.id)
        guard case .folder(let color, let children) = first.kind else {
            return XCTFail("Expected a folder snapshot")
        }
        XCTAssertEqual(color?.hexString, "#12ABEF")
        XCTAssertEqual(children.first?.id, bookmark.id)
        XCTAssertEqual(
            children.first?.kind,
            .bookmark(reference: "Romans 5:5")
        )
    }

    func testBookmarkStoreMutatesNestedTreeAndPreservesObjectIdentity() throws {
        let first = PSBookmark(
            name: "First",
            dateAdded: Date(timeIntervalSince1970: 10),
            dateLastAccessed: Date(timeIntervalSince1970: 20),
            bibleReference: "John 1:1"
        )
        let second = PSBookmark(
            name: "Second",
            dateAdded: Date(timeIntervalSince1970: 30),
            dateLastAccessed: Date(timeIntervalSince1970: 40),
            bibleReference: "John 1:2"
        )
        let folder = PSBookmarkFolder(
            name: "Study",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: [first, second]
        )
        let root = PSBookmarkFolder(
            name: "Bookmarks",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: [folder]
        )
        let center = NotificationCenter()
        var saveCount = 0
        var changeCount = 0
        let observer = center.addObserver(
            forName: .bookmarksChanged,
            object: nil,
            queue: nil
        ) { _ in
            changeCount += 1
        }
        defer { center.removeObserver(observer) }
        let store = BookmarkStore(
            rootProvider: { root },
            save: {
                saveCount += 1
                return true
            },
            notificationCenter: center
        )

        try store.addFolder(
            name: "Notes",
            color: BookmarkColor(hexString: "#12ABEF"),
            to: folder.id
        )
        let notes = try XCTUnwrap(
            store.children(in: folder.id).first { $0.name == "Notes" }
        )
        try store.updateFolder(
            id: notes.id,
            name: "Notes 2",
            color: BookmarkColor(hexString: "#FF0000")
        )
        store.reorder(
            parentID: folder.id,
            sources: [second.id],
            before: first.id
        )
        try store.rename(id: first.id, to: "Opening")

        let children = store.children(in: folder.id)
        XCTAssertEqual(children.map(\.id), [second.id, first.id, notes.id])
        XCTAssertEqual(children[1].name, "Opening")
        XCTAssertEqual(store.node(id: notes.id)?.name, "Notes 2")
        XCTAssertEqual(
            (folder.children?[1] as? PSBookmarkObject)?.id,
            first.id
        )
        XCTAssertEqual(
            (folder.children?[2] as? PSBookmarkFolder)?.rgbHexString,
            "#FF0000"
        )
        XCTAssertEqual(store.markAccessed(id: first.id), "John 1:1")
        XCTAssertTrue(store.remove(id: second.id))
        XCTAssertEqual(store.children(in: folder.id).map(\.id), [first.id, notes.id])
        XCTAssertEqual(saveCount, 6)
        XCTAssertEqual(changeCount, 5)
    }

    func testBookmarkStoreRejectsDuplicateAndInvalidFolderNames() throws {
        let folder = PSBookmarkFolder(
            name: "Study",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: nil
        )
        let root = PSBookmarkFolder(
            name: "Bookmarks",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: [folder]
        )
        let store = BookmarkStore(
            rootProvider: { root },
            save: { true },
            notificationCenter: NotificationCenter()
        )

        XCTAssertThrowsError(
            try store.addFolder(name: "Study", color: nil, to: nil)
        ) {
            XCTAssertEqual($0 as? BookmarkMutationError, .duplicateFolder)
        }
        XCTAssertThrowsError(
            try store.addFolder(
                name: "Bad\(AppConstants.folderSeparatorString)Name",
                color: nil,
                to: nil
            )
        ) {
            XCTAssertEqual($0 as? BookmarkMutationError, .invalidFolderName)
        }
    }

    @MainActor
    func testLibraryBookmarkChildrenParticipateInObservation() throws {
        let root = PSBookmarkFolder(
            name: "Bookmarks",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: nil
        )
        let library = LibraryModel(
            bookmarkStore: BookmarkStore(
                rootProvider: { root },
                save: { true },
                notificationCenter: NotificationCenter()
            ),
            historyStore: HistoryStore(
                defaults: defaults,
                cloudStore: HistoryCloudStoreStub(),
                notificationCenter: NotificationCenter()
            )
        )
        var changed = false
        withObservationTracking {
            _ = library.bookmarkChildren(in: nil).count
        } onChange: {
            changed = true
        }

        try library.addBookmarkFolder(
            name: "Study",
            color: nil,
            parentID: nil
        )

        XCTAssertTrue(changed)
        XCTAssertEqual(library.bookmarkChildren(in: nil).first?.name, "Study")
    }

    @MainActor
    func testLibraryModelRestoresFiltersAndSelectsDictionary() {
        defaults.set(
            BundledModules.strongsGreek,
            forKey: Defaults.lastDictionary
        )
        var selectedModule: String?
        let keys = [
            BundledModules.strongsGreek: ["G0001", "G0002", "Word"],
            BundledModules.strongsHebrew: ["H0001"],
        ]
        let dictionaryStore = DictionaryStore(
            defaults: defaults,
            moduleProvider: { selectedModule },
            moduleLoader: {
                selectedModule = $0
                if let module = $0 {
                    self.defaults.set(module, forKey: Defaults.lastDictionary)
                }
            },
            moduleTypeProvider: { _ in "Lexicons / Dictionaries" },
            keysProvider: { keys[$0] ?? [] },
            entryProvider: { module, key in "\(module):\(key)" },
            htmlBuilder: { body, _ in "<html>\(body)</html>" }
        )
        let library = LibraryModel(
            bookmarkStore: BookmarkStore(
                rootProvider: { PSBookmarkFolder() },
                save: { true },
                notificationCenter: NotificationCenter()
            ),
            historyStore: HistoryStore(
                defaults: defaults,
                cloudStore: HistoryCloudStoreStub(),
                notificationCenter: NotificationCenter()
            ),
            dictionaryStore: dictionaryStore
        )

        library.reloadDictionary()

        XCTAssertEqual(library.dictionaryModule, BundledModules.strongsGreek)
        XCTAssertEqual(library.visibleDictionaryKeys.count, 3)

        library.dictionaryQuery = "0002"
        XCTAssertEqual(library.visibleDictionaryKeys, ["G0002"])
        XCTAssertTrue(
            library.dictionaryEntry(key: "G0002")?.html.contains(
                "\(BundledModules.strongsGreek):G0002"
            ) ?? false
        )

        library.selectDictionary(module: BundledModules.strongsHebrew)
        XCTAssertEqual(library.dictionaryModule, BundledModules.strongsHebrew)
        XCTAssertEqual(library.dictionaryQuery, "")
        XCTAssertEqual(library.visibleDictionaryKeys, ["H0001"])
        XCTAssertEqual(
            defaults.string(forKey: Defaults.lastDictionary),
            BundledModules.strongsHebrew
        )
    }

    func testHistoryStoreUsesNaturalIDsAndPersistsRemoval() throws {
        let firstDate = Date(timeIntervalSince1970: 200)
        let secondDate = Date(timeIntervalSince1970: 100)
        defaults.set(
            [
                ["John 3:16", "0", "KJV", firstDate],
                ["Psalms 23:4", "0", "KJV", secondDate],
            ],
            forKey: AppConstants.historyName
        )
        let cloud = HistoryCloudStoreStub()
        let center = NotificationCenter()
        var changeCount = 0
        let token = center.addObserver(
            forName: .historyChanged,
            object: nil,
            queue: nil
        ) { _ in
            changeCount += 1
        }
        defer { center.removeObserver(token) }
        let store = HistoryStore(
            defaults: defaults,
            cloudStore: cloud,
            notificationCenter: center
        )

        let entries = store.snapshot()

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].id.reference, "John 3:16")
        XCTAssertEqual(entries[0].id.moduleName, "KJV")
        XCTAssertEqual(entries[0].id.dateAdded, firstDate)
        XCTAssertTrue(store.remove(id: entries[0].id))
        XCTAssertEqual(
            defaults.array(forKey: AppConstants.historyName)?.count,
            1
        )
        XCTAssertEqual(
            (cloud.values[AppConstants.historyName] as? [Any])?.count,
            1
        )
        XCTAssertEqual(changeCount, 1)
    }

    func testHistoryStoreOwnsExternalCloudNotificationAndInitialMerge() {
        let localDate = Date(timeIntervalSince1970: 100)
        let cloudDate = Date(timeIntervalSince1970: 200)
        defaults.set(
            [["Genesis 1:1", "0", "KJV", localDate]],
            forKey: AppConstants.historyName
        )
        let cloud = HistoryCloudStoreStub()
        cloud.set(
            [["John 3:16", "0", "KJV", cloudDate]],
            forKey: AppConstants.historyName
        )
        let center = NotificationCenter()
        let store = HistoryStore(
            defaults: defaults,
            cloudStore: cloud,
            notificationCenter: center
        )
        store.startCloudSync()
        defer { store.stopCloudSync() }

        center.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            userInfo: [
                NSUbiquitousKeyValueStoreChangeReasonKey:
                    NSNumber(
                        value: NSUbiquitousKeyValueStoreInitialSyncChange
                    ),
                NSUbiquitousKeyValueStoreChangedKeysKey:
                    [AppConstants.historyName],
            ]
        )

        let merged = defaults.array(forKey: AppConstants.historyName)
        XCTAssertEqual(merged?.count, 2)
        XCTAssertEqual((merged?.first as? [Any])?.first as? String, "John 3:16")
        XCTAssertEqual(
            (cloud.values[AppConstants.historyName] as? [Any])?.count,
            2
        )
    }

    func testLaunchCoordinatorRunsOneShotMigrationsOffUIKit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let documents = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        let installer = root.appendingPathComponent("InstallMgr")
        let temporary = root.appendingPathComponent("MMM")
        for directory in [documents, caches, installer, temporary] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        for name in ["mods.d", "modules", "locales.d", "unused"] {
            try FileManager.default.createDirectory(
                at: documents.appendingPathComponent(name),
                withIntermediateDirectories: true
            )
        }
        let cachePath = caches.appendingPathComponent(
            "cache-\(BundledModules.morphGreek)-1.0"
        )
        XCTAssertTrue(
            FileManager.default.createFile(
                atPath: cachePath.path,
                contents: Data()
            )
        )

        defaults.set(true, forKey: Defaults.kjvRemoved)
        defaults.set("None", forKey: Defaults.strongsGreekModule)
        defaults.set("orphan", forKey: "fontNamePreference_")
        defaults.psSet(
            "Legacy Font",
            forPref: Defaults.fontNamePreference,
            module: BundledModules.bible
        )
        defaults.set("Nonsense 9", forKey: Defaults.lastRef)
        defaults.set("42", forKey: Defaults.bibleVersePosition)
        defaults.set(true, forKey: Defaults.insomniaPreference)
        var resetCount = 0
        let coordinator = LaunchCoordinator(
            defaults: defaults,
            notificationCenter: NotificationCenter(),
            paths: LaunchCoordinator.Paths(
                moduleRoot: documents.path,
                appSupportRoot: caches.path,
                installerRoot: installer.path,
                temporaryRoot: temporary.path
            ),
            moduleControllerAvailable: { true },
            resetModuleSelections: { resetCount += 1 },
            currentReference: { "Nonsense 9" },
            referenceResolves: { _ in false },
            moduleVersion: { _ in "1.0" }
        )

        let result = coordinator.prepare()

        XCTAssertEqual(result, LaunchResult(shouldDisableIdleTimer: true))
        XCTAssertEqual(resetCount, 0)
        XCTAssertTrue(defaults.bool(forKey: Defaults.moduleChoiceRetired))
        XCTAssertTrue(defaults.bool(forKey: Defaults.globalFontOnly))
        XCTAssertTrue(defaults.bool(forKey: Defaults.lastRefValidated))
        XCTAssertTrue(defaults.bool(forKey: Defaults.dictKeyCaseFixed))
        XCTAssertTrue(defaults.bool(forKey: Defaults.swordRetired))
        XCTAssertNil(defaults.object(forKey: Defaults.kjvRemoved))
        XCTAssertNil(defaults.object(forKey: Defaults.strongsGreekModule))
        XCTAssertNil(defaults.object(forKey: "fontNamePreference_"))
        XCTAssertNil(
            defaults.psString(
                Defaults.fontNamePreference,
                forModule: BundledModules.bible
            )
        )
        XCTAssertEqual(defaults.string(forKey: Defaults.lastRef), "Genesis 1")
        XCTAssertEqual(
            defaults.string(forKey: Defaults.bibleVersePosition),
            "1"
        )
        XCTAssertEqual(
            defaults.string(forKey: Defaults.commentaryVersePosition),
            "1"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachePath.path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: installer.path)
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: temporary.path)
        )
        for name in ["mods.d", "modules", "locales.d", "unused"] {
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: documents.appendingPathComponent(name).path
                )
            )
        }
    }

    func testLaunchCoordinatorResetPreservesLegacyKeysAndNotifications() {
        defaults.set(true, forKey: "reset_PocketSword")
        defaults.set("John 3", forKey: Defaults.lastRef)
        defaults.set(["history"], forKey: AppConstants.historyName)
        defaults.set("value", forKey: "loadedSWORDLocales-130708")
        defaults.psSet(
            true,
            forPref: Defaults.redLetterPreference,
            module: BundledModules.bible
        )
        let center = NotificationCenter()
        var resetNotifications = 0
        var redisplayNotifications = 0
        let resetObserver = center.addObserver(
            forName: .appStateDidReset,
            object: nil,
            queue: nil
        ) { _ in resetNotifications += 1 }
        let redisplayObserver = center.addObserver(
            forName: .redisplayPrimaryBible,
            object: nil,
            queue: nil
        ) { _ in redisplayNotifications += 1 }
        defer {
            center.removeObserver(resetObserver)
            center.removeObserver(redisplayObserver)
        }
        var resetSelections = 0
        let coordinator = LaunchCoordinator(
            defaults: defaults,
            notificationCenter: center,
            moduleControllerAvailable: { true },
            resetModuleSelections: { resetSelections += 1 }
        )

        XCTAssertTrue(coordinator.resetPreferences())

        XCTAssertNil(defaults.object(forKey: "reset_PocketSword"))
        XCTAssertNil(defaults.object(forKey: Defaults.lastRef))
        XCTAssertNil(defaults.object(forKey: AppConstants.historyName))
        XCTAssertNil(
            defaults.object(forKey: "loadedSWORDLocales-130708")
        )
        XCTAssertNil(
            defaults.object(
                forKey: defaults.psModuleKey(
                    Defaults.redLetterPreference,
                    BundledModules.bible
                )
            )
        )
        XCTAssertEqual(resetSelections, 1)
        XCTAssertEqual(resetNotifications, 1)
        XCTAssertEqual(redisplayNotifications, 1)
    }

    func testSearchOptionsStorePreservesLegacyKeysAndEnumOrdinals() {
        let store = SearchOptionsStore(defaults: defaults)
        store.save(
            SearchOptionsSnapshot(
                fuzzy: true,
                matchType: .ExactSearch,
                range: .BookRange
            )
        )

        let snapshot = store.snapshot()

        XCTAssertTrue(snapshot.fuzzy)
        XCTAssertEqual(snapshot.matchType, .ExactSearch)
        XCTAssertEqual(snapshot.range, .BookRange)
        XCTAssertEqual(
            defaults.integer(forKey: Defaults.lastSearchType),
            PSSearchType.ExactSearch.rawValue
        )
        XCTAssertEqual(
            defaults.integer(forKey: Defaults.lastSearchRange),
            PSSearchRange.BookRange.rawValue
        )
    }

    @MainActor
    func testSearchModelUsesNaturalResultIdentity() {
        let model = SearchModel(
            optionsStore: SearchOptionsStore(defaults: defaults),
            indexCoordinator: SearchIndexCoordinator(
                freshnessProvider: { _ in true },
                buildOperation: { _, _ in }
            )
        )
        let result = PSSearchResult(
            reference: "John 3:16",
            fullText: "For God so loved the world"
        )
        result.strongsHighlightWords = ["loved"]

        model.setResults([result])

        XCTAssertEqual(model.results.first?.id, "John 3:16")
        XCTAssertEqual(model.results.first?.text, "For God so loved the world")
        XCTAssertEqual(model.results.first?.strongsHighlightWords, ["loved"])
    }

    /// A SECOND "Find all occurrences" must run the new term, not re-show the
    /// previous one's results.
    ///
    /// This is the regression test for a device-reported bug: the reader parked a
    /// `PSSearchHistoryItem` for `SearchView` to pick up in `configure(...)`, but
    /// that runs once per launch behind a `@State` guard, so every Strong's search
    /// after the first silently displayed the earlier term. Tapping H1254 showed
    /// H430's 1,000 rows. `startStrongsQuery` drives the model directly instead.
    @MainActor
    func testRepeatedStrongsQueriesEachRunTheirOwnTerm() async {
        // The query runs on a global queue, so the expressions are collected
        // behind a lock and awaited rather than read straight after the call.
        let collector = ExpressionCollector()
        let model = SearchModel(
            optionsStore: SearchOptionsStore(defaults: defaults),
            indexCoordinator: SearchIndexCoordinator(
                freshnessProvider: { _ in true },
                buildOperation: { _, _ in }
            ),
            debounceInterval: 0,
            featureProvider: { _, _ in true },
            queryOperation: { _, expression, _, _, _ in
                collector.record(expression)
                return [
                    PSSearchResult(
                        reference: "Genesis 1:1",
                        fullText: "In the beginning"
                    ),
                ]
            }
        )
        model.configure(
            modules: [SearchModuleChoice(id: "KJV", kind: .bible)],
            preferredModule: "KJV",
            currentBookName: "Genesis",
            restoring: nil
        )

        model.startStrongsQuery("H430", currentBookName: "Genesis")
        XCTAssertEqual(model.query, "H430")
        XCTAssertTrue(model.strongsSearch)
        await collector.wait(forCount: 1, in: self)

        // The second lookup is the one that used to fail.
        model.startStrongsQuery("H1254", currentBookName: "Genesis")
        XCTAssertEqual(
            model.query,
            "H1254",
            "A second Strong's lookup must replace the query, not keep the first."
        )
        await collector.wait(forCount: 2, in: self)

        let expressions = collector.snapshot()
        XCTAssertTrue(
            expressions[0].contains("430"),
            "First query should search H430; got \(expressions[0])"
        )
        XCTAssertTrue(
            expressions[1].contains("1254"),
            "Second query should search H1254; got \(expressions[1])"
        )

        // An empty or whitespace-only term is ignored rather than clearing the
        // query, so a malformed link cannot wipe a good search.
        model.startStrongsQuery("   ", currentBookName: "Genesis")
        XCTAssertEqual(model.query, "H1254")
        XCTAssertEqual(collector.snapshot().count, 2)
    }

    @MainActor
    func testSearchIndexCoordinatorReportsProgressAndCompletion() async {
        let completed = expectation(description: "Index build completed")
        let coordinator = SearchIndexCoordinator(
            freshnessProvider: { $0 == "KJV" },
            buildOperation: { _, progress in
                var cancel = false
                progress?(0.5, &cancel)
            }
        )
        var states: [SearchIndexState] = []
        coordinator.onStateChange = {
            states.append($0)
        }
        coordinator.onCompletion = { success, cancelled in
            XCTAssertTrue(success)
            XCTAssertFalse(cancelled)
            completed.fulfill()
        }

        coordinator.refresh(module: "KJV")
        coordinator.build(module: "KJV")
        await fulfillment(of: [completed], timeout: 2)

        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertTrue(states.contains(.building(progress: 0)))
        XCTAssertTrue(states.contains(.building(progress: 0.5)))
        XCTAssertEqual(states.last, .ready)
    }

    @MainActor
    func testSearchModelRejectsAStaleCompletion() async {
        let newestSearchCompleted = expectation(
            description: "Newest search completed"
        )
        let coordinator = SearchIndexCoordinator(
            freshnessProvider: { _ in true },
            buildOperation: { _, _ in }
        )
        let model = SearchModel(
            optionsStore: SearchOptionsStore(defaults: defaults),
            indexCoordinator: coordinator,
            debounceInterval: 0,
            featureProvider: { _, _ in false },
            queryOperation: { _, expression, _, _, _ in
                if expression.contains("first") {
                    Thread.sleep(forTimeInterval: 0.15)
                    return [
                        PSSearchResult(
                            reference: "Genesis 1:1",
                            fullText: "first"
                        ),
                    ]
                }
                Thread.sleep(forTimeInterval: 0.01)
                return [
                    PSSearchResult(
                        reference: "John 3:16",
                        fullText: "second"
                    ),
                ]
            }
        )
        model.onHistoryChange = { _ in
            if model.results.first?.reference == "John 3:16" {
                newestSearchCompleted.fulfill()
            }
        }
        model.configure(
            modules: [
                SearchModuleChoice(id: "KJV", kind: .bible),
            ],
            preferredModule: "KJV",
            currentBookName: "John",
            restoring: nil
        )

        model.query = "first"
        model.queryDidChange()
        model.query = "second"
        model.queryDidChange()

        await fulfillment(of: [newestSearchCompleted], timeout: 2)
        try? await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(model.results.map(\.reference), ["John 3:16"])
        XCTAssertEqual(model.results.first?.text, "second")
    }

    @MainActor
    func testSearchModelRestoresHistoryAndStrongHighlights() throws {
        let coordinator = SearchIndexCoordinator(
            freshnessProvider: { _ in false },
            buildOperation: { _, _ in }
        )
        let model = SearchModel(
            optionsStore: SearchOptionsStore(defaults: defaults),
            indexCoordinator: coordinator,
            featureProvider: { module, feature in
                module == "KJV" && feature == "Strongs"
            }
        )
        let historyItem = try XCTUnwrap(
            PSSearchHistoryItem(
                searchTermToDisplay: "H430",
                strongs: true,
                fuzzy: false,
                type: .OrSearch,
                range: .BookRange,
                book: "Genesis"
            )
        )
        historyItem.results = [
            PSVerseTextEntry(
                key: "Genesis 1:1",
                text: "In the beginning God created"
            ),
        ]

        model.configure(
            modules: [
                SearchModuleChoice(id: "KJV", kind: .bible),
                SearchModuleChoice(id: "MHCC", kind: .commentary),
            ],
            preferredModule: "KJV",
            currentBookName: "John",
            restoring: historyItem
        )

        XCTAssertEqual(model.query, "H430")
        XCTAssertTrue(model.strongsSearch)
        XCTAssertEqual(model.range, .BookRange)
        XCTAssertEqual(model.bookName, "Genesis")
        XCTAssertEqual(model.results.first?.reference, "Genesis 1:1")
        XCTAssertEqual(
            SearchModel.highlightTerms(
                query: "love \"the world\" a",
                matchType: .AndSearch,
                strongs: false
            ),
            ["love", "the world"]
        )
    }

    func testSearchIndexBackgroundManagerPersistsRecoveryRequest() {
        var submittedIdentifiers: [String] = []
        var cancelledIdentifiers: [String] = []
        let scheduler = SearchIndexBackgroundManager.Scheduler(
            register: { _, _ in true },
            submit: { request, completion in
                submittedIdentifiers.append(request.identifier)
                completion(nil)
            },
            cancel: {
                cancelledIdentifiers.append($0)
            }
        )
        let manager = SearchIndexBackgroundManager(
            defaults: defaults,
            taskIdentifier: "test.search-index",
            scheduler: scheduler,
            buildOperation: { _, _ in }
        )

        manager.beginForegroundBuild(module: "KJV")

        XCTAssertEqual(
            defaults.string(forKey: Defaults.pendingSearchIndexModule),
            "KJV"
        )
        XCTAssertEqual(submittedIdentifiers, ["test.search-index"])

        manager.finishForegroundBuild(module: "KJV")

        XCTAssertNil(
            defaults.string(forKey: Defaults.pendingSearchIndexModule)
        )
        XCTAssertEqual(cancelledIdentifiers, ["test.search-index"])
    }

    func testSearchIndexBackgroundManagerPerformsPendingBuild() {
        let completed = expectation(description: "Pending index build completed")
        defaults.set("KJV", forKey: Defaults.pendingSearchIndexModule)
        var builtModules: [String] = []
        let scheduler = SearchIndexBackgroundManager.Scheduler(
            register: { _, _ in true },
            submit: { _, completion in completion(nil) },
            cancel: { _ in }
        )
        let manager = SearchIndexBackgroundManager(
            defaults: defaults,
            taskIdentifier: "test.search-index",
            scheduler: scheduler,
            buildOperation: { module, progress in
                builtModules.append(module)
                var cancel = false
                progress?(1, &cancel)
                XCTAssertFalse(cancel)
            }
        )

        manager.performPendingBuild(
            cancellationRequested: { false }
        ) { success, shouldRetry in
            XCTAssertTrue(success)
            XCTAssertFalse(shouldRetry)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 2)
        XCTAssertEqual(builtModules, ["KJV"])
        XCTAssertNil(
            defaults.string(forKey: Defaults.pendingSearchIndexModule)
        )
    }

    func testReaderBridgeEventsPreserveNavigationPayloads() throws {
        XCTAssertEqual(
            ReaderBridgeEvent(
                url: try XCTUnwrap(
                    URL(string: "pocketsword:currentverse:16:241.75:200")
                )
            ),
            .currentVerse(verse: 16, scrollPosition: 241.75)
        )
        XCTAssertEqual(
            ReaderBridgeEvent(
                url: try XCTUnwrap(
                    URL(string: "pocketsword:versemenu:8")
                )
            ),
            .verseMenu(verse: 8)
        )
        XCTAssertEqual(
            ReaderBridgeEvent(
                url: try XCTUnwrap(URL(string: "arraydump:0:42.5:99:"))
            ),
            .versePositions([0, 42.5, 99, 0])
        )
        XCTAssertNil(
            ReaderBridgeEvent(
                url: try XCTUnwrap(URL(string: "pocketsword:currentverse"))
            )
        )
    }

    // `testReaderFrameStopsAtOverlappingTabBar` is GONE (Wave 7). It pinned
    // `PSModuleViewController.readerFrame`, the manual clamp that capped the Wave 6
    // reader host at the floating tab bar's top because a bare SwiftUI `WebView`
    // could not inset itself. `ReaderScreen`'s `NavigationStack` participates in the
    // safe area properly, so the host now fills the controller's view and both the
    // clamp and its test are deleted rather than adjusted.

    /// The per-module display toggles a module's BAKED feature set earns it.
    ///
    /// This is the Wave 7 home of a contract that was previously only observable by
    /// counting rows in a live `UIMenu`: **KJV yields exactly six rows, and
    /// Cross-references is not among them** (it has no `OSISScripref` filter and no
    /// `Feature=Scripref`), while **MHCC yields zero**, which is what makes the
    /// control hide itself instead of presenting an empty menu.
    func testDisplayTogglesMatchBakedFeatureSets() throws {
        let store = try XCTUnwrap(
            PSContentStore.shared,
            "PSContentStore.shared is required for the baked feature set."
        )

        let kjv = ReaderDisplayToggle.toggles(
            forModule: BundledModules.bible,
            store: store
        )
        XCTAssertEqual(
            kjv.map(\.id),
            ["strongs", "morph", "headings", "footnotes", "redLetter", "vpl"],
            "KJV earns six rows in this order, with no cross-references row."
        )
        XCTAssertFalse(kjv.contains { $0.id == "xref" })
        // Each row must carry the same unsuffixed pref name the UIKit menu wrote,
        // because the persisted key is "<pref>_<ModuleName>".
        XCTAssertEqual(
            kjv.map(\.preference),
            [
                Defaults.strongsPreference,
                Defaults.morphPreference,
                Defaults.headingsPreference,
                Defaults.footnotesPreference,
                Defaults.redLetterPreference,
                Defaults.vplPreference,
            ]
        )

        XCTAssertTrue(
            ReaderDisplayToggle.toggles(
                forModule: BundledModules.commentary,
                store: store
            ).isEmpty,
            "MHCC declares no Feature= and no GlobalOptionFilter, so it earns no rows."
        )

        // A nil module or a nil store yields nothing rather than crashing — the
        // old `guard let ... else { setSettingsMenu(nil) }` path.
        XCTAssertTrue(
            ReaderDisplayToggle.toggles(forModule: nil, store: store).isEmpty
        )
        XCTAssertTrue(
            ReaderDisplayToggle.toggles(
                forModule: BundledModules.bible,
                store: nil
            ).isEmpty
        )
    }

    /// The chrome model reads each toggle's CURRENT per-module value, so the
    /// checkmark reflects the pref rather than a stale snapshot.
    @MainActor
    func testChromeModelReflectsPerModuleToggleValues() throws {
        let store = try XCTUnwrap(PSContentStore.shared)
        defaults.psSet(
            true,
            forPref: Defaults.strongsPreference,
            module: BundledModules.bible
        )
        defaults.psSet(
            false,
            forPref: Defaults.vplPreference,
            module: BundledModules.bible
        )

        let chrome = ReaderChromeModel()
        chrome.reloadDisplayToggles(
            forModule: BundledModules.bible,
            store: store,
            defaults: defaults
        )

        XCTAssertEqual(chrome.displayToggles.count, 6)
        XCTAssertEqual(chrome.displayToggleValues["strongs"], true)
        XCTAssertEqual(chrome.displayToggleValues["vpl"], false)

        // Switching to a module with no features empties both, which is what hides
        // the control.
        chrome.reloadDisplayToggles(
            forModule: BundledModules.commentary,
            store: store,
            defaults: defaults
        )
        XCTAssertTrue(chrome.displayToggles.isEmpty)
        XCTAssertTrue(chrome.displayToggleValues.isEmpty)
    }

    /// The accessibility-identifier prefix keeps the UIKit menu's per-tab spelling
    /// ("bible." / "commentary."), so the identifiers do not change meaning.
    @MainActor
    func testChromeIdentifierPrefixFollowsTab() {
        let chrome = ReaderChromeModel()
        chrome.isBibleTab = true
        XCTAssertEqual(chrome.identifierPrefix, "bible")
        chrome.isBibleTab = false
        XCTAssertEqual(chrome.identifierPrefix, "commentary")
    }

    /// `AppSession.start()` restores the persisted reading position and wires the
    /// settings side effects.
    ///
    /// Wave 8 retargeted this off `LegacyStateBridge`, which is deleted. The bridge
    /// existed to mirror UIKit notification state into `AppSession` during the mixed
    /// migration; both ends are SwiftUI now, so `start()` does the two things that
    /// actually mattered — seed `reading` from `ReadingStateStore`, and post the
    /// redisplay a font change needs — directly. The **claims** are the bridge's:
    /// the restored snapshot must carry both verse positions independently, and a
    /// font change must reach the reader.
    @MainActor
    func testSessionStartRestoresReadingStateAndWiresSettingsEffects() {
        defaults.set("John 3", forKey: Defaults.lastRef)
        defaults.set("16", forKey: Defaults.bibleVersePosition)
        defaults.set("17", forKey: Defaults.commentaryVersePosition)
        let settings = SettingsModel(store: SettingsStore(defaults: defaults))
        let session = AppSession(
            settings: settings,
            readingStore: ReadingStateStore(defaults: defaults)
        )

        session.start()

        XCTAssertEqual(session.reading.reference?.chapterRef, "John 3")
        XCTAssertEqual(session.reading.bibleVerse, 16)
        XCTAssertEqual(session.reading.commentaryVerse, 17)

        // A font change must post the redisplay the reader observes; that post IS
        // the whole mechanism by which Preferences reaches the reading surface.
        let redisplayed = expectation(
            forNotification: .resetBibleAndCommentaryView,
            object: nil
        )
        settings.fontName = "Gentium Plus"
        wait(for: [redisplayed], timeout: 2)
        XCTAssertEqual(
            defaults.string(forKey: Defaults.fontNamePreference),
            "Gentium Plus"
        )
    }

    /// `LibraryModel` refreshes its snapshots off `bookmarksChanged` /
    /// `historyChanged`.
    ///
    /// Also a retargeted bridge test: the observers moved from `LegacyStateBridge`
    /// onto the model that owns the data, so this drives them where they now live.
    /// The claim is unchanged — a mutation behind the store's back, announced by
    /// notification, must reach the published arrays, because that is what makes the
    /// SwiftUI lists update.
    @MainActor
    func testLibraryModelReloadsSnapshotsOnChangeNotifications() {
        let firstBookmark = PSBookmark(
            name: "First",
            dateAdded: nil,
            dateLastAccessed: nil,
            bibleReference: "John 1:1"
        )
        let root = PSBookmarkFolder(
            name: "Bookmarks",
            dateAdded: nil,
            dateLastAccessed: nil,
            rgbHexString: nil,
            children: [firstBookmark]
        )
        let center = NotificationCenter()
        let library = LibraryModel(
            bookmarkStore: BookmarkStore(rootProvider: { root }),
            historyStore: HistoryStore(
                defaults: defaults,
                cloudStore: HistoryCloudStoreStub(),
                notificationCenter: center
            ),
            notificationCenter: center
        )
        library.startObservingChanges()

        XCTAssertEqual(library.bookmarks.count, 1)

        root.children = [
            firstBookmark,
            PSBookmark(
                name: "Second",
                dateAdded: nil,
                dateLastAccessed: nil,
                bibleReference: "John 1:2"
            ),
        ]
        defaults.set(
            [["John 1:1", "0", "KJV", Date(timeIntervalSince1970: 1)]],
            forKey: AppConstants.historyName
        )
        center.post(name: .bookmarksChanged, object: nil)
        center.post(name: .historyChanged, object: nil)

        XCTAssertEqual(library.bookmarks.count, 2)
        XCTAssertEqual(library.history.count, 1)
    }

    /// `HistoryStore.addEntry` writes the byte-exact persisted row shape.
    ///
    /// Wave 8 moved this off `PSHistoryController` (a deleted
    /// `UITableViewController`) onto the store. The persisted format is
    /// `[ref, "0", module, NSDate]` — positional, with `"0"` a literal string — and
    /// `PersistedFormatTests` locks the reader side of it. This locks the writer,
    /// which had no direct coverage before: it was only reachable through a view
    /// controller.
    @MainActor
    func testHistoryStoreAddEntryWritesThePersistedRowShape() throws {
        defaults.set("Genesis 5", forKey: Defaults.lastRef)
        defaults.set("9", forKey: Defaults.bibleVersePosition)
        defaults.removeObject(forKey: AppConstants.historyName)

        let store = HistoryStore(
            defaults: defaults,
            cloudStore: HistoryCloudStoreStub(),
            notificationCenter: NotificationCenter(),
            moduleNameProvider: { _ in BundledModules.bible }
        )
        store.addEntry(mode: .bible)

        let history = try XCTUnwrap(
            defaults.array(forKey: AppConstants.historyName)
        )
        XCTAssertEqual(history.count, 1)
        let row = try XCTUnwrap(history[0] as? [Any])
        XCTAssertEqual(row.count, 4)
        XCTAssertEqual(row[0] as? String, "Genesis 5:9")
        XCTAssertEqual(
            row[1] as? String,
            "0",
            "The scroll slot is the literal string \"0\", not a number."
        )
        XCTAssertEqual(row[2] as? String, BundledModules.bible)
        XCTAssertNotNil(row[3] as? Date)

        // Re-recording the same reference in the same module REPLACES the row
        // rather than appending, which is what keeps the list from filling with
        // one entry per scroll.
        store.addEntry(mode: .bible)
        XCTAssertEqual(
            defaults.array(forKey: AppConstants.historyName)?.count,
            1
        )
    }
}
