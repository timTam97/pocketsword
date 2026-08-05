//
//  PSEntryDocument.swift
//  PocketSword
//
//  Wave 9: the native renderer for LEXICON ENTRIES and FOOTNOTES — the two study
//  surfaces that were still `WKWebView`s after the chapter reader went native.
//
//  ── Why this is separate from the chapter renderer ─────────────────────────
//
//  The chapter corpus is a closed set of six inline tags (see
//  `PSChapterDocument.swift`). The lexicons are NOT the same set, and reusing the
//  chapter renderer for them would silently drop most of their structure. Measured
//  over all 15,824 dictionary fields of the three bundled lexicons:
//
//  | tag | occurrences | note |
//  |---|---|---|
//  | `i` | 41,549 | field labels — "*Part of Speech*: Adjective" |
//  | `br` | 40,469 | the ONLY line break; Robinson is nothing but these |
//  | `a` | 29,287 | 14,298 `name=` anchors + 14,989 `href=` cross-links |
//  | `b` | 21,678 | headwords |
//  | `sup` / `font size` | 1,723 each | the Hebrew vowel-point superscripts |
//  | `q` | 29 | quotations |
//  | `bib bn=` | 66 | a scripture reference, non-standard tag |
//  | `latin` `greek` `description` `pronunciation` `sub` `/dictionary` | ≤85 | strays |
//
//  Footnotes are narrower still — 13,918 fields containing only `i` and `font`.
//
//  So `br` matters here and does not exist in a chapter; `a name=` anchors have to
//  be dropped rather than rendered; and the six stray tags are real content that a
//  chapter-shaped renderer would not model.
//
//  ── The links ─────────────────────────────────────────────────────────────
//
//  All 14,989 `href`s are lexicon→lexicon `sword://` links, and they are what makes
//  a definition navigable ("Plural of 433"). They are carried as
//  `EntryLink.lexicon(module:key:)` and re-encoded as `pslink://` for the same
//  reason the chapter's are: `AttributedString.link` is the only way SwiftUI makes a
//  span of `Text` tappable.
//
//  ── What this replaces ────────────────────────────────────────────────────
//
//  `StudyPopupWebView` and `DictionaryEntryWebView`, plus the three HTML shells
//  those needed — `createHTMLString`, `createInfoHTMLString` and
//  `createStrongsInfoHTMLString`, the last of which carried 60 lines of injected CSS
//  purely so a `WKWebView` could look like the sheet it sat in. A `Text` inherits
//  the sheet's material for free, which is what the `background-color: transparent`
//  injection was working around.
//
//  `PSInfoPopupContent`'s lemma/transliteration parser is UNTOUCHED and still reads
//  the raw entry. It is content, not presentation.
//

import Foundation

/// A tappable target inside a lexicon entry or footnote.
enum EntryLink: Equatable, Hashable {
    /// A `sword://<module>/<key>` cross-reference to another lexicon entry.
    case lexicon(module: String, key: String)

    var url: URL? {
        switch self {
        case .lexicon(let module, let key):
            var components = URLComponents()
            components.scheme = "pslink"
            components.host = "lexicon"
            components.path = "/\(module)"
            components.queryItems = [URLQueryItem(name: "key", value: key)]
            return components.url
        }
    }

    init?(url: URL) {
        guard url.scheme == "pslink", url.host == "lexicon" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let module = parts.first else { return nil }
        let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "key" }?.value ?? ""
        self = .lexicon(module: module, key: key)
    }
}

/// One block of an entry. Entries are a flat sequence of paragraphs separated by
/// `<br />`, which is the only structure the lexicons have.
struct EntryBlock: Identifiable, Equatable {
    let id: Int
    var runs: [InlineRun]
    var link: EntryLink?
}

/// A rendered lexicon entry or footnote.
struct EntryDocument: Equatable {
    var blocks: [EntryBlock] = []
    var isEmpty: Bool { blocks.allSatisfy { $0.runs.allSatisfy { $0.text.isEmpty } } }
}

/// Builds `EntryDocument`s from stored lexicon / note HTML.
enum PSEntryDocumentBuilder {

    /// Parse an entry's HTML into blocks.
    ///
    /// The input here is already-expanded HTML rather than a token stream, because
    /// that is what the store yields for a lexicon: `PSContentStore.dictEntry` runs
    /// the tokens through `PSChapterExpander` on the way out, and the note path does
    /// the same. So this is a small tag scanner over a known vocabulary, not a
    /// second token emitter.
    static func build(html: String) -> EntryDocument {
        var document = EntryDocument()
        var runs: [InlineRun] = []
        var style: InlineStyle = []
        var pendingLink: EntryLink?
        var linkDepth = 0
        var text = ""
        var blockIndex = 0
        /// Inside the entry's own `<a name="…">` key anchor, whose text is dropped.
        var suppressingKeyAnchor = false
        /// Swallow the `<br />` that follows that anchor.
        var skipNextBreak = false

        func flushText() {
            guard !text.isEmpty else { return }
            let decoded = PSChapterDocumentBuilder.decodeEntities(text)
            runs.append(
                InlineRun(text: decoded, style: style,
                          link: nil, isMarker: false)
            )
            text = ""
        }

        func flushBlock() {
            flushText()
            // A `<br />` run of two produces an empty block; keep it, because the
            // lexicons use consecutive breaks as paragraph spacing.
            document.blocks.append(
                EntryBlock(id: blockIndex, runs: runs, link: nil)
            )
            blockIndex += 1
            runs = []
        }

        var i = html.startIndex
        while i < html.endIndex {
            let c = html[i]
            guard c == "<" else {
                text.append(c)
                i = html.index(after: i)
                continue
            }
            guard let close = html[i...].firstIndex(of: ">") else {
                text.append(contentsOf: html[i...])
                break
            }
            let tag = String(html[html.index(after: i)..<close])
            let lower = tag.lowercased()
            i = html.index(after: close)

            switch true {
            case lower == "br" || lower == "br/" || lower == "br /":
                if skipNextBreak {
                    skipNextBreak = false
                    text = ""
                } else {
                    flushBlock()
                }
            case lower == "i" || lower.hasPrefix("i "):
                flushText()
                style.insert(lower.contains("transchangeadded") ? .transChangeAdded : .italic)
            case lower == "/i":
                flushText()
                style.remove(.italic)
                style.remove(.transChangeAdded)
            case lower == "b" || lower.hasPrefix("b "):
                flushText()
                style.insert(.bold)
            case lower == "/b":
                flushText()
                style.remove(.bold)
            case lower.hasPrefix("font"), lower == "sup", lower == "sub":
                // `font size="-1"`, and the `<sup>` the Hebrew entries use for a
                // vowel point. Both render smaller; `sup`'s raise is applied by the
                // view so it can scale with the resolved font size.
                flushText()
                style.insert(.smaller)
                if lower == "sup" { style.insert(.superscript) }
                if lower == "sub" { style.insert(.subscript) }
            case lower == "/font", lower == "/sup", lower == "/sub":
                flushText()
                style.remove(.smaller)
                style.remove(.superscript)
                style.remove(.subscript)
            case lower == "q" || lower.hasPrefix("q "):
                flushText()
                style.insert(.italic)
                text.append("\u{201C}")
            case lower == "/q":
                text.append("\u{201D}")
                flushText()
                style.remove(.italic)
            case lower.hasPrefix("a "):
                flushText()
                // A `name=` anchor is a link TARGET; only an `href=` is tappable.
                // Both appear ~14k times, so getting this wrong either loses every
                // cross-link or makes every headword tappable.
                if let href = attribute("href", in: tag) {
                    pendingLink = lexiconLink(from: href)
                    if pendingLink != nil { linkDepth = 1 }
                } else if runs.isEmpty, document.blocks.isEmpty,
                          attribute("name", in: tag) != nil {
                    // The ENTRY'S OWN key anchor, which every lexicon entry opens
                    // with: `<a name="00776"><b>776</b></a>`. Its text is the padded
                    // Strong's number, which the popup already shows as its
                    // reference — so rendering it repeats the number and pushes the
                    // real definition down. The WebView never showed it either: it
                    // was hidden by `createStrongsInfoHTMLString`'s
                    // `a[name]:first-child { display: none }` rule (and the `+ br`
                    // rule after it), which is precisely the CSS this wave deleted.
                    //
                    // Gated on being the FIRST thing in the entry, so a mid-entry
                    // `name=` anchor — which is a legitimate target for a
                    // cross-link — keeps its text.
                    suppressingKeyAnchor = true
                }
            case lower == "/a":
                if suppressingKeyAnchor {
                    // Drop everything the anchor emitted, not just the pending text.
                    // The key anchor wraps its number in `<b>`
                    // (`<a name="04399"><b>4399</b></a>`), and `<b>` flushes — so
                    // clearing `text` alone left the number already appended as a
                    // run. Found on device: H4399 showed "4399 מלאכה" with the number
                    // repeated from the popup's own header.
                    runs.removeAll()
                    text = ""
                    // The `</b>` inside the anchor has not been seen yet, so `.bold`
                    // is still set and would leak into the lemma that follows.
                    style = []
                    suppressingKeyAnchor = false
                    skipNextBreak = true
                    break
                }
                flushText()
                if linkDepth > 0 {
                    // Re-tag the runs emitted since the anchor opened. Walking
                    // backwards and stopping at the first already-linked run is what
                    // keeps two adjacent cross-links from merging into one.
                    if let link = pendingLink {
                        for index in runs.indices.reversed() {
                            guard runs[index].entryLink == nil else { break }
                            runs[index].entryLink = link
                        }
                    }
                    pendingLink = nil
                    linkDepth = 0
                }
            default:
                // `bib bn=`, `latin`, `greek`, `description`, `pronunciation`,
                // `/dictionary` and their closers: unwrapped, contents kept. They
                // carry no presentation of their own in the shipped modules, and
                // dropping the CONTENT would lose real definition text.
                flushText()
            }
        }
        flushBlock()

        // Trim the leading/trailing empty blocks the `a name=` + `br` preamble
        // leaves, which is what the injected CSS's `a[name]:first-child { display:
        // none }` rule was hiding.
        while let first = document.blocks.first,
              first.runs.allSatisfy({ $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
            document.blocks.removeFirst()
        }
        while let last = document.blocks.last,
              last.runs.allSatisfy({ $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
            document.blocks.removeLast()
        }
        return document
    }

    /// `sword://StrongsRealGreek/G3588` -> `.lexicon(module:key:)`.
    ///
    /// Also accepts the `passagestudy.jsp?action=showRef&…` form, which is what the
    /// dictionary's own WebView coordinator used to parse through
    /// `+[PSModuleController data(forLink:)]`.
    private static func lexiconLink(from href: String) -> EntryLink? {
        guard let url = URL(string: href) else { return nil }
        if url.scheme == "sword" {
            guard let module = url.host, !module.isEmpty, module != "Bible" else {
                return nil
            }
            let key = url.pathComponents.filter { $0 != "/" }.first ?? ""
            guard !key.isEmpty else { return nil }
            return .lexicon(module: module,
                            key: key.removingPercentEncoding ?? key)
        }
        // The query form, split without decoding — same as `data(forLink:)`.
        guard href.contains("passagestudy.jsp") else { return nil }
        var fields: [String: String] = [:]
        let query = href.components(separatedBy: "?").dropFirst().joined(separator: "?")
        for pair in query.replacingOccurrences(of: "&amp;", with: "&")
            .components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            fields[kv[0]] = kv[1]
        }
        guard fields["action"] == "showRef",
              let module = fields["modulename"], !module.isEmpty, module != "Bible",
              let value = fields["value"] else {
            return nil
        }
        return .lexicon(module: module,
                        key: value.removingPercentEncoding ?? value)
    }

    /// Read one double-quoted attribute out of a tag body.
    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let range = tag.range(of: "\(name)=\"") else { return nil }
        let rest = tag[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}

extension InlineStyle {
    static let superscript = InlineStyle(rawValue: 1 << 5)
    static let `subscript` = InlineStyle(rawValue: 1 << 6)
}
