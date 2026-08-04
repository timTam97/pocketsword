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

        selectTab("workspace.library.bookmarks")
        XCTAssertTrue(app.navigationBars["Bookmarks"].waitForExistence(timeout: 5))
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
    func testHistoryAndSearchAreReachableFromReading() throws {
        selectTab("workspace.read.bible")
        let historyAndSearch = app.navigationBars["BibleTabTitleString"]
            .buttons["reading.history-search"]
        XCTAssertTrue(historyAndSearch.waitForExistence(timeout: 5))
        historyAndSearch.tap()

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))

        let search = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func selectTab(_ identifier: String) {
        let tab = app.tabBars.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(identifier)")
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Tab \(identifier) was not selected")
    }
}
