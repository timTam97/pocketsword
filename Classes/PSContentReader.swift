//
//  PSContentReader.swift
//  PocketSword
//
//  The coordinating layer over the pure-Swift content reader: the single thing
//  the view controllers talk to. Phase 3 of SWORD_REMOVAL_PLAN.md.
//
//  Composes PSContentStore (rows) + PSBookOSISResolver (name -> OSIS) +
//  PSChapterExpander (tokens -> HTML) + PSChapterAssembler (the accumulator loop),
//  and adds the things those four deliberately do not know about: which module is
//  being read, the per-module option prefs, the bookmark highlight lookup, the
//  bottom padding, the navigation JS, the HTML shell, and language/direction.
//
//  === FAILURE POLICY (Phase 5 step 1: no engine to fall back to) ===
//
//  Through Phase 4 every failure took one path — report through
//  `PSContentStore.fail` and return nil, so the caller fell back to SWORD. There
//  is no SWORD any more, so "return nil" now means "show the user nothing". The
//  ten conditions are therefore **split by whether the app can still function**:
//
//  FATAL (the store itself is unusable — every read would fail, so the app cannot
//  do its job at all). These call `PSContentStore.fatal`, which traps. A crash
//  report naming the broken invariant beats a permanently blank app that looks
//  like it merely lost its data:
//
//    1. Resources/PSContent.sqlite absent from the bundle, or unopenable.
//    2. content_meta schemaVersion != 2 or tokenGrammar != "v2".
//    3. content_meta missing the chunkRows.* sizes.
//    4. Resources/Versification-KJV.json absent, unparseable, or not 66 books.
//
//  All four are build-integrity failures: the store and the versification JSON are
//  bundled resources, validated by PSContentStoreTests, and cannot vary at
//  runtime. If one of them is wrong, every install of that build is wrong — which
//  is exactly the class of bug that must not ship quietly.
//
//  LOUD-AND-NIL (one datum is bad; the rest of the store is fine). These keep
//  reporting through `PSContentStore.fail` — assertionFailure in debug, alog in
//  release — and return nil. One malformed chapter must not brick the app; the
//  user sees that one chapter fail and can navigate away:
//
//    5. A chunk that fails to inflate, or whose row_count / raw_size disagrees
//       with its blob.
//    6. A chapter blob whose record count disagrees with entry_count.
//    7. An MHCC body id that does not resolve in `bodies`.
//    8. A malformed token stream (unterminated token, wrong field count, unknown
//       Strong's flag).
//    9. An unresolvable book name, or a chapter outside the book.
//   10. A dict_keys / notes_index row pointing at a slot its chunk does not have.
//
//  Note what is in NEITHER list, because it is normal rather than a failure:
//  a chapter absent from `chapters` (the converter omits wholly-empty ones, and
//  the reader renders the same "empty chapter" message the engine did), and a
//  dictionary or note lookup that simply misses (nil is the right answer).
//

import Foundation

@objc(PSContentReader)
final class PSContentReader: NSObject {

    @objc(sharedReader)
    static let shared = PSContentReader()

    /// nil when the store failed to open or validate. Held rather than re-fetched
    /// so the failure is reported once, at first use, not on every page turn.
    private let store: PSContentStore?
    private let resolver: PSBookOSISResolver?

    override init() {
        store = PSContentStore.shared
        resolver = PSBookOSISResolver.shared
        super.init()
    }

    /// Whether the reader is usable at all.
    ///
    /// Phase 5 retired `isActive` (the feature flag's *intent* half) and collapsed
    /// every caller onto this. In practice it is always true in production: the two
    /// things it checks are the store and the versification dump, and both are now
    /// fatal if absent. It stays because the tests construct readers over broken
    /// stores, and because `false` is a more useful thing for a test to assert than
    /// a trap.
    @objc var isAvailable: Bool { store != nil && resolver != nil }

    // MARK: - Lexicon lookups
    //
    // The lexicon call sites (`PSDictionaryViewController`,
    // `PSDictionaryEntryViewController`, `PSModuleViewController`,
    // `PSTabBarControllerDelegate`) used to hold a `SwordDictionary` and pass it as
    // an `or:` fallback. Phase 5 step 1 drops that parameter everywhere: a miss is
    // now simply a miss, and nil is the right answer for one.

    /// A lexicon entry for `key`, or nil if the lexicon does not have it.
    @objc(entryForModule:key:)
    static func entry(module: String, key: String?) -> String? {
        guard let key else { return nil }
        return shared.dictionaryEntry(module: module, key: key)
    }

    /// Every key of a lexicon, in the module's own order and true casing.
    @objc(allKeysForModule:)
    static func allKeys(module: String) -> [String] {
        shared.dictionaryKeys(module: module)
    }

    /// How many entries a lexicon has.
    @objc(entryCountForModule:)
    static func entryCount(module: String) -> Int {
        shared.dictionaryEntryCount(module: module)
    }

    /// The **`n` branch only** of `-[SwordModule attributeValueForEntryData:]` —
    /// which, as of Phase 4 step 8, is the only branch of it that renders content.
    ///
    /// The `x` (cross-reference) and `scriptRef` branches are **deleted**: both were
    /// proven unreachable for the shipped content (no `x` anchor is ever emitted and
    /// all 6,959 notes are type='study' with an empty refList; no `action=showRef`
    /// appears in any chapter record or stored heading, and every one of the 14,989
    /// baked `sword://` links routes to the dictionary arm). See PSRefSemanticsTests.
    @objc(footnoteBodyForModule:data:)
    static func footnoteBody(module: String?, data: [AnyHashable: Any]) -> String? {
        guard let module,
              let passage = data[ATTRTYPE_PASSAGE] as? String,
              let marker = data[ATTRTYPE_VALUE] as? String else {
            return nil
        }
        return shared.noteBody(module: module, osisRef: passage, marker: marker)
    }

    // MARK: - Options

    /// Load the render options for a module from the **per-module** prefs.
    ///
    /// The keys are `"<pref>_<ModuleName>"`, matching `-[SwordModule setPreferences]`
    /// (SwordModule.mm:188-213) exactly — and matching it is load-bearing, because
    /// `setPreferences` reads those same per-module keys and pushes them into SWORD
    /// as *global* options on every render. A reader reading the unsuffixed global
    /// keys instead would disagree with SWORD for any user who had touched the
    /// per-tab `▾` menu.
    ///
    /// `setPreferences` pushes eleven options; only five have a token to gate:
    ///
    ///  * scriptRefs / strongs / morphs / headings / footnotes / redLetter — gated
    ///    here (scriptRefs shares `footnotes`' tokens: the note anchors carry
    ///    type='n' and type='x', and the x-branch is the cross-reference one).
    ///  * variants — SWORD is pinned to "Primary Reading" unconditionally, so
    ///    there is nothing to vary.
    ///  * glosses, greekAccents, hebrewPoints, hebrewCantillation — these act on
    ///    *source text* during rendering, not on emitted markup, so they have no
    ///    token. For the five shipped modules that is a no-op: KJV/MHCC declare
    ///    none of OSISGlosses / UTF8GreekAccents / UTF8HebrewPoints /
    ///    UTF8Cantillation in GlobalOptionFilter, so the filters are not even in
    ///    their chains and the option cannot change a byte. The baked store was
    ///    captured with all four Off, which is also their default. A module that
    ///    DID declare one would need its own axis — recorded here because it is
    ///    the one place the reader is narrower than the engine.
    func options(forModule module: String) -> PSChapterExpander.Options {
        let defaults = UserDefaults.standard
        var options = PSChapterExpander.Options()
        options.strongs = defaults.psBool(Defaults.strongsPreference, forModule: module)
        options.morphs = defaults.psBool(Defaults.morphPreference, forModule: module)
        options.headings = defaults.psBool(Defaults.headingsPreference, forModule: module)
        options.redLetter = defaults.psBool(Defaults.redLetterPreference, forModule: module)
        // Footnotes and cross-references are separate toggles in the UI but share
        // the note token family: 'n' is a footnote, 'x' a cross-reference. All
        // 6,959 of KJV's notes are type='study' with an empty refList (the module
        // emits no type="crossReference" notes at all), so no `x` token exists in
        // the shipped content and the two axes are indistinguishable on it. Gate on
        // footnotes, which is the one that has any effect.
        options.footnotes = defaults.psBool(Defaults.footnotesPreference, forModule: module)
        return options
    }

    // MARK: - Chapter rendering

    /// The body only — the equivalent of `-[SwordModule chapterBodyHTML:…]`, and
    /// what the differential test compares.
    ///
    /// `ref` is the caller's ref string ("Genesis 1" / "Gen 1"), used both for
    /// resolution and — unchanged — for the bookmark-highlight lookup, which keys
    /// on `createRefString(ref)` rather than on SWORD's canonical key text.
    func chapterBody(module: String,
                     ref: String,
                     kind: PSChapterAssembler.ModuleKind,
                     applyBookmarkHighlights: Bool,
                     options: PSChapterExpander.Options? = nil,
                     reportFailures: Bool = true) -> (body: String, entryCount: Int)? {
        guard let store, let resolver else {
            PSContentStore.fail("reader is unavailable", report: reportFailures)
            return nil
        }
        guard let (book, chapter) = resolver.resolve(ref: ref) else {
            PSContentStore.fail("cannot resolve ref '\(ref)'", report: reportFailures)
            return nil
        }
        let opts = options ?? self.options(forModule: module)

        guard let records = store.chapterRecords(module: module,
                                                 bookOsis: book.osisName,
                                                 chapter: chapter) else {
            // Not a failure: the converter omits wholly-empty chapters, and the
            // engine renders the same message for them.
            return (emptyChapterBody(bookName: book.name, chapter: chapter), 0)
        }
        // Headings are keyed by the module's own key text, which uses the LONG
        // (roman-numeral) book name: "I Corinthians 1:1", not "1 Corinthians 1:1".
        let headings = store.headings(module: module, bookName: book.longName, chapter: chapter)

        var expanded: [String] = []
        expanded.reserveCapacity(records.records.count)
        for record in records.records {
            if record.isEmpty {
                expanded.append("")
                continue
            }
            guard let html = PSChapterExpander.expand(record, options: opts, reportFailures: reportFailures) else {
                // expand() has already reported the specific malformation.
                return nil
            }
            expanded.append(html)
        }

        var config = PSChapterAssembler.Config()
        config.kind = kind
        config.versePerLine = UserDefaults.standard.psBool(Defaults.vplPreference, forModule: module)
        config.headingsOn = opts.headings

        // The highlight lookup takes the CALLER's ref through createRefString, the
        // same as SwordModule.mm:1157 — "Psalms 23", not SWORD's "Ps 23". Passing
        // the abbreviation renders identical bytes but silently matches no
        // bookmark, so this is not interchangeable.
        let highlightRef = applyBookmarkHighlights ? PSRefHelper.createRefString(ref) : nil

        guard let result = PSChapterAssembler.assemble(
            records: expanded,
            headings: headings,
            config: config,
            headingHTML: { PSChapterExpander.expand($0.html, options: opts.forHeading) },
            highlightColour: { verse in
                guard let highlightRef else { return nil }
                return PSBookmarks.getHighlightRGBColourString(forBookAndChapterRef: highlightRef,
                                                               withVerse: verse)
            },
            emptyChapterMessage: self.emptyChapterBody(bookName: book.name, chapter: chapter))
        else {
            return nil
        }
        return (result.body, result.entryCount)
    }

    /// The typed chapter document the native SwiftUI reader renders — Wave 9's
    /// replacement for `chapterPage`.
    ///
    /// Same inputs, same option prefs, same bookmark-highlight lookup as
    /// `chapterBody`; the difference is that it emits `ChapterDocument` values
    /// instead of HTML, so there is no shell, no CSS, no navigation JS and no six
    /// `&nbsp;` pads. See `PSChapterDocument.swift` for why the token stream gets a
    /// second emitter rather than the HTML being parsed.
    ///
    /// `PSChapterDocumentParityTests` asserts this agrees with `chapterBody` on
    /// text, verse identity, `entryCount` and every link target, for all 1,189
    /// chapters × both modules × both option endpoints.
    func chapterDocument(module: String,
                         ref: String,
                         kind: PSChapterAssembler.ModuleKind,
                         options: PSChapterExpander.Options? = nil,
                         applyBookmarkHighlights: Bool = true,
                         reportFailures: Bool = true) -> ChapterDocument? {
        guard let store, let resolver else {
            PSContentStore.fail("reader is unavailable", report: reportFailures)
            return nil
        }
        guard let (book, chapter) = resolver.resolve(ref: ref) else {
            PSContentStore.fail("cannot resolve ref '\(ref)'", report: reportFailures)
            return nil
        }
        let opts = options ?? self.options(forModule: module)

        guard let records = store.chapterRecords(module: module,
                                                 bookOsis: book.osisName,
                                                 chapter: chapter) else {
            // Not a failure: the converter omits wholly-empty chapters. Same
            // message the engine rendered, now as a document field.
            var document = ChapterDocument()
            document.emptyMessage = emptyChapterMessage(bookName: book.name,
                                                        chapter: chapter)
            return document
        }
        // Headings are keyed by the module's own key text, which uses the LONG
        // (roman-numeral) book name — see `chapterBody`.
        let headings = store.headings(module: module,
                                      bookName: book.longName,
                                      chapter: chapter)

        var config = PSChapterDocumentBuilder.Config()
        config.kind = kind
        config.headingsOn = opts.headings

        // The highlight lookup takes the CALLER's ref through createRefString, not
        // SWORD's abbreviation — passing "Ps 23" renders identical text but matches
        // no bookmark. Identical to `chapterBody`; not interchangeable.
        let highlightRef = applyBookmarkHighlights
            ? PSRefHelper.createRefString(ref)
            : nil

        return PSChapterDocumentBuilder.build(
            records: records.records,
            headings: headings,
            config: config,
            options: opts,
            highlightColour: { verse in
                guard let highlightRef else { return nil }
                return PSBookmarks.getHighlightRGBColourString(
                    forBookAndChapterRef: highlightRef,
                    withVerse: verse
                )
            },
            emptyChapterMessage: self.emptyChapterMessage(bookName: book.name,
                                                          chapter: chapter),
            reportFailures: reportFailures)
    }

    // `chapterPage` is DELETED (Wave 9). It assembled the full HTML document the
    // WebView loaded: the rendered body, six hardcoded `<p>&nbsp;</p>` pads (a
    // faithful port of `-getChapter:`'s own six), `PSChapterNavigationJS`'s two
    // script blocks, the `createHTMLString` shell, and the RTL/lang substitutions.
    // Every part of it existed to serve a WebView:
    //
    //  * the pads are `contentMargins` now, scaled to the real bar height rather
    //    than to six line heights of a font size they did not know;
    //  * the JS is gone entirely — see `ReaderPaneModel`'s table;
    //  * the shell's CSS is resolved type and colour in `ChapterTextRenderer`;
    //  * the RTL/lang substitutions were **no-ops for all five shipped modules**
    //    (every one is `Lang=en` with no `Direction=`), and direction is now the
    //    view's own concern.
    //
    // `chapterBody` is KEPT, and deliberately: it is the fixture-pinned oracle that
    // `PSChapterDocumentParityTests` compares the native document against, and those
    // fixtures were captured from a SWORD engine that no longer exists.

    /// The engine's own empty-chapter fallback (SwordModule.mm:1181), including
    /// that the parenthesised ref is SWORD's `ch` — the chapter part of the key
    /// text, e.g. "Genesis 1".
    private func emptyChapterBody(bookName: String, chapter: Int) -> String {
        let message = NSLocalizedString("EmptyChapterWarning", comment: "This chapter is empty for this module.")
        return "<p style=\"color:grey;text-align:center;font-style:italic;\">\(message) (\(bookName) \(chapter))</p>"
    }

    /// The same message as plain text, for the native reader.
    ///
    /// `emptyChapterBody` wraps it in the `<p style="…">` the engine emitted; the
    /// native reader styles the notice itself, so it wants the string alone. Both
    /// read the one localisation key, so the two cannot drift.
    private func emptyChapterMessage(bookName: String, chapter: Int) -> String {
        let message = NSLocalizedString("EmptyChapterWarning", comment: "This chapter is empty for this module.")
        return "\(message) (\(bookName) \(chapter))"
    }

    // MARK: - Lexicons

    /// A lexicon entry for the key the UI holds. See PSContentStore.dictEntry for
    /// the casing and zero-padding rules, and step 4b's tests for why they matter.
    @objc(dictionaryEntryForModule:key:)
    func dictionaryEntry(module: String, key: String) -> String? {
        store?.dictEntry(module: module, key: key)
    }

    /// Every key of a lexicon, in the module's own `.idx` order and in its **true
    /// casing**.
    ///
    /// SWORD_REMOVAL_PLAN.md Phase 4 step 9: the `capitalizedString` this used to
    /// apply is **gone**. It existed only because `-[SwordDictionary readKeys]`
    /// applied it (SwordDictionary.mm), and the Dictionary tab both displayed and
    /// re-looked-up that string — so it mangled 1,375 of Robinson's 1,526 keys
    /// (`V-PAI-3S` -> `V-Pai-3S`) and the app got away with it only because SWORD
    /// uppercases both sides for a module without `CaseSensitiveKeys`. Phase 3
    /// preserved the mangling to keep the differential comparison a plain equality;
    /// this step fixes it, at the same time as the engine side and the key-cache
    /// invalidation, because doing any one alone leaves a broken state (see the
    /// DefaultsDictKeyCaseFixed migration in PSLaunchViewController).
    ///
    /// `PSContentStore.dictKeys` already returns the true casing, so this is now a
    /// pass-through. `dict_keys.key` stays `COLLATE NOCASE` as defence in depth: it
    /// is what let the mangled keys resolve at all, and keeping it means a stale
    /// cache that somehow survives the migration still finds its entry rather than
    /// showing the user a blank definition.
    @objc(dictionaryKeysForModule:)
    func dictionaryKeys(module: String) -> [String] {
        if let cached = Self.keyCache[module] { return cached }
        let keys = store?.dictKeys(module: module) ?? []
        // Memoise. `dictKeys` is a full table query and the Dictionary tab used to
        // call this once *per cell* (and again per keystroke while filtering); the
        // store is immutable and read-only, so the answer cannot change within a
        // process.
        if !keys.isEmpty { Self.keyCache[module] = keys }
        return keys
    }

    /// Memoised `dictionaryKeys` results. Keyed by module; never invalidated,
    /// because the bundled store is read-only.
    ///
    /// **MAIN-THREAD ONLY, and deliberately unsynchronised.** Every caller is a
    /// UIKit data-source path on the Dictionary tab (`key(at:)`, `rowCount`,
    /// `searchDictionaryEntries`), so there is no contention to protect against and a
    /// lock would be dead weight on a per-cell call. That is an invariant, not an
    /// accident: `PSContentStore` funnels through a serial queue and `PSSearchEngine`
    /// runs FULLMUTEX precisely because they are reached off the main thread, and
    /// this is not. A background caller must add synchronisation here first — an
    /// unguarded dictionary write racing a read is a crash, not a stale answer.
    private static var keyCache: [String: [String]] = [:]

    @objc(dictionaryEntryCountForModule:)
    func dictionaryEntryCount(module: String) -> Int {
        store?.dictEntryCount(module: module) ?? 0
    }

    // MARK: - Notes

    /// A footnote body, expanded, for the `n` branch of
    /// `-[SwordModule attributeValueForEntryData:]`.
    ///
    /// The scriptRef branch is **gone** (Phase 4 step 8): it was unreachable for the
    /// shipped content, and `testCaptureScriptRefAttributes` — which pins
    /// "Ps 23:1-3" yielding three elements — was retargeted at
    /// `PSRefParser` + `PSChapterExpander`, fixture byte-unchanged.
    @objc(noteBodyForModule:osisRef:marker:)
    func noteBody(module: String, osisRef: String, marker: String) -> String? {
        guard let store else { return nil }
        // The passage arrives URL-encoded, straight off the anchor: the emitted
        // href is `passage=Genesis+4%3A1` and `+[PSModuleController data(forLink:)]`
        // splits the query on '&'/'=' WITHOUT decoding it (unlike its own sword://
        // branch, which does both). The engine's `n` branch then hands that string
        // to VerseKey::setText, which tolerates it; a SQL lookup does not, because
        // notes_index holds "Genesis 4:1". Decode here, and accept an
        // already-clean ref too so a caller that decoded first still works.
        let decoded = Self.decodePassage(osisRef)
        guard let note = store.note(module: module, osisRef: decoded, marker: marker) else {
            return nil
        }
        // Notes are captured through renderText(buf), which sets
        // processEntryAttributes=false — the same call shape the app makes at
        // SwordModule.mm:567 — so the stored body already reflects that path. The
        // note text itself is not option-gated: the anchor that leads here is.
        guard let html = PSChapterExpander.expand(note.body, options: .allOn) else { return nil }
        return html
    }

    /// `Genesis+4%3A1` -> `Genesis 4:1`. `+` means space in a query string, so it
    /// is replaced before percent-decoding (decoding first would leave a literal
    /// `+` where a `%2B` had been, though no ref contains one).
    static func decodePassage(_ passage: String) -> String {
        let plussed = passage.replacingOccurrences(of: "+", with: " ")
        return plussed.removingPercentEncoding ?? plussed
    }
}
