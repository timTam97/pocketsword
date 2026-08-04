import XCTest
@testable import PocketSword

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
        XCTAssertTrue(store.remove(at: 0))
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
    func testLegacyBridgeMirrorsNotificationsAndSettingsSideEffects() {
        defaults.set("John 3", forKey: Defaults.lastRef)
        defaults.set("16", forKey: Defaults.bibleVersePosition)
        defaults.set("17", forKey: Defaults.commentaryVersePosition)
        let settings = SettingsModel(store: SettingsStore(defaults: defaults))
        let session = AppSession(settings: settings)
        let center = NotificationCenter()
        var idleTimerValues: [Bool] = []
        let bridge = LegacyStateBridge(
            session: session,
            readingStore: ReadingStateStore(defaults: defaults),
            notificationCenter: center,
            idleTimerHandler: { idleTimerValues.append($0) }
        )

        bridge.start()

        XCTAssertEqual(session.reading.reference?.chapterRef, "John 3")
        XCTAssertEqual(session.reading.bibleVerse, 16)

        defaults.set("Psalms 23", forKey: Defaults.lastRef)
        defaults.set("4", forKey: Defaults.commentaryVersePosition)
        center.post(name: .showCommentaryTab, object: nil)

        XCTAssertEqual(session.selectedWorkspace, .read)
        XCTAssertEqual(session.reading.mode, .commentary)
        XCTAssertEqual(session.reading.reference?.chapterRef, "Psalms 23")
        XCTAssertEqual(session.reading.commentaryVerse, 4)

        settings.keepScreenAwake = true
        XCTAssertEqual(idleTimerValues, [true])

        settings.fontName = "Gentium Plus"
        defaults.removeObject(forKey: Defaults.fontNamePreference)
        defaults.removeObject(forKey: Defaults.insomniaPreference)
        center.post(name: .appStateDidReset, object: nil)

        XCTAssertEqual(settings.fontName, AppConstants.defaultFontName)
        XCTAssertFalse(settings.keepScreenAwake)
        XCTAssertNil(defaults.object(forKey: Defaults.fontNamePreference))
        XCTAssertNil(defaults.object(forKey: Defaults.insomniaPreference))
        XCTAssertEqual(idleTimerValues, [true])

        bridge.stop()
    }

    @MainActor
    func testLegacyBridgeReloadsLibrarySnapshots() {
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
        let historyStore = HistoryStore(
            defaults: defaults,
            cloudStore: HistoryCloudStoreStub(),
            notificationCenter: center
        )
        let library = LibraryModel(
            bookmarkStore: BookmarkStore(rootProvider: { root }),
            historyStore: historyStore
        )
        let session = AppSession(
            settings: SettingsModel(store: SettingsStore(defaults: defaults)),
            library: library
        )
        let bridge = LegacyStateBridge(
            session: session,
            readingStore: ReadingStateStore(defaults: defaults),
            notificationCenter: center,
            idleTimerHandler: { _ in }
        )
        bridge.start()

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

        XCTAssertEqual(session.library.bookmarks.count, 2)
        XCTAssertEqual(session.library.history.count, 1)

        bridge.stop()
    }
}
