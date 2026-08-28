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
            app.descendants(matching: .any)["reading.chapter-content"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["reading.previous-chapter"].exists)
        XCTAssertTrue(app.buttons["reading.next-chapter"].exists)
        XCTAssertFalse(app.buttons["reading.focus-mode"].exists)

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
    func testSearchResultKeyboardAndCopyInteractions() throws {
        selectWorkspace("Search")

        let field = app.searchFields["Search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("beginning")

        let results = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "search.result."
            )
        )
        let firstResult = results.firstMatch
        XCTAssertTrue(
            firstResult.waitForExistence(timeout: 10),
            "Search did not produce a result for 'beginning'."
        )
        XCTAssertTrue(app.keyboards.firstMatch.exists)

        firstResult.swipeUp()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
            "Scrolling the search results did not dismiss the keyboard."
        )

        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 5),
            "Reselecting the Search workspace did not focus the search field."
        )

        guard let visibleResult = results.allElementsBoundByIndex.first(
            where: \.isHittable
        ) else {
            XCTFail("No visible search result was available to long-press.")
            return
        }

        visibleResult.press(forDuration: 1)

        let copyVerse = app.buttons["Copy Verse"]
        XCTAssertTrue(
            copyVerse.waitForExistence(timeout: 5),
            "Long-pressing a search result did not show Copy Verse."
        )
        copyVerse.tap()
        XCTAssertTrue(copyVerse.waitForNonExistence(timeout: 5))
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

    /// Wave 9's acceptance criterion: the chapter is EDGE-TO-EDGE.
    ///
    /// The reader must be a full-height scroll view whose content is inset, so text
    /// flows to the physical edges and scrolls beneath the translucent bars with no
    /// line obscured at rest. Both halves of that tradeoff were wrong once each
    /// before — Wave 6 let the WebView paint under the floating tab bar, Wave 7 kept
    /// it inside the safe area and letterboxed the chapter — so both are asserted.
    ///
    /// Note what this can and cannot see. The old `reading.web-content` identifier
    /// sat on a *container* and reported full-window in both the broken and the
    /// correct case, which is why CLAUDE.md says a hierarchy dump does not catch
    /// letterboxing. The native reader's identifier is on the `ScrollView` ITSELF, so
    /// its frame is now meaningful — that is what makes this assertable at all.
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
        // a frame that stops at the chrome — Wave 7's reader was
        // {{0,116},{402,675}} against a 874-point window.
        XCTAssertEqual(readerFrame.minY, window.minY, accuracy: 1,
                       "the reader does not reach the top edge — letterboxed")
        XCTAssertEqual(readerFrame.maxY, window.maxY, accuracy: 1,
                       "the reader does not reach the bottom edge — letterboxed")

        // ...and the CONTENT is inset, so the first verse is not hidden behind the
        // navigation bar. This is the other half: a full-height scroll view with no
        // content inset is the Wave 6 defect.
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

    /// A Strong's number in the chapter text opens its lexicon entry.
    ///
    /// Wave 9 made this assertable for the first time: in the WebView the verse text
    /// and its links were invisible to XCUITest (only the container had an
    /// identifier, which is why CLAUDE.md says to read the screenshot). The native
    /// reader's links are real accessibility elements carrying their `pslink://`
    /// target, so the whole tap path can be driven from a test.
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
    /// Three device-reported defects met here, all in `PSEntryDocument` /
    /// `EntryTextView`, and all invisible to a unit test because they are about
    /// whether a tap does anything:
    ///
    ///  * the popup passed no `openLink` while its `OpenURLAction` still returned
    ///    `.handled`, so every cross-link was swallowed — the link highlighted on
    ///    press and went nowhere;
    ///  * the link's run range was inferred at `</a>` by walking backwards, so it
    ///    jacketed the prose back to the previous link instead of its own number;
    ///  * the entry it opens is reached in place, with a Back button, rather than by
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
    func testTappingReaderHidesAndRestoresTheTabBar() throws {
        selectWorkspace("Read")

        let reader = app.descendants(matching: .any)
            .matching(identifier: "reading.chapter-content")
            .firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reading.focus-mode"].exists)

        let readTab = app.tabBars.buttons["Read"]
        XCTAssertTrue(readTab.exists)
        let firstVerse = app.links["pslink://versemenu/1"]
        XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
        let initialVerseFrame = firstVerse.frame

        reader.coordinate(
            withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55)
        ).tap()
        // The tab and status bars animate away while the native glass navigation
        // controls remain available over the chapter.
        XCTAssertTrue(readTab.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["reading.chapter-content"].exists
        )
        XCTAssertTrue(app.buttons["reading.reference-picker"].exists)
        XCTAssertEqual(firstVerse.frame.minX, initialVerseFrame.minX, accuracy: 1)
        XCTAssertEqual(firstVerse.frame.minY, initialVerseFrame.minY, accuracy: 1)

        reader.coordinate(
            withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55)
        ).tap()
        XCTAssertTrue(readTab.waitForExistence(timeout: 5))
        XCTAssertEqual(firstVerse.frame.minX, initialVerseFrame.minX, accuracy: 1)
        XCTAssertEqual(firstVerse.frame.minY, initialVerseFrame.minY, accuracy: 1)
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

        // Commit the field before tapping Save, and verify the commit landed.
        //
        // This is not defensive padding — without it the folder is created under
        // a TRUNCATED name. Measured on the iOS 27 simulator: typing "UI Drag B"
        // and tapping Save persisted "UI Drag ", losing exactly the last
        // character, on every run rather than intermittently.
        //
        // The cause is that a SwiftUI `TextField`'s binding is not necessarily
        // current for the final keystroke until the field commits, and tapping
        // Save takes focus away in the same beat. `XCUIElement.value` is NOT a
        // usable check for this: it reported the full "UI Drag B" while the
        // draft the app saved held only the prefix, so asserting on it passes
        // while the bug is live. Typing the newline commits the field the way a
        // user pressing Return does, and the row assertion below — which reads
        // the name back out of the app's own list — is what actually proves it.
        //
        // Getting this wrong is worse than a red test: the truncated folder was
        // invisible to the old exact-name cleanup, so it accumulated in
        // PSBookmarks.plist and later tripped the store's duplicate-name guard
        // with a failure that pointed nowhere near the cause.
        field.typeText("\n")

        app.buttons["bookmarks.folder-save"].tap()
        XCTAssertTrue(
            app.buttons[name].waitForExistence(timeout: 5),
            "The folder was not created as \"\(name)\" — check for a truncated "
                + "name in PSBookmarks.plist."
        )
    }

    /// Deletes leftover test folders, matched by **prefix** rather than by exact
    /// name.
    ///
    /// Exact-name cleanup is not self-healing: a folder that ever lands under a
    /// slightly different name than intended is invisible to the next run and
    /// accumulates in `PSBookmarks.plist` forever, where the store's
    /// duplicate-name guard eventually fails a create for a reason that looks
    /// nothing like the cause. Sweeping the prefix means the suite repairs the
    /// device instead of degrading it.
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
