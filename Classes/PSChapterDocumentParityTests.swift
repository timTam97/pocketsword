//
//  PSChapterDocumentParityTests.swift
//  PocketSwordTests
//
//  Wave 9's acceptance criterion for the native reader's DATA, as distinct from
//  its layout: `PSChapterDocumentBuilder` must agree with the byte-locked HTML
//  emitter about what a chapter says.
//
//  ── Why this test carries the whole safety argument ────────────────────────
//
//  Wave 9 replaced the WebView with a `LazyVStack` over `ChapterDocument`, built
//  by a SECOND emitter over the same v2 token stream (see
//  `PSChapterDocument.swift`'s header for why that beats parsing the HTML). Two
//  emitters over one grammar is only safe if something holds them together, and
//  this is that something.
//
//  The HTML side is a genuine oracle rather than a co-drifting sibling: it is
//  pinned byte-for-byte by `PSContentStoreTests`' chapter-body fixtures — captured
//  from the live SWORD engine, which no longer exists and cannot be re-run — plus
//  `chapter-loop-counters.tsv`. So when these two agree, the native reader agrees
//  with the engine transitively.
//
//  ── What is compared, and what deliberately is not ────────────────────────
//
//  COMPARED (per chapter):
//    * the plain text of every verse, after stripping tags from the HTML side;
//    * `entryCount` — the loop counter, which is not a verse number;
//    * the set of verse numbers, i.e. which slots produced a row at all;
//    * every link target, in document order (Strong's type+value, morph
//      type+value, note kind/value/module/passage).
//
//  NOT COMPARED: CSS, font sizes, the `<p>`/`<br />` structure, the six bottom
//  pads, and the JS block. Those are presentation the native reader owns
//  differently by design — the plan states the native reader requires workflow and
//  feature parity, not pixel-identical WebKit output.
//
//  ── Tiering ───────────────────────────────────────────────────────────────
//
//  The default tier covers a fixed sample chosen to hit every structural feature
//  the corpus has (see `sampleRefs`) at BOTH option endpoints. The exhaustive tier
//  — `PSDOC_EXHAUSTIVE=1` — walks all 1,189 chapters × 2 modules × 2 endpoints,
//  i.e. 4,756 chapter builds. That is minutes, not seconds, which is why it is
//  opt-in; the sample tier is what guards every commit.
//
//  Getting an env var into a *test* run needs a temporary `<EnvironmentVariables>`
//  block in the shared scheme's `TestAction` plus `shouldUseLaunchSchemeArgsEnv =
//  "NO"` — see CLAUDE.md. Back the scheme up and restore it.
//

import XCTest
@testable import PocketSword

final class PSChapterDocumentParityTests: XCTestCase {

    private static var isExhaustive: Bool {
        ProcessInfo.processInfo.environment["PSDOC_EXHAUSTIVE"] != nil
    }

    // MARK: - Plumbing

    private func store() throws -> PSContentStore {
        guard let store = PSContentStore.shared else {
            throw XCTSkip("PSContentStore did not open")
        }
        return store
    }

    private func resolver() throws -> PSBookOSISResolver {
        guard let resolver = PSBookOSISResolver.shared else {
            throw XCTSkip("PSBookOSISResolver did not load")
        }
        return resolver
    }

    /// One chapter, rendered BOTH ways from the same records.
    ///
    /// The records are read once and handed to both emitters, so a store-level
    /// difference cannot masquerade as an emitter difference.
    private func renderBoth(
        module: String,
        ref: String,
        options: PSChapterExpander.Options,
        kind: PSChapterAssembler.ModuleKind
    ) throws -> (html: PSChapterAssembler.Result, document: ChapterDocument)? {
        let store = try store()
        let resolver = try resolver()
        guard let (book, chapter) = resolver.resolve(ref: ref) else {
            XCTFail("\(ref) did not resolve")
            return nil
        }
        guard let records = store.chapterRecords(module: module,
                                                 bookOsis: book.osisName,
                                                 chapter: chapter) else {
            // A wholly-empty chapter is omitted by the converter; both sides show
            // the same message, and there is nothing to compare.
            return nil
        }
        let headings = store.headings(module: module,
                                     bookName: book.longName,
                                     chapter: chapter)

        // ── HTML side ──
        var expanded: [String] = []
        expanded.reserveCapacity(records.records.count)
        for record in records.records {
            if record.isEmpty {
                expanded.append("")
                continue
            }
            guard let html = PSChapterExpander.expand(record, options: options) else {
                XCTFail("\(module) \(ref): a record failed to expand")
                return nil
            }
            expanded.append(html)
        }
        var config = PSChapterAssembler.Config()
        config.kind = kind
        config.versePerLine = false
        config.headingsOn = options.headings
        guard let htmlResult = PSChapterAssembler.assemble(
            records: expanded,
            headings: headings,
            config: config,
            headingHTML: { PSChapterExpander.expand($0.html, options: options.forHeading) },
            highlightColour: { _ in nil },
            emptyChapterMessage: "") else {
            XCTFail("\(module) \(ref): HTML assembly failed")
            return nil
        }

        // ── Native side ──
        var docConfig = PSChapterDocumentBuilder.Config()
        docConfig.kind = kind
        docConfig.headingsOn = options.headings
        guard let document = PSChapterDocumentBuilder.build(
            records: records.records,
            headings: headings,
            config: docConfig,
            options: options,
            highlightColour: { _ in nil },
            emptyChapterMessage: "") else {
            XCTFail("\(module) \(ref): document build failed")
            return nil
        }
        return (htmlResult, document)
    }

    // MARK: - Text normalisation

    /// Reduce the HTML body to the text a reader sees.
    ///
    /// Tags are dropped, entities decoded (through the builder's own decoder, so
    /// the two sides cannot disagree about `&#182;`), and whitespace collapsed. The
    /// verse-number anchors are removed first: the HTML carries the number as
    /// content (`<a …>12</a>`) whereas the native document carries it as
    /// `ChapterVerse.number`, so leaving them in would compare a label against
    /// nothing.
    ///
    /// **Block boundaries become whitespace, on both sides.** The first version of
    /// this method stripped every tag uniformly, which silently glued the last word
    /// of one block to the first word of the next: `<p><b>CHAPTER 1.</b></p>In the
    /// beginning` collapsed to `CHAPTER 1.In the beginning`, while the document side
    /// — which holds the heading and the verse as separate values — naturally reads
    /// `CHAPTER 1. In the beginning`. That produced four failures whose only content
    /// was a missing space, i.e. a defect in this comparison rather than in either
    /// emitter.
    ///
    /// Inter-word spacing across a block boundary is not a property the two
    /// representations can meaningfully agree on: in HTML it is implied by the block
    /// element, and in the document it is implied by the array structure. So both
    /// sides normalise it to one space and the comparison stays about the *text*.
    /// Note this weakens nothing that matters — a genuinely dropped or duplicated
    /// word still fails, as does any difference inside a block.
    private func plainText(fromHTML html: String) -> String {
        var text = html
        // Verse-number anchors, both flavours the assembler emits.
        text = text.replacingOccurrences(
            of: "<a href=\"pocketsword:versemenu:[0-9]+\" id=\"vv[0-9]+\" class=\"verse\">[0-9]+</a>",
            with: "",
            options: .regularExpression)
        text = text.replacingOccurrences(
            of: "<a href=\"#verse[0-9]+\" id=\"vv[0-9]+\" class=\"verse\">[0-9]+</a>",
            with: "",
            options: .regularExpression)
        // Block-level tags carry an implied break; everything else is inline.
        text = text.replacingOccurrences(
            of: "</?(p|br|blockquote|div)\\s*/?>", with: " ",
            options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "",
                                         options: .regularExpression)
        text = PSChapterDocumentBuilder.decodeEntities(text)
        return collapseWhitespace(text)
    }

    private func plainText(from document: ChapterDocument) -> String {
        var pieces: [String] = []
        for verse in document.verses {
            for heading in verse.headings {
                pieces.append(heading.runs.map(\.text).joined())
            }
            pieces.append(verse.runs.map(\.text).joined())
        }
        return collapseWhitespace(pieces.joined(separator: " "))
    }

    private func collapseWhitespace(_ input: String) -> String {
        let collapsed = input.replacingOccurrences(of: "\\s+", with: " ",
                                                   options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Link extraction

    /// Link targets from the HTML, in document order, as comparable strings.
    private func links(fromHTML html: String) -> [String] {
        var out: [String] = []
        let pattern = "<a href=\"passagestudy\\.jsp\\?([^\"]*)\" class=\"([a-z]+)\">"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = html as NSString
        regex.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            let query = ns.substring(with: match.range(at: 1))
            let cls = ns.substring(with: match.range(at: 2))
            var fields: [String: String] = [:]
            for pair in query.replacingOccurrences(of: "&amp;", with: "&")
                .components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                guard kv.count == 2 else { continue }
                fields[kv[0]] = kv[1]
            }
            switch cls {
            case "strongs":
                out.append("strongs:\(fields["type"] ?? ""):\(fields["value"] ?? "")")
            case "morph":
                out.append("morph:\(fields["type"] ?? ""):\(fields["value"] ?? "")")
            case "n", "x":
                out.append("note:\(cls):\(fields["value"] ?? ""):"
                           + "\(fields["module"] ?? ""):\(fields["passage"] ?? "")")
            default:
                break
            }
        }
        return out
    }

    private func links(from document: ChapterDocument) -> [String] {
        var out: [String] = []
        for verse in document.verses {
            for heading in verse.headings {
                out.append(contentsOf: heading.runs.compactMap { describe($0.link) })
            }
            out.append(contentsOf: verse.runs.compactMap { describe($0.link) })
        }
        return out
    }

    private func describe(_ link: InlineLink?) -> String? {
        switch link {
        case .strongs(let type, let value):
            return "strongs:\(type):\(value)"
        case .morph(let type, let value):
            return "morph:\(type):\(value)"
        case .note(let kind, let value, let module, let passage):
            return "note:\(kind):\(value):\(module):\(passage)"
        case .scriptRef:
            // Unreachable for the shipped corpus, and the HTML emitter writes only
            // an opening anchor with no class, so there is nothing to pair it with.
            return nil
        case .verseMenu:
            // Not produced by the token grammar: the RENDERER attaches it to the
            // superscript verse label, the way the assembler synthesised
            // `pocketsword:versemenu:` around each verse. The comparison already
            // strips those anchors from the HTML side (see `plainText(fromHTML:)`)
            // and checks verse identity separately, so counting it here would
            // compare a label against nothing.
            return nil
        case nil:
            return nil
        }
    }

    // MARK: - The comparison

    /// Compare one chapter both ways, failing with the first divergence.
    private func assertParity(module: String,
                              ref: String,
                              options: PSChapterExpander.Options,
                              kind: PSChapterAssembler.ModuleKind,
                              label: String) throws -> Bool {
        guard let (html, document) = try renderBoth(module: module, ref: ref,
                                                    options: options, kind: kind) else {
            return true
        }

        // 1. The loop counter. This is the one `chapter-loop-counters.tsv` pins, so
        //    a mismatch here means the native builder renumbered a chapter.
        guard document.entryCount == html.entryCount else {
            XCTFail("\(label): entryCount \(document.entryCount) != HTML \(html.entryCount)")
            return false
        }

        // 2. Verse identity. Every `vv{i}` anchor the HTML emitted must be a row.
        let htmlVerses = verseNumbers(fromHTML: html.body)
        let docVerses = document.verses.filter { !$0.isIntro }.map(\.number)
        guard htmlVerses == docVerses else {
            XCTFail("""
                \(label): verse numbers differ.
                  HTML:     \(htmlVerses.prefix(20))… (\(htmlVerses.count))
                  document: \(docVerses.prefix(20))… (\(docVerses.count))
                """)
            return false
        }

        // 3. The text. This is the assertion that catches a dropped tag, a
        //    mis-decoded entity, or a gating axis wired to the wrong option.
        let htmlText = plainText(fromHTML: html.body)
        let docText = plainText(from: document)
        guard htmlText == docText else {
            let a = Array(docText), e = Array(htmlText)
            var i = 0
            while i < min(a.count, e.count), a[i] == e[i] { i += 1 }
            let lo = max(0, i - 60)
            XCTFail("""
                \(label): text differs at character \(i) \
                (HTML \(e.count) chars, document \(a.count)).
                  HTML:     …\(String(e[lo..<min(e.count, i + 60)]))…
                  document: …\(String(a[lo..<min(a.count, i + 60)]))…
                """)
            return false
        }

        // 4. Link targets, in order. A Strong's number routed to the wrong lexicon
        //    is invisible in the text but wrong on tap.
        let htmlLinks = links(fromHTML: html.body)
        let docLinks = links(from: document)
        guard htmlLinks == docLinks else {
            var i = 0
            while i < min(htmlLinks.count, docLinks.count),
                  htmlLinks[i] == docLinks[i] { i += 1 }
            XCTFail("""
                \(label): links differ at index \(i) \
                (HTML \(htmlLinks.count), document \(docLinks.count)).
                  HTML:     \(i < htmlLinks.count ? htmlLinks[i] : "<end>")
                  document: \(i < docLinks.count ? docLinks[i] : "<end>")
                """)
            return false
        }
        return true
    }

    private func verseNumbers(fromHTML html: String) -> [Int] {
        var out: [Int] = []
        let pattern = "id=\"vv([0-9]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = html as NSString
        regex.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, let n = Int(ns.substring(with: match.range(at: 1))) else { return }
            out.append(n)
        }
        return out
    }

    // MARK: - Sample tier

    /// Chapters chosen to hit every structural feature the corpus has, rather than
    /// for coverage breadth. Each earns its place:
    ///
    ///  * `Genesis 1` — the ordinary case, dense Strong's + morph.
    ///  * `Genesis 4` — an entry with a footnote anchor.
    ///  * `Psalms 23` — canonical Psalm title (a heading emitted even with
    ///    headings OFF) and the highlighted-body fixture's chapter.
    ///  * `Psalms 119` — the acrostic, 22 interverse titles; the heaviest heading
    ///    chapter in the corpus.
    ///  * `Psalms 3` — a canonical title plus Selah pilcrows (`&#182;`).
    ///  * `Matthew 1` — a genealogy, and MHCC's own first chapter.
    ///  * `John 3` — red-letter (`WordOfChrist`) spans nesting Strong's, which is
    ///    the case where option-off must keep the payload.
    ///  * `Revelation 22` — the last chapter, and the `alloff` fixture's.
    private static let sampleRefs = [
        "Genesis 1", "Genesis 4", "Psalms 3", "Psalms 23",
        "Psalms 119", "Matthew 1", "John 3", "Revelation 22",
    ]

    func testNativeDocumentMatchesHTMLForSampleChaptersAllOptionsOn() throws {
        for ref in Self.sampleRefs {
            guard try assertParity(module: "KJV", ref: ref, options: .allOn,
                                   kind: .bible, label: "KJV \(ref) all-on") else { return }
        }
    }

    func testNativeDocumentMatchesHTMLForSampleChaptersAllOptionsOff() throws {
        for ref in Self.sampleRefs {
            guard try assertParity(module: "KJV", ref: ref, options: .allOff,
                                   kind: .bible, label: "KJV \(ref) all-off") else { return }
        }
    }

    /// The commentary path, which differs structurally: MHCC's verse anchor is
    /// `href="#verse%ld"` rather than `pocketsword:versemenu:`, and its records
    /// arrive through the `bodyref` indirection.
    func testNativeDocumentMatchesHTMLForCommentary() throws {
        for ref in ["Genesis 1", "Psalms 23", "Matthew 1"] {
            guard try assertParity(module: "MHCC", ref: ref, options: .allOn,
                                   kind: .commentary,
                                   label: "MHCC \(ref) all-on") else { return }
            guard try assertParity(module: "MHCC", ref: ref, options: .allOff,
                                   kind: .commentary,
                                   label: "MHCC \(ref) all-off") else { return }
        }
    }

    /// Each option axis alone, so a mis-wired gate cannot hide behind the two
    /// endpoints agreeing. `John 3` carries red-letter; `Psalms 119` headings;
    /// `Genesis 4` footnotes; `Genesis 1` Strong's and morph.
    func testEachOptionAxisAgreesIndependently() throws {
        var axes: [(String, PSChapterExpander.Options)] = []
        for (name, mutate) in [
            ("strongs off", { (o: inout PSChapterExpander.Options) in o.strongs = false }),
            ("morphs off", { (o: inout PSChapterExpander.Options) in o.morphs = false }),
            ("footnotes off", { (o: inout PSChapterExpander.Options) in o.footnotes = false }),
            ("redLetter off", { (o: inout PSChapterExpander.Options) in o.redLetter = false }),
            ("headings off", { (o: inout PSChapterExpander.Options) in o.headings = false }),
        ] as [(String, (inout PSChapterExpander.Options) -> Void)] {
            var options = PSChapterExpander.Options.allOn
            mutate(&options)
            axes.append((name, options))
        }

        for (name, options) in axes {
            for ref in ["Genesis 1", "Genesis 4", "Psalms 119", "John 3"] {
                guard try assertParity(module: "KJV", ref: ref, options: options,
                                       kind: .bible,
                                       label: "KJV \(ref) [\(name)]") else { return }
            }
        }
    }

    // MARK: - Exhaustive tier (PSDOC_EXHAUSTIVE=1)

    /// All 1,189 chapters × both modules × both endpoints — 4,756 builds.
    ///
    /// This is the one that would catch a chapter whose shape nothing in the sample
    /// represents. It is opt-in because it takes minutes.
    func testNativeDocumentMatchesHTMLForEveryChapter() throws {
        try XCTSkipUnless(Self.isExhaustive,
                          "set PSDOC_EXHAUSTIVE=1 to run the exhaustive tier")
        let resolver = try resolver()
        var checked = 0
        for book in resolver.books {
            for chapter in 1...book.chapterCount {
                let ref = "\(book.name) \(chapter)"
                for (module, kind) in [("KJV", PSChapterAssembler.ModuleKind.bible),
                                       ("MHCC", .commentary)] {
                    for options in [PSChapterExpander.Options.allOn, .allOff] {
                        let endpoint = options.strongs ? "all-on" : "all-off"
                        guard try assertParity(module: module, ref: ref,
                                               options: options, kind: kind,
                                               label: "\(module) \(ref) \(endpoint)") else {
                            return
                        }
                        checked += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 4_000,
                             "expected ~4,756 chapter comparisons, ran \(checked)")
    }

    // MARK: - The grammar tables cannot drift apart

    /// Both emitters carry their own copy of the v2 token table, deliberately (see
    /// `PSChapterDocument.swift`'s header). This asserts the copies agree, by
    /// round-tripping a synthetic entry that uses every token through both sides.
    ///
    /// Without this, a typo'd sentinel in one table would only surface as a corpus
    /// chapter that happened to use that token — and `scripRef`, which the corpus
    /// never uses, would never surface at all.
    func testBothEmittersRecogniseTheSameTokenSentinels() throws {
        let cases: [(String, String)] = [
            ("strongs", "word\u{0001}H0430\u{0002}"),
            ("morph", "word\u{0003}|TH8804\u{0004}"),
            ("note", "word\u{0005}1|KJV|Genesis+4%3A1\u{0006}"),
            ("xref", "word\u{0007}1|KJV|Genesis+4%3A1\u{0008}"),
            ("title", "\u{000B}A Psalm of David\u{000C}"),
            ("redLetter", "\u{0011}I am\u{0001}G1510\u{0002}\u{0012}"),
            ("scripRef", "see\u{000E}Gen 1:1\u{000F}"),
        ]
        for (name, input) in cases {
            let html = PSChapterExpander.expand(input, options: .allOn)
            XCTAssertNotNil(html, "\(name): the HTML emitter rejected its own token")
            let runs = PSChapterDocumentBuilder.runs(from: input, options: .allOn)
            XCTAssertNotNil(runs, "\(name): the document builder rejected the token")

            // Neither side may leave a raw sentinel in its output — that is what a
            // table typo looks like.
            if let html {
                XCTAssertFalse(html.unicodeScalars.contains { $0.value < 0x20 && $0 != "\n" && $0 != "\t" },
                               "\(name): the HTML emitter passed a control character through")
            }
            if let runs {
                let text = runs.map(\.text).joined()
                XCTAssertFalse(text.unicodeScalars.contains { $0.value < 0x20 && $0 != "\n" && $0 != "\t" },
                               "\(name): the document builder passed a control character through")
            }
        }
    }

    /// The corpus vocabulary claim this whole design rests on: chapter records
    /// contain only `i.transChangeAdded` and `font size="-1"` as raw markup.
    ///
    /// If a future store carried a `blockquote`, `div` or `br`, the native reader
    /// would silently drop it — so the claim is re-derived from the store on every
    /// run rather than trusted as a comment. Sampled across the books that
    /// historically carried odd markup rather than the whole corpus, so it stays
    /// fast; the exhaustive tier covers the rest by comparing text.
    func testChapterRecordsCarryOnlyTheModelledRawTags() throws {
        let store = try store()
        let resolver = try resolver()
        let modelled: Set<String> = ["i", "/i", "font", "/font"]
        var seen: Set<String> = []

        for book in resolver.books.prefix(12) {
            for chapter in 1...min(book.chapterCount, 4) {
                for module in ["KJV", "MHCC"] {
                    guard let records = store.chapterRecords(
                        module: module,
                        bookOsis: book.osisName,
                        chapter: chapter) else { continue }
                    for record in records.records where !record.isEmpty {
                        for tag in Self.rawTags(in: record) {
                            seen.insert(tag)
                        }
                    }
                }
            }
        }

        let unexpected = seen.subtracting(modelled)
        XCTAssertTrue(unexpected.isEmpty,
                      "chapter records carry raw tags the native reader does not model: "
                      + "\(unexpected.sorted()). Model them in "
                      + "PSChapterDocumentBuilder.inlineRuns(fromMarkup:) or the "
                      + "reader will drop them silently.")
    }

    // MARK: - Lexicon entries (Wave 9's other native surface)

    /// A lexicon entry renders its definition, its cross-links, and NOT its own key.
    ///
    /// Three separate device-found defects live in this one test, all in the same
    /// six-character preamble every entry opens with —
    /// `<a name="04399"><b>4399</b></a><br />`:
    ///
    ///  * the key number must not render (the popup header already shows it, and the
    ///    WebView hid it with `a[name]:first-child { display: none }` — CSS this wave
    ///    deleted);
    ///  * clearing the pending text is not enough, because `<b>` flushes and the
    ///    number is already a run by the time `</a>` arrives;
    ///  * `.bold` must be reset, or it leaks into the Hebrew lemma that follows.
    ///
    /// It also pins the cross-link, which is the whole reason a lexicon entry is
    /// worth rendering natively rather than as static text: all 14,989 of them.
    func testLexiconEntryDropsItsKeyAnchorAndKeepsCrossLinks() throws {
        let store = try store()
        // H4399 — the entry that exposed the `<b>`-inside-anchor case on device.
        let html = try XCTUnwrap(
            store.dictEntry(module: BundledModules.strongsHebrew, key: "04399"),
            "StrongsRealHebrew 04399 is missing from the store"
        )
        XCTAssertTrue(html.hasPrefix("<a name=\"04399\"><b>4399</b></a>"),
                      "the fixture's shape changed; this test targets the key anchor")

        let document = PSEntryDocumentBuilder.build(html: html)
        let text = document.blocks
            .map { $0.runs.map(\.text).joined() }
            .joined(separator: "\n")

        // The key number is gone from the BODY.
        XCTAssertFalse(text.hasPrefix("4399"),
                       "the entry's own key anchor still renders: \(text.prefix(40))")
        // The definition survived.
        XCTAssertTrue(text.contains("deputyship"),
                      "the definition is missing: \(text.prefix(80))")
        // The Hebrew lemma survived, and is not bold — `.bold` from the key anchor's
        // `<b>` must not leak past it.
        let lemmaRuns = document.blocks
            .flatMap(\.runs)
            .filter { $0.text.unicodeScalars.contains { $0.value >= 0x0590 && $0.value <= 0x05FF } }
        XCTAssertFalse(lemmaRuns.isEmpty, "the Hebrew lemma did not render")
        for run in lemmaRuns {
            XCTAssertFalse(run.style.contains(.bold),
                           "bold leaked out of the key anchor into the lemma")
        }

        // The cross-link to 4397 is a real link, and round-trips.
        let links = document.blocks.flatMap(\.runs).compactMap(\.entryLink)
        XCTAssertTrue(
            links.contains(.lexicon(module: BundledModules.strongsHebrew, key: "04397")),
            "the sword:// cross-link did not resolve; found \(links)"
        )
        for link in links {
            let url = try XCTUnwrap(link.url)
            XCTAssertEqual(EntryLink(url: url), link, "entry link round trip failed")
        }
    }

    /// A footnote renders as text. The narrowest vocabulary of the three (`i` and
    /// `font` only, over 13,918 fields), and the one with no header to fall back on
    /// if it comes out empty.
    func testFootnoteBodyRendersAsText() throws {
        let reader = PSContentReader.shared
        // Genesis 4:1 carries KJV's first footnote; the passage arrives URL-encoded
        // off the anchor, which `noteBody` decodes itself.
        let body = reader.noteBody(module: "KJV", osisRef: "Genesis+4%3A1", marker: "1")
        guard let body else {
            throw XCTSkip("KJV Genesis 4:1 note 1 is not in the store")
        }
        let document = PSEntryDocumentBuilder.build(html: body)
        let text = document.blocks.map { $0.runs.map(\.text).joined() }.joined()
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "the footnote rendered empty")
        XCTAssertFalse(text.contains("<"), "a tag survived into the rendered text")
    }

    /// Tag NAMES (lowercased, attributes dropped) appearing literally in a record.
    private static func rawTags(in record: String) -> [String] {
        var out: [String] = []
        var i = record.startIndex
        while let open = record[i...].firstIndex(of: "<") {
            guard let close = record[open...].firstIndex(of: ">") else { break }
            let body = record[record.index(after: open)..<close]
            let name = body.prefix { !$0.isWhitespace }
            out.append(String(name).lowercased())
            i = record.index(after: close)
            if i >= record.endIndex { break }
        }
        return out
    }
}
