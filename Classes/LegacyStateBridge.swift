import Foundation
import UIKit

@MainActor
final class LegacyStateBridge: NSObject {
    private let session: AppSession
    private let readingStore: ReadingStateStore
    private let notificationCenter: NotificationCenter
    private let idleTimerHandler: @MainActor (Bool) -> Void
    private var started = false
    private var observers: [NSObjectProtocol] = []

    init(
        session: AppSession,
        readingStore: ReadingStateStore = ReadingStateStore(),
        notificationCenter: NotificationCenter = .default,
        idleTimerHandler: @escaping @MainActor (Bool) -> Void = {
            UIApplication.shared.isIdleTimerDisabled = $0
        }
    ) {
        self.session = session
        self.readingStore = readingStore
        self.notificationCenter = notificationCenter
        self.idleTimerHandler = idleTimerHandler
        super.init()
    }

    func start() {
        guard !started else {
            return
        }
        started = true

        for name in observedNotifications {
            let observer = notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.legacyStateDidChange(notification.name)
                }
            }
            observers.append(observer)
        }

        session.settings.onReadingAppearanceChanged = { [weak self] in
            self?.notificationCenter.post(
                name: .resetBibleAndCommentaryView,
                object: nil
            )
        }
        session.settings.onKeepScreenAwakeChanged = { [weak self] value in
            self?.idleTimerHandler(value)
        }
        refreshReading()
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        session.settings.onReadingAppearanceChanged = nil
        session.settings.onKeepScreenAwakeChanged = nil
    }

    private func legacyStateDidChange(_ name: Notification.Name) {
        switch name {
        case .appStateDidReset:
            session.settings.reload()
            session.library.reloadBookmarks()
            session.library.reloadHistory()
        case .bookmarksChanged:
            session.library.reloadBookmarks()
        case .historyChanged:
            session.library.reloadHistory()
        case .showBibleTab:
            session.selectedWorkspace = .read
            session.reading.mode = .bible
        case .showCommentaryTab:
            session.selectedWorkspace = .read
            session.reading.mode = .commentary
        default:
            break
        }
        refreshReading()
    }

    private func refreshReading() {
        session.reading.apply(readingStore.snapshot())
    }

    private var observedNotifications: [Notification.Name] {
        [
            .newPrimaryBible,
            .newPrimaryCommentary,
            .appStateDidReset,
            .bookmarksChanged,
            .historyChanged,
            .redisplayPrimaryBible,
            .redisplayPrimaryCommentary,
            .resetBibleAndCommentaryView,
            .showBibleTab,
            .showCommentaryTab,
            .updateSelectedReference,
        ]
    }
}
