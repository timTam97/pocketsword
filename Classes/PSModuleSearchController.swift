//
//  PSModuleSearchController.swift
//  PocketSword
//
//  Redesigned search screen: UISearchController in the nav bar (live,
//  debounced results), a UIMenu options button for Match / Fuzzy / Strong's,
//  standard scope bar (All / OT / NT / Book), and FTS5-highlighted result
//  snippets. Replaces the 2009-era drill-down options table.
//
//  Migrated from PSModuleSearchController.{h,mm} (Swift migration Wave 3). The
//  former .mm contained ZERO sword:: usage — it drove PSSearchEngine through its
//  clean Foundation-only facade, and the Swift PSSearchQuery / PSSearchResult /
//  PSSearchHistoryItem value types directly (same module). As of
//  SWORD_REMOVAL_PLAN.md Phase 5 step 8 the engine is Swift too, so every type on
//  this screen's path is. The @objc PSModuleSearchControllerDelegate protocol is
//  kept because PSTabBarControllerDelegate conforms to it via @objc dispatch.
//
//  ── Search-crash fix carried forward (risk R13) ───────────────────────────
//  The original Obj-C runSearchWithExpression: read self.searchRange /
//  self.bookName INSIDE the background dispatch block, and the main-queue
//  completion read self.* again. Each keystroke re-fires after the debounce, so
//  concurrent completions raced on the nonatomic-strong props (EXC_BAD_ACCESS in
//  objc_retain). The Swift port closes that window:
//    (a) SNAPSHOT every query input on the MAIN thread BEFORE dispatching —
//        searchRange, a COPY of bookName, the strongsTokens, the expression, and
//        the active module — into immutable `let`s. The background closure reads
//        ONLY those captured locals, never self.<mutableProp>.
//    (b) A `queryGeneration` counter is bumped on the main thread at dispatch
//        time and the value captured; the main-queue completion BAILS OUT if the
//        captured generation != the current queryGeneration, so a stale
//        completion can never overwrite newer results or fire
//        notifyDelegateOfNewHistoryItem with stale state.
//    (c) The existing 0.25s debounce is kept (complementary, not a replacement).
//

import UIKit

@objc(PSModuleSearchControllerDelegate)
protocol PSModuleSearchControllerDelegate: NSObjectProtocol {
    @objc func searchDidFinish(_ newSearchHistoryItem: PSSearchHistoryItem?)
}

@objc(PSModuleSearchController)
final class PSModuleSearchController: UIViewController,
    UITabBarControllerDelegate,
    UISearchBarDelegate,
    UISearchResultsUpdating,
    UITableViewDelegate,
    UITableViewDataSource,
    PSSearchIndexBuilderDelegate {

    private static let kDebounceInterval: TimeInterval = 0.25
    private static let kResultCellIdentifier = "resultsCell"

    // The two "Strongs" feature config keys live in SwordManager.h as @"literal"
    // #defines (SWMOD_FEATURE_STRONGS / SWMOD_CONF_FEATURE_STRONGS). Swift cannot
    // reliably import @"…" NSString-literal macros, so mirror the wire values
    // here byte-for-byte (these are SWORD config keys; do not "fix").
    private static let featureStrongs = "Strongs"           // SWMOD_FEATURE_STRONGS
    private static let confFeatureStrongs = "StrongsNumbers" // SWMOD_CONF_FEATURE_STRONGS

    // MARK: - Public surface (matches former Obj-C @property / method surface)

    @objc weak var delegate: PSModuleSearchControllerDelegate?
    @objc var searchTerm: String?
    @objc var searchTermToDisplay: String?
    @objc var strongsSearch: Bool = false
    @objc var fuzzySearch: Bool = false
    @objc var searchType: PSSearchType = .AndSearch
    @objc var searchRange: PSSearchRange = .AllRange
    @objc var bookName: String?
    @objc var results: NSMutableArray?
    @objc var savedTablePosition: NSArray?

    // MARK: - Private state (was the .mm class-extension ivars/props)

    private var listType_: ShownTab = .BibleTab
    private var switchingTabs = false
    private var searchingEnabled = false

    private var searchController: UISearchController!
    private var resultsTable: UITableView!
    private var scopeControl: UISegmentedControl!
    private var optionsBarButton: UIBarButtonItem!
    private var debounceTimer: Timer?
    private var strongsAvailable = false

    /// Index-aligned with `results`: each entry is the list of English words to
    /// highlight in that row for a Strong's search. Empty array for rows with no
    /// mapped words; nil for non-Strong's searches.
    private var strongsHighlightPerResult: [[String]]?

    /// Bumped on the MAIN thread at every search dispatch. A background
    /// completion only applies its results if it still holds the latest value.
    private var queryGeneration: UInt = 0

    // MARK: - Init

    @objc(initWithSearchHistoryItem:)
    convenience init(searchHistoryItem: PSSearchHistoryItem?) {
        self.init()
        setSearchHistoryItem(searchHistoryItem)
    }

    @objc init() {
        super.init(nibName: nil, bundle: nil)
        let tBI = UITabBarItem(tabBarSystemItem: .search, tag: 0)
        self.tabBarItem = tBI
        switchingTabs = true
        searchTerm = nil
        searchTermToDisplay = nil
        results = nil
        bookName = nil
        strongsSearch = false
        savedTablePosition = nil
        navigationItem.title = NSLocalizedString("SearchTitle", comment: "")
        setSearchTitle()

        let defaults = UserDefaults.standard
        fuzzySearch = defaults.bool(forKey: Defaults.lastSearchFuzzy)
        searchType = PSSearchType(rawValue: defaults.integer(forKey: Defaults.lastSearchType)) ?? .AndSearch
        searchRange = PSSearchRange(rawValue: defaults.integer(forKey: Defaults.lastSearchRange)) ?? .AllRange
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycle

    override func loadView() {
        let root = UIView(frame: PSResizing.mainScreenBounds())
        root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.backgroundColor = .systemBackground

        let table = UITableView(frame: root.bounds, style: .plain)
        table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        table.delegate = self
        table.dataSource = self
        table.keyboardDismissMode = .onDrag
        root.addSubview(table)
        resultsTable = table

        // Scope bar as a persistent table header — iOS 26 hides the UISearchBar's
        // built-in scope chips when the search field activates even with manual
        // scopeBarActivation, so we own the UI ourselves.
        let seg = UISegmentedControl(items: [
            NSLocalizedString("SearchScopeAll", comment: "All"),
            NSLocalizedString("SearchRangeOTRowShort", comment: "OT"),
            NSLocalizedString("SearchRangeNTRowShort", comment: "NT"),
            NSLocalizedString("SearchScopeBook", comment: "Book"),
        ])
        seg.addTarget(self, action: #selector(scopeControlChanged(_:)), for: .valueChanged)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: table.bounds.size.width, height: 44))
        header.autoresizingMask = .flexibleWidth
        seg.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(seg)
        NSLayoutConstraint.activate([
            seg.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            seg.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
            seg.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        table.tableHeaderView = header
        scopeControl = seg

        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = true

        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = NSLocalizedString("SearchTitle", comment: "")
        searchController.obscuresBackgroundDuringPresentation = false
        // Keep the nav bar (and its options button) visible while the search bar
        // is active. Without this iOS hides the whole nav bar as soon as the user
        // taps the field, taking the options menu with it.
        searchController.hidesNavigationBarDuringPresentation = false

        scopeControl.selectedSegmentIndex = scopeIndex(for: searchRange)

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        // iOS 16+: keep the search bar stacked under the nav bar title so the
        // options button stays reachable. Without this, iOS 26 defaults to a
        // floating/bottom search dock that hides the nav bar chrome when active.
        if #available(iOS 16.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("CloseButtonTitle", comment: "Close"),
            style: .plain,
            target: self,
            action: #selector(closeButtonPressed))

        optionsBarButton = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain,
            target: nil,
            action: nil)
        navigationItem.rightBarButtonItem = optionsBarButton
        rebuildOptionsMenu()
    }

    // ── The scope bar's 16pt-too-high bug ────────────────────────────────────
    //
    // This screen is presented inside a sheet (see -toggleMultiList). While the
    // sheet settles, UIKit moves the navigation bar down by 16pt *within* the
    // navigation controller's view (frame.origin.y 0 → 16) — but it does not mark
    // that view as needing layout, so our safeAreaInsets.top is never
    // re-propagated. It stays at the pre-shift 108pt while the bar actually ends
    // at 124pt, and the table's adjustedContentInset.top stays 108 with it. The
    // scope bar lives in the table header, so it lands 16pt too high — tucked
    // under the search field, which is what the user sees.
    //
    // Any later layout pass flushes the correct value, which is why dragging the
    // sheet a little and releasing "fixes" it: measured navSuperFrame y=16 with
    // safeTop still 108, then 124 the moment a layout pass ran.
    //
    // So re-assert it once, from `viewDidAppear`, whenever the two genuinely
    // disagree. Three things about the shape here are deliberate:
    //
    //  * The guard IS the correctness condition — our top safe area must reach the
    //    bar's bottom edge — not a delay or a hardcoded 16. If UIKit stops
    //    shifting the bar, or shifts it by something else, this keeps working and
    //    costs nothing when the values already agree.
    //  * `setNeedsLayout` is required, not just `layoutIfNeeded`: the shift happens
    //    without dirtying the view, so `layoutIfNeeded` alone is a no-op (measured).
    //  * `viewDidAppear` is the trigger, NOT `viewDidLayoutSubviews`. Our own
    //    layout callback never fires at the moment of disagreement (the shift skips
    //    layout entirely), and dirtying an ancestor from inside a layout pass risks
    //    an unbounded layout loop if a disagreement is ever unresolvable. Later
    //    causes — a detent drag, rotation — already run a real layout pass of their
    //    own, which is precisely why dragging the sheet fixed it by hand.
    private func reassertSafeAreaAgainstNavigationBar() {
        guard let navView = navigationController?.view,
              let navBar = navigationController?.navigationBar,
              navBar.superview != nil else { return }

        let barBottomInView = navBar.convert(CGPoint(x: 0, y: navBar.bounds.maxY), to: view).y
        guard abs(barBottomInView - view.safeAreaInsets.top) > 0.5 else { return }

        navView.setNeedsLayout()
        navView.layoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reassertSafeAreaAgainstNavigationBar()

        if let name = activeModuleName(),
           !PSSearchEngine.engine(forModuleName: name).indexIsFresh() {
            offerToBuildIndex(forModuleName: name)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let term = searchTermToDisplay {
            searchController.searchBar.text = term
        }

        // Decide searchingEnabled before the first draw so the table header
        // doesn't flash "No search index" for a module that already has one.
        searchingEnabled = activeEngine()?.indexIsFresh() ?? false

        refreshView()

        if let term = searchTerm {
            // Coming back from history: the term is already FTS5-ready.
            runSearch(withExpression: term)
            searchTerm = nil
        }
        setSearchTitle()
    }

    // MARK: - Active module helper

    /// The module this list searches, as a **name**.
    ///
    /// SWORD_REMOVAL_PLAN.md Phase 5 step 5: this returned a `SwordModule`, and all
    /// of its callers only ever needed the name — to key the search engine, to ask
    /// about a feature, or to look a verse up. Returning the name is what lets those
    /// three go through the baked store and the name-keyed engine instead.
    private func activeModuleName() -> String? {
        switch listType_ {
        case .BibleTab:
            return PSModuleController.default().primaryBibleName
        case .CommentaryTab:
            return PSModuleController.default().primaryCommentaryName
        default:
            return nil
        }
    }

    /// Whether the active module carries Strong's numbers, from the baked feature
    /// set (`content_meta`) rather than a live `-hasFeature:`.
    ///
    /// Both spellings are still checked, exactly as before: `Strongs` is the
    /// GlobalOptionFilter form and `StrongsNumbers` the `Feature=` form, and KJV
    /// answers YES to both.
    private func strongsFeatureAvailable() -> Bool {
        guard let name = activeModuleName(), let store = PSContentStore.shared else { return false }
        return store.moduleHasFeature(name, PSModuleSearchController.featureStrongs)
            || store.moduleHasFeature(name, PSModuleSearchController.confFeatureStrongs)
    }

    /// The search engine for the active module, or nil if there is no active module.
    private func activeEngine() -> PSSearchEngine? {
        guard let name = activeModuleName() else { return nil }
        return PSSearchEngine.engine(forModuleName: name)
    }

    // MARK: - History item

    @objc func setSearchHistoryItem(_ searchHistoryItem: PSSearchHistoryItem?) {
        guard let searchHistoryItem = searchHistoryItem else { return }

        // Strip any legacy CLucene-era operators (lemma:, &&, ||) from the
        // display term — old history entries stored those raw.
        let displayTerm = searchHistoryItem.cleanedDisplayTerm()
        searchTermToDisplay = displayTerm
        searchType = searchHistoryItem.searchType
        searchRange = searchHistoryItem.searchRange
        fuzzySearch = searchHistoryItem.fuzzySearch
        results = searchHistoryItem.results
        bookName = searchHistoryItem.bookName
        savedTablePosition = searchHistoryItem.savedTablePosition

        // Only restore Strong's mode if the current Bible still supports it.
        if searchHistoryItem.strongsSearch && strongsFeatureAvailable() {
            strongsSearch = true
        } else {
            strongsSearch = false
        }

        // Build a fresh FTS5 expression from the cleaned display term so the
        // history replay goes through the new engine.
        searchTerm = PSSearchQuery.fts5Expression(fromUserInput: displayTerm,
                                                   matchType: searchType,
                                                   fuzzy: fuzzySearch,
                                                   strongs: strongsSearch)
        scopeControl?.selectedSegmentIndex = scopeIndex(for: searchRange)
        setSearchTitle()
    }

    // MARK: - Tab type

    @objc func setListType(_ listT: ShownTab) {
        listType_ = listT
    }

    @objc func listType() -> ShownTab {
        return listType_
    }

    // MARK: - Titles

    @objc func setSearchTitle() {
        var newTitle = NSLocalizedString("SearchTitle", comment: "")
        if results != nil, searchTermToDisplay != nil {
            newTitle = searchTermToDisplay!
        } else if strongsSearch {
            newTitle = NSLocalizedString("SearchStrongsTitle", comment: "")
        }
        navigationItem.title = newTitle
    }

    @objc func closeButtonPressed() {
        notifyDelegateOfNewHistoryItem()
        NotificationCenter.default.post(name: .toggleMultiList, object: nil)
    }

    // MARK: - Tab bar delegate

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if tabBarController.selectedViewController?.title == NSLocalizedString("SearchTitle", comment: "") {
            switchingTabs = false
        } else {
            switchingTabs = true
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if viewController.title == NSLocalizedString("SearchTitle", comment: "") {
            if !switchingTabs {
                searchButtonPressed(nil)
            }
            UserDefaults.standard.set(ShownMultiListTab.SearchTab.rawValue, forKey: Defaults.lastMultiListTab)
        } else {
            UserDefaults.standard.set(ShownMultiListTab.HistoryTab.rawValue, forKey: Defaults.lastMultiListTab)
        }
    }

    // MARK: - Index-missing prompt

    private func offerToBuildIndex(forModuleName moduleName: String) {
        searchingEnabled = false
        refreshView()

        let alert = UIAlertController(
            title: NSLocalizedString("NoSearchIndexTitle", comment: "No Search Index"),
            message: NSLocalizedString("NoSearchIndexMsg", comment: "No search index is installed for this module, build one?"),
            preferredStyle: .alert)

        alert.addAction(UIAlertAction(
            title: NSLocalizedString("No", comment: "No"),
            style: .cancel,
            handler: { [weak self] _ in self?.refreshView() }))

        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Yes", comment: "Yes"),
            style: .default,
            handler: { [weak self] _ in
                guard let self = self else { return }
                let b = PSSearchIndexBuilder(moduleName: moduleName)
                b.delegate = self
                b.present(from: self)
            }))
        present(alert, animated: true, completion: nil)
    }

    func indexBuilder(_ builder: PSSearchIndexBuilder, didFinishWithSuccess success: Bool, cancelled: Bool) {
        searchingEnabled = success
        refreshView()
        if success, (searchController.searchBar.text?.count ?? 0) > 0 {
            scheduleDebouncedSearch()
        }
    }

    // MARK: - Options menu

    private func rebuildOptionsMenu() {
        strongsAvailable = strongsFeatureAvailable()

        let matchAll = UIAction(
            title: NSLocalizedString("SearchTypeAllRow", comment: "All"),
            image: nil,
            identifier: UIAction.Identifier("match.all"),
            handler: { [weak self] _ in
                self?.searchType = .AndSearch
                self?.persistOptionsAndResearch()
            })
        let matchAny = UIAction(
            title: NSLocalizedString("SearchTypeAnyRow", comment: "Any"),
            image: nil,
            identifier: UIAction.Identifier("match.any"),
            handler: { [weak self] _ in
                self?.searchType = .OrSearch
                self?.persistOptionsAndResearch()
            })
        let matchExact = UIAction(
            title: NSLocalizedString("SearchTypeExactRow", comment: "Exact"),
            image: nil,
            identifier: UIAction.Identifier("match.exact"),
            handler: { [weak self] _ in
                self?.searchType = .ExactSearch
                self?.persistOptionsAndResearch()
            })
        switch searchType {
        case .AndSearch:   matchAll.state = .on
        case .OrSearch:    matchAny.state = .on
        case .ExactSearch: matchExact.state = .on
        @unknown default:  break
        }
        let matchMenu = UIMenu(
            title: NSLocalizedString("SearchTypeSectionHeader", comment: "Match"),
            image: nil,
            identifier: UIMenu.Identifier("match"),
            options: [.displayInline, .singleSelection],
            children: [matchAll, matchAny, matchExact])

        let fuzzyToggle = UIAction(
            title: NSLocalizedString("SearchFuzzyRow", comment: "Fuzzy"),
            image: nil,
            identifier: UIAction.Identifier("fuzzy"),
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.fuzzySearch = !self.fuzzySearch
                self.persistOptionsAndResearch()
            })
        fuzzyToggle.state = fuzzySearch ? .on : .off
        let fuzzyMenu = UIMenu(
            title: "",
            image: nil,
            identifier: UIMenu.Identifier("fuzzyGroup"),
            options: .displayInline,
            children: [fuzzyToggle])

        var topLevel: [UIMenuElement] = [matchMenu, fuzzyMenu]

        if strongsAvailable {
            let strongsToggle = UIAction(
                title: NSLocalizedString("SearchStrongsRow", comment: "Strong's"),
                image: nil,
                identifier: UIAction.Identifier("strongs"),
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.strongsSearch = !self.strongsSearch
                    self.persistOptionsAndResearch()
                })
            strongsToggle.state = strongsSearch ? .on : .off
            let strongsMenu = UIMenu(
                title: "",
                image: nil,
                identifier: UIMenu.Identifier("strongsGroup"),
                options: .displayInline,
                children: [strongsToggle])
            topLevel.append(strongsMenu)
        }

        optionsBarButton.menu = UIMenu(title: "", children: topLevel)
    }

    private func persistOptionsAndResearch() {
        let defaults = UserDefaults.standard
        defaults.set(fuzzySearch, forKey: Defaults.lastSearchFuzzy)
        defaults.set(searchType.rawValue, forKey: Defaults.lastSearchType)
        defaults.set(searchRange.rawValue, forKey: Defaults.lastSearchRange)
        rebuildOptionsMenu()
        scheduleDebouncedSearch()
    }

    // MARK: - Scope bar

    private func scopeIndex(for range: PSSearchRange) -> Int {
        switch range {
        case .AllRange:  return 0
        case .OTRange:   return 1
        case .NTRange:   return 2
        case .BookRange: return 3
        @unknown default: return 0
        }
    }

    private func range(forScopeIndex idx: Int) -> PSSearchRange {
        switch idx {
        case 1: return .OTRange
        case 2: return .NTRange
        case 3: return .BookRange
        default: return .AllRange
        }
    }

    @objc private func scopeControlChanged(_ seg: UISegmentedControl) {
        searchRange = range(forScopeIndex: seg.selectedSegmentIndex)
        if searchRange == .BookRange {
            var currentBook = PSModuleController.getCurrentBibleRef() ?? ""
            if let lastSpace = currentBook.range(of: " ", options: .backwards) {
                currentBook = String(currentBook[..<lastSpace.lowerBound])
            }
            bookName = currentBook
        } else {
            bookName = nil
        }
        UserDefaults.standard.set(searchRange.rawValue, forKey: Defaults.lastSearchRange)
        scheduleDebouncedSearch()
    }

    // MARK: - Debounced search

    func updateSearchResults(for searchController: UISearchController) {
        searchTermToDisplay = searchController.searchBar.text
        scheduleDebouncedSearch()
    }

    private func scheduleDebouncedSearch() {
        debounceTimer?.invalidate()
        if !searchingEnabled { return }

        let text = searchController.searchBar.text
        if (text?.count ?? 0) == 0 {
            results = nil
            strongsHighlightPerResult = nil
            searchTerm = nil
            resultsTable.reloadData()
            setSearchTitle()
            return
        }

        debounceTimer = Timer.scheduledTimer(
            timeInterval: PSModuleSearchController.kDebounceInterval,
            target: self,
            selector: #selector(debounceFired(_:)),
            userInfo: nil,
            repeats: false)
    }

    @objc private func debounceFired(_ t: Timer) {
        runSearchForCurrentText()
    }

    private func runSearchForCurrentText() {
        let raw = searchController.searchBar.text ?? ""
        searchTermToDisplay = raw

        // Strong's mode is sticky — it gets restored from the saved history item
        // after a "Find all occurrences" popup even if the user then types a plain
        // word. Auto-disable when the current text contains no Strong's-shaped
        // tokens; otherwise plain queries hit the lemmas column and return zero
        // results.
        if strongsSearch && !PSModuleSearchController.inputLooksLikeStrongs(raw) {
            strongsSearch = false
            rebuildOptionsMenu()
        }

        let expr = PSSearchQuery.fts5Expression(fromUserInput: raw,
                                                 matchType: searchType,
                                                 fuzzy: fuzzySearch,
                                                 strongs: strongsSearch)
        guard let expr = expr, !expr.isEmpty else {
            results = nil
            strongsHighlightPerResult = nil
            resultsTable.reloadData()
            return
        }
        runSearch(withExpression: expr)
    }

    private static func inputLooksLikeStrongs(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        // Iterate UTF-16 units to mirror the former Obj-C -characterAtIndex: loop.
        let parts = trimmed.components(separatedBy: .whitespaces)
        for tok in parts {
            let units = Array(tok.utf16)
            if units.count < 2 { continue }
            let p = units[0]
            let H = UInt16(UnicodeScalar("H").value), G = UInt16(UnicodeScalar("G").value)
            let h = UInt16(UnicodeScalar("h").value), g = UInt16(UnicodeScalar("g").value)
            if p != H && p != G && p != h && p != g { continue }
            var allDigits = true
            let zero = UInt16(UnicodeScalar("0").value), nine = UInt16(UnicodeScalar("9").value)
            for i in 1..<units.count {
                let c = units[i]
                if c < zero || c > nine { allDigits = false; break }
            }
            if allDigits { return true }
        }
        return false
    }

    private func runSearch(withExpression expression: String) {
        // ── MAIN-THREAD SNAPSHOT (race fix R13) ─────────────────────────────
        // Resolve the module and capture every query input into immutable locals
        // BEFORE dispatching. The background closure reads ONLY these `let`s.
        guard let engine = activeEngine(), engine.indexIsFresh() else {
            results = nil
            strongsHighlightPerResult = nil
            resultsTable.reloadData()
            return
        }

        let capturedExpression = expression
        let capturedScope = searchRange
        let capturedBookName = bookName.map { String($0) }   // defensive copy
        let capturedStrongsTokens: [String]? = strongsSearch
            ? PSSearchQuery.strongsTokens(fromUserInput: searchTermToDisplay ?? "")
            : nil

        // Bump + capture the generation on the main thread so a stale completion
        // can detect it has been superseded.
        queryGeneration &+= 1
        let generation = queryGeneration

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let raw = engine.runQuery(capturedExpression,
                                      scope: capturedScope,
                                      bookName: capturedBookName,
                                      limit: 1000,
                                      strongsTokens: capturedStrongsTokens)
            let entries = NSMutableArray()
            var highlights: [[String]]? = (capturedStrongsTokens?.count ?? 0) > 0 ? [] : nil
            for r in raw {
                entries.add(PSVerseTextEntry(key: r.reference, text: r.fullText))
                if highlights != nil {
                    highlights!.append(r.strongsHighlightWords ?? [])
                }
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                // BAIL OUT if a newer query has been dispatched since — never let
                // a stale completion overwrite fresher results or notify the
                // delegate with stale state.
                if generation != self.queryGeneration { return }

                self.results = entries
                self.strongsHighlightPerResult = highlights
                self.notifyDelegateOfNewHistoryItem()
                self.resultsTable.reloadData()
                self.setSearchTitle()
            }
        }
    }

    // MARK: - Search bar delegate (immediate "return" key)

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        debounceTimer?.invalidate()
        searchBar.resignFirstResponder()
        runSearchForCurrentText()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        results = nil
        strongsHighlightPerResult = nil
        searchTermToDisplay = nil
        resultsTable.reloadData()
        setSearchTitle()
    }

    // MARK: - Full-verse rendering with UI-side highlighting

    /// Returns the list of bareword tokens from the user's current query that
    /// should be visually highlighted in each result verse. Skips short (<2 char)
    /// tokens to avoid highlighting "a", "of" etc. For Strong's searches returns
    /// an empty array — the mapped surface words are instead supplied per-result
    /// via strongsHighlightPerResult, since they vary by verse.
    private func highlightTokens() -> [String] {
        if strongsSearch { return [] }
        let raw = searchTermToDisplay ?? ""
        if raw.isEmpty { return [] }

        // For exact phrase search, highlight only the full phrase as one unit.
        if searchType == .ExactSearch {
            return raw.count >= 2 ? [raw] : []
        }

        // Tokenise: respect "quoted phrases" (highlight whole phrase), otherwise
        // whitespace split. Iterate UTF-16 to mirror the former Obj-C scanner
        // byte-for-byte.
        var out: [String] = []
        let chars = Array(raw.utf16)
        var i = 0
        let n = chars.count
        let space = UInt16(UnicodeScalar(" ").value)
        let tab = UInt16(UnicodeScalar("\t").value)
        let newline = UInt16(UnicodeScalar("\n").value)
        let quote = UInt16(UnicodeScalar("\"").value)
        while i < n {
            let c = chars[i]
            if c == space || c == tab || c == newline { i += 1; continue }
            if c == quote {
                i += 1
                let start = i
                while i < n && chars[i] != quote { i += 1 }
                let phrase = String(utf16CodeUnits: Array(chars[start..<i]), count: i - start)
                if i < n { i += 1 }
                if phrase.utf16.count >= 2 { out.append(phrase) }
            } else {
                let start = i
                while i < n {
                    let ch = chars[i]
                    if ch == space || ch == tab || ch == newline || ch == quote { break }
                    i += 1
                }
                let word = String(utf16CodeUnits: Array(chars[start..<i]), count: i - start)
                if word.utf16.count >= 2 { out.append(word) }
            }
        }
        return out
    }

    /// Produce an NSAttributedString of `verseText` with every occurrence of any
    /// `tokens` entry highlighted. Matching is diacritic-insensitive and case-
    /// insensitive. For Fuzzy mode the tokens are treated as prefixes and we
    /// highlight the full matching word (the token plus any trailing letter/digit
    /// characters).
    private func attributedVerseText(_ verseText: String, tokens: [String], fuzzy: Bool) -> NSAttributedString {
        if verseText.isEmpty { return NSAttributedString() }
        let out = NSMutableAttributedString(
            string: verseText,
            attributes: [.font: UIFont.systemFont(ofSize: UIFont.systemFontSize)])
        if tokens.isEmpty { return out }

        let hlAttrs: [NSAttributedString.Key: Any] = [
            .backgroundColor: UIColor.systemYellow,
            .foregroundColor: UIColor.black,
            .font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize),
        ]
        let opts: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let wordChars = NSCharacterSet.alphanumerics as NSCharacterSet
        let ns = verseText as NSString
        let fullLen = ns.length

        for token in tokens {
            var search = NSRange(location: 0, length: fullLen)
            while search.location < fullLen {
                let hit = ns.range(of: token, options: opts, range: search)
                if hit.location == NSNotFound { break }

                var highlight = hit
                if fuzzy {
                    // Extend the highlight forward to the end of the current word
                    // so "lov" shows "loved"/"loving" fully highlighted.
                    var end = NSMaxRange(hit)
                    while end < fullLen && wordChars.characterIsMember(ns.character(at: end)) {
                        end += 1
                    }
                    highlight.length = end - highlight.location
                }
                out.addAttributes(hlAttrs, range: highlight)
                search.location = NSMaxRange(highlight)
                search.length = fullLen - search.location
            }
        }
        return out
    }

    // MARK: - Table view

    @objc func refreshView() {
        rebuildOptionsMenu()
        searchController?.searchBar.isUserInteractionEnabled = searchingEnabled
        resultsTable?.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !searchingEnabled { return 0 }
        return results?.count ?? 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !searchingEnabled {
            return NSLocalizedString("NoSearchIndexInstalled", comment: "No Search Index Installed")
        }
        if let results = results {
            return "\(results.count) \(NSLocalizedString("SearchResults", comment: "results"))"
        }
        return ""
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: PSModuleSearchController.kResultCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: PSModuleSearchController.kResultCellIdentifier)
            cell?.detailTextLabel?.numberOfLines = 0
            cell?.detailTextLabel?.lineBreakMode = .byWordWrapping
            cell?.textLabel?.font = UIFont.boldSystemFont(ofSize: 15.0)
        }
        guard let cell = cell else { return UITableViewCell() }

        guard let results = results, indexPath.row < results.count,
              let entry = results[indexPath.row] as? PSVerseTextEntry else {
            return cell
        }
        cell.textLabel?.text = entry.key

        // If the entry is missing its full text (e.g. old cached history entries),
        // pull it from the content store on demand.
        //
        // Phase 5 step 5: this went through -[SwordModule textEntryForKey:textType:]
        // with TextTypeStripped, i.e. stripText(). The store's plain_texts column IS
        // stripText()'s output — captured with the four marker-emitting options off —
        // so the marker cleaning is still applied, exactly as before, because a row
        // cached by an older build may carry markers from whatever option state that
        // build rendered under. (Step 8 moved that function out of the Obj-C engine:
        // `PSSearchCleanDisplayText` is now `PSSearchQuery.cleanDisplayText`, same
        // three regexes in the same order.)
        if entry.text == nil, let name = activeModuleName(), let key = entry.key,
           let ref = PSModuleController.createRefString(key),
           let pulled = PSContentStore.shared?.plainText(module: name, osisRef: ref) {
            entry.text = PSSearchQuery.cleanDisplayText(pulled)
        }
        var txt = entry.text ?? ""
        txt = txt.replacingOccurrences(of: "\n", with: " ")

        let tokens: [String]
        let fuzzy: Bool
        if strongsSearch {
            if let perResult = strongsHighlightPerResult, indexPath.row < perResult.count {
                tokens = perResult[indexPath.row]
            } else {
                tokens = []
            }
            fuzzy = false
        } else {
            tokens = highlightTokens()
            fuzzy = fuzzySearch
        }
        cell.detailTextLabel?.attributedText = attributedVerseText(txt, tokens: tokens, fuzzy: fuzzy)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let results = results, indexPath.row < results.count else { return }

        notifyDelegateOfNewHistoryItem()
        guard let entry = results[indexPath.row] as? PSVerseTextEntry, let ref = entry.key else { return }
        let parts = ref.components(separatedBy: ":")
        let verse = parts.count > 1 ? parts[1] : "1"
        let bookChapter = parts.first ?? ref

        let defaults = UserDefaults.standard
        defaults.set(verse, forKey: Defaults.commentaryVersePosition)
        defaults.set(verse, forKey: Defaults.bibleVersePosition)
        defaults.set(PSModuleController.createRefString(bookChapter), forKey: Defaults.lastRef)
        defaults.synchronize()

        switch listType_ {
        case .BibleTab:
            NotificationCenter.default.post(name: .redisplayPrimaryBible, object: nil)
            PSHistoryController.addHistoryItem(.BibleTab)
        case .CommentaryTab:
            NotificationCenter.default.post(name: .redisplayPrimaryCommentary, object: nil)
            PSHistoryController.addHistoryItem(.CommentaryTab)
        default:
            break
        }
        NotificationCenter.default.post(name: .toggleMultiList, object: nil)
    }

    // MARK: - History hand-off

    @objc func notifyDelegateOfNewHistoryItem() {
        guard let term = searchTermToDisplay, !term.isEmpty else {
            delegate?.searchDidFinish(nil)
            return
        }
        let bName: String? = (searchRange == .BookRange) ? bookName : nil
        let item = PSSearchHistoryItem(searchTermToDisplay: term,
                                       strongs: strongsSearch,
                                       fuzzy: fuzzySearch,
                                       type: searchType,
                                       range: searchRange,
                                       book: bName)
        item?.results = results
        saveTablePositionFromCurrentPosition()
        item?.savedTablePosition = savedTablePosition
        delegate?.searchDidFinish(item)
    }

    @objc func saveTablePositionFromCurrentPosition() {
        if (results?.count ?? 0) > 0 {
            savedTablePosition = resultsTable.indexPathsForVisibleRows as NSArray?
        }
    }

    // MARK: - Legacy plumbing

    @objc func searchButtonPressed(_ sender: Any?) {
        searchController.searchBar.becomeFirstResponder()
    }
}
