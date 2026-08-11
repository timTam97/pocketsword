import BackgroundTasks
import Foundation

final class SearchIndexBackgroundManager {
    struct Scheduler {
        let register: (
            _ identifier: String,
            _ handler: @escaping (BGProcessingTask) -> Void
        ) -> Bool
        let submit: (
            _ request: BGProcessingTaskRequest,
            _ completion: @escaping (Error?) -> Void
        ) -> Void
        let cancel: (_ identifier: String) -> Void

        static let live = Scheduler(
            register: { identifier, handler in
                BGTaskScheduler.shared.register(
                    forTaskWithIdentifier: identifier,
                    using: nil
                ) { task in
                    guard let processingTask = task as? BGProcessingTask else {
                        task.setTaskCompleted(success: false)
                        return
                    }
                    handler(processingTask)
                }
            },
            submit: { request, completion in
                DispatchQueue.global(qos: .utility).async {
                    BGTaskScheduler.shared.submitTaskRequest(
                        request,
                        completionHandler: completion
                    )
                }
            },
            cancel: { identifier in
                BGTaskScheduler.shared.cancel(
                    taskRequestWithIdentifier: identifier
                )
            }
        )
    }

    typealias BuildOperation = (
        _ module: String,
        _ progress: PSSearchProgressBlock?
    ) throws -> Void

    private final class Cancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }

    private let defaults: UserDefaults
    private let scheduler: Scheduler
    private let buildOperation: BuildOperation
    private let lock = NSLock()
    private var didRegister = false
    private var foregroundModule: String?
    private var backgroundCancellation: Cancellation?

    let taskIdentifier: String

    /// How many times a *background* build may fail before the recovery record is
    /// dropped. Internal rather than private so the test drives the real budget
    /// instead of hardcoding it.
    static let maxBuildAttempts = 3

    init(
        defaults: UserDefaults = .standard,
        taskIdentifier: String? = nil,
        scheduler: Scheduler = .live,
        buildOperation: @escaping BuildOperation = { module, progress in
            try PSSearchEngine.engine(forModuleName: module)
                .build(progress: progress)
        }
    ) {
        self.defaults = defaults
        self.scheduler = scheduler
        self.buildOperation = buildOperation
        let bundleIdentifier = Bundle.main.bundleIdentifier
            ?? "org.crosswire.PocketSword"
        self.taskIdentifier = taskIdentifier
            ?? "\(bundleIdentifier).search-index"
    }

    @discardableResult
    func register() -> Bool {
        lock.lock()
        guard !didRegister else {
            lock.unlock()
            return true
        }
        didRegister = true
        lock.unlock()

        let registered = scheduler.register(taskIdentifier) { [weak self] task in
            self?.handle(task)
        }
        if !registered {
            lock.lock()
            didRegister = false
            lock.unlock()
        }
        return registered
    }

    func resumePendingBuildIfNeeded() {
        guard let module = pendingModule else { return }
        scheduleRecovery(for: module)
    }

    func beginForegroundBuild(module: String) {
        lock.lock()
        foregroundModule = module
        // A fresh user-initiated build resets the background retry budget: the last
        // module's exhausted attempts must not deny this one its retries. Written under
        // the lock, with the record, because `registerFailedAttempt` reads both together
        // off a background queue.
        defaults.removeObject(forKey: Defaults.pendingSearchIndexAttempts)
        defaults.set(module, forKey: Defaults.pendingSearchIndexModule)
        lock.unlock()
        scheduleRecovery(for: module)
    }

    func finishForegroundBuild(module: String) {
        lock.lock()
        if foregroundModule == module {
            foregroundModule = nil
        }
        lock.unlock()
        clearPendingModule(ifMatching: module)
        scheduler.cancel(taskIdentifier)
    }

    var pendingModule: String? {
        defaults.string(forKey: Defaults.pendingSearchIndexModule)
    }

    private func scheduleRecovery(for module: String) {
        defaults.set(module, forKey: Defaults.pendingSearchIndexModule)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        scheduler.submit(request) { error in
            if let error {
                alog(
                    "Unable to schedule search index recovery for "
                        + "\(module): \(error.localizedDescription)"
                )
            }
        }
    }

    private func handle(_ task: BGProcessingTask) {
        guard let module = pendingModule else {
            task.setTaskCompleted(success: true)
            return
        }

        lock.lock()
        let isForegroundBuildActive = foregroundModule == module
        lock.unlock()
        if isForegroundBuildActive {
            scheduleRecovery(for: module)
            task.setTaskCompleted(success: false)
            return
        }

        let cancellation = Cancellation()
        lock.lock()
        backgroundCancellation = cancellation
        lock.unlock()
        task.expirationHandler = {
            cancellation.cancel()
        }

        performPendingBuild(
            cancellationRequested: { cancellation.isCancelled }
        ) { [weak self] success, shouldRetry in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }
            self.lock.lock()
            self.backgroundCancellation = nil
            self.lock.unlock()

            if shouldRetry {
                self.scheduleRecovery(for: module)
            }
            task.setTaskCompleted(success: success)
        }
    }

    func performPendingBuild(
        cancellationRequested: @escaping () -> Bool,
        completion: @escaping (
            _ success: Bool,
            _ shouldRetry: Bool
        ) -> Void
    ) {
        guard let module = pendingModule else {
            completion(true, false)
            return
        }

        let operation = buildOperation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                completion(false, false)
                return
            }

            var buildError: Error?
            do {
                try operation(module) { _, cancel in
                    cancel = cancellationRequested()
                }
            } catch {
                buildError = error
            }

            let expired = cancellationRequested()

            // Expiration is not a failure: the recovery record stays put and
            // `handle` resubmits the request, which is the entire point of it. It
            // must also come FIRST, because `PSSearchEngine.build` throws
            // `.cancelled` on expiry — so an expired run arrives with both
            // `buildError != nil` and `expired == true`, and testing the error first
            // would bill an interruption as a failure and spend retry budget on it.
            if expired {
                completion(false, true)
                return
            }

            guard let buildError else {
                self.clearPendingModule(ifMatching: module)
                completion(true, false)
                return
            }

            // A build error is NOT automatically terminal, and treating it as one is
            // what made this whole class inert on the path it exists for: clearing
            // the record meant `resumePendingBuildIfNeeded()` found nothing on the
            // next launch, and reporting `shouldRetry: false` meant `handle` did not
            // reschedule either — so one transient failure left the user with no
            // index, no retry, and one log line.
            //
            // A full disk, an sqlite busy timeout, or a process killed mid-write all
            // throw and all succeed on a later attempt, and `build` drops any partial
            // index at entry and again in its catch, so a retry can never compound.
            // But it has to be BOUNDED: `resumePendingBuildIfNeeded()` runs from
            // `didFinishLaunching`, so a deterministic failure (an unreadable content
            // store) would otherwise re-run a ~30 s background build on every cold
            // launch, forever, invisibly. Exhausting the budget clears the record and
            // nothing user-visible is lost — the Search tab's own build button is
            // driven by `indexIsFresh()` and has never consulted this record.
            let willRetry = self.registerFailedAttempt(for: module)
            alog(
                "Background search index build failed for "
                + "\(module): \(buildError.localizedDescription)"
                + (willRetry
                   ? " — will retry"
                   : " — retry budget exhausted, leaving it to the Search tab")
            )
            completion(false, willRetry)
        }
    }

    /// Records one failed background attempt; returns whether a retry is left.
    ///
    /// Only a *build error* spends budget. An expiration is work interrupted rather
    /// than work that failed, and is handled before this is reached.
    ///
    /// **It must NOT resurrect a record that is no longer there, and that check is the
    /// dangerous half.** A background build can fail *after* the user's own foreground
    /// build of the same module has finished and called `finishForegroundBuild` →
    /// `clearPendingModule`. Re-persisting a retry then schedules a recovery build for
    /// a module whose index is already complete and fresh — and because
    /// `PSSearchEngine.build` opens with `dropIndex()`, that recovery would DESTROY the
    /// index the user just waited for and rebuild it from scratch in the background.
    /// So a missing (or reassigned) record means "someone else has taken this over":
    /// spend nothing, ask for nothing.
    ///
    /// The read-modify-write runs under `lock` because it is not atomic —
    /// `UserDefaults` is safe per access, not across a read and a write — and this runs
    /// on a global utility queue while `beginForegroundBuild` clears the same counter
    /// from the main actor. `clearPendingModule` takes the same lock, so it is called
    /// only after this one is released — `NSLock` is not recursive.
    private func registerFailedAttempt(for module: String) -> Bool {
        lock.lock()
        let stillPending =
            defaults.string(forKey: Defaults.pendingSearchIndexModule) == module
        var attempts = 0
        if stillPending {
            attempts = defaults.integer(
                forKey: Defaults.pendingSearchIndexAttempts
            ) + 1
            if attempts < Self.maxBuildAttempts {
                defaults.set(attempts, forKey: Defaults.pendingSearchIndexAttempts)
            }
        }
        lock.unlock()

        guard stillPending else { return false }
        guard attempts < Self.maxBuildAttempts else {
            clearPendingModule(ifMatching: module)
            return false
        }
        return true
    }

    /// Drops the recovery record, and the counter with it.
    ///
    /// Under `lock` for the same reason `registerFailedAttempt` is: the compare and the
    /// two removes are one logical operation, and this is reached from a global utility
    /// queue as well as the main actor. No caller may hold the lock when it calls this
    /// (`NSLock` is not recursive) — `finishForegroundBuild` and `registerFailedAttempt`
    /// both release it first, deliberately.
    private func clearPendingModule(ifMatching module: String) {
        lock.lock()
        defer { lock.unlock() }
        guard defaults.string(forKey: Defaults.pendingSearchIndexModule) == module
        else { return }
        defaults.removeObject(forKey: Defaults.pendingSearchIndexModule)
        // The counter is meaningless without the module it counts for; leaving it
        // behind would poison the budget of the next module's recovery.
        defaults.removeObject(forKey: Defaults.pendingSearchIndexAttempts)
    }
}
