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
        lock.unlock()
        defaults.set(module, forKey: Defaults.pendingSearchIndexModule)
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

            if buildError == nil, !expired {
                self.clearPendingModule(ifMatching: module)
            } else if !expired {
                self.clearPendingModule(ifMatching: module)
                if let buildError {
                    alog(
                        "Background search index build failed for "
                        + "\(module): \(buildError.localizedDescription)"
                    )
                }
            }
            completion(buildError == nil && !expired, expired)
        }
    }

    private func clearPendingModule(ifMatching module: String) {
        guard pendingModule == module else { return }
        defaults.removeObject(forKey: Defaults.pendingSearchIndexModule)
    }
}
