import XCTest

final class PocketSwordUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-DefaultsLastMultiListTab", "0"
        ]
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 20),
            "PocketSword did not reach the foreground."
        )
        XCTAssertTrue(
            app.tabBars.buttons["workspace.read.bible"].waitForExistence(timeout: 20),
            "PocketSword did not finish initialization."
        )
    }

    @MainActor
    func testReadingAndLibraryDestinationsAreReachable() throws {
        // Wave 7: the reading chrome is drawn by ReaderScreen's own SwiftUI
        // NavigationStack, and the enclosing UIKit navigation bar (which carried the
        // "BibleTabTitleString" / "CommentaryTabTitleString" titles) is hidden. The
        // reader is now identified by its own controls rather than by that bar.
        selectTab("workspace.read.bible")
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.buttons["reading.reference-picker"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["reading.previous-chapter"].exists)
        XCTAssertTrue(app.buttons["reading.next-chapter"].exists)
        XCTAssertTrue(app.buttons["reading.focus-mode"].exists)

        selectTab("workspace.read.commentary")
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.buttons["reading.reference-picker"].waitForExistence(timeout: 5)
        )

        selectTab("workspace.library.dictionary")
        XCTAssertTrue(app.searchFields["Search Dictionary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dictionary.module-menu"].exists)

        selectTab("workspace.library.bookmarks")
        XCTAssertTrue(app.navigationBars["Bookmarks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bookmarks.add-folder"].exists)
    }

    @MainActor
    func testSettingsAndAboutAreReachableFromMore() throws {
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()

        let preferences = app.tables.staticTexts["Preferences"].firstMatch
        XCTAssertTrue(preferences.waitForExistence(timeout: 5))
        preferences.tap()
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.sliders["settings.font-size"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["settings.font"].exists)
        XCTAssertTrue(app.switches["settings.keep-awake"].exists)
        XCTAssertTrue(app.switches["settings.rotation-lock"].exists)
        XCTAssertTrue(app.switches["settings.automatic-fullscreen"].exists)

        app.buttons["settings.font"].tap()
        XCTAssertTrue(app.navigationBars["Font"].waitForExistence(timeout: 5))
        let arial = app.buttons["Arial"]
        XCTAssertTrue(arial.waitForExistence(timeout: 5))
        arial.tap()
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 5))

        let backToMore = app.navigationBars.buttons["More"]
        XCTAssertTrue(backToMore.waitForExistence(timeout: 5))
        backToMore.tap()

        let about = app.tables.staticTexts["About"].firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        about.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["about.header"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testReferencePickerSelectsVerse() throws {
        selectTab("workspace.read.bible")

        // Wave 7: the three-segment UISegmentedControl became three buttons, and
        // the reference button opens the picker as a popover rather than the
        // coordinator presenting a wrapped PSRefSelectorController.
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

    @MainActor
    func testHistoryAndSearchAreReachableFromReading() throws {
        selectTab("workspace.read.bible")
        // Wave 7: History & Search is a secondary study action, so it lives in the
        // iOS 27 ToolbarOverflowMenu rather than as a left bar-button item.
        openReadingOverflowMenu()
        // Matched by label: menu rows expose their title, not our identifier.
        let historyAndSearch = app.buttons["History and Search"]
        XCTAssertTrue(historyAndSearch.waitForExistence(timeout: 5))
        historyAndSearch.tap()

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history.close"].exists)
        XCTAssertTrue(app.buttons["history.clear"].exists)

        let search = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search.module-menu"].exists)
        XCTAssertTrue(app.buttons["search.options"].exists)
        XCTAssertTrue(app.segmentedControls["search.scope"].exists)
    }

    @MainActor
    func testBookmarkFolderCrudAndReordering() throws {
        let firstName = "UI Drag A"
        let secondName = "UI Drag B"

        selectTab("workspace.library.bookmarks")
        deleteFolderIfPresent(named: "Drag-A")
        deleteFolderIfPresent(named: "Drag-B")
        deleteFolderIfPresent(named: firstName)
        deleteFolderIfPresent(named: secondName)
        defer {
            deleteFolderIfPresent(named: "Drag-A")
            deleteFolderIfPresent(named: "Drag-B")
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

    /// Opens the reading toolbar's iOS 27 overflow menu.
    ///
    /// `ToolbarOverflowMenu` is system-provided, so its button carries the
    /// system's own identity rather than one we set: confirmed on the iOS 27
    /// simulator as identifier `OverflowBarButtonItem` / label "More". Matched by
    /// identifier, since the label is localized.
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
    func testFocusModeHidesAndRestoresTheTabBar() throws {
        selectTab("workspace.read.bible")

        let focus = app.buttons["reading.focus-mode"]
        XCTAssertTrue(focus.waitForExistence(timeout: 5))
        let tabBarButton = app.tabBars.buttons["workspace.read.bible"]
        XCTAssertTrue(tabBarButton.exists)

        focus.tap()
        // Focus mode hides the tab bar via setTabBarHidden(_:animated:) and the
        // navigation bar via toolbarVisibility, so only the chapter remains. The
        // pinned Focus control itself must survive, since it is the way back out.
        XCTAssertTrue(tabBarButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.web-content"].exists
        )

        let exitFocus = app.buttons["reading.focus-mode"]
        XCTAssertTrue(exitFocus.waitForExistence(timeout: 5))
        exitFocus.tap()
        XCTAssertTrue(tabBarButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testDisplayTogglesAppearForBibleAndNotCommentary() throws {
        // NB: UIKit renders a SwiftUI menu's rows as cells that expose their LABEL
        // but drop the `accessibilityIdentifier` (verified in the iOS 27 hierarchy),
        // so these rows are matched by their localized titles. The exhaustive
        // id/pref/order assertions live in
        // AppStateStoresTests.testDisplayTogglesMatchBakedFeatureSets, which reads
        // the same pure builder this menu is populated from.
        selectTab("workspace.read.bible")
        openReadingOverflowMenu()
        // KJV earns six rows; cross-references is deliberately absent (no
        // OSISScripref filter, no Feature=Scripref).
        XCTAssertTrue(
            app.buttons["Strong's Numbers"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Verse Per Line"].exists)
        XCTAssertFalse(app.buttons["Cross-references"].exists)
        dismissMenu()

        selectTab("workspace.read.commentary")
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
    private func dismissMenu() {
        // A menu is dismissed by tapping outside it. The reader fills the screen,
        // but tapping its centre would hit a verse link, so use a corner well
        // clear of the menu (which anchors to the trailing side of the top bar).
        app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.08, dy: 0.9)
        ).tap()
    }

    @MainActor
    private func selectTab(_ identifier: String) {
        let tab = app.tabBars.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(identifier)")
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Tab \(identifier) was not selected")
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
