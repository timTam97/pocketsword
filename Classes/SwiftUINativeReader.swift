//
//  SwiftUINativeReader.swift
//  PocketSword
//
//  Wave 9: the native reading surface. This is what replaces the WebView.
//
//  `ChapterTextView` renders a `ChapterDocument` (see `PSChapterDocument.swift`)
//  into a `ScrollView` + `LazyVStack` of `Text` views built from
//  `AttributedString`. No WebKit, no HTML, no JavaScript, and no measured pixel
//  offsets.
//
//  ── Edge-to-edge, which is Wave 9's acceptance criterion ───────────────────
//
//  The chapter must SCROLL UNDER the chrome, not stop at it. Both halves of that
//  tradeoff have already been got wrong once each, so neither is acceptable:
//
//   * Wave 6 let the WebView extend under the floating tab bar with no content
//     inset, and lines painted permanently behind it.
//   * Wave 7 kept the WebView inside the safe area, which fixed the overlap and
//     produced letterboxing — black bands top and bottom.
//
//  The answer is both at once, and in a native scroll view it is two modifiers
//  rather than a change to the render path:
//
//      .contentMargins(.vertical, insets, for: .scrollContent)   // content inset
//      .ignoresSafeArea(edges: .vertical)                        // full-height view
//
//  The scroll VIEW is full-height, so text flows to the physical edges and passes
//  beneath the translucent bars; the scroll CONTENT carries the safe-area insets, so
//  no line is ever obscured at rest. This is the one-call fix the Wave 7 comment
//  promised, and it is why the insets were never worth moving into the HTML for a
//  view this wave deletes.
//
//  ── Why the six `<p>&nbsp;</p>` pads are gone ─────────────────────────────
//
//  `PSContentReader.chapterPage` appended six hardcoded non-breaking-space
//  paragraphs — a faithful port of `-getChapter:`'s own six — to buy scroll room
//  past the bottom chrome. `contentMargins` is that, expressed once and correctly:
//  it scales with the actual bar height instead of six line heights of a font size
//  the pads did not know.
//
//  ── Prose vs verse-per-line ───────────────────────────────────────────────
//
//  With the per-module verse-per-line pref OFF (the default, and how the app has
//  always read) verses flow together as continuous prose with superscript numbers
//  inline, breaking at the KJV's own pilcrows. With it ON, each verse is its own
//  row. Both are preserved — see `ChapterParagraph`'s doc comment for why that
//  mattered enough to shape the document type.
//
//  ── Scroll position: identity, not pixels ─────────────────────────────────
//
//  The WebView reported a `versepos` table of measured `offsetTop` values through an
//  `arraydump:` URL, and scroll-to-verse looked up a pixel offset in it. That whole
//  mechanism is gone: `ScrollPosition(id:)` addresses a verse by identity, and
//  `onScrollGeometryChange` reports where the reader is. Two consequences worth
//  stating, because they delete code rather than move it:
//
//   * **Rotation needs no re-measure.** Wave 6's `resetArrays()` +
//     `scrollToVerse()` dance existed because offsets are width-dependent. Identity
//     is not, so the scroll view keeps its anchor across a size change for free.
//   * **There is no poll.** `startDetLocPoll` / `stopDetLocPoll` bracketed a
//     `setInterval` that was **already commented out** in the shipped JS, so the
//     `pocketsword:currentverse:` bridge never actually fired; verse tracking ran
//     entirely off `arraydump` offsets plus scroll callbacks. The native reader
//     tracks the visible verse directly.
//

import SwiftUI

// MARK: - Rendering the document

/// Turns `ChapterDocument` values into `AttributedString`s.
///
/// Kept separate from the views so the mapping from a run's style to its
/// presentation is one place, and so it can be exercised without a view host.
enum ChapterTextRenderer {

    /// Styling inputs the reader supplies. These are the same preferences the HTML
    /// shell read out of `UserDefaults` — one global font and size — resolved once
    /// per render rather than baked into a `<style>` block.
    struct Style {
        var fontName: String
        var fontSize: CGFloat
        /// `createHTMLString`'s `line-height`: 1.4 on iPhone, 1.6 on iPad.
        var lineSpacingMultiple: CGFloat
        /// Whether Strong's / morph / footnote markers are shown at all. The
        /// per-module toggles already gate them out of the document; this is the
        /// view-level switch the search highlighter uses.
        var showsMarkers = true

        /// The terms to highlight, case-insensitively — what `SearchWebView.js`
        /// walked the DOM to do. Empty for a Strong's search, where the match is a
        /// lemma the marker points at rather than text present in the verse.
        var highlightTerms: [String] = []

        /// Resolve from the same defaults keys the HTML shell used, so a font
        /// chosen in Settings applies identically.
        static func current() -> Style {
            let defaults = UserDefaults.standard
            var name = (defaults.object(forKey: Defaults.fontNamePreference) as? String)
                ?? AppConstants.defaultFontName
            if name.isEmpty { name = AppConstants.defaultFontName }
            let size = defaults.integer(forKey: Defaults.fontSizePreference)
            return Style(
                fontName: name,
                fontSize: CGFloat(size == 0 ? 14 : size),
                lineSpacingMultiple: UIDevice.current.userInterfaceIdiom == .phone
                    ? 1.4
                    : 1.6
            )
        }
    }

    /// The verse number, as the superscript label the `a.verse` CSS produced
    /// (70% size, superscript, body colour).
    ///
    /// `tappable` carries the verse-menu link. It is false on a commentary, matching
    /// the deliberate quirk the assembler preserved: a commentary's verse anchor was
    /// `href="#verse%ld"`, not `pocketsword:versemenu:`, so tapping a commentary
    /// verse has never done anything (SwordModule.mm:1116).
    static func verseLabel(_ number: Int, style: Style,
                           tappable: Bool = false) -> AttributedString {
        // A trailing hair space so the number never touches the first word.
        var label = AttributedString("\(number)\u{200A}")
        // 0.75 rather than the CSS's 0.7, and SEMIBOLD. In the WebView a verse
        // number was distinguishable from a Strong's marker by colour alone — both
        // were 70% superscripts, the number in body colour and the marker in grey.
        // Measured on device, that is not enough at 12pt in flowing prose: the
        // numbers disappeared into the markers and the chapter read as one run of
        // superscripts. Weight separates them structurally rather than by hue, which
        // also survives a user who cannot distinguish the two greys.
        label.font = .custom(style.fontName, size: style.fontSize * 0.75)
            .weight(.semibold)
        label.baselineOffset = style.fontSize * 0.32
        label.foregroundColor = .primary
        if tappable, let url = InlineLink.verseMenu(verse: number).url {
            label.link = url
        }
        return label
    }

    /// One verse's text.
    static func text(for verse: ChapterVerse, style: Style) -> AttributedString {
        var out = attributed(runs: verse.runs, style: style)
        for term in style.highlightTerms where !term.isEmpty {
            applyHighlight(term, to: &out)
        }
        return out
    }

    /// Jacket every case-insensitive occurrence of `term` in yellow.
    ///
    /// This is `PS_HighlightAllOccurencesOfString`'s effect. That function
    /// recursively split text nodes and inserted a
    /// `<span class="PocketSwordHighlight">` with `background-color: yellow;
    /// color: black`, skipping `display:none` elements and `<select>`. An
    /// `AttributedString` range carries the same two properties with none of the DOM
    /// followed by `PS_RemoveAllHighlights`'s unwrap-and-normalise to undo it.
    ///
    /// Matching is case-insensitive and diacritic-jacket-free, exactly as the JS was
    /// (`value.toLowerCase().indexOf(keyword)` against an already-lowercased term).
    private static func applyHighlight(_ term: String, to text: inout AttributedString) {
        let jacket = AttributeContainer()
            .backgroundColor(.yellow)
            .foregroundColor(.black)
        var searchRange = text.startIndex..<text.endIndex
        while let found = text[searchRange].range(of: term,
                                                  options: .caseInsensitive) {
            text[found].mergeAttributes(jacket)
            guard found.upperBound < text.endIndex else { break }
            searchRange = found.upperBound..<text.endIndex
        }
    }

    /// A heading's text — `<p><b>` in the HTML.
    static func text(for heading: ChapterHeading, style: Style) -> AttributedString {
        var out = attributed(runs: heading.runs, style: style)
        out.font = .custom(style.fontName, size: style.fontSize).bold()
        return out
    }

    /// Map runs to an `AttributedString`, carrying links as `AttributeContainer`
    /// values so a tap can be routed without re-parsing anything.
    static func attributed(runs: [InlineRun], style: Style) -> AttributedString {
        var out = AttributedString()
        for run in runs {
            if run.isMarker && !style.showsMarkers { continue }
            guard !run.text.isEmpty else { continue }
            var piece = AttributedString(run.text)

            // Size and weight.
            var size = style.fontSize
            if run.style.contains(.smaller) {
                // `a.strongs` / `a.morph` / `a.n` were all `font-size: 70%`, and
                // `font size="-1"` became two points smaller. 70% is the dominant
                // case by three orders of magnitude, so it is the default here and
                // the two-point form is not separately modelled.
                size = style.fontSize * 0.7
            }
            var font = Font.custom(style.fontName, size: size)
            if run.style.contains(.bold) { font = font.bold() }
            if run.style.contains(.italic) || run.style.contains(.transChangeAdded) {
                font = font.italic()
            }
            piece.font = font

            // Colour. Order matters: red-letter wins over the grey of a marker,
            // because a Strong's number inside a WordOfChrist span rendered red in
            // the HTML too (the span set `color` on its subtree).
            if run.style.contains(.transChangeAdded) {
                piece.foregroundColor = .secondary          // i.transChangeAdded { color: gray }
            }
            if run.isMarker {
                piece.foregroundColor = .secondary          // a.strongs/.morph/.n { color: gray }
                piece.baselineOffset = size * 0.34          // vertical-align: super
            }
            if run.style.contains(.wordOfChrist) {
                piece.foregroundColor = .wordOfChrist
            }

            // `AttributedString.link` is the ONLY way to make a span of `Text`
            // tappable in SwiftUI, so the typed link is carried as a `pslink://`
            // URL and turned back into an `InlineLink` by the tap handler. The
            // underline is suppressed to match `a { text-decoration: none }`.
            if let link = run.link, let url = link.url {
                piece.link = url
                piece.underlineStyle = nil
            }
            out += piece
        }
        return out
    }
}

extension Color {
    /// `span.WordOfChrist { color: #D03030 }`, with the dark-mode override the
    /// shell carried (`@media (prefers-color-scheme: dark) { #FF7070 }`).
    static let wordOfChrist = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.44, blue: 0.44, alpha: 1)
                : UIColor(red: 0.82, green: 0.19, blue: 0.19, alpha: 1)
        }
    )

    /// Parse the `rgba(r,g,b,a)` string the bookmark store produces.
    ///
    /// That format is `PSBookmarkFolder.rgbString(fromHexString:)`'s output and is
    /// persisted-adjacent, so it is parsed rather than reimplemented.
    init?(bookmarkRGBAString string: String) {
        guard string.hasPrefix("rgba(") || string.hasPrefix("rgb(") else { return nil }
        let body = string
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let parts = body.components(separatedBy: ",")
        guard parts.count >= 3,
              let r = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let g = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              let b = Double(parts[2].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        let alpha = parts.count > 3
            ? (Double(parts[3].trimmingCharacters(in: .whitespaces)) ?? 0.8)
            : 0.8
        self = Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }
}

// MARK: - The reading surface

/// The native chapter view.
///
/// Owns only presentation: the document, the scroll position and the tap routing
/// come from `ReaderPaneModel`, exactly as the WebView's did.
struct ChapterTextView: View {
    let pane: ReaderPaneModel

    @Environment(\.self) private var environment

    var body: some View {
        @Bindable var pane = pane

        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let message = pane.document.emptyMessage {
                        EmptyChapterNotice(message: message)
                    } else if pane.versePerLine {
                        ForEach(pane.document.verses) { verse in
                            VerseRow(verse: verse, pane: pane, style: pane.textStyle)
                                .id(verse.number)
                                .tracksTopmostVerse([verse], pane: pane)
                        }
                    } else {
                        ForEach(pane.document.paragraphs) { paragraph in
                            ParagraphRow(paragraph: paragraph, pane: pane,
                                         style: pane.textStyle)
                                .id(paragraph.id)
                                .tracksTopmostVerse(paragraph.verses, pane: pane)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .scrollTargetLayout()
            }
            .scrollPosition($pane.scrollPosition)
            // ── Wave 9's acceptance criterion, in two lines. ──
            //
            // The scroll view fills the window (`ignoresSafeArea`) so text reaches
            // the physical edges and flows under the translucent navigation bar and
            // floating tab bar; the CONTENT carries the safe-area insets
            // (`contentMargins`) so no line is ever obscured at rest. Wave 6 had the
            // first without the second (text hidden behind the tab bar); Wave 7 had
            // the second without the first (letterboxed with black bands).
            //
            // `for: .scrollContent` is the placement that insets the content rather
            // than the indicators — using the default would also pull the scroll
            // indicator inward and leave it floating.
            .contentMargins(
                .vertical,
                EdgeInsets(top: proxy.safeAreaInsets.top,
                           leading: 0,
                           bottom: proxy.safeAreaInsets.bottom,
                           trailing: 0),
                for: .scrollContent
            )
            .ignoresSafeArea(edges: .vertical)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                pane.scrollOffsetChanged(offset)
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if oldPhase != .animating, oldPhase.isScrolling, newPhase == .idle {
                    pane.userScrollEnded()
                }
            }
        }
        // The identifier the XCUITests match on. It was `reading.web-content` on the
        // WebView container; kept as a distinct name so a test cannot accidentally
        // pass against a surface that no longer exists.
        .accessibilityIdentifier("reading.chapter-content")
    }

    /// `createHTMLString` gave the iPad body a 10pt padding and the iPhone none;
    /// text pinned to the physical edge is unreadable now that the view is
    /// full-width, so the phone gets a modest gutter too.
    private var horizontalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 16 : 20
    }
}

private extension View {
    /// Reports this row's verse to the pane while it is the topmost visible one.
    ///
    /// This is the replacement for the JS `currentVerse()` scan, and it is the piece
    /// that has to live in the VIEW rather than the model: only the view knows where
    /// a row actually sits, because the whole point of Wave 9 is that the model no
    /// longer holds measured offsets.
    ///
    /// `currentVerse()` walked the `versepos` table for the first entry past
    /// `window.pageYOffset` and clamped at both ends. The native equivalent asks each
    /// row whether it straddles the top of the viewport, which needs no table and
    /// stays correct across a rotation for free.
    ///
    /// Found on device: without this, `scrollOffsetChanged` persisted the OFFSET but
    /// re-persisted the old verse, so `bibleVersePosition` stuck at 1 while the
    /// reader sat at verse 11 — and the toolbar title went with it. That also breaks
    /// relaunch restoration, since `.verse` restores read that key.
    func tracksTopmostVerse(_ verses: [ChapterVerse], pane: ReaderPaneModel) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            // The row covers the top of the reading area (in the scroll view's own
            // space, where 0 is the top of the visible content).
            let frame = proxy.frame(in: .scrollView)
            return frame.minY <= 1 && frame.maxY > 1
        } action: { _, isTopmost in
            guard isTopmost, let first = verses.first else { return }
            pane.topmostVerseChanged(first.number)
        }
    }
}

/// One flowing paragraph: several verses concatenated, numbers inline.
private struct ParagraphRow: View {
    let paragraph: ChapterParagraph
    let pane: ReaderPaneModel
    let style: ChapterTextRenderer.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(paragraph.headings.enumerated()), id: \.offset) { _, heading in
                HeadingRow(heading: heading, style: style)
            }
            ChapterRunsText(text: flowed, pane: pane, style: style)
                .padding(.bottom, style.fontSize * 0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The verses of this paragraph, run together with their superscript numbers —
    /// which is exactly what the HTML did with verse 1 of a chapter and every verse
    /// after it that did not open a paragraph.
    private var flowed: AttributedString {
        var out = AttributedString()
        for verse in paragraph.verses {
            if !verse.isIntro {
                out += ChapterTextRenderer.verseLabel(
                    verse.number,
                    style: style,
                    tappable: pane.mode == .bible
                )
            }
            var body = ChapterTextRenderer.text(for: verse, style: style)
            if let colour = verse.highlightColour,
               let background = Color(bookmarkRGBAString: colour) {
                // The HTML wrapped a highlighted verse in a span per block element
                // (64 spans for Ps 23's three verses, faithfully); an
                // `AttributedString` background runs the length of the range, which
                // is the same visible result without the span gymnastics.
                body.backgroundColor = background
                body.foregroundColor = .black
            }
            out += body
        }
        return out
    }
}

/// One verse on its own row — the verse-per-line layout.
private struct VerseRow: View {
    let verse: ChapterVerse
    let pane: ReaderPaneModel
    let style: ChapterTextRenderer.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(verse.headings.enumerated()), id: \.offset) { _, heading in
                HeadingRow(heading: heading, style: style)
            }
            ChapterRunsText(text: labelled, pane: pane, style: style)
                .padding(.bottom, style.fontSize * 0.35)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var labelled: AttributedString {
        var out = AttributedString()
        if !verse.isIntro {
            out += ChapterTextRenderer.verseLabel(
                verse.number,
                style: style,
                tappable: pane.mode == .bible
            )
            out += AttributedString(" ")
        }
        var body = ChapterTextRenderer.text(for: verse, style: style)
        if let colour = verse.highlightColour,
           let background = Color(bookmarkRGBAString: colour) {
            body.backgroundColor = background
            body.foregroundColor = .black
        }
        out += body
        return out
    }
}

private struct HeadingRow: View {
    let heading: ChapterHeading
    let style: ChapterTextRenderer.Style

    var body: some View {
        Text(ChapterTextRenderer.text(for: heading, style: style))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, style.fontSize * 0.7)
            .padding(.bottom, style.fontSize * 0.3)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A `Text` that routes taps on its links.
///
/// Links reach the string as `pslink://` URLs (the only way SwiftUI makes a span of
/// `Text` tappable), and this is where they are turned back into typed
/// `InlineLink`s and handed to the pane. An `openURL` environment override is used
/// rather than `onOpenURL`: the latter is for URLs arriving from outside the app,
/// and would send a Strong's tap out through `AppSession`'s `sword://` router.
private struct ChapterRunsText: View {
    let text: AttributedString
    let pane: ReaderPaneModel
    let style: ChapterTextRenderer.Style

    var body: some View {
        Text(text)
            .lineSpacing(style.fontSize * (style.lineSpacingMultiple - 1))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                guard let link = InlineLink(url: url) else {
                    // Not one of ours — let the system have it. MHCC's own
                    // `sword://` scripture links arrive here.
                    return .systemAction
                }
                pane.handle(link: link)
                return .handled
            })
    }
}

// MARK: - Lexicon entries and footnotes

/// The native renderer for a lexicon entry or a footnote — Wave 9's replacement for
/// `StudyPopupWebView` and `DictionaryEntryWebView`.
///
/// A `ScrollView` of `Text`, one per `EntryBlock`. It inherits the sheet's material
/// for free, which is what `createInfoHTMLString`'s injected
/// `html, body { background-color: transparent; }` was working around, and it needs
/// none of the 60 lines of CSS `createStrongsInfoHTMLString` pushed into the page to
/// make a WebView resemble the sheet it sat in.
struct EntryTextView: View {
    let document: EntryDocument
    /// Tapping a cross-link.
    ///
    /// When `nil` the link is left to the system rather than swallowed — see the
    /// `openURL` override below. Both call sites supply one; `nil` exists so a
    /// preview or a future read-only surface cannot silently eat a tap.
    var openLink: ((EntryLink) -> Void)?
    var topInset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(document.blocks) { block in
                    Text(attributed(block))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, blockSpacing(block))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset)
            .padding(.bottom, 28)
        }
        .environment(\.openURL, OpenURLAction { url in
            // `.handled` is claimed ONLY when there is a handler to claim it for.
            //
            // The bug this guards was upstream — `StudyPopupSheet` simply passed no
            // `openLink`, so `openLink?(link)` was a no-op on a link that looked live
            // and highlighted on press. Both call sites now pass one, so this arm is
            // unreachable in the shipping app; it is kept so that a future surface
            // which forgets to wire `openLink` degrades to the system's handling
            // instead of silently eating the tap. Verified by reverting the sheet:
            // `testLexiconCrossLinkNavigatesWithinThePopup` goes red, and reverting
            // this guard alone does NOT reproduce the defect.
            guard let link = EntryLink(url: url), let openLink else {
                return .systemAction
            }
            openLink(link)
            return .handled
        })
        .textSelection(.enabled)
    }

    /// An empty block is the lexicons' paragraph spacing (a doubled `<br />`), so it
    /// contributes space rather than a blank line of text.
    private func blockSpacing(_ block: EntryBlock) -> CGFloat {
        block.runs.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            ? 8
            : 2
    }

    private func attributed(_ block: EntryBlock) -> AttributedString {
        var out = AttributedString()
        for run in block.runs where !run.text.isEmpty {
            var piece = AttributedString(run.text)
            var size: CGFloat = 17
            if run.style.contains(.smaller) { size = 13 }
            var font = Font.system(size: size)
            if run.style.contains(.bold) { font = font.bold() }
            if run.style.contains(.italic) || run.style.contains(.transChangeAdded) {
                font = font.italic()
            }
            piece.font = font
            if run.style.contains(.superscript) { piece.baselineOffset = 5 }
            if run.style.contains(.subscript) { piece.baselineOffset = -3 }
            if let link = run.entryLink, let url = link.url {
                piece.link = url
                piece.foregroundColor = StudyPalette.accent
                piece.underlineStyle = .single
            }
            out += piece
        }
        return out
    }
}

private struct EmptyChapterNotice: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.body.italic())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .accessibilityIdentifier("reading.empty-chapter")
    }
}
