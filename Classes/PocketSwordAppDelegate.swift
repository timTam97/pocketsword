//
//  PocketSwordAppDelegate.swift
//  PocketSword
//
//  Swift port (Wave 4, hub — FINAL entry point) of the former
//  PocketSwordAppDelegate.{h,mm} AND main.m. This is the UIApplicationDelegate.
//
//  @main: this class is now the application entry point. main.m (which called
//  UIApplicationMain(argc, argv, nil, @"PocketSwordAppDelegate")) has been
//  DELETED — the @main attribute synthesises the UIApplicationMain bootstrap on
//  this class, so there must be NO other UIApplicationMain call anywhere
//  (verified: main.m removed, no Info.plist principal class).
//
//  The @objc(PocketSwordAppDelegate) runtime name is REQUIRED for parity: the old
//  main.m named "PocketSwordAppDelegate" as the principal class, and the Obj-C++
//  coordinator (PSTabBarControllerDelegate.mm) still resolves the singleton via
//  [PocketSwordAppDelegate sharedAppDelegate]. The Swift class method is named
//  shared() for Swift call sites (the Foundation +shared* auto-rename, used by the
//  Swift PocketSwordSceneDelegate) but pins the Obj-C selector to sharedAppDelegate
//  via @objc(sharedAppDelegate) so the Obj-C++ caller binds unchanged.
//
//  Responsibilities preserved EXACTLY from the .mm:
//   - starts HistoryStore's iCloud history synchronization.
//   - hands scene configuration to PocketSwordSceneDelegate (Swift, same module).
//   - routes sword:// URLs via application(_:handleOpen:options:) — pinned to the
//     Obj-C selector application:handleOpenURL:options: so the Swift scene delegate
//     (which already calls application(_:handleOpen:options:)) binds unchanged.
//
//  ZERO sword:: — the one SWORD touch (resolving a requested module to decide
//  bible-vs-commentary) goes through the Swift PSModuleController facade exactly as
//  the original .mm reached it through Foundation-typed accessors.
//
//  The two UIKit category overrides from the old .mm (UITabBarController /
//  UINavigationController forcing PSResizing.supportedInterfaceOrientations) are
//  preserved as Swift extensions below.
//
//  Copyright (C) 2008-2010 CrossWire Bible Society
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software
//  Foundation; either version 2 of the License, or (at your option) any later
//  version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
//  PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//

import UIKit

@main
@MainActor
@objc(PocketSwordAppDelegate)
final class PocketSwordAppDelegate: NSObject, UIApplicationDelegate {

    @objc var urlToOpen: URL?
    @objc var tabBarControllerDelegate: PSTabBarControllerDelegate?
    let session: AppSession
    private let historyStore: HistoryStore
    private let searchIndexBackgroundManager: SearchIndexBackgroundManager
    private let readingStateStore = ReadingStateStore()
    private lazy var legacyStateBridge = LegacyStateBridge(
        session: session,
        readingStore: readingStateStore
    )

    override init() {
        let historyStore = HistoryStore()
        let searchIndexBackgroundManager = SearchIndexBackgroundManager()
        self.historyStore = historyStore
        self.searchIndexBackgroundManager = searchIndexBackgroundManager
        self.session = AppSession(
            library: LibraryModel(historyStore: historyStore),
            search: SearchModel(
                indexBuildStarted: {
                    searchIndexBackgroundManager.beginForegroundBuild(
                        module: $0
                    )
                },
                indexBuildFinished: {
                    searchIndexBackgroundManager.finishForegroundBuild(
                        module: $0
                    )
                }
            )
        )
        super.init()
    }

    /// + (PocketSwordAppDelegate *)sharedAppDelegate — Obj-C selector pinned so the
    /// Obj-C++ coordinator's [PocketSwordAppDelegate sharedAppDelegate] binds
    /// unchanged; Swift callers (the scene delegate) use the auto-renamed shared().
    @objc(sharedAppDelegate)
    class func shared() -> PocketSwordAppDelegate? {
        return UIApplication.shared.delegate as? PocketSwordAppDelegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = searchIndexBackgroundManager.register()
        searchIndexBackgroundManager.resumePendingBuildIfNeeded()
        legacyStateBridge.start()
        historyStore.startCloudSync()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration",
                                                 sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PocketSwordSceneDelegate.self
        return configuration
    }

    /*
     * The URL format is as follows:
     *
     * scheme (required): "sword://"
     *
     * host (optional): an installed module
     *
     * path (required): a bible reference, for example: "John+3:16" or "John 3"
     *
     * query (optional): for example:
     *   "?type=bible"
     *   - type is either "bible" or "commentary".  bible is the default if not present.
     *
     * Some complete example URLs are:
     * sword:///John+3:16                                (verse with no module specified)
     * sword://KJV/John+3:16                             (verse with module)
     * sword://ESV/John+3:16?type=bible                  (verse with a foreign module; the
     *                                                    module is ignored and the reference
     *                                                    is shown in the bundled module)
     *
     * The old "module=list" query component is gone along with the module selector;
     * a URL naming a module that is not installed still navigates to the reference.
     *
     * SWORD_REMOVAL_PLAN.md Phase 4: this is the ONLY place the app accepts a
     * reference it did not itself generate, and it used to do no validation at all
     * — it percent-decoded, stripped "/", turned "+" into space, split on ":",
     * kept the leading digits of the verse, and wrote the result straight to
     * Defaults.lastRef. So `sword://KJV/Nonsense+9:9` persisted "Nonsense 9" as
     * lastRef, which neither the reader nor the ref selector can resolve, and
     * `sword:///John` persisted the chapter-less "John". Both now go through
     * PSRefParser and are rejected outright rather than poisoning lastRef.
     */
    @objc(application:handleOpenURL:options:)
    @discardableResult
    func application(_ application: UIApplication,
                     handleOpen url: URL?,
                     // `options` is vestigial: unused here and always passed nil by the
                     // scene delegate. Typed as a neutral dictionary rather than the
                     // iOS-26-deprecated UIApplication.OpenURLOptionsKey. The @objc
                     // selector (application:handleOpenURL:options:) is unaffected.
                     options: [AnyHashable: Any]?) -> Bool {
        guard let route = URLRouter()?.route(for: url) else {
            return false
        }

        self.urlToOpen = route.sourceURL
        session.apply(route)

        switch route.destination {
        case .bible(let module):
            if let mod = module {
                // they requested a specific module and it is available
                PSModuleController.default()?.loadPrimaryBible(mod)
                //defaults.set(mod, forKey: Defaults.lastBible)
            }

            tabBarControllerDelegate?.setShownTabTo(.BibleTab)

            readingStateStore.persist(route)

            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
            PSHistoryController.addHistoryItem(.BibleTab)
        case .commentary(let module):
            if let mod = module {
                // they requested a specific module and it is available
                PSModuleController.default()?.loadPrimaryCommentary(mod)
            }

            tabBarControllerDelegate?.setShownTabTo(.CommentaryTab)

            readingStateStore.persist(route)

            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
            //NotificationCenter.default.post(name: NotificationAddCommentaryHistoryItem, object: nil)
            PSHistoryController.addHistoryItem(.CommentaryTab)
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaults.standard.synchronize()
        PSModuleController.releaseDefaultModuleController()
        // `SwordManager.releaseDefaultManager()` is GONE (Phase 5 step 7): there is no
        // manager. The content store closes its handle in `deinit`, and the process is
        // terminating anyway.
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        PSModuleController.default()?.didReceiveMemoryWarning()
    }
}

// MARK: - Forced-orientation UIKit category overrides
//
// The old .mm carried UITabBarController(PocketSword) / UINavigationController
// (PocketSword) categories overriding -supportedInterfaceOrientations to defer to
// PSResizing. Preserved as Swift extension overrides.

extension UITabBarController {
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }
}

extension UINavigationController {
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }
}
