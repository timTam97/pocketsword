//
//  PSEntryDocument.swift
//  PocketSword
//
//  The native renderer for LEXICON ENTRIES and FOOTNOTES.
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
//  be dropped rather than rendered; and the stray tags are real content.
//
//  ── The links ─────────────────────────────────────────────────────────────
//
//  All 14,989 `href`s are lexicon→lexicon `sword://` links ("Plural of 433"),
//  carried as `EntryLink.lexicon(module:key:)` and re-encoded as `pslink://`
//  because `AttributedString.link` is the only way SwiftUI makes a span of `Text`
//  tappable.
//
//  `PSInfoPopupContent`'s lemma/transliteration parser reads the raw entry; it is
//  content, not presentation.
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
        /// Index into `runs` of the first run the open anchor emitted, which is what
        /// BOUNDS the link when it closes. See `applyPendingLink()`.
        var linkStartRun = 0
        var text = ""
        var blockIndex = 0
        /// Inside the entry's own `<a name="…">` key anchor, whose text is dropped.
        var suppressingKeyAnchor = false
        /// Swallow the `<br />` that IMMEDIATELY follows that anchor, so the dropped
        /// key does not leave an empty first line.
        ///
        /// "Immediately" is load-bearing. The two Strong's lexicons shape their
        /// preamble differently: all 8,674 Hebrew entries are
        /// `<a name="03899"><b>3899</b></a><br />`, break adjacent, but all 5,624
        /// **Greek** entries are `<a name="03588">3588</a> <b>ὁ</b> [O(] {ho} \<i>ho</i>\<br/>`
        /// — a whole lemma line before the first break. An unconditional flag would
        /// eat the Greek lemma's OWN break. So the flag is cleared as soon as any
        /// content is emitted.
        var skipNextBreak = false

        func flushText() {
            guard !text.isEmpty else { return }
            let decoded = PSChapterDocumentBuilder.decodeEntities(text)
            runs.append(
                InlineRun(text: decoded, style: style,
                          link: nil, isMarker: false)
            )
            text = ""
            // Real content has been emitted, so the pending `<br />` is no longer the
            // key anchor's own — see `skipNextBreak`.
            if !decoded.trimmingCharacters(in: .whitespaces).isEmpty {
                skipNextBreak = false
            }
        }

        func flushBlock() {
            flushText()
            // An anchor that spans a `<br />` owns runs in BOTH blocks, so tag the
            // ones in the block being CLOSED while they are still reachable.
            // `applyPendingLink()` can only see runs in the current `runs` array, and
            // the `</a>` arrives after this copy — so without this the pre-break half
            // of the link goes dead while looking like ordinary prose.
            if linkDepth > 0 { applyPendingLink() }
            // A `<br />` run of two produces an empty block; keep it, because the
            // lexicons use consecutive breaks as paragraph spacing.
            document.blocks.append(
                EntryBlock(id: blockIndex, runs: runs, link: nil)
            )
            blockIndex += 1
            runs = []
            // The anchor is still open, so every run the NEXT block emits before its
            // `</a>` is its own too — 0 is the exact bound for the continuation.
            // Clearing `pendingLink` instead would silently DROP a real cross-link.
            //
            // No shipped content exercises this (zero `href` anchors span a `<br />`,
            // and none are nested or unbalanced), so
            // `testCrossLinkSpanningALineBreakKeepsBothHalves` is synthetic on purpose
            // and is the only thing holding this.
            linkStartRun = 0
        }

        /// Tag the runs the anchor has emitted INTO `runs` with its link.
        ///
        /// Called from `</a>`, and from `flushBlock()` for an anchor still open when a
        /// `<br />` splits it — in that case it runs twice, once per block, each time
        /// bounding at the runs that block actually holds.
        ///
        /// **Bounded at `linkStartRun`, which is the whole point.** A lexicon entry is
        /// one long block of prose with a cross-link every few words, and the text
        /// between links carries no link. Inferring the start by walking backwards to
        /// the previous linked run would jacket the whole span between two links (e.g.
        /// all of H3899's definition as one link). Recording where the anchor OPENED
        /// is exact and keeps adjacent cross-links separate.
        func applyPendingLink() {
            guard let link = pendingLink, linkStartRun < runs.count else { return }
            for index in linkStartRun..<runs.count {
                runs[index].entryLink = link
            }
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
                    if pendingLink != nil {
                        linkDepth = 1
                        // `flushText()` above has already emitted everything before
                        // the anchor, so the next run appended is the anchor's first.
                        linkStartRun = runs.count
                    }
                } else if runs.isEmpty, document.blocks.isEmpty,
                          attribute("name", in: tag) != nil {
                    // The ENTRY'S OWN key anchor, which every lexicon entry opens with:
                    // `<a name="00776"><b>776</b></a>`. Its text is the padded Strong's number
                    // the popup already shows as its reference, so rendering it repeats the
                    // number and pushes the definition down.
                    //
                    // Gated on being the FIRST thing in the entry, so a mid-entry `name=`
                    // anchor — a legitimate cross-link target — keeps its text.
                    suppressingKeyAnchor = true
                }
            case lower == "/a":
                if suppressingKeyAnchor {
                    // Drop everything the anchor emitted, not just the pending text: the key
                    // anchor wraps its number in `<b>`, which flushes, so the number is
                    // already a run.
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
                    applyPendingLink()
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
        // leaves.
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

    /// `sword://StrongsRealGreek/G3588` -> `.lexicon(module:key:)`. Also accepts
    /// the `passagestudy.jsp?action=showRef&…` form.
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
