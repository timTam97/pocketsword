//
//  PSChapterDocument.swift
//  PocketSword
//
//  Wave 9: the typed chapter document the native SwiftUI reader renders.
//
//  This is the render path's replacement for a string of HTML. Where
//  `PSChapterExpander` + `PSChapterAssembler` turn the store's token stream into
//  the exact bytes the SWORD markup filters emitted, `PSChapterDocumentBuilder`
//  (below) turns the SAME token stream into these values, and a `LazyVStack`
//  renders them.
//
//  ── Why this is not "parse the HTML" ───────────────────────────────────────
//
//  SWIFTUI_MIGRATION_PLAN.md originally called for SwiftSoup over the assembled
//  HTML. It was measured instead, and the measurement changed the design: across
//  all 2,378 chapter rows — 61,190 non-empty expanded records plus all 1,322
//  stored headings — the emitted chapter vocabulary is a CLOSED SET of six inline
//  tags (`a` with class strongs/morph/n, `i.transChangeAdded`, `font size="-1"`,
//  the `<p><b>…</b></p>` title pair, `span.WordOfChrist`) with numeric-only
//  entities. There is no `blockquote`, `div`, `table`, `ruby`, `br` or `<!P>` in
//  any chapter record.
//
//  The token stream already IS a structured document; serialising it to HTML only
//  to re-parse it would be a round trip through a format this app owns, and would
//  buy a ~30k-LOC HTML5 parser to handle six known tags. So the grammar gets a
//  SECOND emitter rather than a parser.
//
//  ── The two emitters, and what holds them together ────────────────────────
//
//      tokens ──PSChapterExpander────────▶ HTML             (kept: fixture-pinned)
//      tokens ──PSChapterDocumentBuilder─▶ ChapterDocument  (the render path)
//
//  Both consume the same `PSChapterExpander.Options`, so a disabled toggle SKIPS
//  its token here exactly as it does there — including red-letter's exception,
//  where the option being off drops the span but KEEPS its recursively-expanded
//  payload. `PSChapterDocumentParityTests` asserts the two agree, chapter by
//  chapter, on plain text / verse anchors / entryCount / link targets. That test
//  is the whole safety argument for this file: the HTML side is byte-locked to
//  fixtures captured from the live engine, so it is a real oracle and not a
//  co-drifting sibling.
//
//  **Do not "simplify" either emitter into calling the other.** Their independence
//  is what makes the parity test mean anything, which is the same reasoning
//  `PSChapterExpander`'s own header gives for there having been three
//  implementations of the grammar.
//
//  ── The counter is still not a verse number ───────────────────────────────
//
//  `ChapterVerse.number` is `PSChapterAssembler`'s loop counter `i`, not a verse
//  ordinal: it advances for slots the loop skips as empty or duplicate. It drives
//  the verse label, the verse-menu target and the bookmark-highlight lookup, and
//  it is what `chapter-loop-counters.tsv` pins. Deriving it from an array index
//  here would silently renumber every chapter that has an empty slot.
//

import Foundation

// MARK: - Inline runs

/// What a span of verse text links to when tapped.
///
/// These are the four `a` classes the corpus actually contains, as a typed value
/// instead of a `passagestudy.jsp?action=…` query string. The reader's link router
/// switches on this rather than re-parsing a URL it just built.
enum InlineLink: Equatable, Hashable {
    /// `class="strongs"` — a Strong's number. `type` is "Hebrew", "Greek", or ""
    /// (the corpus contains only the first two); `value` is the raw number as the
    /// lexicon keys it.
    case strongs(type: String, value: String)
    /// `class="morph"` — a morphological tag.
    case morph(type: String, value: String)
    /// `class="n"` (or `"x"`) — a footnote / cross-reference marker. The fields are
    /// the note anchor's, and `passage` arrives URL-encoded exactly as the HTML
    /// href carried it, because `PSContentReader.noteBody` decodes it itself.
    case note(kind: String, value: String, module: String, passage: String)
    /// A `<reference>` tag's `action=showRef` anchor. Unreachable for the shipped
    /// content (SWORD_REMOVAL_PLAN.md Phase 4 step 8 proved zero occurrences
    /// across 122,380 record expansions), carried so a future module cannot
    /// silently lose its links.
    case scriptRef(value: String)
}

/// The typographic axes a run can carry, as a set rather than a class name.
///
/// `transChangeAdded` (21,609 occurrences) is the italic grey "words supplied by
/// the translator"; `wordOfChrist` (2,038) is red-letter; `smallCaps` is
/// `font size="-1"`, which the HTML shell rewrote to a two-points-smaller
/// `font-size` — here it is a relative size, applied by the view.
struct InlineStyle: OptionSet, Hashable {
    let rawValue: Int

    static let transChangeAdded = InlineStyle(rawValue: 1 << 0)
    static let wordOfChrist     = InlineStyle(rawValue: 1 << 1)
    static let smaller          = InlineStyle(rawValue: 1 << 2)
    /// The `<b>` inside a title. Titles are their own block, but a heading's
    /// stored html can carry nested emphasis.
    static let bold             = InlineStyle(rawValue: 1 << 3)
    static let italic           = InlineStyle(rawValue: 1 << 4)
}

/// One contiguous span of text with uniform styling and at most one link.
struct InlineRun: Equatable, Hashable {
    var text: String
    var style: InlineStyle = []
    var link: InlineLink?

    /// A Strong's/morph anchor's own text is decorative — `<H0430>` / `(8804)` —
    /// and the view renders it superscript-small. Marking it lets the reader
    /// offer "hide markers" and lets the search highlighter skip it, neither of
    /// which is possible once it is flattened into the verse text.
    var isMarker: Bool = false

    init(text: String, style: InlineStyle = [], link: InlineLink? = nil, isMarker: Bool = false) {
        self.text = text
        self.style = style
        self.link = link
        self.isMarker = isMarker
    }
}

// MARK: - Blocks

/// A heading, i.e. what `<p><b>…</b></p>` was.
///
/// Both sources land here: the loop's own PREVERSE injection (gated on
/// `headingsOn || canonical`) and a title token inside a record, which is always
/// non-canonical Interverse — see `PSChapterExpander`'s header for why those gate
/// differently.
struct ChapterHeading: Equatable, Hashable {
    var runs: [InlineRun]
    /// Canonical headings (Psalm titles) render as scripture rather than as
    /// editorial furniture, and are emitted even with headings off.
    var isCanonical: Bool
}

/// One verse row: the unit the `LazyVStack` renders and scrolls to.
///
/// `id` is `number`, so `ScrollPosition(id:)` addresses a verse directly. That is
/// the whole reason the JS `versePositionArray` and its pixel offsets can go: a
/// native scroll view resolves a verse by identity instead of by measured offset,
/// which is also why rotation no longer needs to re-measure anything.
struct ChapterVerse: Identifiable, Equatable, Hashable {
    /// `PSChapterAssembler`'s loop counter — NOT a verse ordinal. See the header.
    var number: Int
    var id: Int { number }
    /// Headings that precede this verse.
    var headings: [ChapterHeading] = []
    var runs: [InlineRun] = []
    /// A bookmark highlight colour, as the `rgb(r,g,b)` string
    /// `PSBookmarks.getHighlightRGBColourString` returns. Kept as the persisted
    /// string form rather than a `Color` so the model stays free of SwiftUI.
    var highlightColour: String?
    /// The intro slot (`i == 0`) has no verse number and renders without a label.
    var isIntro: Bool { number == 0 }
}

/// A whole rendered chapter.
struct ChapterDocument: Equatable {
    var verses: [ChapterVerse] = []
    /// `PSChapterAssembler.Result.entryCount`, reproduced exactly — the loop
    /// counter after the final iteration, which is one past the last slot.
    var entryCount: Int = 0
    /// Set when the chapter has no content at all, carrying the same message the
    /// engine's own fallback showed.
    var emptyMessage: String?

    var isEmpty: Bool { verses.isEmpty }
}

// MARK: - Builder

/// Expands the store's token stream directly into a `ChapterDocument`.
///
/// A sibling of `PSChapterExpander` + `PSChapterAssembler`, sharing their option
/// gating and their loop shape. Where they append strings, this appends runs.
enum PSChapterDocumentBuilder {

    // The v2 token grammar. Deliberately duplicated from `PSChapterExpander`
    // rather than shared: these are the wire format of the baked store, and the
    // two emitters are independent by design (see this file's header). A test
    // asserts the two tables agree.
    private static let strongsOpen: Character    = "\u{0001}"
    private static let strongsClose: Character   = "\u{0002}"
    private static let morphOpen: Character      = "\u{0003}"
    private static let morphClose: Character     = "\u{0004}"
    private static let noteOpen: Character       = "\u{0005}"
    private static let noteClose: Character      = "\u{0006}"
    private static let xrefOpen: Character       = "\u{0007}"
    private static let xrefClose: Character      = "\u{0008}"
    private static let titleOpen: Character      = "\u{000B}"
    private static let titleClose: Character     = "\u{000C}"
    private static let scripRefOpen: Character   = "\u{000E}"
    private static let scripRefClose: Character  = "\u{000F}"
    private static let redLetterOpen: Character  = "\u{0011}"
    private static let redLetterClose: Character = "\u{0012}"

    /// The per-render inputs, mirroring `PSChapterAssembler.Config`.
    struct Config {
        var kind: PSChapterAssembler.ModuleKind = .bible
        var headingsOn = true
        // No `versePerLine`: it was a *layout* choice expressed as markup (a
        // `<br />` and a `<span id>` per verse). The native reader lays verses out
        // as rows either way, so the toggle drives row layout in the view instead
        // of the document. See `ReaderVerseRow`.
    }

    /// Build a document from one chapter's expanded-in-place records.
    ///
    /// Returns nil on a malformed token stream, matching
    /// `PSChapterExpander.expand`'s contract — the caller reports and shows the
    /// chapter as failed rather than rendering a partial verse.
    static func build(records: [String],
                      headings: [Int: [PSHeading]],
                      config: Config,
                      options: PSChapterExpander.Options,
                      highlightColour: (Int) -> String?,
                      emptyChapterMessage: @autoclosure () -> String,
                      reportFailures: Bool = true) -> ChapterDocument? {
        var document = ChapterDocument()
        var lastEntry = ""
        var i = 0

        for (slot, raw) in records.enumerated() {
            // ── Normalisation order is load-bearing, and getting it wrong here was
            //    a real bug the parity test caught. ──
            //
            // `PSChapterAssembler` runs its `*x`/`*n` replacement and its
            // leading-whitespace strip over the ENTRY AS ALREADY EXPANDED TO HTML.
            // This builder consumes the *token stream*, and the two are not
            // interchangeable for either step:
            //
            //  * The v2 sentinels are U+0001…U+0012, and several of them —
            //    U+000B (title open) and U+000C (title close) among them — ARE
            //    whitespace to `CharacterSet.whitespacesAndNewlines`. Stripping
            //    leading whitespace off the raw record therefore ate the title
            //    token's opening sentinel on the 1,184 KJV records shaped
            //    `" " + <title>CHAPTER n.</title>`, leaving an unbalanced stream
            //    whose text survived into the body. Symptom: with headings OFF the
            //    native reader still showed "CHAPTER 1.", because the token that
            //    the `headings` axis gates had stopped looking like a token.
            //  * `*x`/`*n` exist only in EXPANDED output (they are the note
            //    anchors' `*n` label); the corpus scan confirms zero occurrences in
            //    any raw record, so applying that replacement here is at best a
            //    no-op and at worst corrupts a verse that legitimately contains an
            //    asterisk followed by an n.
            //
            // So: expand first, then normalise the runs, and run the
            // duplicate/empty test over the joined post-expansion text — which is
            // the same string the assembler compares, and what keeps the loop
            // counter aligned with `chapter-loop-counters.tsv`.
            guard var runs = runs(from: raw,
                                  options: options,
                                  reportFailures: reportFailures) else { return nil }

            // The assembler's leading-whitespace strip, over the expanded text.
            // Deliberately preserving its quirk: an entry that is ENTIRELY
            // whitespace is left alone (the Obj-C `rangeOfCharacterFromSet` returned
            // NSNotFound), so it then fails the isEmpty test and IS emitted.
            stripLeadingWhitespace(&runs)

            let thisEntry = runs.map(\.text).joined()

            if thisEntry != lastEntry && !thisEntry.isEmpty {
                var verse = ChapterVerse(number: i)

                // Preverse headings, gated `headingsOn || canonical` — the loop's
                // own injection, a different mechanism from the markup filter's
                // interverse emission (which arrives as a title token below).
                for heading in headings[slot] ?? [] where heading.bucket == "Preverse" {
                    guard config.headingsOn || heading.canonical else { continue }
                    guard !heading.html.isEmpty else { continue }
                    // A stored heading expands under `forHeading`, where the title
                    // wrapper is unconditional. See PSChapterExpander's header.
                    // Note the `*x`/`*n` replacement the assembler applies to a
                    // heading is NOT applied to the token stream, for the same
                    // reason as above: those strings exist only post-expansion.
                    // `Self.runs(...)`: the local `runs` array shadows the static
                    // method inside this loop body.
                    guard var headingRuns = Self.runs(from: heading.html,
                                                      options: options.forHeading,
                                                      reportFailures: reportFailures) else { return nil }
                    // A stored heading's own title wrapper is the heading itself, so
                    // the marker is stripped rather than hoisted.
                    for index in headingRuns.indices {
                        headingRuns[index].style.remove(.titleMarker)
                    }
                    guard headingRuns.contains(where: { !$0.text.isEmpty }) else { continue }
                    verse.headings.append(
                        ChapterHeading(runs: headingRuns, isCanonical: heading.canonical)
                    )
                }

                // A title token at the head of a record became its own `<p><b>`
                // block in the HTML. Hoist those into `headings` so the view can
                // lay them out as headings rather than inline bold text.
                let hoisted = hoistLeadingTitles(&runs)
                verse.headings.append(contentsOf: hoisted)

                verse.runs = runs
                verse.highlightColour = highlightColour(i)

                // The assembler drops a bible intro slot whose whole content was a
                // `<br />`; with no `br` in the corpus that reduces to dropping an
                // entry that has no text at all.
                let hasText = runs.contains { !$0.text.isEmpty }
                if !(i == 0 && config.kind == .bible && !hasText && verse.headings.isEmpty) {
                    document.verses.append(verse)
                }
            }

            lastEntry = thisEntry
            i += 1
        }

        document.entryCount = i
        if document.verses.isEmpty {
            document.emptyMessage = emptyChapterMessage()
        }
        return document
    }

    /// The assembler's leading-whitespace strip, applied across runs.
    ///
    /// `-chapterBodyHTML:` did this with `rangeOfCharacterFromSet:` over the
    /// inverted whitespace set and `substringFromIndex:`, so:
    ///
    ///  * it removes the whole leading whitespace RUN, not one character;
    ///  * an entry that is *entirely* whitespace is left untouched, because
    ///    `NSNotFound` meant "no non-whitespace to cut back to". That entry then
    ///    fails the `isEqualToString:@""` test and IS emitted, which is why a few
    ///    chapters carry a blank row. Reproduced, not tidied.
    private static func stripLeadingWhitespace(_ runs: inout [InlineRun]) {
        // Nothing to cut back to → leave it exactly as it is.
        guard runs.contains(where: {
            $0.text.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) != nil
        }) else { return }

        for index in runs.indices {
            if let firstNonWS = runs[index].text.rangeOfCharacter(
                from: CharacterSet.whitespacesAndNewlines.inverted) {
                if firstNonWS.lowerBound != runs[index].text.startIndex {
                    runs[index].text = String(runs[index].text[firstNonWS.lowerBound...])
                }
                return
            }
            // This run is all whitespace and something later is not: drop it whole
            // and keep going.
            runs[index].text = ""
        }
    }

    /// Moves title blocks that lead a record into headings, returning them.
    ///
    /// A title token expands to a block in both emitters; keeping it inline would
    /// render a Psalm's interverse title as bold text mid-paragraph.
    private static func hoistLeadingTitles(_ runs: inout [InlineRun]) -> [ChapterHeading] {
        var hoisted: [ChapterHeading] = []
        while let first = runs.first, first.style.contains(.titleMarker) {
            // Collect the run span belonging to this title.
            var titleRuns: [InlineRun] = []
            while let run = runs.first, run.style.contains(.titleMarker) {
                var cleaned = run
                cleaned.style.remove(.titleMarker)
                titleRuns.append(cleaned)
                runs.removeFirst()
            }
            hoisted.append(ChapterHeading(runs: titleRuns, isCanonical: false))
        }
        return hoisted
    }

    // MARK: Token expansion

    private static func closingToken(for open: Character) -> Character? {
        switch open {
        case strongsOpen:   return strongsClose
        case morphOpen:     return morphClose
        case noteOpen:      return noteClose
        case xrefOpen:      return xrefClose
        case titleOpen:     return titleClose
        case scripRefOpen:  return scripRefClose
        case redLetterOpen: return redLetterClose
        default:            return nil
        }
    }

    private static func gatingAxis(
        for open: Character
    ) -> ((PSChapterExpander.Options) -> Bool)? {
        switch open {
        case strongsOpen:        return { $0.strongs }
        case morphOpen:          return { $0.morphs }
        case noteOpen, xrefOpen: return { $0.footnotes }
        case titleOpen:          return { $0.headings }
        case redLetterOpen:      return { $0.redLetter }
        case scripRefOpen:       return nil
        default:                 return nil
        }
    }

    /// Expand a tokenised entry into runs.
    ///
    /// The literal text between tokens carries the only raw HTML the corpus has —
    /// `<i class="transChangeAdded">` and `<font size="-1">` — so it goes through
    /// `inlineRuns(fromMarkup:)` rather than being taken verbatim.
    static func runs(from input: String,
                     options: PSChapterExpander.Options,
                     reportFailures: Bool = true) -> [InlineRun]? {
        var out: [InlineRun] = []
        var literal = ""
        let chars = Array(input)
        var i = 0

        func flushLiteral(_ style: InlineStyle) {
            guard !literal.isEmpty else { return }
            out.append(contentsOf: inlineRuns(fromMarkup: literal, baseStyle: style))
            literal = ""
        }

        while i < chars.count {
            let c = chars[i]
            guard let closer = closingToken(for: c) else {
                literal.append(c)
                i += 1
                continue
            }
            guard let end = nextIndex(of: closer, in: chars, from: i + 1) else {
                PSContentStore.fail(
                    "unterminated token U+\(String(format: "%04X", c.unicodeScalars.first!.value))",
                    report: reportFailures)
                return nil
            }
            let payload = String(chars[(i + 1)..<end])
            flushLiteral([])

            if let axis = gatingAxis(for: c), !axis(options) {
                // Option off. Red-letter keeps its payload; the anchors have no
                // surviving text of their own. Identical to the HTML emitter.
                if c == redLetterOpen {
                    guard let inner = runs(from: payload, options: options,
                                           reportFailures: reportFailures) else { return nil }
                    out += inner
                }
                i = end + 1
                continue
            }

            switch c {
            case strongsOpen:
                guard let run = strongsRun(payload, reportFailures) else { return nil }
                out.append(run)
            case morphOpen:
                guard let run = morphRun(payload, reportFailures) else { return nil }
                out.append(run)
            case noteOpen, xrefOpen:
                let fields = payload.components(separatedBy: "|")
                guard fields.count == 3 else {
                    PSContentStore.fail("bad note payload: \(payload.debugDescription)",
                                        report: reportFailures)
                    return nil
                }
                let kind = c == xrefOpen ? "x" : "n"
                out.append(
                    InlineRun(text: kind,
                              style: .smaller,
                              link: .note(kind: kind, value: fields[0],
                                          module: fields[1], passage: fields[2]),
                              isMarker: true)
                )
            case titleOpen:
                guard let inner = runs(from: payload, options: options,
                                        reportFailures: reportFailures) else { return nil }
                // Marked so `hoistLeadingTitles` can lift it into a heading, and
                // bold because that is what `<p><b>` meant.
                out += inner.map {
                    var run = $0
                    run.style.insert(.bold)
                    run.style.insert(.titleMarker)
                    return run
                }
            case scripRefOpen:
                guard !payload.contains("|") else {
                    PSContentStore.fail("bad scripRef payload: \(payload.debugDescription)",
                                        report: reportFailures)
                    return nil
                }
                // The HTML emitter writes only the OPENING anchor here: the
                // matching `</a>` comes from the surrounding text's own end tag,
                // so the link's extent is not knowable from this token alone.
                // Unreachable for the shipped content; recorded as a zero-width
                // run so a future module's link is not silently dropped.
                out.append(
                    InlineRun(text: "", link: .scriptRef(value: payload))
                )
            case redLetterOpen:
                guard let inner = runs(from: payload, options: options,
                                        reportFailures: reportFailures) else { return nil }
                // The HTML carried a literal leading/trailing space inside the
                // span (`<span class="WordOfChrist"> ` / `</span> `); those are
                // part of the construct, so they are preserved as text.
                out.append(InlineRun(text: " ", style: .wordOfChrist))
                out += inner.map {
                    var run = $0
                    run.style.insert(.wordOfChrist)
                    return run
                }
                out.append(InlineRun(text: " ", style: .wordOfChrist))
            default:
                PSContentStore.fail("unhandled token", report: reportFailures)
                return nil
            }
            i = end + 1
        }
        flushLiteral([])
        return out
    }

    private static func nextIndex(of target: Character,
                                 in chars: [Character],
                                 from start: Int) -> Int? {
        var i = start
        while i < chars.count {
            if chars[i] == target { return i }
            i += 1
        }
        return nil
    }

    /// `\x01 G|H|- value \x02`, or the explicit `*type|value|shown` form.
    private static func strongsRun(_ payload: String, _ report: Bool) -> InlineRun? {
        let type: String
        let value: String
        let shown: String
        if payload.hasPrefix("*") {
            let fields = String(payload.dropFirst()).components(separatedBy: "|")
            guard fields.count == 3 else {
                PSContentStore.fail("bad strongs payload: \(payload.debugDescription)",
                                    report: report)
                return nil
            }
            (type, value, shown) = (fields[0], fields[1], fields[2])
        } else {
            guard let flag = payload.first else {
                PSContentStore.fail("empty strongs payload", report: report)
                return nil
            }
            value = String(payload.dropFirst())
            shown = value
            switch flag {
            case "G": type = "Greek"
            case "H": type = "Hebrew"
            case "-": type = ""
            default:
                PSContentStore.fail("bad strongs flag '\(flag)'", report: report)
                return nil
            }
        }
        // `<H0430>` — the angle brackets were `&lt;`/`&gt;` in the HTML.
        return InlineRun(text: "<\(shown)>",
                         style: .smaller,
                         link: .strongs(type: type, value: value),
                         isMarker: true)
    }

    /// `\x03 type|value \x04`, or the explicit `*type|value|shown` form. Both
    /// derivations `PSChapterExpander` reconstructs are reconstructed here too.
    private static func morphRun(_ payload: String, _ report: Bool) -> InlineRun? {
        let type: String
        let value: String
        var shown: String
        if payload.hasPrefix("*") {
            let fields = String(payload.dropFirst()).components(separatedBy: "|")
            guard fields.count == 3 else {
                PSContentStore.fail("bad morph payload: \(payload.debugDescription)",
                                    report: report)
                return nil
            }
            (type, value, shown) = (fields[0], fields[1], fields[2])
        } else {
            let fields = payload.components(separatedBy: "|")
            guard fields.count == 2 else {
                PSContentStore.fail("bad morph payload: \(payload.debugDescription)",
                                    report: report)
                return nil
            }
            value = fields[1]
            type = fields[0].isEmpty ? "strongMorph%3A" + value : fields[0]
            shown = value
            let v = Array(value)
            if v.count >= 3, v[0] == "T", v[1] == "H" || v[1] == "G",
               v[2].isNumber, v[2].isASCII {
                shown = String(v[2...])
            }
        }
        return InlineRun(text: "(\(shown))",
                         style: .smaller,
                         link: .morph(type: type, value: value),
                         isMarker: true)
    }

    // MARK: Literal markup

    /// Split literal inter-token text on the only two raw tags the chapter corpus
    /// contains, decoding numeric entities.
    ///
    /// Measured over the whole corpus: `<i class="transChangeAdded">` (21,568) and
    /// `<font size="-1">` (6,886) inside chapter records, and nothing else. An
    /// unrecognised tag is DROPPED rather than shown as literal text — the HTML
    /// renderer would not have displayed it either — and reported in debug so a
    /// vocabulary change cannot pass silently.
    static func inlineRuns(fromMarkup markup: String,
                           baseStyle: InlineStyle) -> [InlineRun] {
        var out: [InlineRun] = []
        var style = baseStyle
        var text = ""
        var i = markup.startIndex

        func flush() {
            guard !text.isEmpty else { return }
            out.append(InlineRun(text: decodeEntities(text), style: style))
            text = ""
        }

        while i < markup.endIndex {
            let c = markup[i]
            guard c == "<" else {
                text.append(c)
                i = markup.index(after: i)
                continue
            }
            guard let close = markup[i...].firstIndex(of: ">") else {
                // An unterminated `<` is literal text.
                text.append(contentsOf: markup[i...])
                break
            }
            let tag = String(markup[markup.index(after: i)..<close])
            flush()
            let lower = tag.lowercased()
            if lower.hasPrefix("i ") || lower == "i" {
                style.insert(lower.contains("transchangeadded") ? .transChangeAdded : .italic)
            } else if lower == "/i" {
                style.remove(.transChangeAdded)
                style.remove(.italic)
            } else if lower.hasPrefix("font") {
                style.insert(.smaller)
            } else if lower == "/font" {
                style.remove(.smaller)
            } else if lower == "b" {
                style.insert(.bold)
            } else if lower == "/b" {
                style.remove(.bold)
            } else if lower == "br" || lower == "br/" || lower == "br /" {
                text.append("\n")
            } else {
                PSContentStore.fail(
                    "chapter markup carries an unmodelled tag <\(tag)> — the native"
                    + " reader is dropping it; the corpus scan found only i/font",
                    report: false)
            }
            i = markup.index(after: close)
        }
        flush()
        return out
    }

    /// Decode the entity forms the corpus uses.
    ///
    /// Numeric only (`&#182;` the pilcrow, `&#8217;` the right single quote,
    /// `&#8211;` en dash, `&#230;` æ, a run of Hebrew letters), plus the five named
    /// ones the expander's own anchor templates emit (`&amp;` `&lt;` `&gt;`
    /// `&quot;` `&apos;`) so a run that came through markup reads correctly.
    static func decodeEntities(_ input: String) -> String {
        guard input.contains("&") else { return input }
        var out = ""
        out.reserveCapacity(input.count)
        var i = input.startIndex

        while i < input.endIndex {
            guard input[i] == "&",
                  let semi = input[i...].firstIndex(of: ";"),
                  input.distance(from: i, to: semi) <= 10 else {
                out.append(input[i])
                i = input.index(after: i)
                continue
            }
            let body = String(input[input.index(after: i)..<semi])
            if body.hasPrefix("#") {
                let digits = String(body.dropFirst())
                let scalarValue: UInt32?
                if digits.lowercased().hasPrefix("x") {
                    scalarValue = UInt32(digits.dropFirst(), radix: 16)
                } else {
                    scalarValue = UInt32(digits)
                }
                if let value = scalarValue, let scalar = Unicode.Scalar(value) {
                    out.unicodeScalars.append(scalar)
                    i = input.index(after: semi)
                    continue
                }
            } else {
                switch body {
                case "amp":  out.append("&");  i = input.index(after: semi); continue
                case "lt":   out.append("<");  i = input.index(after: semi); continue
                case "gt":   out.append(">");  i = input.index(after: semi); continue
                case "quot": out.append("\""); i = input.index(after: semi); continue
                case "apos": out.append("'");  i = input.index(after: semi); continue
                case "nbsp": out.append("\u{00A0}"); i = input.index(after: semi); continue
                default: break
                }
            }
            out.append(input[i])
            i = input.index(after: i)
        }
        return out
    }
}

// MARK: - Internal style marker

extension InlineStyle {
    /// Marks runs that came from a title token, so `hoistLeadingTitles` can lift
    /// them out. Stripped before the document is returned, so it never reaches a
    /// view — hence `fileprivate`-by-convention rather than a public axis.
    static let titleMarker = InlineStyle(rawValue: 1 << 30)
}
