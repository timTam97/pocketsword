//
//  PSModuleViewController.swift
//  PocketSword
//
//  Swift port (Wave 4, render-path cluster) of the former PSModuleViewController.{h,mm}.
//  This is the shared base for PSBibleViewController and PSCommentaryViewController.
//  It owns the title segmented control + module button, hosts the PSWebView, drives
//  chapter navigation, saves/restores the scroll/verse position, and — critically —
//  is the WKNavigationDelegate that decodes the JS bridge URLs (pocketsword:// for
//  current-verse + verse context menu, arraydump:// for the verse-position array,
//  sword:// for cross-references, and passagestudy file:// links) and routes the
//  rendered Strong's / morph / footnote / xref / dictionary HTML to the info pane.
//
//  Migrated ATOMICALLY with PSWebView (its hosted view + delegate) and its two
//  subclasses PSBibleViewController / PSCommentaryViewController (§2A Rule 3: a
//  Swift base cannot sit under Obj-C subclass headers). The original .mm had ZERO
//  sword:: — every SWORD touch goes through the Foundation-only Sword* facades.
//
//  All public selectors are preserved 1:1 so the still-Obj-C++ coordinator
//  (PSTabBarControllerDelegate.mm) keeps compiling. The coordinator reaches this
//  class via the generated PocketSword-Swift.h; this class reaches the coordinator
//  via PSTabBarControllerDelegate.h (clean after 0e, in the bridging header).
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit
import WebKit

// SWORD feature / passagestudy attribute / output-key names are @"literal" #defines
// in the Obj-C facade headers (SwordManager.h / SwordModule.h). Obj-C string #defines
// do NOT import into Swift, so these mirror the literals byte-for-byte (same approach
// as PSModuleController.swift). Wire strings unchanged.
private enum SWRender {
    // SWMOD_FEATURE_* / SWMOD_CONF_FEATURE_* (SwordManager.h)
    static let featureStrongs = "Strongs"
    static let confFeatureStrongs = "StrongsNumbers"
    static let featureMorph = "Morph"
    static let featureHeadings = "Headings"
    static let featureFootnotes = "Footnotes"
    static let featureScriptRef = "Scripref"          // not Scriptref
    static let featureRedLetterWords = "RedLetterWords"

    // ATTRTYPE_* (SwordModule.h)
    static let attrType = "type"
    static let attrAction = "action"
    static let attrValue = "value"

    // SW_OUTPUT_*_KEY (SwordModule.h)
    static let outputTextKey = "OutputTextKey"
    static let outputRefKey = "OutputRefKey"

    // SWMOD_CATEGORY_BIBLES (SwordManager.h) — the module `type` string, which is
    // what content_meta stores and what `ModuleType == bible` was derived from
    // (+[SwordModule moduleTypeForModuleTypeString:]).
    static let typeBibles = "Biblical Texts"
}

@objc(PSModuleViewController)
class PSModuleViewController: UIViewController, WKNavigationDelegate, PSWebViewDelegate {

    // MARK: - State

    @objc var titleSegmentedControl: UISegmentedControl?
    @objc var webView: PSWebView!
    @objc var moduleButton: UIBarButtonItem?

    // weak back-reference to the coordinator (the old `delegate` ivar/property).
    // NOT @objc: the custom -setDelegate: below does non-trivial bar-button setup,
    // so an @objc stored property would clash with the synthesized setter. The
    // coordinator only ever calls -setDelegate: (never reads -delegate via Obj-C);
    // internal Swift access through `delegate` is all that's needed.
    private weak var delegate: PSTabBarControllerDelegate?

    @objc var refToShow: String?
    @objc var jsToShow: String?
    @objc var tappedVerse: String?
    @objc private(set) var isFullScreen: Bool = false
    private var previousTabBarView: UIView?
    private var finishedLoading: Bool = false
    @objc var versePositionArray: NSArray?
    private var currentShownVerse: NSInteger = 0
    private var verseToShow: NSInteger = 0

    // Set by the subclass initialisers (PSBibleViewController -> .BibleTab,
    // PSCommentaryViewController -> .CommentaryTab). Defaults to .BibleTab as in the
    // original (the base's -init left tabType at its zero value; subclasses set it).
    var tabType: ShownTab = .BibleTab

    // MARK: - Init

    @objc override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - View

    override func loadView() {
        let screenBounds = PSResizing.mainScreenBounds()
        let viewWidth = screenBounds.size.width
        let viewHeight = screenBounds.size.height

        let baseView = UIView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))

        let wv = PSWebView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        wv.setDelegate(self)
        wv.psDelegate = self
        wv.backgroundColor = UIColor.systemBackground
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.loadHTMLString("<html><body>&nbsp;</body></html>", baseURL: nil)
        baseView.addSubview(wv)
        self.webView = wv

        self.view = baseView
        currentShownVerse = 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        switch tabType {
        case .BibleTab:
            let tbi = UITabBarItem(title: NSLocalizedString("TabBarTitleBible", comment: "Bible"),
                                   image: UIImage(named: "bible.png"), tag: 10)
            self.tabBarItem = tbi
            NotificationCenter.default.addObserver(self, selector: #selector(setModuleNameViaNotification),
                                                   name: .newPrimaryBible, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(prevChapter),
                                                   name: .bibleSwipeRight, object: nil)
        case .CommentaryTab:
            let tbi = UITabBarItem(title: NSLocalizedString("TabBarTitleCommentary", comment: "Commentary"),
                                   image: UIImage(named: "commentary.png"), tag: 10)
            self.tabBarItem = tbi
            NotificationCenter.default.addObserver(self, selector: #selector(setModuleNameViaNotification),
                                                   name: .newPrimaryCommentary, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(prevChapter),
                                                   name: .commentarySwipeRight, object: nil)
        default:
            break
        }

        let backImg = UIImage(named: "back-white.png")
        backImg?.accessibilityLabel = NSLocalizedString("VoiceOverPreviousChapterButton", comment: "")
        let forwardImg = UIImage(named: "forward-white.png")
        forwardImg?.accessibilityLabel = NSLocalizedString("VoiceOverNextChapterButton", comment: "")
        let segments: [Any] = [backImg as Any, "Gen 23:23", forwardImg as Any]
        let segControl = UISegmentedControl(items: segments)
        segControl.isMomentary = true

        let arrowWidth: CGFloat = 50.0
        let refWidth: CGFloat = 78.0
        segControl.setWidth(arrowWidth, forSegmentAt: 0)
        segControl.setWidth(refWidth, forSegmentAt: 1)
        segControl.setWidth(arrowWidth, forSegmentAt: 2)
        segControl.addTarget(self, action: #selector(segmentedControlAction(_:)), for: .valueChanged)
        self.navigationItem.titleView = segControl
        self.titleSegmentedControl = segControl

        isFullScreen = false
        NotificationCenter.default.addObserver(self, selector: #selector(redoBookmarkHighlights),
                                               name: .bookmarksChanged, object: nil)
        finishedLoading = false
    }

    // MARK: - Scroll / verse positioning

    @objc(scrollToVerse:)
    func scrollToVerse(_ verseNumber: NSInteger) {
        _ = scrollToVerseIfPossible(verseNumber)
    }

    @discardableResult
    private func scrollToVerseIfPossible(_ verseNumber: NSInteger) -> Bool {
        guard verseNumber > 0 else { return false }
        guard let scrollView = webView?.scrollView() else { return false }

        var newYOffset: CGFloat = 0.0
        if verseNumber > 1 {
            guard let versePositionArray = versePositionArray else { return false }
            let verseIndex = verseNumber - 1
            guard verseIndex >= 0 && verseIndex < versePositionArray.count else { return false }
            newYOffset = CGFloat((versePositionArray.object(at: verseIndex) as? NSNumber)?.floatValue ?? 0)
        }

        var topLength: CGFloat = 0
        var bottomLength: CGFloat = 0
        if !isFullScreen {
            topLength = view.safeAreaInsets.top
            bottomLength = view.safeAreaInsets.bottom
        }
        newYOffset = max(0, newYOffset - topLength)

        let maxYOffset = max(0, scrollView.contentSize.height - webView.frame.size.height + bottomLength)
        if newYOffset > maxYOffset {
            newYOffset = maxYOffset
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: newYOffset), animated: false)
        return true
    }

    func scrollHappened(_ psWebView: PSWebView, newOffsetY: CGFloat) {
        guard let versePositionArray = versePositionArray else { return }
        var verseNumber: NSInteger = 0
        while verseNumber < versePositionArray.count {
            if newOffsetY < CGFloat((versePositionArray.object(at: verseNumber) as? NSNumber)?.floatValue ?? 0) {
                break
            }
            verseNumber += 1
        }
        if verseNumber == 0 {
            verseNumber = 1
        } else if verseNumber == versePositionArray.count {
            verseNumber -= 1
        }
        if verseNumber == currentShownVerse {
            return
        }
        currentShownVerse = verseNumber
        // index 0 == verse 1, so we need to add one and then subtract 1, so the resulting verse is the number.
        // our method of updating the title bar & remembering our position.
        let verseString = String(format: "%d", Int32(verseNumber))
        if tabType == .BibleTab {
            UserDefaults.standard.set(String(format: "%d", Int32(newOffsetY)), forKey: "bibleScrollPosition")
            UserDefaults.standard.set(verseString, forKey: Defaults.bibleVersePosition)
        } else {
            UserDefaults.standard.set(String(format: "%d", Int32(newOffsetY)), forKey: "commentaryScrollPosition")
            UserDefaults.standard.set(verseString, forKey: Defaults.commentaryVersePosition)
        }
        let ref = NSMutableString(string: PSModuleController.getCurrentBibleRef())
        ref.appendFormat(":%@", verseString)
        setTabTitle(PSModuleController.createRefString(ref as String))
    }

    private func saveVersePositionArray(_ verseArray: [Any]?) {
        guard let verseArray = verseArray, verseArray.count != 0 else { return }
        let mutVerseArray = NSMutableArray(capacity: verseArray.count)
        // ignore the first element in the array, because it is "arraydump"
        // The rest of the array is the location of each verse.
        for i in 1..<verseArray.count {
            mutVerseArray.add(NSNumber(value: (verseArray[i] as? NSString)?.floatValue ?? 0))
        }
        self.versePositionArray = mutVerseArray
        if verseToShow > 0 && scrollToVerseIfPossible(verseToShow) {
            verseToShow = 0
        }
    }

    @objc(segmentedControlAction:)
    func segmentedControlAction(_ sender: Any) {
        guard let segControl = sender as? UISegmentedControl else { return }
        switch segControl.selectedSegmentIndex {
        case 0: // previous
            prevChapter()
        case 1: // Ref
            delegate?.toggleNavigation()
        case 2: // next
            nextChapter()
        default:
            break
        }
    }

    // Loads the next chapter into the Web View
    @objc(nextChapter)
    func nextChapter() {
        verseToShow = 0
        let currentRef = PSModuleController.getCurrentBibleRef()
        if currentRef == PSModuleController.getLastRefAvailable() {
            return
        }

        guard let ref = PSModuleController.default().setToNextChapter() else {
            return
        }

        if isFullScreen {
            PSTabBarControllerDelegate.displayTitle(ref)
        }

        switch tabType {
        case .BibleTab:
            delegate?.displayChapter(ref, with: BibleViewPoll, restore: RestoreNoPosition)
            PSHistoryController.addHistoryItem(.BibleTab)
        case .CommentaryTab:
            delegate?.displayChapter(ref, with: CommentaryViewPoll, restore: RestoreNoPosition)
            PSHistoryController.addHistoryItem(.CommentaryTab)
        default:
            break
        }
    }

    // Loads the previous chapter into the Web View
    //
    // Restores NO position, i.e. lands at the START of the previous chapter — the
    // same as -nextChapter, and symmetric with it.
    //
    // This used to pass RestoreVersePosition, which reads the *shared*
    // Defaults{Bible,Commentary}VersePosition — the verse you were on in the chapter
    // you are LEAVING. Paging back from John 3:20 therefore restored "verse 20" into
    // John 2, dumping you near the bottom of a chapter you had just arrived at.
    // Chapter paging is not a position-restoring operation; going back a chapter
    // means going to its beginning.
    @objc(prevChapter)
    func prevChapter() {
        verseToShow = 0
        let currentRef = PSModuleController.getCurrentBibleRef()
        if currentRef == PSModuleController.getFirstRefAvailable() {
            return
        }

        guard let ref = PSModuleController.default().setToPreviousChapter() else {
            return
        }

        if isFullScreen {
            PSTabBarControllerDelegate.displayTitle(ref)
        }

        switch tabType {
        case .BibleTab:
            delegate?.displayChapter(ref, with: BibleViewPoll, restore: RestoreNoPosition)
            PSHistoryController.addHistoryItem(.BibleTab)
        case .CommentaryTab:
            delegate?.displayChapter(ref, with: CommentaryViewPoll, restore: RestoreNoPosition)
            PSHistoryController.addHistoryItem(.CommentaryTab)
        default:
            break
        }
    }

    @objc(setEnabledNextButton:)
    func setEnabledNextButton(_ enabled: Bool) {
        titleSegmentedControl?.setEnabled(enabled, forSegmentAt: 2)
    }

    @objc(setEnabledPreviousButton:)
    func setEnabledPreviousButton(_ enabled: Bool) {
        titleSegmentedControl?.setEnabled(enabled, forSegmentAt: 0)
    }

    @objc(setTabTitle:)
    func setTabTitle(_ title: String?) {
        let titleToDisplay = PSModuleController.createTitleRefString(title)
        titleSegmentedControl?.setTitle(titleToDisplay, forSegmentAt: 1)
        if let subviews = titleSegmentedControl?.subviews {
            PSModuleViewController.setVoiceOverForRefSegmentedControlSubviews(subviews)
        }
    }

    @objc(setModuleNameViaNotification)
    func setModuleNameViaNotification() {
        autoreleasepool {
            rebuildSettingsMenu()
            if tabType != .BibleTab && PSModuleController.default().primaryCommentaryName == nil {
                // The real empty-state path: no commentary installed, so there is
                // nothing to page through.
                titleSegmentedControl?.setTitle("PocketSword", forSegmentAt: 1)
                setEnabledNextButton(false)
                setEnabledPreviousButton(false)
            }
        }
    }

    /// The active module for this tab's `▾` settings menu, by NAME: the primary Bible
    /// on the Bible tab, the primary commentary on the Commentary tab.
    ///
    /// Phase 5 step 5: was a `SwordModule`, read only for its `name`, its
    /// `hasFeature:` answers and its `type`. All three now come from `content_meta`.
    private var settingsMenuModuleName: String? {
        (tabType == .BibleTab) ? PSModuleController.default().primaryBibleName
                               : PSModuleController.default().primaryCommentaryName
    }

    /// The redisplay notification this tab's renderer listens for.
    private var redisplayNotification: Notification.Name {
        (tabType == .BibleTab) ? .redisplayPrimaryBible : .redisplayPrimaryCommentary
    }

    /// Builds the per-tab `▾` (textformat) settings menu from the active module's
    /// advertised features. Every row writes the PER-MODULE pref key ("<pref>_<mod>")
    /// keyed on the module's own name — the same domain `-[SwordModule setPreferences]`
    /// reads on every render, which is what makes these toggles actually take effect.
    ///
    /// Feature gating reads the BAKED feature set (`content_meta`'s
    /// `module.<name>.features`) as of Phase 5 step 5, which holds exactly what
    /// `-[SwordModule hasFeature:]` answered. That matters because hasFeature: also
    /// matched GlobalOptionFilter entries (OSIS/GBF/ThML/UTF8-prefixed and bare), not
    /// just `Feature=` lines — so KJV's OSISFootnotes / OSISHeadings /
    /// OSISRedLetterWords filters satisfy the Footnotes / Headings / RedLetterWords
    /// gates even though it declares only `Feature=StrongsNumbers`.
    ///
    /// Measured consequence worth knowing: KJV yields **six** rows, not seven. It has
    /// no `OSISScripref` filter and no `Feature=Scripref`, so the Cross-references row
    /// was never in its menu — verified against the live engine in step 4, so this is
    /// a record of existing behaviour rather than a change.
    ///
    /// A module that advertises nothing (e.g. MHCC, whose conf declares no `Feature=`
    /// and no `GlobalOptionFilter`) yields NO rows at all now that the font moved to
    /// Preferences — so the button hides itself rather than presenting an empty menu.
    @objc(rebuildSettingsMenu)
    func rebuildSettingsMenu() {
        guard let modName = settingsMenuModuleName, let store = PSContentStore.shared else {
            setSettingsMenu(nil)
            return
        }

        /// Whether this module advertises a feature — from the BAKED feature set
        /// (`module.<name>.features` in `content_meta`) rather than a live
        /// `-[SwordModule hasFeature:]`. The converter reproduced hasFeature:'s full
        /// rule, prefixed GlobalOptionFilter matching included, and
        /// PSDifferentialTests checked all 75 answers against the engine while it was
        /// still in the tree.
        func has(_ feature: String) -> Bool { store.moduleHasFeature(modName, feature) }

        /// Whether this tab is showing a Bible, which is the verse-per-line gate.
        /// `module.type == bible` became a `content_meta` type-string comparison.
        let isBible = store.moduleMeta(modName, key: "type") == SWRender.typeBibles

        let prefix = (tabType == .BibleTab) ? "bible" : "commentary"
        var topLevel: [UIMenuElement] = []

        /// One inline-grouped boolean toggle over a per-module pref key.
        func addToggle(_ title: String, pref: String, id: String) {
            let action = UIAction(title: title, image: nil,
                                  identifier: UIAction.Identifier("\(prefix).\(id)")) { [weak self] _ in
                guard let self = self, let mName = self.settingsMenuModuleName else { return }
                let current = UserDefaults.standard.psBool(pref, forModule: mName)
                UserDefaults.standard.psSet(!current, forPref: pref, module: mName)
                UserDefaults.standard.synchronize()
                NotificationCenter.default.post(name: self.redisplayNotification, object: nil)
                self.rebuildSettingsMenu()
            }
            action.state = UserDefaults.standard.psBool(pref, forModule: modName) ? .on : .off
            topLevel.append(UIMenu(title: "", image: nil,
                                   identifier: UIMenu.Identifier("\(prefix).\(id)Group"),
                                   options: .displayInline, children: [action]))
        }

        if has(SWRender.featureStrongs) || has(SWRender.confFeatureStrongs) {
            addToggle(NSLocalizedString("PreferencesStrongsPreferencesTitle", comment: "Strong's Numbers"),
                      pref: Defaults.strongsPreference, id: "strongs")
        }
        if has(SWRender.featureMorph) {
            addToggle(NSLocalizedString("PreferencesMorphTagsTitle", comment: "Morphological Tags"),
                      pref: Defaults.morphPreference, id: "morph")
        }
        if has(SWRender.featureHeadings) {
            addToggle(NSLocalizedString("PreferencesHeadingsTitle", comment: "Headings"),
                      pref: Defaults.headingsPreference, id: "headings")
        }
        if has(SWRender.featureFootnotes) {
            addToggle(NSLocalizedString("PreferencesFootnotesTitle", comment: "Footnotes"),
                      pref: Defaults.footnotesPreference, id: "footnotes")
        }
        if has(SWRender.featureScriptRef) {
            addToggle(NSLocalizedString("PreferencesCrossReferencesTitle", comment: "Cross-references"),
                      pref: Defaults.scriptRefsPreference, id: "xref")
        }
        if has(SWRender.featureRedLetterWords) {
            addToggle(NSLocalizedString("PreferencesRedLetterTitle", comment: "Red Letter"),
                      pref: Defaults.redLetterPreference, id: "redLetter")
        }
        if isBible {
            // VPL is a rendering-side option only — it never went through
            // -setPreferences (see PSModulePreferencesController's old vplChanged:).
            addToggle(NSLocalizedString("PreferencesVPLTitle", comment: "Verse Per Line"),
                      pref: Defaults.vplPreference, id: "vpl")
        }

        // No Font row here: font name + size are a single GLOBAL setting configured
        // in the Preferences pane, not per module.
        setSettingsMenu(topLevel.isEmpty ? nil : UIMenu(title: "", children: topLevel))
    }

    /// Installs the display-settings menu, hiding the button entirely when there is
    /// nothing to show (an empty UIMenu renders as a button that does nothing).
    private func setSettingsMenu(_ menu: UIMenu?) {
        moduleButton?.menu = menu
        moduleButton?.isHidden = (menu == nil)
    }

    @objc(setDelegate:)
    func setDelegate(_ vc: PSTabBarControllerDelegate?) {
        let searchButton = UIBarButtonItem(image: UIImage(named: "history.png"),
                                           style: .plain, target: vc,
                                           action: NSSelectorFromString("toggleMultiList:"))
        searchButton.accessibilityLabel = NSLocalizedString("VoiceOverHistoryAndSearchButton", comment: "")
        self.navigationItem.leftBarButtonItem = searchButton

        let rightButton = UIBarButtonItem(image: UIImage(systemName: "textformat"),
                                          style: .plain, target: nil, action: nil)
        rightButton.accessibilityLabel = NSLocalizedString("VoiceOverDisplaySettingsButton", comment: "")
        self.moduleButton = rightButton
        rebuildSettingsMenu()

        if tabType == .BibleTab {
            if PSFeatureFlags.voiceReferenceEnabled {
                let voiceButton = UIBarButtonItem(
                    image: UIImage(systemName: "microphone"),
                    style: .plain,
                    target: vc,
                    action: NSSelectorFromString("toggleVoiceRef:")
                )
                voiceButton.accessibilityLabel = NSLocalizedString("VoiceOverVoiceRefButton", comment: "")
                voiceButton.isHidden = true
                navigationItem.rightBarButtonItems = [rightButton, voiceButton]

                Task {
                    if case .available = await PSVoiceRefSession.availability() {
                        voiceButton.isHidden = false
                    }
                }
            } else {
                navigationItem.rightBarButtonItem = rightButton
            }
        } else {
            setModuleNameViaNotification()
            navigationItem.rightBarButtonItem = rightButton
        }
        delegate = vc
    }

    func topReloadTriggered(_ psWebView: PSWebView) {
        prevChapter()
    }

    func bottomReloadTriggered(_ psWebView: PSWebView) {
        nextChapter()
    }

    private func setupWebViewRefreshViews() {
        var topLength: CGFloat = 0
        var bottomLength: CGFloat = 0
        if !isFullScreen {
            topLength = view.safeAreaInsets.top
            bottomLength = view.safeAreaInsets.bottom
        }
        webView.setupRefreshViews(topLength, bottom: bottomLength)
    }

    @objc(setVerseToShow:)
    func setVerseToShow(_ verseNumber: NSInteger) {
        verseToShow = verseNumber
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let transparentAppearance = UINavigationBarAppearance()
        transparentAppearance.configureWithTransparentBackground()
        self.navigationController?.navigationBar.standardAppearance = transparentAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = transparentAppearance

        if let refToShow = refToShow {
            let webText: String?
            if tabType == .BibleTab {
                webText = PSModuleController.default().getBibleChapter(refToShow, withExtraJS: String(format: "%@\nstartDetLocPoll();\n", jsToShow ?? ""))
            } else {
                webText = PSModuleController.default().getCommentaryChapter(refToShow, withExtraJS: String(format: "%@\nstartDetLocPoll();\n", jsToShow ?? ""))
            }
            webView.loadHTMLString(webText ?? "", baseURL: URL(fileURLWithPath: Bundle.main.resourcePath ?? ""))
            self.refToShow = nil
            self.jsToShow = nil
        } else if let jsToShow = jsToShow {
            let jsString = String(format: "%@; startDetLocPoll();", jsToShow)
            webView.stringByEvaluatingJavaScriptFromString(jsString)
            self.jsToShow = nil
        } else if verseToShow > 0 {
            // go there.
            if scrollToVerseIfPossible(verseToShow) {
                verseToShow = 0
            }
        } else {
            webView.stringByEvaluatingJavaScriptFromString("startDetLocPoll();")
        }
        if !isFullScreen {
            if finishedLoading {
                setupWebViewRefreshViews()
            }
        }
        if finishedLoading {
            var topLength: CGFloat = 0.0
            if !isFullScreen {
                topLength = view.safeAreaInsets.top
            }
            scrollHappened(webView, newOffsetY: webView.scrollView().contentOffset.y + topLength)
        }
        if UserDefaults.standard.bool(forKey: Defaults.fullscreenModePreference) {
            webView.autoFullscreenMode = true
        } else {
            webView.autoFullscreenMode = false
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        webView.stringByEvaluatingJavaScriptFromString("stopDetLocPoll();")
        let verseKey = (tabType == .BibleTab) ? Defaults.bibleVersePosition : Defaults.commentaryVersePosition
        self.jsToShow = String(format: "scrollToVerse(%@);", (UserDefaults.standard.object(forKey: verseKey) as? String) ?? "")
        if !isFullScreen {
            webView.removeRefreshViews()
        }
        coordinator.animate(alongsideTransition: nil) { _ in
            NotificationCenter.default.post(name: .rotateInfoPane, object: nil)
            let js: String
            if let jsToShow = self.jsToShow {
                js = String(format: "resetArrays();%@startDetLocPoll();", jsToShow)
                self.jsToShow = nil
            } else {
                js = "resetArrays();startDetLocPoll();"
            }
            self.webView.stringByEvaluatingJavaScriptFromString(js)
            if self.finishedLoading {
                self.setupWebViewRefreshViews()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.stringByEvaluatingJavaScriptFromString("stopDetLocPoll();")
    }

    @objc(switchToFullscreen)
    func switchToFullscreen() {
        if !isFullScreen {
            toggleFullscreen()
        }
    }

    @objc(switchToNormalscreen)
    func switchToNormalscreen() {
        if isFullScreen {
            toggleFullscreen()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return isFullScreen
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    @objc(toggleFullscreen)
    func toggleFullscreen() {
        webView.stringByEvaluatingJavaScriptFromString("stopDetLocPoll();")
        isFullScreen = !isFullScreen
        webView.removeRefreshViews()

        setNeedsStatusBarAppearanceUpdate()

        // resize webview to be full screen / normal
        webView.removeFromSuperview()
        if isFullScreen {
            // previousTabBarView is an ivar to hang on to the original view...
            previousTabBarView = self.tabBarController?.view
            self.tabBarController?.view.addSubview(webView)
            webView.frame = PSResizing.getOrientationRect(.portrait)
        } else {
            self.view.addSubview(webView)
            self.tabBarController?.view = previousTabBarView
        }

        UIView.animate(withDuration: 0.5, delay: 0, options: .beginFromCurrentState, animations: {
            self.tabBarController?.tabBar.alpha = (self.isFullScreen) ? 0 : 1
        }, completion: { _ in
            self.setupWebViewRefreshViews()
            self.webView.stringByEvaluatingJavaScriptFromString("startDetLocPoll();")
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc(highlightBookmarks)
    func highlightBookmarks() {
        let shownBookmarks = PSBookmarks.getBookmarksForCurrentRef()
        if shownBookmarks.count > 0 {
            if let path = Bundle.main.path(forResource: "HighlightBookmarks", ofType: "js"),
               let jsCode = try? String(contentsOfFile: path, encoding: .utf8) {
                webView.stringByEvaluatingJavaScriptFromString(jsCode)
            }
            for case let bookmark as PSBookmark in shownBookmarks {
                if let rgbHexString = bookmark.rgbHexString, let bref = bookmark.ref {
                    let parts = bref.components(separatedBy: ":")
                    if parts.count > 1 {
                        let verse = parts[1]
                        let jsFunction = String(format: "PS_HighlightVerseWithHexColour('%@','%@')", verse,
                                                PSBookmarkFolder.rgbString(fromHexString: rgbHexString))
                        webView.stringByEvaluatingJavaScriptFromString(jsFunction)
                    }
                }
            }
        }
    }

    @objc(removeBookmarkHighlights)
    func removeBookmarkHighlights() {
        // SWORD_REMOVAL_PLAN.md Phase 4: the verse count comes from the baked
        // versification table rather than `-[SwordModule getVerseMax]`.
        //
        // This is an upper bound for a JS loop that clears highlight spans, so it
        // must cover the chapter currently on screen — which is `lastRef`, the same
        // ref the render used. `-getVerseMax` read it off the module's live key,
        // which is left pointing at that chapter by the render, so the two agree;
        // resolving `lastRef` says so explicitly instead of depending on where the
        // shared key happens to be left. 0 on an unresolvable ref clears nothing,
        // which is the same no-op the engine's -1-vs-0 path produced.
        var verses = 0
        if let resolver = PSBookOSISResolver.shared,
           let ref = PSModuleController.getCurrentBibleRef(),
           let (book, chapter) = resolver.resolve(ref: ref) {
            verses = resolver.verseMax(book: book, chapter: chapter) ?? 0
        }
        let jsFunction = String(format: "PS_RemoveHighlights('%d')", Int32(verses))
        webView.stringByEvaluatingJavaScriptFromString(jsFunction)
    }

    @objc(redoBookmarkHighlights)
    func redoBookmarkHighlights() {
        removeBookmarkHighlights()
        highlightBookmarks()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ wv: WKWebView, didFinish navigation: WKNavigation!) {
        setupWebViewRefreshViews()
        finishedLoading = true
        if verseToShow > 0 {
            if scrollToVerseIfPossible(verseToShow) {
                verseToShow = 0
            }
        } else {
            var topLength: CGFloat = 0.0
            if !isFullScreen {
                topLength = view.safeAreaInsets.top
            }
            scrollHappened(webView, newOffsetY: webView.scrollView().contentOffset.y + topLength)
        }
        // highlight search results
        // TODO: implement highlighting of search results
    }

    func webView(_ wv: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        finishedLoading = false
    }

    func webView(_ wv: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        autoreleasepool {
            let request = navigationAction.request
            let requestString = request.url?.absoluteString ?? ""
            let components = requestString.components(separatedBy: ":")

            if components.count > 1 && components[0] == "pocketsword" {
                if components[1] == "currentverse" {
                    // our method of updating the title bar & remembering our position.
                    if tabType == .BibleTab {
                        UserDefaults.standard.set(components[3], forKey: "bibleScrollPosition")
                        UserDefaults.standard.set(components[2], forKey: Defaults.bibleVersePosition)
                    } else {
                        UserDefaults.standard.set(components[3], forKey: "commentaryScrollPosition")
                        UserDefaults.standard.set(components[2], forKey: Defaults.commentaryVersePosition)
                    }
                    UserDefaults.standard.synchronize()
                    let ref = NSMutableString(string: PSModuleController.getCurrentBibleRef())
                    ref.appendFormat(":%@", components[2])
                    setTabTitle(PSModuleController.createRefString(ref as String))
                } else if components[1] == "versemenu" && tabType == .BibleTab {
                    // ONLY for BibleTab, not CommentaryTab...
                    // bring up the contextual menu for a verse.
                    self.tappedVerse = components[2]
                    let tappedVerseInt = NSInteger((self.tappedVerse as NSString?)?.integerValue ?? 0)
                    let sheetTitle = String(format: NSLocalizedString("RefSelectorVerseTitle", comment: ""), tappedVerseInt)
                    let actionSheet = UIAlertController(title: sheetTitle, message: nil, preferredStyle: .actionSheet)
                    actionSheet.addAction(UIAlertAction(title: NSLocalizedString("VerseContextualMenuAddBookmark", comment: ""), style: .default) { _ in
                        // add a bookmark!
                        let refToBookmark = PSModuleController.createRefString(PSModuleController.getCurrentBibleRef())
                        let tableViewController = PSBookmarksAddTableViewController(bookAndChapterRef: refToBookmark, andVerse: self.tappedVerse)
                        let containingNavigationController = UINavigationController(rootViewController: tableViewController)
                        self.present(containingNavigationController, animated: true, completion: nil)
                        self.tappedVerse = nil
                    })
                    actionSheet.addAction(UIAlertAction(title: NSLocalizedString("VerseContextualMenuCommentary", comment: ""), style: .default) { _ in
                        // switch to the equivalent commentary entry.
                        let commView = (self as? PSBibleViewController)?.commentaryView
                        commView?.setVerseToShow(NSInteger((self.tappedVerse as NSString?)?.integerValue ?? 0))
                        let fs = self.isFullScreen
                        if fs {
                            self.toggleFullscreen()
                            commView?.viewWillAppear(true)
                        }
                        NotificationCenter.default.post(name: .showCommentaryTab, object: nil)
                        if fs {
                            commView?.toggleFullscreen()
                        }
                        self.tappedVerse = nil
                    })
                    actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
                    // TODO: for iPad, use popoverPresentationController.sourceView/sourceRect instead.
                    self.present(actionSheet, animated: true, completion: nil)
                }
                decisionHandler(.cancel)
                return
            } else if components.count > 0 && components[0] == "arraydump" {
                saveVersePositionArray(components)
                decisionHandler(.cancel)
                return
            } else if request.url?.scheme == "sword" {
                // our internal reference to say this is a Bible verse to display in the Bible tab
                // This should only happen in the commentary tab & we allow it to "load" normally.
                dlog("\nCOMMENTARY: requestString: \(requestString)")
                decisionHandler(.allow)
                return
            } else {
                guard let url = request.url else {
                    decisionHandler(.allow)
                    return
                }
                let rData = PSModuleController.data(forLink: url)
                var entry: String? = nil
                var popupContent: PSInfoPopupContent? = nil

                if let rData = rData, (rData[SWRender.attrAction] as? String) == "showStrongs" {
                    //
                    // Strong's Numbers
                    //
                    var mod = BundledModules.strongsGreek
                    var hebrew = false
                    if (rData[SWRender.attrType] as? String) == "Hebrew" {
                        mod = BundledModules.strongsHebrew
                        hebrew = true
                    }

                    let rawNumber = (rData[SWRender.attrValue] as? String) ?? ""
                    let strongsReference = "\(hebrew ? "H" : "G")\(rawNumber)"
                    entry = PSContentReader.entry(module: mod, key: rawNumber)
                    let hasDefinition = entry != nil
                    // Keep the raw rendered entry so the popup can pull the
                    // Greek/Hebrew lemma out for its header (only when it's a
                    // real definition, not the "no module" placeholder).
                    let rawEntry = hasDefinition ? entry : nil
                    if entry == nil {
                        if hebrew {
                            entry = NSLocalizedString("NoHebrewStrongsNumbersModuleInstalled", comment: "")
                        } else {
                            entry = NSLocalizedString("NoGreekStrongsNumbersModuleInstalled", comment: "")
                        }
                    }

                    entry = PSModuleController.createStrongsInfoHTMLString(entry, usingModuleForPreferences: mod)
                    if let entry = entry {
                        popupContent = PSInfoPopupContent(
                            strongsHTML: entry,
                            rawEntry: rawEntry,
                            reference: strongsReference,
                            allowsSearch: hasDefinition && tabType == .BibleTab
                        )
                    }

                } else if let rData = rData, (rData[SWRender.attrAction] as? String) == "showMorph" {
                    //
                    // Morphological Tags
                    //
                    let mod = BundledModules.morphGreek
                    if (rData[SWRender.attrType] as? String)?.hasPrefix("strongMorph") == true {
                        entry = NSLocalizedString("MorphHebrewNotSupported", comment: "")
                    } else {
                        entry = PSContentReader.entry(module: mod, key: rData[SWRender.attrValue] as? String)
                        if entry == nil {
                            entry = NSLocalizedString("NoMorphGreekModuleInstalled", comment: "")
                        }
                    }
                    entry = PSModuleController.createInfoHTMLString(entry, usingModuleForPreferences: mod)

                } else if let rData = rData, (rData[SWRender.attrAction] as? String) == "showNote" {
                    if (rData[SWRender.attrType] as? String) == "n" { // footnote
                        let mod = (tabType == .BibleTab)
                            ? PSModuleController.default().primaryBibleName
                            : PSModuleController.default().primaryCommentaryName
                        entry = PSContentReader.footnoteBody(module: mod, data: rData)
                        entry = entry?.replacingOccurrences(of: "*x", with: "x")
                        entry = entry?.replacingOccurrences(of: "*n", with: "n")
                        entry = PSModuleController.createInfoHTMLString(entry, usingModuleForPreferences: mod)
                    }
                    // The `x` (cross-reference) arm is GONE — SWORD_REMOVAL_PLAN.md
                    // Phase 4 step 8. No `x` anchor is ever emitted for the shipped
                    // content (zero cross-reference tokens in the store) and all
                    // 6,959 notes are type='study' with an EMPTY refList, so the
                    // branch that parsed that refList had nothing to act on. Both
                    // facts are re-derived from the store by
                    // PSRefSemanticsTests.testEveryNoteIsAStudyNoteWithAnEmptyRefList
                    // and testNoShippedContentEmitsAShowRefAnchor.
                }
                // The `showRef` arm is GONE with it. It called
                // attributeValueForEntryData:cleanFeed:YES to expand a scriptRef
                // into a Bible-verse list, and nothing in the shipped content can
                // reach it: the only sword:// links anywhere are 14,989
                // lexicon->lexicon ones, and every one of them routes to the
                // DICTIONARY arm, not this one — asserted over all 14,989 by
                // PSRefSemanticsTests.testEveryBakedSwordLinkRoutesToTheDictionaryArm
                // via the PSRefLinkRouter seam. The app's own bible-ref links carry
                // the `bible` scheme and are intercepted earlier.

                if let popupContent = popupContent {
                    NotificationCenter.default.post(name: .showInfoPane, object: popupContent)
                    decisionHandler(.cancel)
                    return
                } else if let entry = entry {
                    NotificationCenter.default.post(name: .showInfoPane, object: entry)
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }
    }

    @objc(setVoiceOverForRefSegmentedControlSubviews:)
    class func setVoiceOverForRefSegmentedControlSubviews(_ subviews: [UIView]) {
        for segmentView in subviews {
            if segmentView.accessibilityLabel == "forward-white.png" ||
                segmentView.accessibilityLabel == NSLocalizedString("VoiceOverNextChapterButton", comment: "") {
                // forward button
                segmentView.accessibilityLabel = NSLocalizedString("VoiceOverNextChapterButton", comment: "")
            } else if segmentView.accessibilityLabel == "back-white.png" ||
                        segmentView.accessibilityLabel == NSLocalizedString("VoiceOverPreviousChapterButton", comment: "") {
                // backward button
                segmentView.accessibilityLabel = NSLocalizedString("VoiceOverPreviousChapterButton", comment: "")
            } else {
                // chapter title
                segmentView.accessibilityLabel = PSModuleController.getCurrentBibleRef()
            }
        }
    }
}
