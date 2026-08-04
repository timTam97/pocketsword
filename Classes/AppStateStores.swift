import Foundation

enum RotationLock: Int, Equatable {
    case unlocked = 0
    case portrait = 1
    case landscape = 2
}

struct SettingsSnapshot: Equatable {
    let fontName: String
    let fontSize: Int
    let keepScreenAwake: Bool
    let rotationLock: RotationLock
    let automaticFullscreen: Bool
}

final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func snapshot() -> SettingsSnapshot {
        let savedFontSize = defaults.integer(forKey: Defaults.fontSizePreference)
        return SettingsSnapshot(
            fontName: defaults.string(forKey: Defaults.fontNamePreference)
                ?? AppConstants.defaultFontName,
            fontSize: savedFontSize == 0 ? 12 : savedFontSize,
            keepScreenAwake: defaults.bool(forKey: Defaults.insomniaPreference),
            rotationLock: RotationLock(
                rawValue: defaults.integer(forKey: Defaults.rotationLockPosition)
            ) ?? .unlocked,
            automaticFullscreen: defaults.bool(
                forKey: Defaults.fullscreenModePreference
            )
        )
    }

    func ensureFontSizeDefault() {
        guard defaults.integer(forKey: Defaults.fontSizePreference) == 0 else {
            return
        }
        defaults.set(12, forKey: Defaults.fontSizePreference)
    }

    func saveFontName(_ value: String) {
        defaults.set(value, forKey: Defaults.fontNamePreference)
        defaults.synchronize()
    }

    func saveFontSize(_ value: Int) {
        defaults.set(value, forKey: Defaults.fontSizePreference)
        defaults.synchronize()
    }

    func saveKeepScreenAwake(_ value: Bool) {
        defaults.set(value, forKey: Defaults.insomniaPreference)
        defaults.synchronize()
    }

    func saveRotationLock(_ value: RotationLock) {
        defaults.setValue(
            NSNumber(value: Int32(value.rawValue)),
            forKey: Defaults.rotationLockPosition
        )
        defaults.synchronize()
    }

    func saveAutomaticFullscreen(_ value: Bool) {
        defaults.set(value, forKey: Defaults.fullscreenModePreference)
        defaults.synchronize()
    }
}

struct ReadingSnapshot: Equatable {
    let reference: BibleReference?
    let bibleModule: String
    let commentaryModule: String
    let bibleVerse: Int
    let commentaryVerse: Int
}

final class ReadingStateStore {
    private let defaults: UserDefaults
    private let parser: PSRefParser?

    init(
        defaults: UserDefaults = .standard,
        parser: PSRefParser? = PSRefParser()
    ) {
        self.defaults = defaults
        self.parser = parser
    }

    func snapshot() -> ReadingSnapshot {
        let persistedReference = defaults.string(forKey: Defaults.lastRef)
            ?? "Genesis 1"
        return ReadingSnapshot(
            reference: parser?.parse(persistedReference),
            bibleModule: defaults.string(forKey: Defaults.lastBible)
                ?? BundledModules.bible,
            commentaryModule: defaults.string(forKey: Defaults.lastCommentary)
                ?? BundledModules.commentary,
            bibleVerse: intValue(forKey: Defaults.bibleVersePosition),
            commentaryVerse: intValue(forKey: Defaults.commentaryVersePosition)
        )
    }

    func persist(_ route: URLRoute) {
        defaults.set(route.persistedChapterRef, forKey: Defaults.lastRef)
        defaults.set(route.versePosition, forKey: Defaults.bibleVersePosition)
        if case .commentary = route.destination {
            defaults.set(
                route.versePosition,
                forKey: Defaults.commentaryVersePosition
            )
        }
        defaults.synchronize()
    }

    private func intValue(forKey key: String) -> Int {
        guard let value = defaults.string(forKey: key), let int = Int(value) else {
            return 1
        }
        return int
    }
}

struct BookmarkColor: Equatable, Hashable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init?(hexString: String?) {
        guard var value = hexString, !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            return nil
        }
        red = UInt8((rgb >> 16) & 0xff)
        green = UInt8((rgb >> 8) & 0xff)
        blue = UInt8(rgb & 0xff)
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

struct BookmarkNode: Identifiable, Equatable {
    enum Kind: Equatable {
        case bookmark(reference: String?)
        case folder(color: BookmarkColor?, children: [BookmarkNode])
    }

    let id: UUID
    let name: String?
    let dateAdded: Date?
    let dateLastAccessed: Date?
    let kind: Kind
}

final class BookmarkStore {
    private let rootProvider: () -> PSBookmarkFolder

    init(rootProvider: @escaping () -> PSBookmarkFolder = {
        PSBookmarks.default()
    }) {
        self.rootProvider = rootProvider
    }

    func snapshot() -> [BookmarkNode] {
        (rootProvider().children ?? []).compactMap { child in
            guard let child = child as? PSBookmarkObject else {
                return nil
            }
            return node(from: child)
        }
    }

    private func node(from object: PSBookmarkObject) -> BookmarkNode {
        let kind: BookmarkNode.Kind
        if let folder = object as? PSBookmarkFolder {
            let children = (folder.children ?? []).compactMap { child -> BookmarkNode? in
                guard let child = child as? PSBookmarkObject else {
                    return nil
                }
                return node(from: child)
            }
            kind = .folder(
                color: BookmarkColor(hexString: folder.rgbHexString),
                children: children
            )
        } else {
            kind = .bookmark(reference: (object as? PSBookmark)?.ref)
        }
        return BookmarkNode(
            id: object.id,
            name: object.name,
            dateAdded: object.dateAdded,
            dateLastAccessed: object.dateLastAccessed,
            kind: kind
        )
    }
}

struct HistoryEntry: Identifiable, Equatable {
    struct ID: Hashable {
        let reference: String?
        let moduleName: String?
        let dateAdded: Date?
    }

    let id: ID
    let reference: String?
    let scrollAmount: String?
    let moduleName: String?
    let dateAdded: Date?

    init(item: PSHistoryItem) {
        reference = item.bibleReference
        scrollAmount = item.scrollAmount
        moduleName = item.moduleName
        dateAdded = item.dateAdded
        id = ID(
            reference: item.bibleReference,
            moduleName: item.moduleName,
            dateAdded: item.dateAdded
        )
    }
}

protocol HistoryCloudStoring: AnyObject {
    func array(forKey defaultName: String) -> [Any]?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension NSUbiquitousKeyValueStore: HistoryCloudStoring {}

final class HistoryStore {
    private let defaults: UserDefaults
    private let cloudStore: HistoryCloudStoring
    private let notificationCenter: NotificationCenter
    private var cloudObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        cloudStore: HistoryCloudStoring = NSUbiquitousKeyValueStore.default,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.cloudStore = cloudStore
        self.notificationCenter = notificationCenter
    }

    deinit {
        stopCloudSync()
    }

    func snapshot() -> [HistoryEntry] {
        (defaults.array(forKey: AppConstants.historyName) ?? []).compactMap {
            guard let array = $0 as? [Any],
                  let item = PSHistoryItem(array: array) else {
                return nil
            }
            return HistoryEntry(item: item)
        }
    }

    @discardableResult
    func remove(at index: Int, notify: Bool = true) -> Bool {
        var history = defaults.array(forKey: AppConstants.historyName) ?? []
        guard history.indices.contains(index) else {
            return false
        }
        history.remove(at: index)
        persist(history, notify: notify)
        return true
    }

    func clear() {
        defaults.removeObject(forKey: AppConstants.historyName)
        defaults.synchronize()
        cloudStore.removeObject(forKey: AppConstants.historyName)
        cloudStore.set([], forKey: AppConstants.historyName)
        notificationCenter.post(name: .historyChanged, object: nil)
    }

    func startCloudSync() {
        guard cloudObserver == nil else {
            return
        }
        cloudObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            self?.handleExternalCloudChange(notification)
        }
    }

    func stopCloudSync() {
        guard let cloudObserver else {
            return
        }
        notificationCenter.removeObserver(cloudObserver)
        self.cloudObserver = nil
    }

    func handleExternalCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonNumber = userInfo[
                NSUbiquitousKeyValueStoreChangeReasonKey
              ] as? NSNumber else {
            return
        }

        let reason = reasonNumber.intValue
        guard reason == NSUbiquitousKeyValueStoreServerChange
                || reason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }

        let changedKeys = userInfo[
            NSUbiquitousKeyValueStoreChangedKeysKey
        ] as? [String] ?? []
        guard changedKeys.contains(AppConstants.historyName) else {
            return
        }

        synchronizeFromCloud(
            initialSync: reason == NSUbiquitousKeyValueStoreInitialSyncChange
        )
    }

    func synchronizeFromCloud(initialSync: Bool) {
        let cloudHistory = PSHistoryItem.parseHistoryArrayArray(
            cloudStore.array(forKey: AppConstants.historyName)
        )
        let localHistory = NSMutableArray(
            array: PSHistoryItem.parseHistoryArrayArray(
                defaults.array(forKey: AppConstants.historyName)
            ) ?? []
        )
        let cloudHistoryCopy = NSMutableArray(array: cloudHistory ?? [])

        if PSHistoryItem.arraysAreEqual(
            cloudHistory,
            secondArray: localHistory as? [Any]
        ) {
            dlog("\ninitial arrays are equal, don't need to do anything! :)")
            return
        }

        let history: NSMutableArray
        if initialSync {
            initialSynchronize(
                withCloud: cloudHistoryCopy as? [Any],
                withLocalHistory: localHistory as? [Any]
            )
            return
        } else if cloudHistory == nil || cloudHistory?.isEmpty == true {
            dlog("\ndeleting local history due to iCloud deletion")
            defaults.removeObject(forKey: AppConstants.historyName)
            defaults.synchronize()
            notificationCenter.post(name: .historyChanged, object: nil)
            return
        } else if localHistory.count == 0 {
            dlog(
                "\nlocal history was blank, but we now need to update it "
                    + "from the changed iCloud version."
            )
            history = cloudHistoryCopy
        } else {
            history = NSMutableArray(
                array: Self.synchronizeHistoryArray(
                    cloudHistoryCopy,
                    with: localHistory
                ) ?? []
            )
        }

        sortDeduplicateAndCap(history)
        let combinedHistory = PSHistoryItem.arrayArray(
            fromHistoryItems: history as? [Any]
        )
        persistLocal(combinedHistory)

        if PSHistoryItem.arraysAreEqual(
            cloudHistory,
            secondArray: history as? [Any]
        ) {
            dlog(
                "\nOur new local history now equals the iCloud version, "
                    + "so don't re-update the cloud copy :P"
            )
            return
        }

        dlog(
            "\nAfter our sync, we have a new history item & so we need "
                + "to update the iCloud version as well..."
        )
        cloudStore.set(
            combinedHistory ?? [],
            forKey: AppConstants.historyName
        )
    }

    func initialSynchronize(
        withCloud cloudHistory: [Any]?,
        withLocalHistory localHistory: [Any]?
    ) {
        let history = NSMutableArray(array: localHistory ?? [])
        history.addObjects(from: cloudHistory ?? [])
        sortDeduplicateAndCap(history)

        let combinedHistory = PSHistoryItem.arrayArray(
            fromHistoryItems: history as? [Any]
        )
        persistLocal(combinedHistory)

        if PSHistoryItem.arraysAreEqual(
            cloudHistory,
            secondArray: history as? [Any]
        ) {
            return
        }
        cloudStore.set(
            combinedHistory ?? [],
            forKey: AppConstants.historyName
        )
    }

    static func synchronizeHistoryArray(
        _ firstArray: NSMutableArray?,
        with secondArray: NSMutableArray?
    ) -> [Any]? {
        guard let firstArray,
              let secondArray,
              firstArray.count != 0,
              secondArray.count != 0 else {
            return nil
        }

        let capacity = firstArray.count > secondArray.count
            ? secondArray.count
            : firstArray.count
        let returnArray = NSMutableArray(capacity: capacity)
        let firstNewest = firstArray[0] as? PSHistoryItem
        let secondNewest = secondArray[0] as? PSHistoryItem

        if firstNewest?.isEqual(to: secondNewest) ?? false {
            dlog("\nhistoryArrays are now (?) equal")
            return (firstArray.count > secondArray.count
                ? secondArray
                : firstArray) as? [Any]
        }

        switch firstNewest?.ageComparison(to: secondNewest) ?? .invalidAge {
        case .older:
            if let secondNewest {
                returnArray.add(secondNewest)
            }
            secondArray.removeObject(at: 0)
            if let rest = synchronizeHistoryArray(
                firstArray,
                with: secondArray
            ) {
                returnArray.addObjects(from: rest)
            }
        case .newer:
            if let firstNewest {
                returnArray.add(firstNewest)
            }
            firstArray.removeObject(at: 0)
            if let rest = synchronizeHistoryArray(
                firstArray,
                with: secondArray
            ) {
                returnArray.addObjects(from: rest)
            }
        default:
            dlog("tie-breaker!")
            if let firstNewest {
                returnArray.add(firstNewest)
            }
            if let secondNewest {
                returnArray.add(secondNewest)
            }
            firstArray.removeObject(at: 0)
            secondArray.removeObject(at: 0)
            if let rest = synchronizeHistoryArray(
                firstArray,
                with: secondArray
            ) {
                returnArray.addObjects(from: rest)
            }
        }

        return returnArray as? [Any]
    }

    private func persist(_ history: [Any], notify: Bool) {
        defaults.set(history, forKey: AppConstants.historyName)
        defaults.synchronize()
        cloudStore.set(history, forKey: AppConstants.historyName)
        if notify {
            notificationCenter.post(name: .historyChanged, object: nil)
        }
    }

    private func persistLocal(_ history: [Any]?) {
        defaults.set(history, forKey: AppConstants.historyName)
        defaults.synchronize()
        notificationCenter.post(name: .historyChanged, object: nil)
    }

    private func sortDeduplicateAndCap(_ history: NSMutableArray) {
        let sortDescriptor = NSSortDescriptor(
            key: "dateAdded",
            ascending: false
        )
        history.sort(using: [sortDescriptor])
        Self.deduplicate(history)
        while history.count >= AppConstants.historyMaxEntries {
            history.removeLastObject()
        }
    }

    private static func deduplicate(_ history: NSMutableArray) {
        var firstIndex = 0
        while firstIndex < history.count {
            let newItem = history[firstIndex] as? PSHistoryItem
            let reference = newItem?.bibleReference
            let module = newItem?.moduleName

            var secondIndex = firstIndex + 1
            while secondIndex < history.count {
                let existingItem = history[secondIndex] as? PSHistoryItem
                if reference == existingItem?.bibleReference,
                   module == existingItem?.moduleName {
                    history.removeObject(at: secondIndex)
                    secondIndex -= 1
                }
                secondIndex += 1
            }
            firstIndex += 1
        }
    }
}

struct SearchOptionsSnapshot: Equatable {
    let fuzzy: Bool
    let matchType: PSSearchType
    let range: PSSearchRange
}

final class SearchOptionsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func snapshot() -> SearchOptionsSnapshot {
        SearchOptionsSnapshot(
            fuzzy: defaults.bool(forKey: Defaults.lastSearchFuzzy),
            matchType: PSSearchType(
                rawValue: defaults.integer(forKey: Defaults.lastSearchType)
            ) ?? .AndSearch,
            range: PSSearchRange(
                rawValue: defaults.integer(forKey: Defaults.lastSearchRange)
            ) ?? .AllRange
        )
    }

    func save(_ snapshot: SearchOptionsSnapshot) {
        defaults.set(snapshot.fuzzy, forKey: Defaults.lastSearchFuzzy)
        defaults.set(snapshot.matchType.rawValue, forKey: Defaults.lastSearchType)
        defaults.set(snapshot.range.rawValue, forKey: Defaults.lastSearchRange)
    }
}
