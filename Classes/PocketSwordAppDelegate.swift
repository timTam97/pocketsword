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
//   - registers for NSUbiquitousKeyValueStore change notifications (iCloud history
//     sync) in didFinishLaunchingWithOptions and routes the server/initial-sync
//     change for PSHistoryName through
//     +[PSHistoryController synchronizeHistoryItemsFromCloud:].
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
@objc(PocketSwordAppDelegate)
final class PocketSwordAppDelegate: NSObject, UIApplicationDelegate {

    @objc var urlToOpen: URL?
    @objc var tabBarControllerDelegate: PSTabBarControllerDelegate?

    /// + (PocketSwordAppDelegate *)sharedAppDelegate — Obj-C selector pinned so the
    /// Obj-C++ coordinator's [PocketSwordAppDelegate sharedAppDelegate] binds
    /// unchanged; Swift callers (the scene delegate) use the auto-renamed shared().
    @objc(sharedAppDelegate)
    class func shared() -> PocketSwordAppDelegate? {
        return UIApplication.shared.delegate as? PocketSwordAppDelegate
    }

    @objc func storeDidChange(_ notification: Notification) {
        // We get more information from the notification, by using:
        //  NSUbiquitousKeyValueStoreChangeReasonKey or NSUbiquitousKeyValueStoreChangedKeysKey constants
        // against the notification's userInfo.
        guard let userInfo = notification.userInfo else { return }

        // get the reason (initial download, external change or quota violation change)
        guard let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber else {
            return
        }

        // reason was deduced, go ahead and check for the change
        let reason = reasonForChange.intValue
        if reason == NSUbiquitousKeyValueStoreServerChange ||
            // the value changed from the remote server
            reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            // initial syncs happen the first time the device is synced

            let initialSync = (reason == NSUbiquitousKeyValueStoreInitialSyncChange)

            let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

            // in case you have more than one key,
            // loop through and check for the one we want (PSHistoryName)
            for changedKey in changedKeys {
                if changedKey == AppConstants.historyName {
                    PSHistoryController.synchronizeHistoryItemsFromCloud(initialSync)
                }
            }
        }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if NSClassFromString("NSUbiquitousKeyValueStore") != nil {
            // register to observe notifications from the store
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(storeDidChange(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default)
        }

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

    /// Parse url's query portion (like key=value&name=something) into a dictionary.
    private func parseQueryDictionary(from url: URL) -> [String: String] {
        var result: [String: String] = [:]
        guard let query = url.query, !query.isEmpty else {
            return result
        }

        let pairs = query.components(separatedBy: "&")
        for keyValueStr in pairs {
            let keyValueArray = keyValueStr.components(separatedBy: "=")
            if keyValueArray.count > 1 {
                result[keyValueArray[0]] = keyValueArray[1]
            }
        }

        return result
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
        guard let url = url, url.scheme == "sword" else {
            return false
        }

        self.urlToOpen = url

        var module: String? = url.host
        var reference = url.path
        reference = (reference.removingPercentEncoding ?? reference)
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "+", with: " ")

        let chapter: String
        let verseRaw: String
        if reference.range(of: ":") == nil {
            chapter = reference
            verseRaw = "1"
        } else {
            let parts = reference.components(separatedBy: ":")
            chapter = parts[0]
            verseRaw = parts[1]
        }

        // preserve only the first number in verse, i.e. change 28-30 into 28, or change 26,28;30 into 26
        let digits = CharacterSet.decimalDigits
        let verseChars = Array(verseRaw.unicodeScalars)
        var i = 1
        while i < verseChars.count {
            if !digits.contains(verseChars[i]) {
                break
            }
            i += 1
        }
        let verse = String(String.UnicodeScalarView(verseChars[0..<min(i, verseChars.count)]))

        let params = parseQueryDictionary(from: url)
        let type = params["type"]

        let isBible: Bool // determined first by "module" if present, then fall back to "type", then default to "bible"
        if let mod = module, !mod.isEmpty {
            // they requested a specific module
            let requestedModule = PSModuleController.default()?.swordManager?.module(withName: mod)
            if let requestedModule = requestedModule {
                isBible = (requestedModule.type == bible)
            } else {
                // The requested module is not installed. With a fixed bundled module
                // set that is the common case for a foreign sword:// link, so ignore
                // the module component and still navigate to the reference.
                module = nil
                isBible = (type == nil || type == "bible")
            }
        } else {
            // no module requested
            isBible = (type == nil || type == "bible")
        }

        let defaults = UserDefaults.standard
        if isBible {
            if let mod = module {
                // they requested a specific module and it is available
                PSModuleController.default()?.loadPrimaryBible(mod)
                //defaults.set(mod, forKey: Defaults.lastBible)
            }

            tabBarControllerDelegate?.setShownTabTo(.BibleTab)

            defaults.set(PSModuleController.createRefString(chapter), forKey: Defaults.lastRef)
            defaults.set(verse, forKey: Defaults.bibleVersePosition)
            defaults.synchronize()

            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
            PSHistoryController.addHistoryItem(.BibleTab)
        } else {
            if let mod = module {
                // they requested a specific module and it is available
                PSModuleController.default()?.loadPrimaryCommentary(mod)
            }

            tabBarControllerDelegate?.setShownTabTo(.CommentaryTab)

            defaults.set(PSModuleController.createRefString(chapter), forKey: Defaults.lastRef)
            defaults.set(verse, forKey: Defaults.bibleVersePosition)
            defaults.set(verse, forKey: Defaults.commentaryVersePosition)
            defaults.synchronize()

            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
            //NotificationCenter.default.post(name: NotificationAddCommentaryHistoryItem, object: nil)
            PSHistoryController.addHistoryItem(.CommentaryTab)
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaults.standard.synchronize()
        PSModuleController.releaseDefaultModuleController()
        SwordManager.releaseDefaultManager()
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
