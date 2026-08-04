//
//  PSTabBarControllerDelegate.swift
//  PocketSword
//
//  Swift port (Wave 4, FINAL — the central coordinator, last app-layer file
//  migrated) of the former PSTabBarControllerDelegate.{h,mm}. This is the running
//  app's hub: it owns the tab bar, the Bible/Commentary/Dictionary VCs, the
//  reference selector, the info popup (Strong's / morph / footnotes / xrefs / dict
//  entries), the module selector, and the search/history multi-list, and it routes
//  verse-tap / Strong's / footnote / xref / dict-entry callbacks via WKNavigation
//  policy + NSNotificationCenter.
//
//  The @objc(PSTabBarControllerDelegate) runtime name is REQUIRED: the Swift scene
//  delegate builds it (`PSTabBarControllerDelegate()`) and reads its tabBarController,
//  the Swift app delegate holds it (`tabBarControllerDelegate`) and drives
//  setShownTabTo: / toggleModulesList(animated:with:fromButton:), and the Swift
//  render-path VC base (PSModuleViewController) holds a back-reference and calls
//  -displayChapter:.../-toggleNavigation + the class method +displayTitle:. All
//  callers now live in the same Swift module, so they bind directly.
//
//  After this file there is NO app-layer Obj-C left — only the permanent Obj-C++
//  SWORD bridge (Sword*.mm + SwordModuleTextEntry.m) and PSSearchEngine.mm's
//  FTS5/sword index-build path remain (per the plan's "Never migrated" list).
//
//  ZERO sword:: — the one former C++ touch (sword::LocaleMgr in
//  updateViewWithSelectedBookName) already goes through the Foundation-only
//  +[SwordManager translateBookName:] helper; every other SWORD touch is funnelled
//  through the @objc facades on SwordManager / SwordModule / SwordDictionary /
//  PSModuleController exactly as the original .mm did.
//
//  The 13 NSNotificationCenter observers are registered with the Notification.Name
//  symbols in AppConstants.swift whose rawValues match the original @"..." strings
//  byte-for-byte, so any remaining Obj-C poster still reaches this observer.
//
//  Copyright (C) 2008-2010 CrossWire Bible Society
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software
//  Foundation; either version 2 of the License, or (at your option) any later
//  version.
//

import UIKit
import SwiftUI
import WebKit
import QuartzCore

// RestorePositionType / PollingType were plain C enums in the old
// PSTabBarControllerDelegate.h. The Swift render-path VC base
// (PSModuleViewController.swift) passes their cases verbatim
// (`BibleViewPoll`, `RestoreNoPosition`, ...) into -displayChapter:.../-redisplayChapter:
// so we keep the bare (non-NS_ENUM) case spelling by declaring them as @objc enums
// whose cases keep the original global identifiers via a typealias of bare globals.
// We mirror the original raw values (1/2/3) so any persisted/passed integer matches.
@objc enum RestorePositionType: Int {
    case scroll = 1   // RestoreScrollPosition
    case verse = 2    // RestoreVersePosition
    case none = 3     // RestoreNoPosition
}

@objc enum PollingType: Int {
    case bible = 1        // BibleViewPoll
    case commentary = 2   // CommentaryViewPoll
    case none = 3         // NoViewPoll
}

// The original C enums imported into Swift with the bare member names
// (RestoreScrollPosition / BibleViewPoll / ...). PSModuleViewController.swift was
// written against those bare names, so we re-export them as module-level
// constants to keep that call site binding unchanged.
let RestoreScrollPosition = RestorePositionType.scroll
let RestoreVersePosition = RestorePositionType.verse
let RestoreNoPosition = RestorePositionType.none
let BibleViewPoll = PollingType.bible
let CommentaryViewPoll = PollingType.commentary
let NoViewPoll = PollingType.none

@objc(PSTabBarControllerDelegate)
final class PSTabBarControllerDelegate: NSObject,
                                        UITabBarControllerDelegate,
                                        PSModuleSearchControllerDelegate,
                                        UIPopoverPresentationControllerDelegate,
                                        UIAdaptivePresentationControllerDelegate,
                                        WKNavigationDelegate {

    // Tab bar
    @objc var tabBarController: UITabBarController!

    // Bible tab
    @objc var bibleTabController: PSBibleViewController?

    // Commentary tab
    @objc var commentaryTabController: PSCommentaryViewController?

    // Bible & Commentary tab
    private var refSelectorController: PSRefSelectorController?
    private var refNavigationController: UINavigationController?
    // (refTitleSplashView / refTitleSplashTimer were dead ivars in the .mm — never
    // assigned or read — so they are dropped.)

    // Info popup (Strong's, morph, footnotes, xrefs, dict entries).
    private var infoPopupController: PSInfoPopupViewController?

    // MultiList (history + search)
    private var multiListController: UITabBarController?

    // Search tab
    @objc var savedSearchHistoryItem: PSSearchHistoryItem?
    @objc var savedSearchResultsTab: ShownTab = .BibleTab
    private var settingsTabController: UIViewController?

    @objc override init() {
        super.init()

        let tbc = UITabBarController()
        tbc.delegate = self
        self.tabBarController = tbc

        _ = PSModuleController.default() // init

        var tabs: [UIViewController] = []
        // Order of the tabs:
        // 00: Bible
        // 01: Commentary
        // 02: Dictionary
        // 03: Bookmarks
        // 04: Preferences
        // 05: About

        // add the Commentary Tab.
        let cvc = PSCommentaryViewController()
        cvc.title = CommentaryTabTitleString
        _ = cvc.view // load the view before we continue!
        cvc.setDelegate(self)
        let cTab = UINavigationController(rootViewController: cvc)
        tabs.insert(cTab, at: 0)
        self.commentaryTabController = cvc

        // add the Bible Tab.
        // Do this second because we need the commentary tab to initialise the Bible tab!
        let bvc = PSBibleViewController()
        bvc.title = BibleTabTitleString
        _ = bvc.view // load the view before we continue!
        bvc.setDelegate(self)
        bvc.commentaryView = commentaryTabController
        let bTab = UINavigationController(rootViewController: bvc)
        tabs.insert(bTab, at: 0)
        self.bibleTabController = bvc

        // add the Dictionary Tab.
        let dictionaryViewController = PSDictionaryViewController(style: .grouped)
        let dictionaryTab = UINavigationController(rootViewController: dictionaryViewController)
        let dTBI = UITabBarItem(title: NSLocalizedString("TabBarTitleDictionary", comment: "Dictionary"),
                                image: UIImage(named: "dictionary.png"), tag: 99)
        dTBI.accessibilityIdentifier = "workspace.library.dictionary"
        dictionaryTab.tabBarItem = dTBI
        tabs.insert(dictionaryTab, at: 2)

        // add the bookmarks tab.
        PSBookmarks.importBookmarksFromV2()
        let bookmarksViewController = PSBookmarksNavigatorController(style: .grouped)
        let bookmarksTab = UINavigationController(rootViewController: bookmarksViewController)
        let tbI = UITabBarItem(tabBarSystemItem: .bookmarks, tag: 0)
        tbI.accessibilityIdentifier = "workspace.library.bookmarks"
        bookmarksTab.tabBarItem = tbI
        tabs.insert(bookmarksTab, at: 3)

        // add the Preferences tab.
        let settings = PocketSwordAppDelegate.shared()?.session.settings
            ?? SettingsModel()
        let preferencesViewController = UIHostingController(
            rootView: SettingsView(
                settings: settings,
                maximumFontSize: PSResizing.iPad() ? 36 : 20
            )
        )
        preferencesViewController.title = NSLocalizedString(
            "PreferencesTitle",
            comment: "Preferences"
        )
        preferencesViewController.navigationItem.largeTitleDisplayMode = .never
        let preferencesTabBarItem = UITabBarItem(title: NSLocalizedString("TabBarTitlePreferences", comment: "Preferences"),
                                                 image: UIImage(named: "gear-24.png"), tag: 9)
        preferencesTabBarItem.accessibilityIdentifier = "workspace.settings.preferences"
        if PSResizing.iPad() {
            let preferencesIPadTab = UINavigationController(rootViewController: preferencesViewController)
            preferencesIPadTab.tabBarItem = preferencesTabBarItem
            tabs.insert(preferencesIPadTab, at: 4)
            settingsTabController = preferencesIPadTab
        } else {
            preferencesViewController.tabBarItem = preferencesTabBarItem
            tabs.insert(preferencesViewController, at: 4)
            settingsTabController = preferencesViewController
        }

        // add the About tab.
        let aboutViewController = UIHostingController(
            rootView: AboutView(information: .current())
        )
        aboutViewController.title = NSLocalizedString(
            "AboutTitle",
            comment: "About"
        )
        aboutViewController.navigationItem.largeTitleDisplayMode = .never
        let aboutTBI = UITabBarItem(title: NSLocalizedString("TabBarTitleAbout", comment: "About"),
                                    image: UIImage(named: "About.png"), tag: 0)
        aboutTBI.accessibilityIdentifier = "workspace.settings.about"
        if PSResizing.iPad() {
            let aboutIPadTab = UINavigationController(rootViewController: aboutViewController)
            aboutIPadTab.tabBarItem = aboutTBI
            tabs.insert(aboutIPadTab, at: 5)
        } else {
            aboutViewController.tabBarItem = aboutTBI
            tabs.insert(aboutViewController, at: 5)
        }

        tabBarController.setViewControllers(tabs, animated: false)

        tabBarController.customizableViewControllers = nil
        tabBarController.selectedIndex = 0
        tabBarController.moreNavigationController.topViewController?.navigationItem.rightBarButtonItem = nil
        tabBarController.delegate = self

        NotificationCenter.default.post(name: .newPrimaryBible, object: nil)
        let lastRef = PSModuleController.getCurrentBibleRef()

        if PocketSwordAppDelegate.shared()?.urlToOpen == nil {
            displayChapter(lastRef, with: BibleViewPoll, restore: RestoreScrollPosition)
        } else {
            PocketSwordAppDelegate.shared()?.urlToOpen = nil
            displayChapter(lastRef, with: BibleViewPoll, restore: RestoreVersePosition)
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(redisplayChapterWithDefaults), name: .resetBibleAndCommentaryView, object: nil)
        nc.addObserver(self, selector: #selector(redisplayBibleChapter), name: .redisplayPrimaryBible, object: nil)
        nc.addObserver(self, selector: #selector(redisplayCommentaryChapter), name: .redisplayPrimaryCommentary, object: nil)

        nc.addObserver(self, selector: #selector(toggleMultiListNoArg), name: .toggleMultiList, object: nil)
        nc.addObserver(self, selector: #selector(toggleNavigation), name: .toggleNavigation, object: nil)

        nc.addObserver(self, selector: #selector(hideInfo), name: .hideInfoPane, object: nil)
        nc.addObserver(self, selector: #selector(showInfoWithNotification(_:)), name: .showInfoPane, object: nil)
        nc.addObserver(self, selector: #selector(rotateInfo(_:)), name: .rotateInfoPane, object: nil)

        nc.addObserver(self, selector: #selector(displayCommentaryTabViaNotification), name: .showCommentaryTab, object: nil)
        nc.addObserver(self, selector: #selector(displayBibleTabViaNotification), name: .showBibleTab, object: nil)

        nc.addObserver(self, selector: #selector(updateViewWithSelectedBookChapterVerse(_:)), name: .updateSelectedReference, object: nil)

        nc.addObserver(self, selector: #selector(redisplayBibleChapterAfterBookmarksChange), name: .bookmarksChanged, object: nil)
    }

    @objc(setTabTitle:ofTab:)
    func setTabTitle(_ newTitle: String?, ofTab tab: ShownTab) {
        if tab == .BibleTab {
            bibleTabController?.setTabTitle(newTitle)
        } else if tab == .CommentaryTab {
            commentaryTabController?.setTabTitle(newTitle)
        }
    }

    @objc(setEnabledBibleNextButton:)
    func setEnabledBibleNextButton(_ enabled: Bool) {
        bibleTabController?.setEnabledNextButton(enabled)
    }

    @objc(setEnabledBiblePreviousButton:)
    func setEnabledBiblePreviousButton(_ enabled: Bool) {
        bibleTabController?.setEnabledPreviousButton(enabled)
    }

    @objc(setEnabledCommentaryNextButton:)
    func setEnabledCommentaryNextButton(_ enabled: Bool) {
        commentaryTabController?.setEnabledNextButton(enabled)
    }

    @objc(setEnabledCommentaryPreviousButton:)
    func setEnabledCommentaryPreviousButton(_ enabled: Bool) {
        commentaryTabController?.setEnabledPreviousButton(enabled)
    }

    // MARK: - PSModuleSearchControllerDelegate

    func searchDidFinish(_ newSearchHistoryItem: PSSearchHistoryItem?) {
        // NB: the original .mm had identical branches here (a copy/paste of the
        // bible-webView isDescendantOf check in both arms) — preserved verbatim so
        // behaviour is byte-identical.
        if let bibleWeb = bibleTabController?.webView,
           let selView = tabBarController.selectedViewController?.view,
           bibleWeb.isDescendant(of: selView) {
            self.savedSearchResultsTab = .BibleTab
        } else if let bibleWeb = bibleTabController?.webView,
                  let selView = tabBarController.selectedViewController?.view,
                  bibleWeb.isDescendant(of: selView) {
            self.savedSearchResultsTab = .CommentaryTab
        }
        self.savedSearchHistoryItem = newSearchHistoryItem
    }

    @objc(toggleMultiList:)
    func toggleMultiList(_ sender: Any?) {
        toggleMultiList()
    }

    // The notification-observer entry point (the old -toggleMultiList took no args
    // and was registered directly; #selector needs a distinct @objc name so the
    // arg-less form is reachable as a selector).
    @objc func toggleMultiListNoArg() {
        toggleMultiList()
    }

    @objc func toggleMultiList() {
        // Check the live view hierarchy, not just the ivar — swipe-to-dismiss
        // leaves the ivar set, which otherwise makes every alternate tap hit
        // the dismiss branch with nothing actually on screen.
        if let multiList = multiListController, multiList.presentingViewController != nil {
            tabBarController.dismiss(animated: true, completion: nil)
            multiListController = nil
        } else {
            let multiList = UITabBarController()
            multiListController = multiList
            let historyController = PSHistoryController()
            let searchController = PSModuleSearchController()
            let searchNavigationController = UINavigationController(rootViewController: searchController)
            searchNavigationController.title = NSLocalizedString("SearchTitle", comment: "")
            let historyNavigationController = UINavigationController(rootViewController: historyController)
            multiList.delegate = searchController
            searchController.delegate = self
            multiList.viewControllers = [historyNavigationController, searchNavigationController]

            let bibleOnScreen: Bool = {
                if let bibleWeb = bibleTabController?.webView,
                   let selView = tabBarController.selectedViewController?.view,
                   bibleWeb.isDescendant(of: selView) {
                    return true
                }
                return bibleTabController?.isFullScreen ?? false
            }()

            if bibleOnScreen {
                historyController.setListType(.BibleTab)
                searchController.setListType(.BibleTab)
                if savedSearchResultsTab == .BibleTab, let item = savedSearchHistoryItem, item.results != nil {
                    // restore the previous search term:
                    searchController.setSearchHistoryItem(item)
                    // [multiListController setSelectedViewController:searchNavigationController];
                } else if let item = savedSearchHistoryItem,
                          (item.searchTerm != nil || (item.searchTermToDisplay?.count ?? 0) > 0) {
                    // Strong's-popup-triggered searches arrive with only
                    // searchTermToDisplay + strongsSearch set — the FTS5
                    // expression is built later in setSearchHistoryItem:.
                    searchController.setSearchHistoryItem(item)
                    self.savedSearchHistoryItem = nil
                    multiList.selectedViewController = searchNavigationController
                }
            } else {
                historyController.setListType(.CommentaryTab)
                searchController.setListType(.CommentaryTab)
                if savedSearchResultsTab == .CommentaryTab, let item = savedSearchHistoryItem, item.results != nil {
                    // restore the previous search term:
                    searchController.setSearchHistoryItem(item)
                    // [multiListController setSelectedViewController:searchNavigationController];
                } else if let item = savedSearchHistoryItem,
                          (item.searchTerm != nil || (item.searchTermToDisplay?.count ?? 0) > 0) {
                    searchController.setSearchHistoryItem(item)
                    self.savedSearchHistoryItem = nil
                    multiList.selectedViewController = searchNavigationController
                }
            }

            if UserDefaults.standard.integer(forKey: DefaultsLastMultiListTab) == ShownMultiListTab.SearchTab.rawValue {
                multiList.selectedViewController = searchNavigationController
            }
            tabBarController.present(multiList, animated: true, completion: nil)
        }
    }

    @objc(presentationControllerDidDismiss:)
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if refNavigationController != nil {
            refSelectorController = nil
            refNavigationController = nil
        }
        if let infoPopup = infoPopupController,
           presentationController.presentedViewController == infoPopup {
            infoPopupController = nil
        }
    }

    @objc func displayCommentaryTabViaNotification() {
        setShownTabTo(.CommentaryTab)
    }

    @objc func displayBibleTabViaNotification() {
        setShownTabTo(.BibleTab)
    }

    @objc(toggleVoiceRef:)
    func toggleVoiceRef(_ sender: Any?) {
        guard PSFeatureFlags.voiceReferenceEnabled,
              PSModuleController.default()?.primaryBibleName != nil,
              tabBarController.presentedViewController == nil else {
            return
        }

        let voiceController = PSVoiceRefViewController()
        voiceController.onReferenceResolved = { reference in
            let selectedReference = [
                AppConstants.bookNameString: reference.displayBookName,
                AppConstants.chapterString: "\(reference.chapter)",
                AppConstants.verseString: "\(reference.verse)"
            ]
            NotificationCenter.default.post(name: .updateSelectedReference,
                                            object: selectedReference)
        }

        if let sheet = voiceController.sheetPresentationController {
            let identifier = UISheetPresentationController.Detent.Identifier("voiceReference")
            sheet.detents = [
                .custom(identifier: identifier) { _ in 280 }
            ]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        tabBarController.present(voiceController, animated: true)
    }

    @objc func toggleNavigation() {
        let iPad = PSResizing.iPad()
        if refNavigationController != nil || (tabBarController.presentedViewController != nil) {
            tabBarController.dismiss(animated: true, completion: nil)
            refSelectorController = nil
            refNavigationController = nil
        } else {
            if let bibleWeb = bibleTabController?.webView,
               let selView = tabBarController.selectedViewController?.view,
               bibleWeb.isDescendant(of: selView) {
                // bible tab
                if PSModuleController.default()?.primaryBibleName == nil {
                    // no Bible selected, so ignore...
                    return
                }
                let refSel = PSRefSelectorController(style: .plain)
                refSelectorController = refSel
                refSel.setupNavigation()
                let refNav = UINavigationController(rootViewController: refSel)
                refNavigationController = refNav
                if !iPad {
                    refSel.willShowNavigation()
                    tabBarController.present(refNav, animated: true, completion: nil)
                } else {
                    refNav.modalPresentationStyle = .popover
                    let viewToPresentPopoverFrom = bibleTabController?.titleSegmentedControl
                    var rect = viewToPresentPopoverFrom?.frame ?? .zero
                    rect.origin.x = 0
                    rect.origin.y = 0
                    refNav.popoverPresentationController?.sourceView = viewToPresentPopoverFrom
                    refNav.popoverPresentationController?.sourceRect = rect
                    refNav.popoverPresentationController?.permittedArrowDirections = .up
                    refNav.popoverPresentationController?.delegate = self
                    refSel.willShowNavigation()
                    tabBarController.present(refNav, animated: true, completion: nil)
                }
            } else if let commWeb = commentaryTabController?.webView,
                      let selView = tabBarController.selectedViewController?.view,
                      commWeb.isDescendant(of: selView) {
                // commentary tab
                if PSModuleController.default()?.primaryCommentaryName == nil {
                    // no Commentary selected, so ignore...
                    return
                }
                let refSel = PSRefSelectorController(style: .plain)
                refSelectorController = refSel
                refSel.setupNavigation()
                let refNav = UINavigationController(rootViewController: refSel)
                refNavigationController = refNav
                if !iPad {
                    refSel.willShowNavigation()
                    tabBarController.present(refNav, animated: true, completion: nil)
                } else {
                    refNav.modalPresentationStyle = .popover
                    let viewToPresentPopoverFrom = commentaryTabController?.titleSegmentedControl
                    var rect = viewToPresentPopoverFrom?.frame ?? .zero
                    rect.origin.x = 0
                    rect.origin.y = 0
                    refNav.popoverPresentationController?.sourceView = viewToPresentPopoverFrom
                    refNav.popoverPresentationController?.sourceRect = rect
                    refNav.popoverPresentationController?.permittedArrowDirections = .up
                    refNav.popoverPresentationController?.delegate = self
                    refSel.willShowNavigation()
                    tabBarController.present(refNav, animated: true, completion: nil)
                }
            }
        }
    }

    @objc(updateViewWithSelectedBookChapterVerse:)
    func updateViewWithSelectedBookChapterVerse(_ notification: Notification?) {
        guard let bcv = notification?.object as? [AnyHashable: Any] else { return }

        let bookNameString = bcv[BookNameString] as? String
        // Match the original -[NSString integerValue] (lenient leading-numeric parse).
        let chapter = ((bcv[ChapterString] as? String ?? "") as NSString).integerValue
        let verse = ((bcv[VerseString] as? String ?? "") as NSString).integerValue
        updateViewWithSelectedBookName(bookNameString, chapter: chapter, verse: verse)
    }

    @objc(updateViewWithSelectedBookName:chapter:verse:)
    func updateViewWithSelectedBookName(_ bookNameString: String?, chapter: Int, verse: Int) {
        // SWORD_REMOVAL_PLAN.md Phase 4: passthrough, where this used to call
        // +[SwordManager translateBookName:]. That method's own comment claimed to
        // "translate back to English", but it never did: there is no `en` locale
        // conf, and the only English locale — SWLocale(0), swlocale.cpp:63-69 — is
        // constructed with SWConfig(0) and has no [Text] section, so `translate`
        // returns its input. Identity for all 66 books, asserted in
        // PSRefSemanticsTests.testTranslateBookNameIsIdentityForAll66.
        //
        // The input is already the form the app wants: the selector VCs put
        // `PSVersificationBook.name` in the notification dict, and lastRef is built
        // straight from it.
        let bookName = bookNameString
        let verseString = "\(verse)"
        let ref = (bookName ?? "") + " \(chapter)"
        let moduleController = PSModuleController.default()
        let currentRef = PSModuleController.getCurrentBibleRef()
        if currentRef == ref {
            // we only need to move to the selected verse rather than reload the whole chapter
            let javascript = "scrollToVerse(\(verseString));"
            bibleTabController?.scrollToVerse(verse)
            bibleTabController?.webView?.stringByEvaluatingJavaScriptFromString(javascript)
            commentaryTabController?.scrollToVerse(verse)
            commentaryTabController?.webView?.stringByEvaluatingJavaScriptFromString(javascript)
            if moduleController?.primaryBibleName != nil {
                setTabTitle("\(ref):\(verseString)", ofTab: .BibleTab)
            }
            if moduleController?.primaryCommentaryName != nil {
                setTabTitle("\(ref):\(verseString)", ofTab: .CommentaryTab)
            }
        } else {
            if let bibleWeb = bibleTabController?.webView,
               let selView = tabBarController.selectedViewController?.view,
               bibleWeb.isDescendant(of: selView) {
                // bible tab
                UserDefaults.standard.set(verseString, forKey: DefaultsBibleVersePosition)
                UserDefaults.standard.set(verseString, forKey: DefaultsCommentaryVersePosition)
                UserDefaults.standard.synchronize()
                displayChapter(ref, with: BibleViewPoll, restore: RestoreVersePosition)
                PSHistoryController.addHistoryItem(.BibleTab)
            } else if let commWeb = commentaryTabController?.webView,
                      let selView = tabBarController.selectedViewController?.view,
                      commWeb.isDescendant(of: selView) {
                // commentary tab
                UserDefaults.standard.set(verseString, forKey: DefaultsBibleVersePosition)
                UserDefaults.standard.set(verseString, forKey: DefaultsCommentaryVersePosition)
                UserDefaults.standard.synchronize()
                displayChapter(ref, with: CommentaryViewPoll, restore: RestoreVersePosition)
                PSHistoryController.addHistoryItem(.CommentaryTab)
            } else {
                // something tab???
                UserDefaults.standard.set(verseString, forKey: DefaultsBibleVersePosition)
                UserDefaults.standard.set(verseString, forKey: DefaultsCommentaryVersePosition)
                UserDefaults.standard.synchronize()
                displayChapter(ref, with: NoViewPoll, restore: RestoreVersePosition)
            }
        }
    }

    @objc(displayTitle:)
    class func displayTitle(_ title: String?) {
        guard let keyWindow = PSResizing.keyWindow() else { return }
        let hud = MBProgressHUD.showAdded(to: keyWindow, animated: true)
        hud.mode = .text
        hud.label.text = PSModuleController.createRefString(title)
        hud.removeFromSuperViewOnHide = true

        hud.hide(animated: true, afterDelay: 0.75)
    }

    @objc func redisplayChapterWithDefaults() {
        let ref = PSModuleController.getCurrentBibleRef()
        displayChapter(ref, with: NoViewPoll, restore: RestoreVersePosition)
    }

    @objc func redisplayBibleChapterAfterBookmarksChange() {
        bibleTabController?.refToShow = nil
        bibleTabController?.jsToShow = nil
        redisplayChapter(BibleViewPoll, restore: RestoreScrollPosition)
    }

    @objc func redisplayBibleChapter() {
        bibleTabController?.refToShow = nil
        bibleTabController?.jsToShow = nil
        redisplayChapter(BibleViewPoll, restore: RestoreVersePosition)
    }

    @objc func redisplayCommentaryChapter() {
        commentaryTabController?.refToShow = nil
        commentaryTabController?.jsToShow = nil
        redisplayChapter(CommentaryViewPoll, restore: RestoreVersePosition)
    }

    @objc(redisplayChapter:restore:)
    func redisplayChapter(_ pollingType: PollingType, restore position: RestorePositionType) {
        let ref = PSModuleController.getCurrentBibleRef()
        displayChapter(ref, with: pollingType, restore: position)
    }

    @objc(displayChapter:withPollingType:restoreType:)
    func displayChapter(_ ref: String?, with polling: PollingType, restore position: RestorePositionType) {
        let bibleJavascript = NSMutableString(string: "")
        let commentaryJavascript = NSMutableString(string: "")
        var versePosition = UserDefaults.standard.string(forKey: DefaultsBibleVersePosition)
        switch position {
        case .scroll:
            if let scrollPosition = UserDefaults.standard.string(forKey: "bibleScrollPosition") {
                bibleJavascript.appendFormat("scrollToPosition(%@);\n", scrollPosition)
            }
            if let scrollPosition = UserDefaults.standard.string(forKey: "commentaryScrollPosition") {
                commentaryJavascript.appendFormat("scrollToPosition(%@);\n", scrollPosition)
            }
        case .verse:
            if let versePosition = versePosition {
                bibleJavascript.appendFormat("scrollToVerse(%@);\n", versePosition)
                bibleTabController?.setVerseToShow((versePosition as NSString).integerValue)
            }
            versePosition = UserDefaults.standard.string(forKey: DefaultsCommentaryVersePosition)
            if let versePosition = versePosition {
                commentaryJavascript.appendFormat("scrollToVerse(%@);\n", versePosition)
                commentaryTabController?.setVerseToShow((versePosition as NSString).integerValue)
            }
        case .none:
            break
        }

        switch polling {
        case .bible:
            bibleJavascript.append("startDetLocPoll();\n")
            let bText = PSModuleController.default()?.getBibleChapter(ref, withExtraJS: bibleJavascript as String)
            bibleTabController?.webView?.loadHTMLString(bText ?? "", baseURL: URL(fileURLWithPath: Bundle.main.resourcePath ?? ""))
            commentaryTabController?.refToShow = ref
            commentaryTabController?.jsToShow = commentaryJavascript as String
        case .commentary:
            commentaryJavascript.append("startDetLocPoll();\n")
            let cText = PSModuleController.default()?.getCommentaryChapter(ref, withExtraJS: commentaryJavascript as String)
            commentaryTabController?.webView?.loadHTMLString(cText ?? "", baseURL: URL(fileURLWithPath: Bundle.main.resourcePath ?? ""))
            bibleTabController?.refToShow = ref
            bibleTabController?.jsToShow = bibleJavascript as String
        case .none:
            commentaryTabController?.refToShow = ref
            commentaryTabController?.jsToShow = commentaryJavascript as String
            bibleTabController?.refToShow = ref
            bibleTabController?.jsToShow = bibleJavascript as String
        }

        var cVersePosition = "1"
        if let versePos = versePosition {
            cVersePosition = versePos
        } else {
            versePosition = "1"
        }
        switch position {
        case .scroll:
            cVersePosition = UserDefaults.standard.string(forKey: DefaultsCommentaryVersePosition) ?? "1"
        case .verse:
            break
        case .none:
            versePosition = "1"
            cVersePosition = "1"
        }

        var titleString = "\(PSModuleController.createRefString(ref) ?? ""):\(versePosition ?? "1")"
        if PSModuleController.default()?.primaryBibleName != nil {
            setTabTitle(titleString, ofTab: .BibleTab)
        }
        titleString = "\(PSModuleController.createRefString(ref) ?? ""):\(cVersePosition)"
        if PSModuleController.default()?.primaryCommentaryName != nil {
            setTabTitle(titleString, ofTab: .CommentaryTab)
        }

        let currentRef = PSModuleController.getCurrentBibleRef()
        if currentRef == PSModuleController.getLastRefAvailable() {
            setEnabledBibleNextButton(false)
            setEnabledBiblePreviousButton(true)
            setEnabledCommentaryNextButton(false)
            setEnabledCommentaryPreviousButton(true)
        } else if currentRef == PSModuleController.getFirstRefAvailable() {
            setEnabledBibleNextButton(true)
            setEnabledBiblePreviousButton(false)
            setEnabledCommentaryNextButton(true)
            setEnabledCommentaryPreviousButton(false)
        } else {
            setEnabledBibleNextButton(true)
            setEnabledBiblePreviousButton(true)
            setEnabledCommentaryNextButton(true)
            setEnabledCommentaryPreviousButton(true)
        }
    }

    @objc(highlightSearchTerm:forTab:)
    func highlightSearchTerm(_ term: String?, forTab tab: ShownTab) {
        switch tab {
        case .BibleTab:
            bibleTabController?.webView?.wkWebView?.highlightAllOccurencesOfString(term ?? "", completion: nil)
        case .CommentaryTab:
            commentaryTabController?.webView?.wkWebView?.highlightAllOccurencesOfString(term ?? "", completion: nil)
        default:
            break
        }
    }

    @objc(showInfoWithNotification:)
    func showInfoWithNotification(_ notification: Notification?) {
        if let content = notification?.object as? PSInfoPopupContent {
            showInfo(content)
        } else if let infoString = notification?.object as? String {
            showInfo(infoString)
        }
    }

    @objc(showInfo:)
    func showInfo(_ infoString: String?) {
        guard let infoString = infoString else { return }
        showInfo(PSInfoPopupContent(html: infoString))
    }

    private func showInfo(_ content: PSInfoPopupContent) {
        if let infoPopup = infoPopupController, infoPopup.presentingViewController != nil {
            // Already on screen — just swap the HTML, don't re-present.
            infoPopup.loadContent(content)
            return
        }

        let popup = PSInfoPopupViewController()
        // Force the view hierarchy to build so we can wire up the nav delegate
        // before presentation — WKWebView needs to exist before we assign it.
        _ = popup.view
        popup.webView?.navigationDelegate = self
        popup.onSearch = { [weak self] term in
            self?.startStrongsSearch(term)
        }

        popup.modalPresentationStyle = .pageSheet
        popup.presentationController?.delegate = self

        if let sheet = popup.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            // Dim the background at every detent — night-mode black-on-black
            // left the popup indistinguishable from the chapter.
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        self.infoPopupController = popup
        popup.loadContent(content)
        tabBarController.present(popup, animated: true, completion: nil)
    }

    private func startStrongsSearch(_ term: String) {
        guard !term.isEmpty else { return }

        self.savedSearchHistoryItem = nil
        let searchItem = PSSearchHistoryItem()
        searchItem.searchTermToDisplay = term
        searchItem.strongsSearch = true
        self.savedSearchHistoryItem = searchItem
        hideInfoWithCompletion { [weak self] in
            self?.toggleMultiList()
        }
    }

    @objc(rotateInfo:)
    func rotateInfo(_ notification: Notification?) {
        // The sheet presentation controller handles rotation natively; nothing
        // to do here. Kept as a no-op so existing NotificationRotateInfoPane
        // posts remain valid.
    }

    @objc func hideInfo() {
        hideInfoWithCompletion(nil)
    }

    @objc(hideInfoWithCompletion:)
    func hideInfoWithCompletion(_ completion: (() -> Void)?) {
        guard let popup = infoPopupController else {
            completion?()
            return
        }
        infoPopupController = nil
        popup.dismiss(animated: true, completion: completion)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ wv: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request

        // +dataForLink: returns id (imported as [AnyHashable: Any]!) — keep it as a
        // genuine optional for the `if let rData` guards below.
        let rData: [AnyHashable: Any]? = PSModuleController.data(forLink: request.url)
        var entry: String? = nil
        var popupContent: PSInfoPopupContent? = nil

        if request.url?.scheme == "bible" {
            // our internal reference to say this is a Bible verse to display in the Bible tab
            if let rData = rData, (rData[ATTRTYPE_ACTION] as? String) == "showRef" {
                // error checking, should always get here...
                setShownTabTo(.BibleTab)
                var ref = (rData[ATTRTYPE_VALUE] as? String) ?? ""
                let comps = ref.components(separatedBy: ":")

                if comps.count > 1 {
                    // we have a verse
                    UserDefaults.standard.set(comps[1], forKey: DefaultsBibleVersePosition)
                    UserDefaults.standard.synchronize()
                    ref = comps[0] // just the book & ch
                    displayChapter(ref, with: BibleViewPoll, restore: RestoreVersePosition)
                } else {
                    displayChapter(ref, with: BibleViewPoll, restore: RestoreNoPosition)
                }
                PSHistoryController.addHistoryItem(.BibleTab)

                decisionHandler(.cancel)
                return
            }
        } else if request.url?.scheme == "search" {
            // Tapping a Strong's link routes here (e.g. search://H0430).
            // The FTS5 engine handles H0xxx/Hxxx equivalence internally, so
            // we no longer need to build `lemma:` expressions with || operators.
            if let strongsSearchTerm = request.url?.host {
                startStrongsSearch(strongsSearchTerm)
            }

            decisionHandler(.cancel)
            return
        }

        if let rData = rData, (rData[ATTRTYPE_ACTION] as? String) == "showRef" {
            //
            // it's a Bible ref or dictionary entry to show.
            //
            let mod = rData[ATTRTYPE_MODULE] as? String
            // The three-way routing predicate now lives in PSRefLinkRouter as a
            // pure function, so it is assertable without the simulator — Phase 4
            // step 8's deletion of the `scriptRef` branch rests on an assertion
            // over all 14,989 baked lexicon links routing to `.dictionary`. Same
            // decision, same inputs, no behaviour change.
            var isABibleRef = false
            if let mod = mod {
                // The module's type comes from content_meta as of Phase 5 step 5 —
                // which is what PSRefLinkRouter's own test already used. A nil here
                // means "not a module we ship", and the router's documented
                // `ret = bible` default sends that down the bibleRef arm, exactly as
                // an uninstalled module did before.
                let store = PSContentStore.shared
                let moduleType = store?.moduleMeta(mod, key: "type")
                if PSRefLinkRouter.destination(forModuleName: mod,
                                               moduleType: moduleType) == .bibleRef {
                    isABibleRef = true
                } else {
                    // Should be a dictionary entry.
                    var strongs = false
                    if let store = store {
                        entry = PSContentReader.entry(module: mod,
                                                      key: rData[ATTRTYPE_VALUE] as? String)

                        var strongsSearchTerm = ""
                        let hasGreekDef = store.moduleHasFeature(mod, SWMOD_CONF_FEATURE_GREEKDEF)
                        let hasHebrewDef = store.moduleHasFeature(mod, SWMOD_CONF_FEATURE_HEBREWDEF)
                        if hasGreekDef && hasHebrewDef {
                            // should already have a prefix
                            strongsSearchTerm = (rData[ATTRTYPE_VALUE] as? String) ?? ""
                            strongs = true
                        } else if hasGreekDef {
                            let greek = NSMutableString(string: (rData[ATTRTYPE_VALUE] as? String) ?? "")
                            while greek.length > 0 && greek.character(at: 0) == unichar(UInt8(ascii: "0")) {
                                greek.deleteCharacters(in: NSRange(location: 0, length: 1))
                            }
                            strongsSearchTerm = "G\(greek)"
                            strongs = true
                        } else if hasHebrewDef {
                            let hebrew = NSMutableString(string: (rData[ATTRTYPE_VALUE] as? String) ?? "")
                            while hebrew.length > 0 && hebrew.character(at: 0) == unichar(UInt8(ascii: "0")) {
                                hebrew.deleteCharacters(in: NSRange(location: 0, length: 1))
                            }
                            strongsSearchTerm = "H0\(hebrew)"
                            strongs = true
                        }
                        if strongs {
                            // Preserve the raw rendered entry so the popup can
                            // extract the Greek/Hebrew lemma for its header.
                            let rawEntry = entry
                            entry = PSModuleController.createStrongsInfoHTMLString(entry, usingModuleForPreferences: mod)
                            if let entry = entry {
                                popupContent = PSInfoPopupContent(
                                    strongsHTML: entry,
                                    rawEntry: rawEntry,
                                    reference: strongsSearchTerm,
                                    allowsSearch: true
                                )
                            }
                        }
                    } else {
                        entry = "<p style=\"color:grey;text-align:center;font-style:italic;\">\(mod) \(NSLocalizedString("ModuleNotInstalled", comment: "is not installed."))</p>"
                    }

                    if !strongs {
                        let fontName = UserDefaults.standard.object(forKey: DefaultsFontNamePreference)
                        UserDefaults.standard.set(StrongsFontName, forKey: DefaultsFontNamePreference)
                        UserDefaults.standard.synchronize()
                        entry = PSModuleController.createInfoHTMLString(entry, usingModuleForPreferences: mod)
                        UserDefaults.standard.set(fontName, forKey: DefaultsFontNamePreference)
                        UserDefaults.standard.synchronize()
                    }
                }
            } else {
                // Bible ref:
                isABibleRef = true
            }

            if isABibleRef {
                // The scriptRef EXPANSION is gone — SWORD_REMOVAL_PLAN.md Phase 4
                // step 8. This arm used to call
                // -attributeValueForEntryData:cleanFeed: to turn a scriptRef into a
                // list of Bible verses, and nothing in the shipped content can reach
                // it: the only sword:// links baked anywhere are 14,989
                // lexicon->lexicon ones, and every one routes to the DICTIONARY arm
                // above (asserted over all 14,989 by
                // PSRefSemanticsTests.testEveryBakedSwordLinkRoutesToTheDictionaryArm
                // through the PSRefLinkRouter seam). The app's own bible-ref links
                // carry the `bible` scheme and are intercepted at the top of this
                // method, well before here.
                //
                // What is KEPT is the not-installed placeholder, which is the one
                // user-visible outcome this arm still has: a link naming a module the
                // user does not have. Everything else falls through to
                // decisionHandler(.allow), exactly as it already did whenever the
                // expansion produced nothing.
                // Whether the named module is one we ship, from content_meta. An
                // empty/absent module name means "the primary Bible", which always
                // exists — so only a NAMED, unknown module produces the placeholder.
                let moduleIsKnown: Bool
                if let mod = mod, mod != "" {
                    moduleIsKnown = PSContentStore.shared?.moduleMeta(mod, key: "type") != nil
                } else {
                    moduleIsKnown = PSModuleController.default()?.primaryBibleName != nil
                }
                if let mod = mod, !moduleIsKnown {
                    entry = "<p style=\"color:grey;text-align:center;font-style:italic;\">\(mod) \(NSLocalizedString("ModuleNotInstalled", comment: "is not installed."))</p>"
                    entry = PSModuleController.createInfoHTMLString(entry, usingModuleForPreferences: nil)
                }
            }

        } else if let rData = rData, (rData[ATTRTYPE_ACTION] as? String) == "showNote" {
            if (rData[ATTRTYPE_TYPE] as? String) == "n" { // footnote
                let bible = PSModuleController.default()?.primaryBibleName
                entry = PSContentReader.footnoteBody(module: bible, data: rData)
                entry = PSModuleController.createInfoHTMLString(entry, usingModuleForPreferences: bible)
            }
            // The `x` (cross-reference) arm is GONE too. No `x` anchor is ever
            // emitted for the shipped content, AND all 6,959 notes are type='study'
            // with an empty refList — so the branch that parsed that refList had
            // nothing to act on either way. Both re-derived from the store by
            // PSRefSemanticsTests.
        }

        if let popupContent = popupContent {
            showInfo(popupContent)
            decisionHandler(.cancel)
        } else if let resolvedEntry = entry {
            let cleaned = resolvedEntry.replacingOccurrences(of: "*x", with: "x").replacingOccurrences(of: "*n", with: "n")
            showInfo(cleaned)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    @objc(setShownTabTo:)
    func setShownTabTo(_ tab: ShownTab) {
        switch tab {
        case .BibleTab:
            for uivc in tabBarController.viewControllers ?? [] {
                if uivc.title == BibleTabTitleString {
                    tabBarController.selectedViewController = uivc
                }
            }
        case .CommentaryTab:
            for uivc in tabBarController.viewControllers ?? [] {
                if uivc.title == CommentaryTabTitleString {
                    tabBarController.selectedViewController = uivc
                }
            }
        case .PreferencesTab:
            if let settingsTabController {
                tabBarController.selectedViewController = settingsTabController
            }
        default:
            break
        }
    }

    // NOT an override: the coordinator is an NSObject, not a UIViewController, so
    // this is the plain -supportedInterfaceOrientations method the original Obj-C
    // class declared (consumed via the informal orientation hook). @objc preserves
    // the selector for any runtime caller.
    @objc var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

// PSLoadingViewController rode along in the old PSTabBarControllerDelegate.{h,mm}
// translation unit, so it is ported here to keep the unit intact. It forwards its
// supported orientations to the shared PSResizing helper.
@objc(PSLoadingViewController)
final class PSLoadingViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return PSResizing.supportedInterfaceOrientations()
    }
}
