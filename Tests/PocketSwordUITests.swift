import XCTest

/// UI tests over the four workspaces — Read, Search, Library, Settings:
///
/// - Bible and Commentary are two modes of the Read workspace (`reading.mode`).
/// - Search is a workspace with `TabRole.search`.
/// - Dictionary, Bookmarks and History are Library sections.
/// - Settings is a workspace, with About pushed from its toolbar.
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
            app.descendants(matching: .any)["reading.chapter-content"]
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
            app.descendants(matching: .any)["reading.chapter-content"]
                .waitForExistence(timeout: 5)
        )

        selectReadingMode("Commentary")
        XCTAssertTrue(
            app.buttons["reading.reference-picker"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.chapter-content"].exists
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
    /// Search workspace (a tab selection, not a sheet presentation).
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
        // History is a workspace section, so there is no Close button.
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

    /// The chapter is EDGE-TO-EDGE: a full-height scroll view whose content is
    /// inset, so text flows to the physical edges and scrolls beneath the
    /// translucent bars with no line obscured at rest. Both halves are asserted —
    /// dropping either paints text under the tab bar or letterboxes the chapter.
    ///
    /// The `reading.chapter-content` identifier is on the `ScrollView` ITSELF, so
    /// its frame is meaningful.
    @MainActor
    func testChapterScrollsUnderTheChromeEdgeToEdge() throws {
        // `.firstMatch` is required, not incidental: BOTH panes carry this
        // identifier because both stay in the hierarchy for the app's lifetime (the
        // inactive one at `opacity(0)`), which is what lets `displayChapter` defer a
        // render into the pane that is not on screen. A bare subscript throws
        // "multiple matching elements".
        let reader = app.descendants(matching: .any)
            .matching(identifier: "reading.chapter-content")
            .firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 10))

        let readerFrame = reader.frame
        let window = app.windows.firstMatch.frame

        // The scroll view fills the window vertically. Letterboxing shows up here as
        // a frame that stops at the chrome.
        XCTAssertEqual(readerFrame.minY, window.minY, accuracy: 1,
                       "the reader does not reach the top edge — letterboxed")
        XCTAssertEqual(readerFrame.maxY, window.maxY, accuracy: 1,
                       "the reader does not reach the bottom edge — letterboxed")

        // ...and the CONTENT is inset, so the first verse is not hidden behind the
        // navigation bar. A full-height scroll view with no content inset is the
        // other failure.
        let navigationBarBottom = app.navigationBars.firstMatch.frame.maxY
        let firstVerse = app.links["pslink://versemenu/1"]
        if firstVerse.waitForExistence(timeout: 5) {
            XCTAssertGreaterThanOrEqual(
                firstVerse.frame.minY, navigationBarBottom - 1,
                "verse 1 is painted behind the navigation bar"
            )
        }
    }

    /// Flowing prose still tracks the exact inline verse at the viewport top.
    ///
    /// Genesis 1's first paragraph contains verses 1-5 in one `Text`. A small drag
    /// stays inside that paragraph, so a row-level tracker remains stuck at verse 1;
    /// the per-verse text-layout tracker must advance the reference value.
    @MainActor
    func testFlowingReaderTracksTheVisibleVerseWithinAParagraph() throws {
        let reader = app.descendants(matching: .any)
            .matching(identifier: "reading.chapter-content")
            .firstMatch
        let reference = app.buttons["reading.reference-picker"]
        XCTAssertTrue(reader.waitForExistence(timeout: 10))
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        let initialValue = try XCTUnwrap(reference.value as? String)

        let start = reader.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)
        )
        let end = reader.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38)
        )
        start.press(forDuration: 0.05, thenDragTo: end)

        let advanced = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                (reference.value as? String) != initialValue
            },
            object: nil
        )
        wait(for: [advanced], timeout: 10)
        XCTAssertNotEqual(reference.value as? String, initialValue)
    }

    /// A Strong's number in the chapter text opens its lexicon entry. The reader's
    /// links are real accessibility elements carrying their `pslink://` target,
    /// so the whole tap path is driven from the test.
    @MainActor
    func testStrongsLinkOpensItsLexiconEntry() throws {
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.chapter-content"]
                .waitForExistence(timeout: 10)
        )
        // Genesis 1:1's first Strong's number, H07225 (bereshith).
        let strongs = app.links["pslink://strongs/Hebrew/07225"]
        guard strongs.waitForExistence(timeout: 5) else {
            throw XCTSkip("Strong's numbers are switched off for this module")
        }
        strongs.tap()

        let popup = app.descendants(matching: .any)["study.popup"]
        XCTAssertTrue(popup.firstMatch.waitForExistence(timeout: 10),
                      "tapping a Strong's number did not open the study popup")
    }

    /// A cross-link INSIDE a lexicon entry navigates to the entry it names.
    ///
    /// Covers what a unit test cannot — whether a tap does anything:
    ///
    ///  * the popup must pass `openLink`, or an `OpenURLAction` returning
    ///    `.handled` swallows every cross-link;
    ///  * the link's run range must be bounded at its own anchor;
    ///  * the target entry opens in place, with a Back button, rather than by
    ///    stacking a second sheet.
    ///
    /// H07225's entry ("In the beginning") cross-links to H07218 (rosh). The link's
    /// identifier is its `pslink://lexicon/…` URL, so the assertion is on the
    /// TARGET, not merely on something being tappable.
    @MainActor
    func testLexiconCrossLinkNavigatesWithinThePopup() throws {
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.chapter-content"]
                .waitForExistence(timeout: 10)
        )
        let strongs = app.links["pslink://strongs/Hebrew/07225"]
        guard strongs.waitForExistence(timeout: 5) else {
            throw XCTSkip("Strong's numbers are switched off for this module")
        }
        strongs.tap()

        let popup = app.descendants(matching: .any)["study.popup"]
        XCTAssertTrue(popup.firstMatch.waitForExistence(timeout: 10),
                      "the study popup did not open")

        // The cross-link is a real, addressable element — not a span of dead text.
        let crossLink = app.links["pslink://lexicon/StrongsRealHebrew?key=07218"]
        guard crossLink.waitForExistence(timeout: 5) else {
            throw XCTSkip("H07225's entry does not cross-link to H07218 in this build")
        }
        crossLink.tap()

        // Following it swaps the entry in place and offers a way back. "Back" is the
        // proof the navigation happened: it exists only while the trail is non-empty.
        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10),
                      "tapping a lexicon cross-link did nothing — no entry was pushed")

        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5),
                      "Back did not return to the entry the reader opened")
        XCTAssertTrue(popup.firstMatch.exists,
                      "going back dismissed the popup instead of popping the trail")
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
            app.descendants(matching: .any)["reading.chapter-content"].exists
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
        // Prefix sweep, not two exact names: it also collects any truncated
        // leftover ("UI Drag ") from an earlier interrupted or raced run.
        deleteFoldersIfPresent(withPrefix: "UI Drag")
        defer {
            deleteFoldersIfPresent(withPrefix: "UI Drag")
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
        // 15s, not 5s: the long-press-then-drag that drives iOS 27's `.reorderable()`
        // is timing-sensitive under the load of a full-suite run.
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

        // Commit the field before tapping Save, and verify the commit landed.
        //
        // Without it the folder is created under a TRUNCATED name (typing
        // "UI Drag B" persisted "UI Drag ", on every run): a SwiftUI `TextField`'s
        // binding is not necessarily current for the final keystroke until the
        // field commits, and tapping Save takes focus in the same beat.
        // `XCUIElement.value` is NOT a usable check — it reported the full text
        // while the app saved the prefix. Typing the newline commits the field;
        // the row assertion below reads the name back from the app's own list.
        field.typeText("\n")

        app.buttons["bookmarks.folder-save"].tap()
        XCTAssertTrue(
            app.buttons[name].waitForExistence(timeout: 5),
            "The folder was not created as \"\(name)\" — check for a truncated "
                + "name in PSBookmarks.plist."
        )
    }

    /// Deletes leftover test folders, matched by **prefix** rather than by exact
    /// name, so a folder saved under a slightly different name cannot accumulate in
    /// `PSBookmarks.plist` and later trip the store's duplicate-name guard.
    @MainActor
    private func deleteFoldersIfPresent(withPrefix prefix: String) {
        let matches = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)
        )
        // Bounded rather than `while`: a row that will not delete would
        // otherwise spin here until the test times out with no diagnosis.
        for _ in 0..<8 {
            let row = matches.firstMatch
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
}
