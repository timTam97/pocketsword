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
        selectTab("workspace.read.bible")
        XCTAssertTrue(app.navigationBars["BibleTabTitleString"].exists)

        selectTab("workspace.read.commentary")
        XCTAssertTrue(app.navigationBars["CommentaryTabTitleString"].exists)

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

        let referenceControl = app.segmentedControls[
            "reading.reference-picker"
        ]
        XCTAssertTrue(referenceControl.waitForExistence(timeout: 5))
        referenceControl.buttons.element(boundBy: 1).tap()

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
        let historyAndSearch = app.navigationBars["BibleTabTitleString"]
            .buttons["reading.history-search"]
        XCTAssertTrue(historyAndSearch.waitForExistence(timeout: 5))
        historyAndSearch.tap()

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history.close"].exists)
        XCTAssertTrue(app.buttons["history.clear"].exists)

        let search = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
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
        wait(for: [reordered], timeout: 5)
        XCTAssertLessThan(second.frame.minY, first.frame.minY)
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
