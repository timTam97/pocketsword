import XCTest

/// Wave 8 rewrote the navigation these tests drive.
///
/// The app had six tabs plus a modally-presented History/Search pair; it now has
/// four workspaces — Read, Search, Library, Settings — so "select a tab" means
/// something different, and several destinations moved:
///
/// - Bible and Commentary were two tabs; they are two modes of the Read workspace,
///   switched by `reading.mode` rather than by the tab bar.
/// - Search was half of a modal; it is a workspace with `TabRole.search`.
/// - History was the other half; it is a Library section.
/// - Dictionary and Bookmarks were tabs; they are Library sections.
/// - Preferences and About were rows under the system "More" list; Settings is a
///   workspace, with About pushed from its toolbar.
final class PocketSwordUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 20),
            "PocketSword did not reach the foreground."
        )
        // The reader's own controls, not a tab title: the Read workspace draws its
        // chrome with a SwiftUI NavigationStack and has no navigation-bar title.
        XCTAssertTrue(
            app.buttons["reading.reference-picker"].waitForExistence(timeout: 20),
            "PocketSword did not finish initialization."
        )
    }

    @MainActor
    func testAllFourWorkspacesAreReachable() throws {
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["reading.previous-chapter"].exists)
        XCTAssertTrue(app.buttons["reading.next-chapter"].exists)
        XCTAssertTrue(app.buttons["reading.focus-mode"].exists)

        selectWorkspace("Search")
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search.module-menu"].exists)
        XCTAssertTrue(app.buttons["search.options"].exists)
        XCTAssertTrue(app.segmentedControls["search.scope"].exists)

        selectWorkspace("Library")
        // The Library sections set no `navigationTitle`: the `library.section`
        // menu sits in the principal slot and names the active section itself.
        XCTAssertTrue(
            app.buttons["library.section"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["bookmarks.add-folder"].exists)

        selectWorkspace("Settings")
        XCTAssertTrue(
            app.navigationBars["Preferences"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.sliders["settings.font-size"].exists)
        XCTAssertTrue(app.buttons["settings.font"].exists)
        XCTAssertTrue(app.switches["settings.keep-awake"].exists)
        XCTAssertTrue(app.switches["settings.rotation-lock"].exists)
        XCTAssertTrue(app.switches["settings.automatic-fullscreen"].exists)
    }

    @MainActor
    func testBibleAndCommentaryModesBothRender() throws {
        selectWorkspace("Read")
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"]
                .waitForExistence(timeout: 5)
        )

        selectReadingMode("Commentary")
        XCTAssertTrue(
            app.buttons["reading.reference-picker"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"].exists
        )

        selectReadingMode("Bible")
        XCTAssertTrue(
            app.buttons["reading.reference-picker"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testSettingsFontPickerAndAbout() throws {
        selectWorkspace("Settings")
        XCTAssertTrue(
            app.navigationBars["Preferences"].waitForExistence(timeout: 5)
        )

        app.buttons["settings.font"].tap()
        XCTAssertTrue(app.navigationBars["Font"].waitForExistence(timeout: 5))
        let arial = app.buttons["Arial"]
        XCTAssertTrue(arial.waitForExistence(timeout: 5))
        arial.tap()
        XCTAssertTrue(
            app.navigationBars["Preferences"].waitForExistence(timeout: 5)
        )

        // Wave 8: About is pushed from the Settings toolbar rather than being a
        // second "More" row.
        app.buttons["workspace.settings.about"].tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["about.header"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testReferencePickerSelectsVerse() throws {
        selectWorkspace("Read")

        let referenceButton = app.buttons["reading.reference-picker"]
        XCTAssertTrue(referenceButton.waitForExistence(timeout: 5))
        referenceButton.tap()

        XCTAssertTrue(
            app.navigationBars["Select Book"].waitForExistence(timeout: 5)
        )
        let genesis = app.buttons["reference.book.Gen"]
        XCTAssertTrue(genesis.waitForExistence(timeout: 5))
        genesis.tap()

        XCTAssertTrue(app.navigationBars["Genesis"].waitForExistence(timeout: 5))
        let chapter = app.buttons["reference.chapter.1"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        chapter.tap()

        XCTAssertTrue(
            app.navigationBars["Genesis 1"].waitForExistence(timeout: 5)
        )
        let verse = app.buttons["reference.verse.1"]
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        verse.tap()

        XCTAssertTrue(
            app.navigationBars["Select Book"].waitForNonExistence(timeout: 5)
        )
    }

    /// The reader's overflow-menu "History and Search" action switches to the
    /// Search workspace.
    ///
    /// This replaces `testHistoryAndSearchAreReachableFromReading`, whose subject
    /// — a modally-presented `UITabBarController` — no longer exists. The action
    /// itself survives because the reader is still where you are when you decide to
    /// search; it changes the tab selection now instead of presenting a sheet.
    ///
    /// That change is also what retires the `suppressMultiListPresentAnimation`
    /// workaround: the Wave 7 crash this path used to hit needed a UIKit sheet
    /// dismissing while another UIKit sheet was presented, and a tab selection is
    /// neither.
    @MainActor
    func testReadingOverflowMenuOpensTheSearchWorkspace() throws {
        selectWorkspace("Read")
        openReadingOverflowMenu()

        // Matched by label: UIKit renders a SwiftUI menu's rows as cells that
        // expose their title but drop the accessibility identifier.
        let historyAndSearch = app.buttons["History and Search"]
        XCTAssertTrue(historyAndSearch.waitForExistence(timeout: 5))
        historyAndSearch.tap()

        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields["Search"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLibrarySectionsSwitch() throws {
        selectWorkspace("Library")
        XCTAssertTrue(app.buttons["bookmarks.add-folder"].waitForExistence(timeout: 5))

        selectLibrarySection("History")
        XCTAssertTrue(app.buttons["history.clear"].waitForExistence(timeout: 5))
        // Wave 8: History is a workspace section, so there is nothing to close and
        // the Close button is deliberately absent.
        XCTAssertFalse(app.buttons["history.close"].exists)

        selectLibrarySection("Dictionary")
        XCTAssertTrue(
            app.searchFields["Search Dictionary"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["dictionary.module-menu"].exists)

        selectLibrarySection("Bookmarks")
        XCTAssertTrue(
            app.buttons["bookmarks.add-folder"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testFocusModeHidesAndRestoresTheTabBar() throws {
        selectWorkspace("Read")

        let focus = app.buttons["reading.focus-mode"]
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        let readTab = app.tabBars.buttons["Read"]
        XCTAssertTrue(readTab.exists)

        focus.tap()
        // Focus mode hides the tab bar (via `toolbarVisibility(for: .tabBar)`) and
        // the status bar, leaving only the chapter. The pinned Focus control must
        // survive, since it is the way back out.
        XCTAssertTrue(readTab.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"].exists
        )

        let exitFocus = app.buttons["reading.focus-mode"]
        XCTAssertTrue(exitFocus.waitForExistence(timeout: 5))
        exitFocus.tap()
        XCTAssertTrue(readTab.waitForExistence(timeout: 5))
    }

    @MainActor
    func testDisplayTogglesAppearForBibleAndNotCommentary() throws {
        // NB: UIKit renders a SwiftUI menu's rows as cells that expose their LABEL
        // but drop the `accessibilityIdentifier` (verified in the iOS 27
        // hierarchy), so these rows are matched by their localized titles. The
        // exhaustive id/pref/order assertions live in
        // AppStateStoresTests.testDisplayTogglesMatchBakedFeatureSets, which reads
        // the same pure builder this menu is populated from.
        selectWorkspace("Read")
        selectReadingMode("Bible")
        openReadingOverflowMenu()
        // KJV earns six rows; cross-references is deliberately absent (no
        // OSISScripref filter, no Feature=Scripref).
        XCTAssertTrue(
            app.buttons["Strong's Numbers"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Verse Per Line"].exists)
        XCTAssertFalse(app.buttons["Cross-references"].exists)
        dismissMenu()

        selectReadingMode("Commentary")
        openReadingOverflowMenu()
        // MHCC advertises nothing, so it contributes no display rows at all — only
        // the always-present History & Search action.
        XCTAssertTrue(
            app.buttons["History and Search"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["Strong's Numbers"].exists)
        XCTAssertFalse(app.buttons["Verse Per Line"].exists)
        dismissMenu()
    }

    @MainActor
    func testBookmarkFolderCrudAndReordering() throws {
        let firstName = "UI Drag A"
        let secondName = "UI Drag B"

        selectWorkspace("Library")
        deleteFolderIfPresent(named: firstName)
        deleteFolderIfPresent(named: secondName)
        defer {
            deleteFolderIfPresent(named: firstName)
            deleteFolderIfPresent(named: secondName)
        }

        createFolder(named: firstName)
        createFolder(named: secondName)

        let first = app.buttons[firstName]
        let second = app.buttons[secondName]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(second.frame.minY, first.frame.minY)

        second.press(forDuration: 1, thenDragTo: first)

        let reordered = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                second.frame.minY < first.frame.minY
            },
            object: nil
        )
        // 15s, not 5s: the long-press-then-drag that drives iOS 27's
        // `.reorderable()` is timing-sensitive, and this occasionally missed the
        // window under the load of a full-suite run while passing in isolation.
        // The assertion is unchanged — only the patience for the animation is.
        wait(for: [reordered], timeout: 15)
        XCTAssertLessThan(second.frame.minY, first.frame.minY)
    }

    // MARK: - Helpers

    /// Opens the reading toolbar's iOS 27 overflow menu.
    ///
    /// `ToolbarOverflowMenu` is system-provided, so its button carries the system's
    /// own identity rather than one we set: confirmed on the iOS 27 simulator as
    /// identifier `OverflowBarButtonItem` / label "More". Matched by identifier,
    /// since the label is localized.
    @MainActor
    private func openReadingOverflowMenu() {
        let overflow = app.buttons["OverflowBarButtonItem"].firstMatch
        XCTAssertTrue(
            overflow.waitForExistence(timeout: 5),
            "Could not find the reading toolbar's overflow menu."
        )
        overflow.tap()
    }

    @MainActor
    private func dismissMenu() {
        // A menu is dismissed by tapping outside it. The reader fills the screen,
        // but tapping its centre would hit a verse link, so use a corner well clear
        // of the menu (which anchors to the trailing side of the top bar).
        app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.08, dy: 0.75)
        ).tap()
    }

    /// Selects a workspace by its LABEL, not an identifier.
    ///
    /// `Tab`'s `accessibilityIdentifier` does not reach the tab-bar button —
    /// verified in the iOS 27 hierarchy, where the four buttons carry only their
    /// localized labels. Note the on-screen order is Read, Library, Settings,
    /// Search: `TabRole.search` moves Search to the trailing position regardless of
    /// where it is declared.
    @MainActor
    private func selectWorkspace(_ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(
            tab.waitForExistence(timeout: 5),
            "Missing workspace \(label)"
        )
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Workspace \(label) was not selected")
    }

    /// Switches the Read workspace between Bible and commentary, through the
    /// `reading.mode` menu in the toolbar's leading slot.
    @MainActor
    private func selectReadingMode(_ label: String) {
        let control = app.buttons["reading.mode"]
        XCTAssertTrue(
            control.waitForExistence(timeout: 5),
            "Missing the reading-mode control"
        )
        control.tap()
        let option = app.buttons[label].firstMatch
        XCTAssertTrue(
            option.waitForExistence(timeout: 5),
            "Missing reading mode \(label)"
        )
        option.tap()
    }

    /// Switches the Library workspace's section, through the `library.section`
    /// menu that occupies the navigation bar's principal slot.
    @MainActor
    private func selectLibrarySection(_ label: String) {
        let control = app.buttons["library.section"]
        XCTAssertTrue(
            control.waitForExistence(timeout: 5),
            "Missing the library section control"
        )
        control.tap()
        let option = app.buttons[label].firstMatch
        XCTAssertTrue(
            option.waitForExistence(timeout: 5),
            "Missing library section \(label)"
        )
        option.tap()
    }

    @MainActor
    private func createFolder(named name: String) {
        app.buttons["bookmarks.add-folder"].tap()
        let field = app.textFields["bookmarks.folder-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["bookmarks.folder-save"].tap()
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5))
    }

    @MainActor
    private func deleteFolderIfPresent(named name: String) {
        let row = app.buttons[name]
        guard row.waitForExistence(timeout: 1) else { return }
        row.swipeLeft()

        let deleteAction = app.buttons["Delete"].firstMatch
        guard deleteAction.waitForExistence(timeout: 2) else { return }
        deleteAction.tap()

        let confirmation = app.buttons["Delete"].firstMatch
        guard confirmation.waitForExistence(timeout: 2) else { return }
        confirmation.tap()
        _ = row.waitForNonExistence(timeout: 5)
    }
}
