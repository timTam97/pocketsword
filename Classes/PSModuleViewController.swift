//
//  PSModuleViewController.swift
//  PocketSword
//
//  Shared UIKit host for the Bible and commentary tabs during the mixed migration.
//  `ReaderScreen` (SwiftUIReaderChrome.swift) owns the live WebPage/WebView surface
//  AND, as of Wave 7, the whole reading chrome; this controller is now a thin
//  adapter that keeps the coordinator contracts (-displayChapter:, -setTabTitle:,
//  the notification observers, the verse menu, the info-popup routing) and pushes
//  chrome state into a ReaderChromeModel.
//
//  Wave 7 removed from here: the three-segment UISegmentedControl that lived in
//  navigationItem.titleView, the history/search + textformat + microphone
//  UIBarButtonItems, `rebuildSettingsMenu`'s UIMenu construction (now the pure
//  `ReaderDisplayToggle.toggles(forModule:store:)`), and
//  `setVoiceOverForRefSegmentedControlSubviews` (the SwiftUI buttons carry their
//  own permanent accessibility labels, so there is nothing to re-apply). The
//  UIKit navigation bar itself is hidden — SwiftUI's NavigationStack inside the
//  host draws the bar now.
//
//  Created by Nic Carter on 3/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

import UIKit
import SwiftUI
import WebKit

// SWORD passagestudy attribute names are @"literal" #defines in globals.h. Obj-C
// string #defines do NOT import into Swift, so these mirror the literals
// byte-for-byte (same approach as PSModuleController.swift). Wire strings unchanged.
//
// Wave 7 removed the feature-name constants (SWMOD_FEATURE_* / SWMOD_CONF_FEATURE_*,
// plus SWMOD_CATEGORY_BIBLES) from this enum: the display menu they gated moved to
// `ReaderDisplayToggle` in SwiftUIReaderChrome.swift, which carries its own mirrored
// copies. The unused SW_OUTPUT_*_KEY pair went with them. What is left is only what
// the info-popup routing below reads out of `+dataForLink:`.
private enum SWRender {
    // ATTRTYPE_* (globals.h)
    static let attrType = "type"
    static let attrAction = "action"
    static let attrValue = "value"
}

@objc(PSModuleViewController)
class PSModuleViewController: UIViewController, ReaderWebPageModelDelegate {

    // MARK: - State

    private var readerModel: ReaderWebPageModel!
    private var chromeModel: ReaderChromeModel!
    private var readerHostController: UIHostingController<ReaderScreen>!

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
    private var finishedLoading: Bool = false
    @objc var versePositionArray: NSArray?
    private var currentShownVerse: NSInteger = 0
    private var verseToShow: NSInteger = 0
    private var isRestoringAfterTransition = false

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
        self.view = baseView

        let model = ReaderWebPageModel()
        model.delegate = self
        let chrome = ReaderChromeModel()
        chrome.isBibleTab = (tabType == .BibleTab)
        readerModel = model
        chromeModel = chrome

        let host = UIHostingController(
            rootView: ReaderScreen(
                chrome: chrome,
                reader: model,
                makeReferencePicker: { [weak self] in
                    self?.makeReferencePicker()
                        ?? ReferencePickerView(model: ReferencePickerModel())
                }
            )
        )
        // Wave 7: the host fills the controller's view outright. Wave 6 had to cap
        // the frame at the floating tab bar's top because a bare WebView cannot
        // inset itself; `ReaderScreen`'s NavigationStack takes the safe area into
        // account for us, so `readerFrame`'s clamp is gone along with the manual
        // `viewDidLayoutSubviews` pass.
        //
        // Note this only makes the reader stop AT the chrome, not flow under it —
        // the chapter is currently letterboxed rather than edge-to-edge. See the
        // long comment at the top of `ReaderScreen.body` for why that is left to
        // Wave 9 rather than fixed in the WebView.
        host.view.frame = baseView.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .systemBackground
        host.view.clipsToBounds = true
        addChild(host)
        baseView.addSubview(host.view)
        host.didMove(toParent: self)
        readerHostController = host

        configureChromeCallbacks()

        loadHTMLString("<html><body>&nbsp;</body></html>")
        currentShownVerse = 1
    }

    /// Wires the SwiftUI chrome's actions back onto the existing UIKit paths, so
    /// every one of them keeps its current behaviour (history entry, MBProgressHUD
    /// title in focus mode, redisplay notification, ...).
    private func configureChromeCallbacks() {
        chromeModel.onPreviousChapter = { [weak self] in
            self?.prevChapter()
        }
        chromeModel.onNextChapter = { [weak self] in
            self?.nextChapter()
        }
        chromeModel.onHistoryAndSearch = { [weak self] in
            guard let self else { return }
            // Goes through the -FromMenu variant: this action fires from the
            // ToolbarOverflowMenu, which is itself a presentation, so the
            // present must be unanimated to avoid the iOS 27 floating-tab-bar
            // assertion. See PSTabBarControllerDelegate.toggleMultiListFromMenu.
            self.delegate?.toggleMultiListFromMenu()
        }
        chromeModel.onVoiceReference = { [weak self] in
            guard let self else { return }
            self.delegate?.toggleVoiceRef(self)
        }
        chromeModel.onToggleFocus = { [weak self] in
            self?.toggleFullscreen()
        }
        chromeModel.onDisplayToggle = { [weak self] toggle in
            guard let self, let modName = self.settingsMenuModuleName else {
                return
            }
            // Identical to the UIKit UIAction handler this replaces: flip the
            // PER-MODULE pref key ("<pref>_<ModuleName>"), redisplay, and rebuild
            // so the checkmark reflects the new value.
            let current = UserDefaults.standard.psBool(
                toggle.preference,
                forModule: modName
            )
            UserDefaults.standard.psSet(
                !current,
                forPref: toggle.preference,
                module: modName
            )
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(
                name: self.redisplayNotification,
                object: nil
            )
            self.rebuildSettingsMenu()
        }
    }

    /// Builds the SwiftUI reference picker for the popover, preserving the
    /// notification contract the UIKit `PSRefSelectorController` posted:
    /// `toggleNavigation` to close, then `updateSelectedReference` with the
    /// book-name / chapter / verse payload.
    private func makeReferencePicker() -> ReferencePickerView {
        let model = ReferencePickerModel(
            books: (PSBookOSISResolver.shared?.books ?? [])
                .map(ReferencePickerBook.init),
            currentReference: PSModuleController.getCurrentBibleRef(),
            // Same rule the deleted PSRefSelectorController.setupNavigation used:
            // the iPhone presentation adapts to a sheet, which needs an explicit
            // Cancel; an iPad popover is dismissed by tapping outside it.
            showsCancel: !PSResizing.iPad()
        )
        model.onCancel = { [weak self] in
            self?.chromeModel.isPresentingReferencePicker = false
        }
        model.onSelection = { [weak self] selection in
            guard let self else { return }
            self.chromeModel.isPresentingReferencePicker = false
            NotificationCenter.default.post(
                name: .updateSelectedReference,
                object: [
                    AppConstants.bookNameString: selection.bookName,
                    AppConstants.chapterString: String(selection.chapter),
                    AppConstants.verseString: String(selection.verse),
                ]
            )
        }
        return ReferencePickerView(model: model)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        switch tabType {
        case .BibleTab:
            let tbi = UITabBarItem(title: NSLocalizedString("TabBarTitleBible", comment: "Bible"),
                                   image: UIImage(named: "bible.png"), tag: 10)
            tbi.accessibilityIdentifier = "workspace.read.bible"
            self.tabBarItem = tbi
            NotificationCenter.default.addObserver(self, selector: #selector(setModuleNameViaNotification),
                                                   name: .newPrimaryBible, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(prevChapter),
                                                   name: .bibleSwipeRight, object: nil)
        case .CommentaryTab:
            let tbi = UITabBarItem(title: NSLocalizedString("TabBarTitleCommentary", comment: "Commentary"),
                                   image: UIImage(named: "commentary.png"), tag: 10)
            tbi.accessibilityIdentifier = "workspace.read.commentary"
            self.tabBarItem = tbi
            NotificationCenter.default.addObserver(self, selector: #selector(setModuleNameViaNotification),
                                                   name: .newPrimaryCommentary, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(prevChapter),
                                                   name: .commentarySwipeRight, object: nil)
        default:
            break
        }

        // The chrome is drawn by ReaderScreen's own NavigationStack, so the
        // enclosing UIKit navigation bar must go — leaving it visible stacks two
        // bars. The UINavigationController is still the tab's root because the
        // coordinator builds it that way until the Wave 8 cutover.
        navigationController?.setNavigationBarHidden(true, animated: false)

        isFullScreen = false
        NotificationCenter.default.addObserver(self, selector: #selector(redoBookmarkHighlights),
                                               name: .bookmarksChanged, object: nil)
        finishedLoading = false
    }

    // MARK: - Scroll / verse positioning

    @objc(scrollToVerse:)
    func scrollToVerse(_ verseNumber: NSInteger) {
        guard verseNumber > 0 else {
            return
        }
        evaluateJavaScript("scrollToVerse(\(verseNumber));")
        verseToShow = 0
    }

    private func scrollHappened(_ newOffsetY: CGFloat) {
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
        persistReaderPosition(
            verse: verseNumber,
            scrollOffset: newOffsetY
        )
    }

    private func persistReaderPosition(
        verse: NSInteger,
        scrollOffset: CGFloat
    ) {
        currentShownVerse = verse
        // index 0 == verse 1, so we need to add one and then subtract 1, so the resulting verse is the number.
        // our method of updating the title bar & remembering our position.
        let verseString = String(format: "%d", Int32(verse))
        if tabType == .BibleTab {
            UserDefaults.standard.set(
                String(format: "%d", Int32(scrollOffset)),
                forKey: "bibleScrollPosition"
            )
            UserDefaults.standard.set(verseString, forKey: Defaults.bibleVersePosition)
        } else {
            UserDefaults.standard.set(
                String(format: "%d", Int32(scrollOffset)),
                forKey: "commentaryScrollPosition"
            )
            UserDefaults.standard.set(verseString, forKey: Defaults.commentaryVersePosition)
        }
        let ref = NSMutableString(string: PSModuleController.getCurrentBibleRef())
        ref.appendFormat(":%@", verseString)
        setTabTitle(PSModuleController.createRefString(ref as String))
    }

    private func saveVersePositionArray(_ positions: [CGFloat]) {
        guard !positions.isEmpty else {
            return
        }
        versePositionArray = positions.map {
            NSNumber(value: Double($0))
        } as NSArray
        if verseToShow > 0 {
            scrollToVerse(verseToShow)
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
        chromeModel?.isNextEnabled = enabled
    }

    @objc(setEnabledPreviousButton:)
    func setEnabledPreviousButton(_ enabled: Bool) {
        chromeModel?.isPreviousEnabled = enabled
    }

    @objc(setTabTitle:)
    func setTabTitle(_ title: String?) {
        // +createTitleRefString: is still what shortens the displayed reference
        // (the "1 Cor"/"1. Cor" leading-number handling and the 3-char book mask);
        // only the control it lands in changed. The un-munged form becomes the
        // accessibility label, which is what the old
        // -setVoiceOverForRefSegmentedControlSubviews: applied to the title
        // segment on every title change.
        chromeModel?.title = PSModuleController.createTitleRefString(title) ?? ""
        chromeModel?.accessibilityReference =
            PSModuleController.getCurrentBibleRef() ?? ""
    }

    @objc(setModuleNameViaNotification)
    func setModuleNameViaNotification() {
        autoreleasepool {
            rebuildSettingsMenu()
            if tabType != .BibleTab && PSModuleController.default().primaryCommentaryName == nil {
                // The real empty-state path: no commentary installed, so there is
                // nothing to page through.
                chromeModel?.title = "PocketSword"
                chromeModel?.accessibilityReference = "PocketSword"
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

    /// Rebuilds the per-tab display toggles from the active module's advertised
    /// features and refreshes their current values.
    ///
    /// The gating rule, the row order and the per-module `"<pref>_<ModuleName>"` key
    /// format all moved verbatim into the pure
    /// `ReaderDisplayToggle.toggles(forModule:store:)`, which is where the KJV-six /
    /// MHCC-zero contract is now documented and asserted. This method is just the
    /// push into the observable chrome; an empty result hides the control, which is
    /// the same outcome as the old `setSettingsMenu(nil)`.
    @objc(rebuildSettingsMenu)
    func rebuildSettingsMenu() {
        chromeModel?.reloadDisplayToggles(forModule: settingsMenuModuleName)
    }

    @objc(setDelegate:)
    func setDelegate(_ vc: PSTabBarControllerDelegate?) {
        // Wave 7: the history/search, display-settings and microphone
        // UIBarButtonItems are gone. Their actions are `ToolbarOverflowMenu`
        // buttons in ReaderScreen, wired through `configureChromeCallbacks`, so
        // the only thing left to do here is take the back-reference and prime the
        // chrome's state.
        delegate = vc
        rebuildSettingsMenu()

        if tabType == .BibleTab {
            if PSFeatureFlags.voiceReferenceEnabled {
                Task { [weak self] in
                    if case .available = await PSVoiceRefSession.availability() {
                        self?.chromeModel?.isVoiceAvailable = true
                    }
                }
            }
        } else {
            setModuleNameViaNotification()
        }
    }

    @objc(setVerseToShow:)
    func setVerseToShow(_ verseNumber: NSInteger) {
        verseToShow = verseNumber
    }

    /// Opens or closes the reference picker.
    ///
    /// Wave 7 moved the picker into a popover anchored on the SwiftUI reference
    /// button, so it is presented by `ReaderScreen` rather than by the coordinator.
    /// This is the seam the coordinator's `-toggleNavigation` (and the
    /// `NotificationToggleNavigation` observers behind it) now drives.
    @objc(toggleReferencePicker)
    func toggleReferencePicker() {
        guard let chromeModel else { return }
        chromeModel.isPresentingReferencePicker.toggle()
    }

    /// Whether this reader currently has the picker up — the coordinator uses this
    /// to decide whether a `toggleNavigation` should close rather than open.
    var isPresentingReferencePicker: Bool {
        chromeModel?.isPresentingReferencePicker ?? false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The enclosing UIKit navigation bar stays hidden for the reading tabs —
        // ReaderScreen's NavigationStack draws the bar. Re-asserted here because
        // returning from a pushed More-tab controller can restore it.
        navigationController?.setNavigationBarHidden(true, animated: false)

        if let refToShow = refToShow {
            let webText: String?
            if tabType == .BibleTab {
                webText = PSModuleController.default().getBibleChapter(refToShow, withExtraJS: String(format: "%@\nstartDetLocPoll();\n", jsToShow ?? ""))
            } else {
                webText = PSModuleController.default().getCommentaryChapter(refToShow, withExtraJS: String(format: "%@\nstartDetLocPoll();\n", jsToShow ?? ""))
            }
            loadHTMLString(webText ?? "")
            self.refToShow = nil
            self.jsToShow = nil
        } else if let jsToShow = jsToShow {
            let jsString = String(format: "%@; startDetLocPoll();", jsToShow)
            evaluateJavaScript(jsString)
            self.jsToShow = nil
        } else if verseToShow > 0 {
            scrollToVerse(verseToShow)
        } else if finishedLoading {
            evaluateJavaScript("startDetLocPoll();")
        }
        if finishedLoading {
            scrollHappened(readerModel.lastScrollOffset)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let verseToRestore = max(1, currentShownVerse)
        isRestoringAfterTransition = true
        evaluateJavaScript("stopDetLocPoll();")
        coordinator.animate(alongsideTransition: nil) { _ in
            NotificationCenter.default.post(name: .rotateInfoPane, object: nil)
            let js = """
                resetArrays();
                scrollToVerse(\(verseToRestore));
                startDetLocPoll();
                return window.pageYOffset;
                """
            self.evaluateJavaScript(js) { [weak self] result in
                guard let self else {
                    return
                }
                let restoredOffset = (result as? NSNumber)
                    .map { CGFloat($0.doubleValue) }
                    ?? self.readerModel.lastScrollOffset
                self.persistReaderPosition(
                    verse: verseToRestore,
                    scrollOffset: restoredOffset
                )
                self.isRestoringAfterTransition = false
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        evaluateJavaScript("stopDetLocPoll();")
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

    /// Focus mode: hide the tab bar and the navigation bar so only the chapter
    /// remains.
    ///
    /// Wave 7 rewrote this. It used to REPARENT `readerHostController.view` into
    /// `tabBarController.view`, stash the old `tabBarController.view` in
    /// `previousTabBarView`, and on exit ASSIGN `tabBarController.view =
    /// previousTabBarView` — i.e. it swapped a view controller's root view out from
    /// under it and animated `tabBar.alpha` by hand. On iOS 27 the floating tab bar
    /// is not a plain subview whose alpha can be faded, and forcing its layout
    /// inside an animation block is exactly the shape that trips the
    /// `_UITabBarVisualProvider_FloatingAccessibility` AnimationKit assertion
    /// documented in `startStrongsSearch`.
    ///
    /// `setTabBarHidden(_:animated:)` (iOS 18+) is the supported way to do this: the
    /// tab bar controller keeps its own view, animates itself, and republishes the
    /// safe area so the SwiftUI reader re-insets on its own. The navigation bar is
    /// hidden by `ReaderScreen`'s `toolbarVisibility`, driven off the same
    /// `isFocused` flag, and the status bar follows `prefersStatusBarHidden`.
    @objc(toggleFullscreen)
    func toggleFullscreen() {
        evaluateJavaScript("stopDetLocPoll();")
        isFullScreen = !isFullScreen
        chromeModel?.isFocused = isFullScreen

        setNeedsStatusBarAppearanceUpdate()
        tabBarController?.setTabBarHidden(isFullScreen, animated: true)

        evaluateJavaScript("startDetLocPoll();")
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
                evaluateJavaScript(jsCode)
            }
            for case let bookmark as PSBookmark in shownBookmarks {
                if let rgbHexString = bookmark.rgbHexString, let bref = bookmark.ref {
                    let parts = bref.components(separatedBy: ":")
                    if parts.count > 1 {
                        let verse = parts[1]
                        let jsFunction = String(format: "PS_HighlightVerseWithHexColour('%@','%@')", verse,
                                                PSBookmarkFolder.rgbString(fromHexString: rgbHexString))
                        evaluateJavaScript(jsFunction)
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
        evaluateJavaScript(jsFunction)
    }

    @objc(redoBookmarkHighlights)
    func redoBookmarkHighlights() {
        removeBookmarkHighlights()
        highlightBookmarks()
    }

    // MARK: - SwiftUI WebKit

    func isReaderVisible(in container: UIView) -> Bool {
        isViewLoaded && view.isDescendant(of: container)
    }

    func loadHTMLString(_ html: String) {
        readerModel.loadHTMLString(
            html,
            baseURL: URL(
                fileURLWithPath: Bundle.main.resourcePath ?? ""
            )
        )
    }

    func evaluateJavaScript(
        _ script: String,
        completion: ((Any?) -> Void)? = nil
    ) {
        readerModel.evaluateJavaScript(
            script,
            completion: completion
        )
    }

    func highlightAllOccurrences(of term: String) {
        readerModel.highlightAllOccurrences(of: term)
    }

    func readerWebPageModel(
        _ model: ReaderWebPageModel,
        didScrollTo offset: CGFloat
    ) {
        guard !isRestoringAfterTransition else {
            return
        }
        scrollHappened(offset)
    }

    func readerWebPageModelDidStartNavigation(_ model: ReaderWebPageModel) {
        finishedLoading = false
    }

    func readerWebPageModelDidFinishNavigation(_ model: ReaderWebPageModel) {
        finishedLoading = true
        if verseToShow > 0 {
            scrollToVerse(verseToShow)
        } else {
            scrollHappened(model.lastScrollOffset)
        }
    }

    func readerWebPageModelDidEndUserScroll(_ model: ReaderWebPageModel) {
        if UserDefaults.standard.bool(
            forKey: Defaults.fullscreenModePreference
        ) {
            switchToFullscreen()
        }
    }

    func readerWebPageModel(
        _ model: ReaderWebPageModel,
        decidePolicyFor request: URLRequest
    ) -> WKNavigationActionPolicy {
        navigationPolicy(for: request)
    }

    private func navigationPolicy(
        for request: URLRequest
    ) -> WKNavigationActionPolicy {
        autoreleasepool {
            let requestString = request.url?.absoluteString ?? ""

            if let url = request.url, let event = ReaderBridgeEvent(url: url) {
                switch event {
                case .currentVerse(let verse, let scrollPosition):
                    if !isRestoringAfterTransition {
                        persistReaderPosition(
                            verse: verse,
                            scrollOffset: scrollPosition
                        )
                        UserDefaults.standard.synchronize()
                    }
                case .verseMenu(let verse):
                    if tabType == .BibleTab {
                        presentVerseMenu(verse: verse)
                    }
                case .versePositions(let positions):
                    saveVersePositionArray(positions)
                }
                return .cancel
            }

            if request.url?.scheme == "sword" {
                // our internal reference to say this is a Bible verse to display in the Bible tab
                // This should only happen in the commentary tab & we allow it to "load" normally.
                dlog("\nCOMMENTARY: requestString: \(requestString)")
                return .allow
            }

            guard let url = request.url else {
                return .allow
            }
            let rData = PSModuleController.data(forLink: url)
            var entry: String?
            var popupContent: PSInfoPopupContent?

            if let rData,
               (rData[SWRender.attrAction] as? String) == "showStrongs" {
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
                let rawEntry = hasDefinition ? entry : nil
                if entry == nil {
                    if hebrew {
                        entry = NSLocalizedString(
                            "NoHebrewStrongsNumbersModuleInstalled",
                            comment: ""
                        )
                    } else {
                        entry = NSLocalizedString(
                            "NoGreekStrongsNumbersModuleInstalled",
                            comment: ""
                        )
                    }
                }

                entry = PSModuleController.createStrongsInfoHTMLString(
                    entry,
                    usingModuleForPreferences: mod
                )
                if let entry {
                    popupContent = PSInfoPopupContent(
                        strongsHTML: entry,
                        rawEntry: rawEntry,
                        reference: strongsReference,
                        allowsSearch: hasDefinition && tabType == .BibleTab
                    )
                }
            } else if let rData,
                      (rData[SWRender.attrAction] as? String) == "showMorph" {
                let mod = BundledModules.morphGreek
                if (rData[SWRender.attrType] as? String)?
                    .hasPrefix("strongMorph") == true {
                    entry = NSLocalizedString(
                        "MorphHebrewNotSupported",
                        comment: ""
                    )
                } else {
                    entry = PSContentReader.entry(
                        module: mod,
                        key: rData[SWRender.attrValue] as? String
                    )
                    if entry == nil {
                        entry = NSLocalizedString(
                            "NoMorphGreekModuleInstalled",
                            comment: ""
                        )
                    }
                }
                entry = PSModuleController.createInfoHTMLString(
                    entry,
                    usingModuleForPreferences: mod
                )
            } else if let rData,
                      (rData[SWRender.attrAction] as? String) == "showNote",
                      (rData[SWRender.attrType] as? String) == "n" {
                let mod = (tabType == .BibleTab)
                    ? PSModuleController.default().primaryBibleName
                    : PSModuleController.default().primaryCommentaryName
                entry = PSContentReader.footnoteBody(
                    module: mod,
                    data: rData
                )
                entry = entry?.replacingOccurrences(of: "*x", with: "x")
                entry = entry?.replacingOccurrences(of: "*n", with: "n")
                entry = PSModuleController.createInfoHTMLString(
                    entry,
                    usingModuleForPreferences: mod
                )
            }

            if let popupContent {
                NotificationCenter.default.post(
                    name: .showInfoPane,
                    object: popupContent
                )
                return .cancel
            }
            if let entry {
                NotificationCenter.default.post(
                    name: .showInfoPane,
                    object: entry
                )
                return .cancel
            }
            return .allow
        }
    }

    private func presentVerseMenu(verse: Int) {
        tappedVerse = "\(verse)"
        let sheetTitle = String(
            format: NSLocalizedString(
                "RefSelectorVerseTitle",
                comment: ""
            ),
            verse
        )
        let actionSheet = UIAlertController(
            title: sheetTitle,
            message: nil,
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(
            UIAlertAction(
                title: NSLocalizedString(
                    "VerseContextualMenuAddBookmark",
                    comment: ""
                ),
                style: .default
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                let ref = PSModuleController.createRefString(
                    PSModuleController.getCurrentBibleRef()
                )
                let controller = PSBookmarksAddTableViewController(
                    bookAndChapterRef: ref,
                    andVerse: tappedVerse
                )
                present(
                    UINavigationController(rootViewController: controller),
                    animated: true
                )
                tappedVerse = nil
            }
        )
        actionSheet.addAction(
            UIAlertAction(
                title: NSLocalizedString(
                    "VerseContextualMenuCommentary",
                    comment: ""
                ),
                style: .default
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                let commentary = (self as? PSBibleViewController)?
                    .commentaryView
                commentary?.setVerseToShow(verse)
                let wasFullScreen = isFullScreen
                if wasFullScreen {
                    toggleFullscreen()
                    commentary?.viewWillAppear(true)
                }
                NotificationCenter.default.post(
                    name: .showCommentaryTab,
                    object: nil
                )
                if wasFullScreen {
                    commentary?.toggleFullscreen()
                }
                tappedVerse = nil
            }
        )
        actionSheet.addAction(
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: ""),
                style: .cancel
            )
        )
        present(actionSheet, animated: true)
    }

    // -setVoiceOverForRefSegmentedControlSubviews: is GONE (Wave 7). It existed
    // because -setTitle:forSegmentAt: rebuilt a UISegmentedControl's subviews and
    // dropped their accessibility labels, so every title change had to walk the
    // subviews and re-derive each one from its image filename. The SwiftUI buttons
    // in ReaderReferenceControl carry permanent .accessibilityLabel modifiers, and
    // the reference button's label is bound to the chrome model, so there is
    // nothing to re-apply.
}
