//
//  SwordOracleCaptureTests.swift
//  PocketSwordTests
//
//  Captures the live SWORD engine's output as checked-in golden fixtures, while
//  the engine is still in the tree.
//
//  This is the Phase-2 half of the SWORD-removal plan's oracle strategy: SWORD is
//  deleted forever in Phase 5, so the only way Phase 3's pure-Swift content
//  reader can be held to account is against data captured now. Everything these
//  tests write under Tests/Fixtures/ becomes Phase 3's acceptance criterion.
//
//  Two modes:
//
//  * Assertion mode (default). If a fixture already exists on disk, the captured
//    output is compared against it and any difference fails. This is what keeps
//    the fixtures honest in CI once they are committed.
//  * Capture mode. Set the PSORACLE_CAPTURE environment variable and the tests
//    (re)write the fixtures instead of asserting, into the directory named by
//    PSORACLE_FIXTURE_DIR (defaults to a path derived from #filePath, i.e. the
//    source tree, not the simulator sandbox).
//
//  Capturing is deliberately opt-in: a test that rewrites its own expectations
//  on every run asserts nothing.
//
//  IMPORTANT: these tests drive the *real* singleton SwordManager that the host
//  app is using, and they set global SWORD options to a fixed configuration to
//  make output reproducible. -[SwordModule getChapter:] calls -setPreferences,
//  which pushes the per-module NSUserDefaults prefs back into those same global
//  options, so the option state here is not durable across a render by the app.
//  That is exactly why the converter sets options directly rather than via prefs.
//

import XCTest
import CryptoKit
import SQLite3
@testable import PocketSword

final class SwordOracleCaptureTests: XCTestCase {

    // MARK: - Configuration

    /// The render configuration the offline converter (tools/swordbake) uses.
    /// Capturing under any other configuration would produce an oracle that the
    /// content store cannot possibly match.
    ///
    /// Headings is **On**: 1,250 of KJV's 1,388 `<title>` tags are
    /// non-canonical and live in intro-only entry slots, and
    /// osisheadings.cpp:132 only emits interverse titles into the body when the
    /// option is on. Lemmas is **Off**: KJV declares
    /// `GlobalOptionFilter=OSISLemma`, and leaving it on makes
    /// osishtmlhref.cpp:66 emit ~145k anchors for `lemma.TR:` Greek parts.
    private static let renderOptions: [(String, String)] = [
        (SW_OPTION_STRONGS, SW_ON),
        (SW_OPTION_MORPHS, SW_ON),
        (SW_OPTION_FOOTNOTES, SW_ON),
        (SW_OPTION_SCRIPTREFS, SW_ON),
        (SW_OPTION_REDLETTERWORDS, SW_ON),
        (SW_OPTION_HEADINGS, SW_ON),
        (SW_OPTION_VARIANTS, SW_OPTION_VARIANTS_PRIMARY),
        (SW_OPTION_LEMMAS, SW_OFF),
        (SW_OPTION_GLOSSES, SW_OFF),
        (SW_OPTION_GREEKACCENTS, SW_OFF),
        (SW_OPTION_HEBREWPOINTS, SW_OFF),
        (SW_OPTION_HEBREWCANTILLATION, SW_OFF),
    ]

    /// The **other** endpoint: every option `-[SwordModule setPreferences]`
    /// pushes, off. This is the state a *fresh install* actually renders — there
    /// is no `registerDefaults` anywhere in the app, and both the Obj-C
    /// `GetBoolPrefForMod` macro and Swift's `UserDefaults.psBool` bottom out in
    /// `-boolForKey:`, which answers NO for a missing key. Nothing pinned it
    /// before, which meant the fixture set covered a configuration no user has on
    /// first launch.
    ///
    /// `setPreferences` pushes **eleven** options, not the six a reader might
    /// guess from the per-tab `▾` menu (SwordModule.mm:188-213): scriptRefs,
    /// strongs, morphs, headings, footnotes, glosses, redLetter, variants,
    /// greekAccents, hebrewPoints, hebrewCantillation. Ten are booleans; variants
    /// is pinned to Primary Reading unconditionally and is therefore the same in
    /// both configurations. Lemmas is **not** pushed by `setPreferences` at all —
    /// it sits at `SWOptionFilter`'s constructor default, which is the first
    /// entry of `oValues()`, i.e. "Off" (swoptfilter.cpp:43, osislemma.cpp:37).
    /// It is set explicitly here so the capture does not depend on that.
    private static let allOffRenderOptions: [(String, String)] = [
        (SW_OPTION_STRONGS, SW_OFF),
        (SW_OPTION_MORPHS, SW_OFF),
        (SW_OPTION_FOOTNOTES, SW_OFF),
        (SW_OPTION_SCRIPTREFS, SW_OFF),
        (SW_OPTION_REDLETTERWORDS, SW_OFF),
        (SW_OPTION_HEADINGS, SW_OFF),
        (SW_OPTION_VARIANTS, SW_OPTION_VARIANTS_PRIMARY),
        (SW_OPTION_LEMMAS, SW_OFF),
        (SW_OPTION_GLOSSES, SW_OFF),
        (SW_OPTION_GREEKACCENTS, SW_OFF),
        (SW_OPTION_HEBREWPOINTS, SW_OFF),
        (SW_OPTION_HEBREWCANTILLATION, SW_OFF),
    ]

    /// `-chapterBodyHTML:` reads two prefs of its own, straight out of
    /// NSUserDefaults rather than from the SWORD option state: `vplPreference`
    /// (verse-per-line) and `headingsPreference` (which gates the *preverse*
    /// heading injection the accumulator loop does itself, separately from the
    /// markup filter's own interverse emission). A capture that leaves them at
    /// whatever the simulator happens to hold is not reproducible, so each
    /// configuration pins both and restores them afterwards.
    ///
    /// Note the all-on set deliberately pins `headings` **on** even though the
    /// original capture ran with it off: the two agree byte-for-byte because
    /// every one of KJV's 138 Preverse headings is `canonical`, and the injection
    /// is gated `headings || canonical`. Asserting the existing 19 fixtures still
    /// match is what proves that.
    private struct RenderConfig {
        let name: String
        let options: [(String, String)]
        let vpl: Bool
        let headings: Bool

        static let allOn = RenderConfig(name: "all-on",
                                        options: SwordOracleCaptureTests.renderOptions,
                                        vpl: false, headings: true)
        static let allOff = RenderConfig(name: "all-off",
                                         options: SwordOracleCaptureTests.allOffRenderOptions,
                                         vpl: false, headings: false)
    }

    /// Chapters chosen to cover the edge cases the plan calls out, not for
    /// breadth. Each one exists to catch a specific way the reader can go wrong.
    private static let bibleChapters: [(ref: String, why: String)] = [
        ("Gen 1",   "book + chapter intro titles in the verse-0 slot"),
        ("Ps 3",    "canonical preverse title (Heading/Preverse bucket)"),
        ("Ps 119",  "acrostic titles throughout the chapter"),
        ("Matt 1",  "NT boundary + type=\"main\" title"),
        ("John 3",  "red-letter (Words of Christ) spans"),
        ("Gen 4",   "footnote-dense chapter"),
        ("Ps 23",   "short chapter, canonical title"),
        ("Rev 22",  "last chapter of the versification"),
    ]

    private static let commentaryChapters = ["Gen 1", "Matt 1", "Ps 23"]

    /// Sampled lexicon keys. Includes the fixed-width-padding cases that
    /// SWLD::strongsPad mishandles for prefixed input (see testStrongsPadning...).
    private static let greekKeys  = ["25", "3056", "2316", "4018", "5547"]
    private static let hebrewKeys = ["430", "1", "7225", "3068", "0430"]
    private static let morphKeys  = ["N-NSF", "V-PAI-3S", "CONJ", "PREP"]

    // MARK: - Fixture plumbing

    private static var isCapturing: Bool {
        ProcessInfo.processInfo.environment["PSORACLE_CAPTURE"] != nil
    }

    /// Fixture directory. Derived from this file's path so capture writes into
    /// the source tree rather than the simulator's data container.
    private static func fixtureDir() -> URL {
        if let override = ProcessInfo.processInfo.environment["PSORACLE_FIXTURE_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        // <repo>/Classes/SwordOracleCaptureTests.swift -> <repo>/Tests/Fixtures
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return repoRoot.appendingPathComponent("Tests/Fixtures", isDirectory: true)
    }

    /// Compare `actual` against the committed fixture named `name`, or write it
    /// when capturing. A missing fixture in assertion mode is reported as a skip
    /// rather than a failure, so the suite is green on a fresh clone before the
    /// fixtures have been generated.
    private func checkFixture(_ name: String, actual: String) throws {
        let dir = Self.fixtureDir()
        let url = dir.appendingPathComponent(name)

        if Self.isCapturing {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try actual.write(to: url, atomically: true, encoding: .utf8)
            print("[oracle] captured \(name) (\(actual.utf8.count) bytes)")
            return
        }

        guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("fixture \(name) not captured yet; run with PSORACLE_CAPTURE=1")
        }

        if expected != actual {
            // Report the first divergence rather than dumping two chapters of HTML.
            let e = Array(expected), a = Array(actual)
            var i = 0
            while i < min(e.count, a.count), e[i] == a[i] { i += 1 }
            let lo = max(0, i - 60)
            XCTFail("""
                fixture \(name) does not match live SWORD output.
                  first difference at character \(i) (expected \(e.count) chars, got \(a.count))
                  expected: …\(String(e[lo..<min(e.count, i + 60)]))…
                  actual:   …\(String(a[lo..<min(a.count, i + 60)]))…
                """)
        }
    }

    // MARK: - Pref / bookmark state (restored in tearDown)

    /// Per-module NSUserDefaults keys this test overwrote, mapped to their
    /// original values (`nil` meaning "was absent"). `-chapterBodyHTML:` reads
    /// `vplPreference_<mod>` and `headingsPreference_<mod>` directly, so a
    /// reproducible capture has to pin them — and a test that leaves them pinned
    /// would change what the *app* renders on the next launch of this simulator.
    private var savedModulePrefs: [String: Any?] = [:]

    /// `PSBookmarks.default()`'s children, saved while the highlight capture
    /// installs a synthetic bookmark set. Nothing is ever written to disk:
    /// `saveBookmarksToFile()` is deliberately not called, so the user's real
    /// PSBookmarks.plist is untouched.
    private var savedBookmarkChildren: [Any]??

    override func tearDown() {
        let defaults = UserDefaults.standard
        for (key, value) in savedModulePrefs {
            if let value = value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        savedModulePrefs = [:]

        if let saved = savedBookmarkChildren {
            PSBookmarks.default().children = saved
            savedBookmarkChildren = nil
        }
        super.tearDown()
    }

    private func pinModulePref(_ pref: String, module: String, to value: Bool) {
        let key = UserDefaults.standard.psModuleKey(pref, module)
        if savedModulePrefs[key] == nil {
            savedModulePrefs[key] = UserDefaults.standard.object(forKey: key)
        }
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - Engine readiness

    /// The bundled modules are seeded on a detached background thread from
    /// PocketSwordSceneDelegate with no completion signal, so a test that touches
    /// a module immediately after launch can race the unzip. Poll instead.
    private func waitForModules(_ names: [String], timeout: TimeInterval = 90) throws {
        guard let manager = SwordManager.default() else {
            throw XCTSkip("no SwordManager — the host app has not initialised the engine")
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if names.allSatisfy({ manager.isModuleInstalled($0) }) { return }
            // The seeding thread also needs the manager's lock; sleep rather than
            // spin so we are not contending with it.
            Thread.sleep(forTimeInterval: 0.25)
        }
        throw XCTSkip("modules \(names) not installed within \(timeout)s — seeding did not complete")
    }

    /// Pin the per-module prefs `-[SwordModule setPreferences]` reads
    /// (SwordModule.mm:190-199) to the state a given fixture was captured under.
    ///
    /// Needed by any capture that goes through `-attributeValueForEntryData:`,
    /// because that method calls `setPreferences`, which reads these keys off
    /// NSUserDefaults and pushes them into SWORD as global options — overwriting
    /// whatever `configuredModule` just set.
    ///
    /// Before this existed those two fixtures silently depended on prefs left in
    /// the simulator container by ordinary app use, and failed on a freshly-wiped
    /// one. The values below are not a guess: they are what the committed fixtures
    /// actually contain — `KJV-scriptref-attributes.txt` holds 65 Strong's anchors
    /// and zero morph / note / red-letter ones, so it was captured with Strong's on
    /// and those three off. `tearDown` restores whatever was there.
    private func pinSetPreferencesPrefs(module: String,
                                        strongs: Bool, morphs: Bool,
                                        footnotes: Bool, headings: Bool,
                                        redLetter: Bool, scriptRefs: Bool) {
        pinModulePref(Defaults.strongsPreference, module: module, to: strongs)
        pinModulePref(Defaults.morphPreference, module: module, to: morphs)
        pinModulePref(Defaults.footnotesPreference, module: module, to: footnotes)
        pinModulePref(Defaults.headingsPreference, module: module, to: headings)
        pinModulePref(Defaults.redLetterPreference, module: module, to: redLetter)
        pinModulePref(Defaults.scriptRefsPreference, module: module, to: scriptRefs)
        // The converter renders with these four Off regardless (see renderOptions).
        for pref in [Defaults.greekAccentsPreference, Defaults.hvpPreference,
                     Defaults.hebrewCantillationPreference, Defaults.glossesPreference] {
            pinModulePref(pref, module: module, to: false)
        }
    }

    private func configuredModule(_ name: String,
                                  config: RenderConfig = .allOn) throws -> SwordModule {
        try waitForModules([name])
        guard let manager = SwordManager.default() else {
            throw XCTSkip("no SwordManager")
        }
        guard let mod = manager.module(withName: name) else {
            throw XCTSkip("module \(name) not available")
        }
        for (option, value) in config.options {
            manager.setGlobalOption(option, value: value)
        }
        // -chapterBodyHTML: reads these two off NSUserDefaults itself rather than
        // from the SWORD option state, so pinning the global options is not
        // enough to make a capture reproducible.
        pinModulePref(Defaults.vplPreference, module: name, to: config.vpl)
        pinModulePref(Defaults.headingsPreference, module: name, to: config.headings)
        return mod
    }

    // MARK: - Chapter bodies

    func testCaptureKJVChapterBodies() throws {
        try captureKJVChapterBodies(config: .allOn, suffix: "")
    }

    /// The all-off endpoint — the configuration a **fresh install** renders, and
    /// the one the reader has to reproduce before the flag can be flipped on for
    /// a user who has never touched the `▾` menu.
    ///
    /// Fixture names carry an `-alloff` suffix so this set sits alongside the
    /// original 19 rather than replacing them; a divergence in either endpoint
    /// then names which one broke.
    func testCaptureKJVChapterBodiesAllOptionsOff() throws {
        try captureKJVChapterBodies(config: .allOff, suffix: "-alloff")
    }

    private func captureKJVChapterBodies(config: RenderConfig, suffix: String) throws {
        let mod = try configuredModule("KJV", config: config)
        var summary: [String] = []

        for entry in Self.bibleChapters {
            mod.aquireModuleLock()
            var entryCount: NSInteger = 0
            // applyBookmarkHighlights:NO — the highlight injection reads
            // PSBookmarks, i.e. the user's own data. The highlighted path is
            // captured separately, against a synthetic bookmark set.
            let maybeBody = mod.chapterBodyHTML(entry.ref,
                                                applyBookmarkHighlights: false,
                                                entryCount: &entryCount)
            mod.releaseModuleLock()
            let body = try XCTUnwrap(maybeBody, "\(entry.ref) returned no body")

            let safe = entry.ref.replacingOccurrences(of: " ", with: "_")
            try checkFixture("KJV-\(safe)\(suffix).html", actual: body)
            summary.append("\(entry.ref)\tentries=\(entryCount)\tbytes=\(body.utf8.count)\t\(entry.why)")

            XCTAssertGreaterThan(entryCount, 0, "\(entry.ref) produced no entries")
            XCTAssertFalse(body.isEmpty, "\(entry.ref) produced an empty body")
        }

        try checkFixture("KJV-chapter-summary\(suffix).tsv",
                         actual: summary.joined(separator: "\n") + "\n")
    }

    func testCaptureMHCCChapterBodies() throws {
        try captureMHCCChapterBodies(config: .allOn, suffix: "")
    }

    func testCaptureMHCCChapterBodiesAllOptionsOff() throws {
        try captureMHCCChapterBodies(config: .allOff, suffix: "-alloff")
    }

    private func captureMHCCChapterBodies(config: RenderConfig, suffix: String) throws {
        let mod = try configuredModule("MHCC", config: config)
        var summary: [String] = []

        for ref in Self.commentaryChapters {
            mod.aquireModuleLock()
            var entryCount: NSInteger = 0
            let maybeBody = mod.chapterBodyHTML(ref,
                                                applyBookmarkHighlights: false,
                                                entryCount: &entryCount)
            mod.releaseModuleLock()
            let body = try XCTUnwrap(maybeBody, "\(ref) returned no body")

            let safe = ref.replacingOccurrences(of: " ", with: "_")
            try checkFixture("MHCC-\(safe)\(suffix).html", actual: body)
            summary.append("\(ref)\tentries=\(entryCount)\tbytes=\(body.utf8.count)")
        }

        try checkFixture("MHCC-chapter-summary\(suffix).tsv",
                         actual: summary.joined(separator: "\n") + "\n")
    }

    /// The **production** render path, which nothing pinned before:
    /// `-getChapter:` passes `applyBookmarkHighlights:YES` (SwordModule.mm:1199),
    /// so every one of the 19 original fixtures captured a path the app never
    /// takes. `-highlightVerse:withClass:` is not a simple wrap — it walks the
    /// verse's block tags and re-opens the span after each one — so it is exactly
    /// the kind of code a reimplementation gets subtly wrong.
    ///
    /// The bookmark set is synthetic and installed only in memory:
    /// `PSBookmarks.saveBookmarksToFile()` is never called, and `tearDown`
    /// restores the singleton's children. Ps 23 is chosen because it is short
    /// enough to eyeball and its verse 1 carries a canonical preverse heading, so
    /// the fixture also pins that a highlight does not disturb heading injection.
    func testCaptureBookmarkHighlightedChapterBody() throws {
        let mod = try configuredModule("KJV", config: .allOn)

        let bookmarks = PSBookmarks.default()
        savedBookmarkChildren = bookmarks.children

        // A folder carrying the colour, holding bookmarks on Ps 23:1/:3/:6.
        // getBookmarks(forBookAndChapterRef:) stamps the folder's rgbHexString
        // onto each child at read time, which is how a bookmark gets a colour at
        // all — a bookmark with no enclosing coloured folder never highlights.
        let epoch = Date(timeIntervalSince1970: 0)
        let folder = PSBookmarkFolder(name: "oracle-highlights",
                                      dateAdded: epoch,
                                      dateLastAccessed: epoch,
                                      rgbHexString: "#FFCC00",
                                      children: ["1", "3", "6"].map {
            PSBookmark(name: "Psalms 23:\($0)",
                       dateAdded: epoch,
                       dateLastAccessed: epoch,
                       bibleReference: "Psalms 23:\($0)")
        })
        bookmarks.children = [folder]

        // Sanity-check the fixture is actually exercising the path, rather than
        // silently capturing an unhighlighted body because the ref format drifted.
        let colour = PSBookmarks.getHighlightRGBColourString(forBookAndChapterRef: "Psalms 23", withVerse: 1)
        XCTAssertEqual(colour, "rgba(255,204,0,0.8)",
                       "the synthetic bookmark set does not resolve — the highlight fixture would be a no-op")

        // "Psalms 23", not "Ps 23": the highlight lookup keys on
        // `[PSModuleController createRefString:chapter]` — the *caller's* string,
        // not SWORD's canonical key text — and the app passes the full book name
        // (PSModuleViewController hands `getBibleChapter:` a ref built from
        // DefaultsLastRef, which is seeded "Genesis 1"). Passing the abbreviation
        // renders the same bytes but silently matches no bookmark, which is why
        // the highlighted-span assertion below is not redundant with the fixture.
        mod.aquireModuleLock()
        var entryCount: NSInteger = 0
        let maybeBody = mod.chapterBodyHTML("Psalms 23",
                                            applyBookmarkHighlights: true,
                                            entryCount: &entryCount)
        mod.releaseModuleLock()
        let body = try XCTUnwrap(maybeBody, "Psalms 23 returned no body")

        try checkFixture("KJV-Ps_23-highlighted.html", actual: body)
        XCTAssertEqual(entryCount, 7, "Ps 23's loop counter changed")

        // Which verses were highlighted, derived from the body rather than
        // assumed. NOT a span count: -highlightVerse: closes and re-opens its
        // span around *every* block element inside the verse, and
        // -findNextBlockElement treats any non-self-closing tag as a block — so
        // each Strong's anchor produces another pair. Ps 23 verse 1 alone yields
        // more than 20. Segmenting on the verse anchors is the assertion that
        // actually says "verses 1, 3 and 6, and nothing else".
        var highlighted: [Int] = []
        let segments = body.components(separatedBy: "<a href=\"pocketsword:versemenu:")
        for segment in segments.dropFirst() {
            guard let verse = Int(segment.prefix(while: { $0.isNumber })) else { continue }
            if segment.contains("class=\"highlightedVerse\"") { highlighted.append(verse) }
        }
        XCTAssertEqual(highlighted, [1, 3, 6],
                       "the highlight landed on the wrong verses")
        XCTAssertTrue(body.contains("background-color:rgba(255,204,0,0.8);color:black;"),
                      "the folder's colour did not reach the injected span")
    }

    /// The loop counter that drives `id="vv{i}"` and `pocketsword:versemenu:i`
    /// is NOT the verse number — it advances even for entries the loop skips as
    /// empty or duplicate. Pin that: Gen 1 has 31 verses, so a counter equal to
    /// 31 would mean the intro slot had been dropped.
    func testChapterEntryCountIsNotAVerseCount() throws {
        let mod = try configuredModule("KJV")
        mod.aquireModuleLock()
        var entryCount: NSInteger = 0
        _ = mod.chapterBodyHTML("Gen 1", applyBookmarkHighlights: false, entryCount: &entryCount)
        mod.releaseModuleLock()

        // Measured: 32, for Gen 1's 31 verses. The counter starts at 0 on the
        // verse-0 intro slot and is incremented at the bottom of each iteration,
        // including the final one that steps out of the chapter — so it lands on
        // (verses + 1), not on the verse count and not on (verses + 2).
        // This is exactly the off-by-one the converter had to design around: it
        // stores the loop's input sequence so a Phase-3 port reproduces the
        // counter rather than recomputing it.
        XCTAssertEqual(entryCount, 32,
                       "Gen 1's loop counter changed; the vv{i} anchors and versemenu links depend on it")
    }

    /// Headings are the subtlest axis in the whole conversion, so assert the two
    /// distinct mechanisms are both actually present in the captured bodies
    /// rather than trusting the byte comparison alone.
    ///
    /// * Non-canonical titles (1,250 of KJV's 1,388) sit in intro-only entry
    ///   slots and reach the body only because Headings is On.
    /// * Canonical Psalm titles (138) are routed to
    ///   EntryAttributes["Heading"]["Preverse"] and are injected by getChapter's
    ///   own glue, not by the markup filter.
    func testCapturedBodiesContainBothHeadingMechanisms() throws {
        let mod = try configuredModule("KJV")

        mod.aquireModuleLock()
        var count: NSInteger = 0
        let gen1 = mod.chapterBodyHTML("Gen 1", applyBookmarkHighlights: false, entryCount: &count)
        let ps3 = mod.chapterBodyHTML("Ps 3", applyBookmarkHighlights: false, entryCount: &count)
        mod.releaseModuleLock()

        // Genesis 1's intro slots carry <title type="main"> and
        // <title type="chapter">CHAPTER 1.</title>, emitted unclassed as
        // <p><b>…</b></p> by osishtmlhref.cpp:439.
        let g = try XCTUnwrap(gen1)
        XCTAssertTrue(g.contains("<p><b>"),
                      "Gen 1 body lost its intro titles — Headings is probably Off")
        XCTAssertTrue(g.uppercased().contains("CHAPTER 1"),
                      "Gen 1 body lost the chapter title specifically")

        // Psalm 3's canonical title is a preverse heading.
        let p = try XCTUnwrap(ps3)
        XCTAssertTrue(p.contains("<p><b>"),
                      "Ps 3 body lost its canonical preverse title")
    }

    // MARK: - Lexicons

    func testCaptureLexiconEntries() throws {
        let cases: [(module: String, keys: [String])] = [
            ("StrongsRealGreek", Self.greekKeys),
            ("StrongsRealHebrew", Self.hebrewKeys),
            ("Robinson", Self.morphKeys),
        ]

        for c in cases {
            guard let dict = try configuredModule(c.module) as? SwordDictionary else {
                XCTFail("\(c.module) is not a SwordDictionary")
                continue
            }
            var lines: [String] = []
            for key in c.keys {
                let entry = dict.entry(forKey: key) ?? "<nil>"
                lines.append("### key=\(key)")
                lines.append(entry)
            }
            try checkFixture("\(c.module)-entries.txt", actual: lines.joined(separator: "\n") + "\n")
        }
    }

    /// Documents a real, user-visible SWORD bug that Phase 3 is expected to FIX,
    /// so the fix is not later mistaken for a regression.
    ///
    /// `SWLD::strongsPad` (swld.cpp:124-167) pads a numeric key to 5 digits, but
    /// when the key carries a leading `G`/`H` it advances past the letter and
    /// pads to *4* digits without re-prepending it — so `"H430"` becomes
    /// `"0430"`, which is not a key. `rawstr4.cpp:234-241` then snaps to a
    /// neighbouring entry and sets no error, silently returning the wrong
    /// definition.
    ///
    /// The app itself is unaffected today because it passes the bare number
    /// (osishtmlhref.cpp:66 strips the prefix), which is the path asserted first.
    func testStrongsPaddingBareNumbersAreCorrectPrefixedAreNot() throws {
        guard let dict = try configuredModule("StrongsRealHebrew") as? SwordDictionary else {
            XCTFail("StrongsRealHebrew is not a SwordDictionary")
            return
        }

        // The path the app actually uses: a bare number pads to 5 digits.
        let bare = dict.entry(forKey: "430")
        XCTAssertNotNil(bare, "bare Strong's number should resolve")
        XCTAssertEqual(dict.entry(forKey: "0430"), bare,
                       "'430' and '0430' must resolve to the same entry (strongsPad zero-fills)")

        // The broken path, recorded as-is. If Phase 3 makes this return nil, that
        // is the intended fix -- update this test and say so.
        let prefixed = dict.entry(forKey: "H430")
        if prefixed == bare {
            XCTFail("unexpected: 'H430' now matches '430'; strongsPad behaviour changed")
        } else {
            let note = """
                strongsPad drops a leading G/H without re-prepending it, so 'H430'
                pads to '0430' (4 digits) and rawstr4 snaps to a neighbour with no
                error set. Phase 3 must return nil on a miss instead.
                  entry(forKey: "430")  -> \(bare?.prefix(60) ?? "<nil>")…
                  entry(forKey: "H430") -> \(prefixed?.prefix(60) ?? "<nil>")…
                """
            try checkFixture("strongsPad-prefixed-key-bug.txt", actual: note + "\n")
        }
    }

    // MARK: - Notes and cross-references

    /// `attributeValueForEntryData:` is the footnote / xref / scriptRef lookup
    /// that PSInfoPopupViewController drives. Capture its output shape for both
    /// the string case (`type=n`) and the array-of-dictionaries case
    /// (`type=scriptRef`).
    func testCaptureFootnoteAndScriptRefAttributes() throws {
        let mod = try configuredModule("KJV")
        // -attributeValueForEntryData: calls setPreferences, which re-reads the
        // per-module prefs and overwrites the options set above. These are the
        // values the committed fixture was captured under.
        pinSetPreferencesPrefs(module: "KJV", strongs: true, morphs: false,
                               footnotes: false, headings: false,
                               redLetter: false, scriptRefs: false)
        var lines: [String] = []

        // Passages verified to carry footnotes in the KJV module (`value` is the
        // swordFootnote number the anchor embedded). Esther 1:19 carries four,
        // which exercises marker numbering beyond the first.
        //
        // All 6,959 of KJV's notes are type="study" with an empty refList -- the
        // module emits no type="crossReference" notes at all -- so the `x` branch
        // of attributeValueForEntryData: (which parses refList into a ListKey) is
        // unreachable for the shipped content and is deliberately not captured.
        for (passage, value) in [("Genesis 4:1", "1"),
                                 ("Genesis 4:10", "1"),
                                 ("Esther 1:19", "1"),
                                 ("Esther 1:19", "4")] {
            // ATTRTYPE_* / SW_OUTPUT_*_KEY come from SwordModule.h via the test
            // bridging header, so the keys cannot drift from the Obj-C side.
            let data: [AnyHashable: Any] = [
                ATTRTYPE_PASSAGE: passage,
                ATTRTYPE_VALUE: value,
                ATTRTYPE_TYPE: "n",
                ATTRTYPE_MODULE: "KJV",
            ]
            let result = mod.attributeValue(forEntryData: data)
            lines.append("### footnote passage=\(passage) value=\(value)")
            lines.append(Self.describe(result))
        }

        try checkFixture("KJV-footnote-attributes.txt", actual: lines.joined(separator: "\n") + "\n")
    }

    /// **RETARGETED in Phase 4 step 8.** The fixture is unchanged; what produces it
    /// is now `PSRefParser` + `PSContentStore` + `PSChapterExpander` instead of
    /// `-[SwordModule attributeValueForEntryData:]`'s deleted `scriptRef` branch.
    ///
    /// The retarget is possible because of a measured property of the store: a
    /// chapter record's slot index **is** the verse number (`entry_count ==
    /// verseMax[chapter-1] + 1` for all 1,189 chapters, slot 0 being the verse-0
    /// intro), so `chapterRecords()[verse]` expanded at the fixture's option
    /// endpoint reproduces the engine's per-verse HTML byte-for-byte — 6/6 refs,
    /// including the one range.
    ///
    /// So this keeps its value as a golden fixture *and* becomes the grammar test
    /// for the parser: it exercises the abbreviated forms ("Gen 1:1", "Ps 23:1-3"),
    /// the in-chapter range, the display format ("Psalms 23:1"), and — added here —
    /// the three refs that pin the `name`-vs-`longName` choice for the 18 books
    /// where they differ ("1 Cor 13:4", "III John 1", "Rev 22:21").
    ///
    /// The old version had to pin `-setChapter:` first, because the engine branch
    /// seeded `parseVerseList` from `[PSModuleController getCurrentBibleRef]` —
    /// ambient global state. `PSRefParser` takes its context explicitly and needs no
    /// such pin, which is the whole point of that design choice.
    func testCaptureScriptRefAttributes() throws {
        guard let store = PSContentStore.shared,
              let resolver = PSBookOSISResolver.shared,
              let parser = PSRefParser() else {
            throw XCTSkip("store / resolver / parser unavailable")
        }

        // The fixture's option endpoint: Strong's on, everything else off.
        let options = PSChapterExpander.Options(strongs: true, morphs: false,
                                                footnotes: false, redLetter: false,
                                                headings: false)

        var lines: [String] = []
        for ref in ["Gen 1:1", "John 3:16", "Ps 23:1-3", "Rom 8:28"] {
            lines.append("### scriptRef value=\(ref)")
            guard let parsed = parser.parse(ref) else {
                XCTFail("PSRefParser rejected '\(ref)'")
                continue
            }
            guard let records = store.chapterRecords(module: "KJV",
                                                     bookOsis: parsed.book.osisName,
                                                     chapter: parsed.chapter) else {
                XCTFail("KJV \(ref) is not in the store")
                continue
            }
            // The engine emitted one {ref, text} pair per verse of the range.
            var out = ["array(\(parsed.endVerse - parsed.verse + 1)):"]
            for verse in parsed.verse...parsed.endVerse {
                guard verse < records.records.count,
                      let html = PSChapterExpander.expand(records.records[verse], options: options) else {
                    XCTFail("KJV \(ref) verse \(verse): no record / expansion failed")
                    continue
                }
                // The engine's OutputRefKey is the module's own key text, which uses
                // the localised long name ("Psalms 23:1", "I Corinthians 13:4").
                out.append("  ref=\(parsed.book.localisedName) \(parsed.chapter):\(verse)")
                out.append("  text=\(html)")
            }
            lines.append(out.joined(separator: "\n"))
        }

        try checkFixture("KJV-scriptref-attributes.txt", actual: lines.joined(separator: "\n") + "\n")
    }

    /// The grammar cases that pin the `name`-vs-`longName` choice, kept separate
    /// from the committed fixture so adding them does not require a recapture.
    ///
    /// 18 of the 66 books have `name != longName`, and these three are the ones a
    /// wrong choice would show up in: a numbered book, a roman-numeral spelling, and
    /// Revelation (whose longName carries the " of John " that createRefString
    /// strips).
    func testScriptRefGrammarPinsTheNameVersusLongNameChoice() throws {
        guard let store = PSContentStore.shared, let parser = PSRefParser() else {
            throw XCTSkip("store / parser unavailable")
        }
        let cases: [(input: String, osis: String, chapter: Int, verse: Int,
                     name: String, localised: String)] = [
            ("1 Cor 13:4",  "1Cor", 13, 4,  "1 Corinthians", "I Corinthians"),
            ("III John 1",  "3John", 1, 1,  "3 John",        "III John"),
            ("Rev 22:21",   "Rev",  22, 21, "Revelation",    "Revelation of John"),
        ]
        for c in cases {
            guard let parsed = parser.parse(c.input) else {
                XCTFail("PSRefParser rejected '\(c.input)'")
                continue
            }
            XCTAssertEqual(parsed.book.osisName, c.osis, "'\(c.input)': wrong book")
            XCTAssertEqual(parsed.chapter, c.chapter)
            XCTAssertEqual(parsed.verse, c.verse)
            // `name` is the munged display form the app persists; `localisedName` is
            // what the engine's key text used. Both must be what the table says.
            XCTAssertEqual(parsed.book.name, c.name)
            XCTAssertEqual(parsed.book.localisedName, c.localised)
            XCTAssertEqual(parsed.chapterRef, "\(c.name) \(c.chapter)")
            // And the verse actually exists in the store.
            guard let records = store.chapterRecords(module: "KJV", bookOsis: c.osis,
                                                     chapter: c.chapter) else {
                XCTFail("KJV \(c.input) is not in the store")
                continue
            }
            XCTAssertGreaterThan(records.records.count, c.verse,
                                 "'\(c.input)': slot \(c.verse) is out of range")
            XCTAssertFalse(records.records[c.verse].isEmpty,
                           "'\(c.input)': slot \(c.verse) is empty")
        }
    }

    /// Renders `attributeValue(forEntryData:)`'s heterogeneous return (NSString
    /// for note bodies, NSArray of {OutputRefKey, OutputTextKey} for reference
    /// lists) into a stable, diffable text form.
    private static func describe(_ value: Any?) -> String {
        switch value {
        case nil:
            return "<nil>"
        case let s as String:
            return "string: \(s)"
        case let arr as [Any]:
            var out = ["array(\(arr.count)):"]
            for element in arr {
                if let dict = element as? [AnyHashable: Any] {
                    let ref = dict[SW_OUTPUT_REF_KEY] as? String ?? "<no-ref>"
                    let text = dict[SW_OUTPUT_TEXT_KEY] as? String ?? "<no-text>"
                    out.append("  ref=\(ref)")
                    out.append("  text=\(text)")
                } else {
                    out.append("  \(element)")
                }
            }
            return out.joined(separator: "\n")
        case let dict as [AnyHashable: Any]:
            let ref = dict[SW_OUTPUT_REF_KEY] as? String ?? "<no-ref>"
            let text = dict[SW_OUTPUT_TEXT_KEY] as? String ?? "<no-text>"
            return "dict: ref=\(ref) text=\(text)"
        default:
            return "other: \(String(describing: value))"
        }
    }

    // MARK: - Fold-equivalence guard

    /// `PSFoldForIndex` (Obj-C, index side) and `PSSearchQuery.foldForIndex`
    /// (Swift, query side) are a byte-for-byte duplicated algorithm. Both files
    /// warn about the duplication in prose and neither had an executable guard —
    /// if they drift, queries silently stop matching the rows the index built.
    ///
    /// Fixtures come from the **lexicon** entries rather than KJV verses: the
    /// index's `text_norm` column is built from KJV `stripText()`, which is plain
    /// English and exercises almost none of the Hebrew-points / polytonic-Greek
    /// ranges the fold actually targets.
    func testFoldForIndexAgreesBetweenObjCAndSwift() throws {
        var samples: [String] = [
            "",
            "plain ascii text",
            "MiXeD CaSe",
            // Greek polytonic (U+0300-U+036F after NFD)
            "ἀγάπη", "Θεός", "λόγος", "περιβόλαιον",
            // Hebrew with points + cantillation (U+0591-U+05C7)
            "אֱלֹהִים", "בְּרֵאשִׁית", "יְהוָ֣ה", "חֹשֶׁךְ",
            // Latin diacritics, precomposed and decomposed
            "café", "cafe\u{0301}", "pilchâ'", "zeh'-eek",
            // Non-BMP, to exercise the surrogate-pair branch
            "𝔊𝔯𝔢𝔢𝔨 text", "😀 emoji",
            // Combining marks from the other dropped ranges
            "a\u{20D0}b", "x\u{FE20}y", "q\u{1DC0}r",
        ]

        // Plus real lexicon text, which is where the exotic ranges actually live.
        if let greek = try? configuredModule("StrongsRealGreek") as? SwordDictionary,
           let entry = greek.entry(forKey: "25") {
            samples.append(entry)
        }
        if let hebrew = try? configuredModule("StrongsRealHebrew") as? SwordDictionary,
           let entry = hebrew.entry(forKey: "430") {
            samples.append(entry)
        }

        for sample in samples {
            let objc = PSFoldForIndex(sample)
            let swift = PSSearchQuery.foldForIndex(sample)
            XCTAssertEqual(objc, swift,
                           "fold mismatch for \(sample.debugDescription): Obj-C \(objc.debugDescription) vs Swift \(swift.debugDescription)")
        }
    }

    /// The display-side cleaner is only defined in Obj-C, but Phase 3 has to
    /// reproduce it, so pin its behaviour on the marker forms SWORD emits.
    func testCleanDisplayTextStripsInlineMarkers() {
        XCTAssertEqual(PSSearchCleanDisplayText("And God <H0430> divided <H0996> the light"),
                       "And God divided the light")
        XCTAssertEqual(PSSearchCleanDisplayText("word <TH8799> in <TG5707> place"),
                       "word in place")
        XCTAssertEqual(PSSearchCleanDisplayText("in the field <H7704> , and"),
                       "in the field, and")
        XCTAssertEqual(PSSearchCleanDisplayText("a [] b"), "a b")
        XCTAssertEqual(PSSearchCleanDisplayText(""), "")
    }

    // MARK: - Phase 5 pre-work: the last two engine-only fixtures
    //
    // Added by SWORD_REMOVAL_PLAN.md Phase 5 pre-work item 2, immediately before
    // the engine is deleted. Same job as the rest of this file — capture what the
    // deletion is about to make uncheckable — for the two things Phase 5 removes
    // the last executable check for:
    //
    //  1. search-index-KJV.digest — all 31,102 rows of the *engine-built* FTS
    //     index. PSSearchIndexParityTests builds it both ways in one process and
    //     compares; with no engine there is no second way, so the engine's answer
    //     has to be on disk. Digested rather than stored in full: SHA-256 per text
    //     column is ~3 MB against ~8 MB, and is still row-exact.
    //  2. chapter-loop-counters.tsv — entryCount for all 1,189 chapters of both
    //     modules. Today exactly one value of it is pinned (Gen 1 == 32, above);
    //     after this, all 2,378 are.

    /// SHA-256, **truncated to its leading 64 bits**.
    ///
    /// The digest is a change detector, not a commitment scheme: it has to make any
    /// byte change in any column change the line, and nothing more. 64 bits does
    /// that with a ~2^-64 per-row miss probability, and keeps the committed fixture
    /// at ~2.7 MB instead of the 8.7 MB full hex costs — a difference that matters
    /// for a file that goes into git and is read on every test run.
    private static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // `testCaptureEngineBuiltSearchIndexDigest` lived here and has been **removed**
    // by Phase 5 step 1, having done its one job.
    //
    // It forced `swiftContentReader` off so that `-buildWithProgress:` would take
    // the SWORD walk rather than the store, and digested the result into
    // `Tests/Fixtures/search-index-KJV.digest`. Step 1 retires that flag and makes
    // the store path unconditional, so the engine walk can no longer be *selected* —
    // which means the capture can no longer capture the engine, and keeping it would
    // have silently started digesting the store into its own oracle.
    //
    // The fixture it produced is committed and is now the acceptance criterion in
    // `PSSearchIndexParityTests.testStoreBuiltIndexMatchesTheEngineDigest`. Do not
    // recreate this capture.

    /// `entryCount` for all 1,189 chapters of both shipped modules.
    ///
    /// Captured at one option endpoint; the companion test below proves that is
    /// not a loss of coverage, because the counter is driven by the module's entry
    /// sequence rather than by the emitted markup.
    func testCaptureChapterLoopCounters() throws {
        guard let resolver = PSBookOSISResolver.shared else { throw XCTSkip("no resolver") }
        var out = ["# live-SWORD chapter loop counters (-chapterBodyHTML:'s entryCount)",
                   "# format: module\tref\tentryCount",
                   "# NOT a verse count: the counter advances for entries the loop skips",
                   "# and for the final iteration that steps out of the chapter."]
        var total = 0

        for module in ["KJV", "MHCC"] {
            // configuredModule pins vpl/headings and registers them for tearDown.
            let mod = try configuredModule(module, config: .allOff)
            for book in resolver.books {
                for chapter in 1...book.chapterCount {
                    let ref = "\(book.name) \(chapter)"
                    mod.aquireModuleLock()
                    var entryCount: NSInteger = 0
                    _ = mod.chapterBodyHTML(ref, applyBookmarkHighlights: false, entryCount: &entryCount)
                    mod.releaseModuleLock()
                    out.append("\(module)\t\(ref)\t\(entryCount)")
                    total += 1
                }
            }
        }

        print("[oracle] loop counters captured: \(total)")
        XCTAssertEqual(total, 2378, "1,189 chapters x 2 modules")
        try checkFixture("chapter-loop-counters.tsv", actual: out.joined(separator: "\n") + "\n")
    }

    /// The invariant that licenses capturing the counter at one endpoint only:
    /// `entryCount` does not depend on the render options.
    ///
    /// It should not — the counter is incremented once per entry the `do…while`
    /// visits and the loop's continuation test is on the *key*, not on the
    /// rendered markup — but "should not" is exactly what a fixture is for.
    func testLoopCounterIsIndependentOfRenderOptions() throws {
        guard let resolver = PSBookOSISResolver.shared else { throw XCTSkip("no resolver") }

        var flat: [String] = []
        for book in resolver.books {
            for chapter in 1...book.chapterCount { flat.append("\(book.name) \(chapter)") }
        }
        // Stride 37 — prime, so unaligned to book boundaries. ~32 chapters.
        let refs = flat.enumerated().filter { $0.offset % 37 == 0 }.map(\.element)

        var seen: [String: NSInteger] = [:]
        var compared = 0
        for module in ["KJV", "MHCC"] {
            for config in [RenderConfig.allOn, RenderConfig.allOff] {
                let mod = try configuredModule(module, config: config)
                for ref in refs {
                    mod.aquireModuleLock()
                    var count: NSInteger = 0
                    _ = mod.chapterBodyHTML(ref, applyBookmarkHighlights: false, entryCount: &count)
                    mod.releaseModuleLock()
                    let key = "\(module)|\(ref)"
                    if let first = seen[key] {
                        XCTAssertEqual(first, count,
                                       "\(module) \(ref): the loop counter changed with the render options — "
                                       + "chapter-loop-counters.tsv would only cover one endpoint")
                        compared += 1
                    } else {
                        seen[key] = count
                    }
                }
            }
        }
        print("[oracle] counter-invariance comparisons: \(compared)")
        XCTAssertGreaterThan(compared, 50, "the sample collapsed")
    }
}
