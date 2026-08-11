//
//  PocketSwordAppDelegate.swift
//  PocketSword
//
//  Wave 8: reduced to the two things UIKit still owns, plus ownership of the
//  long-lived models.
//
//  It is **no longer the entry point** — `@main` is on `PocketSwordApp`
//  (PocketSwordApp.swift), and this class is reached through
//  `@UIApplicationDelegateAdaptor`. What used to be here and is gone:
//
//  - `configurationForConnecting…` and `PocketSwordSceneDelegate` (deleted):
//    `WindowGroup` configures the scene. The `UISceneDelegateClassName` entry in
//    `misc/Info.plist` went with it — a stale entry there would name a class that
//    no longer exists.
//  - `application(_:handleOpen:options:)`: `onOpenURL` delivers URLs now. The
//    routing itself moved to `AppSession.open(_:)`, which is where it belonged —
//    it was never delegate work, only delivery was.
//  - The `UITabBarController` / `UINavigationController`
//    `supportedInterfaceOrientations` category overrides: replaced by
//    `supportedInterfaceOrientations(for:)` on the scene delegate below, which is
//    iOS 27's supported hook. Overriding a system class's property in an
//    extension worked, but it applied to every such controller in the process
//    including ones SwiftUI creates for its own use.
//  - `applicationWillTerminate` / `applicationDidReceiveMemoryWarning`: the
//    former synchronized defaults and released the module controller, both of
//    which the `scenePhase` handler and process teardown already cover; the
//    latter called a method that has been a documented no-op since
//    SWORD_REMOVAL_PLAN.md Phase 5 step 5.
//
//  What is left is genuinely delegate-shaped: `BGTaskScheduler.register` must be
//  called before `didFinishLaunching` returns, and iCloud history sync wants to
//  start once per process.
//
//  Copyright (C) 2008-2010 CrossWire Bible Society
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software
//  Foundation; either version 2 of the License, or (at your option) any later
//  version.
//

import UIKit

@MainActor
final class PocketSwordAppDelegate: NSObject, UIApplicationDelegate {

    let session: AppSession
    let launchCoordinator = LaunchCoordinator()
    private(set) lazy var readingWorkspace = ReadingWorkspaceModel(
        session: session
    )

    private let historyStore: HistoryStore
    private let searchIndexBackgroundManager: SearchIndexBackgroundManager

    override init() {
        let historyStore = HistoryStore()
        let searchIndexBackgroundManager = SearchIndexBackgroundManager()
        self.historyStore = historyStore
        self.searchIndexBackgroundManager = searchIndexBackgroundManager
        self.session = AppSession(
            library: LibraryModel(historyStore: historyStore),
            search: SearchModel(
                indexBuildStarted: {
                    searchIndexBackgroundManager.beginForegroundBuild(module: $0)
                },
                indexBuildFinished: {
                    searchIndexBackgroundManager.finishForegroundBuild(module: $0)
                }
            )
        )
        super.init()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Must happen before this method returns, which is the whole reason an
        // app delegate is still here.
        _ = searchIndexBackgroundManager.register()
        searchIndexBackgroundManager.resumePendingBuildIfNeeded()
        historyStore.startCloudSync()
        session.start()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        // The ONLY reason a scene delegate still exists: the rotation-lock
        // preference has to be reported through
        // `supportedInterfaceOrientations(for:)`, and SwiftUI has no equivalent
        // modifier on iOS.
        configuration.delegateClass = PocketSwordSceneOrientationDelegate.self
        return configuration
    }
}

/// Reports the rotation-lock preference to the window scene.
///
/// This replaces the pair of Obj-C category overrides on `UITabBarController` and
/// `UINavigationController` that the app carried since long before the SwiftUI
/// migration. `supportedInterfaceOrientations(for:)` is new in iOS 27 and is the
/// scene-scoped replacement for the deprecated
/// `application(_:supportedInterfaceOrientationsFor:)`; returning a mask here
/// overrides the `UISupportedInterfaceOrientations` Info.plist value for this
/// scene, which is exactly what the preference needs to do.
///
/// The mask itself comes from `RotationLock`, so the three states are unchanged:
/// unlocked allows all but upside-down on iPhone (all on iPad), and the two locked
/// states pin to their orientation.
final class PocketSwordSceneOrientationDelegate: UIResponder,
                                                 UIWindowSceneDelegate {
    func supportedInterfaceOrientations(
        for windowScene: UIWindowScene
    ) -> UIInterfaceOrientationMask {
        let isPad = UIDevice.current.userInterfaceIdiom != .phone
        let lock = RotationLock(
            rawValue: UserDefaults.standard.integer(
                forKey: Defaults.rotationLockPosition
            )
        ) ?? .unlocked

        switch lock {
        case .unlocked:
            return isPad ? .all : .allButUpsideDown
        case .landscape:
            return .landscape
        case .portrait:
            return isPad ? [.portrait, .portraitUpsideDown] : .portrait
        }
    }
}
