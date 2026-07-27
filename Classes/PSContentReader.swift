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
//  === FAILURE POLICY (while PSFeatureFlags.swiftContentReader exists) ===
//
//  Every failure takes ONE path: report through PSContentStore.fail — which is
//  assertionFailure in debug (loud during development) and alog in release — and
//  return nil, so the caller falls back to SWORD. A blank chapter must never be
//  the user-visible outcome of a reader bug.
//
//  The conditions that return nil, which is exactly the list PHASE 5 MUST CONVERT
//  TO HARD FAILURES once there is no SWORD left to fall back to:
//
//    1. Resources/PSContent.sqlite absent from the bundle, or unopenable.
//    2. content_meta schemaVersion != 2 or tokenGrammar != "v2".
//    3. content_meta missing the chunkRows.* sizes.
//    4. Resources/Versification-KJV.json absent, unparseable, or not 66 books.
//    5. A chunk that fails to inflate, or whose row_count / raw_size disagrees
//       with its blob.
//    6. A chapter blob whose record count disagrees with entry_count.
//    7. An MHCC body id that does not resolve in `bodies`.
//    8. A malformed token stream (unterminated token, wrong field count, unknown
//       Strong's flag).
//    9. An unresolvable book name, or a chapter outside the book.
//   10. A dict_keys / notes_index row pointing at a slot its chunk does not have.
//
//  Note what is NOT in that list, because it is normal rather than a failure:
//  a chapter absent from `chapters` (the converter omits wholly-empty ones, and
//  the reader renders the same "empty chapter" message the engine does), and a
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

    /// Whether the reader is usable at all. The feature flag gates *intent*; this
    /// gates *capability*, and both must hold.
    @objc var isAvailable: Bool { store != nil && resolver != nil }

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

    /// The full page — body + bottom padding + navigation JS + the HTML shell —
    /// i.e. the equivalent of `-[SwordModule getChapter:withExtraJS:]`, which is
    /// what `PSModuleController.getBibleChapter(_:withExtraJS:)` returns.
    func chapterPage(module: String,
                     ref: String,
                     kind: PSChapterAssembler.ModuleKind,
                     extraJS: String) -> String? {
        guard let rendered = chapterBody(module: module, ref: ref, kind: kind,
                                         applyBookmarkHighlights: true) else {
            return nil
        }
        // Identical to -getChapter:'s own six pads.
        let body = rendered.body + "<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>"

        // The navigation JS comes from +[SwordModule chapterNavigationJSWithEntryCount:extraJS:]
        // rather than a copy here. It is 4 KB of pure JS with no SWORD dependency,
        // and a duplicate would be the single most likely thing in this phase to
        // drift unnoticed. Phase 5 moves the method (not a copy of it) into Swift
        // when SwordModule.mm is deleted.
        let js = SwordModule.chapterNavigationJS(withEntryCount: rendered.entryCount, extraJS: extraJS)

        guard var text = PSModuleController.createHTMLString(body,
                                                            usingPreferences: true,
                                                            withJS: js,
                                                            usingModuleForPreferences: module,
                                                            fixedWidth: true) else {
            PSContentStore.fail("createHTMLString returned nil for \(module) \(ref)")
            return nil
        }

        // Language + direction, as -getChapter: does at SwordModule.mm:1346-1350.
        // Both come from the module .conf, which is still on disk this phase (the
        // zips keep seeding into Documents/ — see the plan's open dependency), so
        // this reads them from the live module rather than duplicating the values.
        // Phase 5 takes them from content_meta.
        if let mod = SwordManager.default()?.module(withName: module) {
            if mod.isRTL() {
                text = text.replacingOccurrences(of: "dir=\"ltr\"", with: "dir=\"rtl\"")
            }
            if let lang = mod.lang(), !lang.isEmpty {
                text = text.replacingOccurrences(of: "xml:lang=\"en\"",
                                                 with: "xml:lang=\"\(lang)\" lang=\"\(lang)\"")
            }
        }
        return text
    }

    /// The engine's own empty-chapter fallback (SwordModule.mm:1181), including
    /// that the parenthesised ref is SWORD's `ch` — the chapter part of the key
    /// text, e.g. "Genesis 1".
    private func emptyChapterBody(bookName: String, chapter: Int) -> String {
        let message = NSLocalizedString("EmptyChapterWarning", comment: "This chapter is empty for this module.")
        return "<p style=\"color:grey;text-align:center;font-style:italic;\">\(message) (\(bookName) \(chapter))</p>"
    }

    // MARK: - Lexicons

    /// A lexicon entry for the key the UI holds. See PSContentStore.dictEntry for
    /// the casing and zero-padding rules, and step 4b's tests for why they matter.
    @objc(dictionaryEntryForModule:key:)
    func dictionaryEntry(module: String, key: String) -> String? {
        store?.dictEntry(module: module, key: key)
    }

    /// Every key of a lexicon, **as the Dictionary tab displays them**.
    ///
    /// `capitalizedString` is applied here because that is what
    /// `-[SwordDictionary readKeys]` does (SwordDictionary.mm:67) and the tab both
    /// displays and re-looks-up that string. It mangles 1,375 of Robinson's 1,526
    /// keys (`V-PAI-3S` -> `V-Pai-3S`) and is therefore **wrong**, but it is
    /// preserved deliberately this phase: changing it here would make the
    /// differential test need a per-field allowlist instead of plain equality, and
    /// would invalidate the on-disk key caches (SwordDictionary.mm:85-109). Fixing
    /// the display is Phase 4 work, and it must clear those caches when it lands.
    @objc(dictionaryKeysForModule:)
    func dictionaryKeys(module: String) -> [String] {
        (store?.dictKeys(module: module) ?? []).map { ($0 as NSString).capitalized }
    }

    @objc(dictionaryEntryCountForModule:)
    func dictionaryEntryCount(module: String) -> Int {
        store?.dictEntryCount(module: module) ?? 0
    }

    // MARK: - Notes

    /// A footnote body, expanded, for the `n` branch of
    /// `-[SwordModule attributeValueForEntryData:]`.
    ///
    /// The **scriptRef branch stays on SWORD** this phase: it resolves arbitrary
    /// references including ranges through `parseVerseList`
    /// (SwordModule.mm:597-621) — `testCaptureScriptRefAttributes` pins
    /// "Ps 23:1-3" yielding three elements — and range resolution is Phase 4.
    @objc(noteBodyForModule:osisRef:marker:)
    func noteBody(module: String, osisRef: String, marker: String) -> String? {
        guard let store, let note = store.note(module: module, osisRef: osisRef, marker: marker) else {
            return nil
        }
        // Notes are captured through renderText(buf), which sets
        // processEntryAttributes=false — the same call shape the app makes at
        // SwordModule.mm:567 — so the stored body already reflects that path. The
        // note text itself is not option-gated: the anchor that leads here is.
        guard let html = PSChapterExpander.expand(note.body, options: .allOn) else { return nil }
        return html
    }
}
