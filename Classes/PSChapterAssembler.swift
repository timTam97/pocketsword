//
//  PSChapterAssembler.swift
//  PocketSword
//
//  Replays the SWORD engine's chapter accumulator loop over the content store's
//  expanded records. A faithful transliteration, quirks and paragraphing hacks
//  included: the fixtures are byte-exact, so any "improvement" is a divergence.
//
//  THE COUNTER IS NOT A VERSE NUMBER. `i` advances at the bottom of every
//  iteration, including for slots the loop skips as empty or duplicate, and
//  including the final one that steps out of the chapter — so Gen 1's 31 verses
//  produce 32. It drives the `id="vv{i}"` anchors, the verse-menu links and the
//  bookmark-highlight lookup, so the store persists the loop's INPUT sequence
//  (empties preserved) and this replays it, rather than either side recomputing
//  the number.
//
//  Three branches are unreachable for the five shipped modules (zero occurrences
//  of `<blockquote class="lg">`, `indentedLineOfWidth-` or `<!P>` in the corpus)
//  and are kept anyway, because their absence would be a silent behaviour change
//  if a module ever emitted them: the `lg` blockquote anchor move,
//  `hackChapterToAccommodateBrokenLG`, and the post-loop blockquote close.
//

import Foundation

enum PSChapterAssembler {

    struct Result {
        let body: String
        /// The loop counter — see the file header. NOT a verse count.
        let entryCount: Int
    }

    /// How to format the verse rows. Bibles and commentaries differ in more than
    /// styling: a commentary's anchor is `href="#verse%ld"`, not a verse-menu link,
    /// so tapping a commentary verse does nothing. Deliberate.
    enum ModuleKind {
        case bible
        case commentary
    }

    /// The per-render inputs the loop reads that are not the records themselves.
    struct Config {
        var kind: ModuleKind = .bible
        /// `vplPreference_<module>` — verse-per-line.
        var versePerLine = false
        /// `headingsPreference_<module>`. Gates the PREVERSE heading injection the
        /// loop does itself, which is a different mechanism from the markup
        /// filter's interverse emission — hence `headings || canonical`.
        var headingsOn = true
        // No `bookmarkRef` here: highlighting is driven entirely by the
        // `highlightColour` closure, and the caller decides what ref that keys on —
        // PSContentReader passes the CALLER's ref through createRefString
        // ("Psalms 23", not "Ps 23"), because the abbreviation renders identical
        // bytes but matches no bookmark.
    }

    // MARK: - Assembly

    /// Replay the loop. `records` is the ordered entry list from the store
    /// (verse 0 upward, empties preserved), already expanded to HTML;
    /// `headings[verse]` is that slot's heading list.
    ///
    /// `emptyChapterMessage` is appended when nothing rendered, matching the
    /// engine's own fallback. The caller supplies it so this file stays free of
    /// localisation lookups.
    static func assemble(records: [String],
                         headings: [Int: [PSHeading]],
                         config: Config,
                         headingHTML: (PSHeading) -> String?,
                         highlightColour: (Int) -> String?,
                         emptyChapterMessage: @autoclosure () -> String) -> Result? {
        var verses = ""
        var lastEntry = ""
        var i = 0

        for (slot, raw) in records.enumerated() {
            var thisEntry = raw
            // *x / *n -> x / n, for xrefs and footnotes.
            thisEntry = thisEntry.replacingOccurrences(of: "*x", with: "x")
            thisEntry = thisEntry.replacingOccurrences(of: "*n", with: "n")
            // Strip a leading whitespace run. An entry that is ENTIRELY whitespace is
            // left alone — it then fails the empty test and IS emitted. Deliberate.
            if let firstNonWS = thisEntry.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted),
               firstNonWS.lowerBound != thisEntry.startIndex {
                thisEntry = String(thisEntry[firstNonWS.lowerBound...])
            }

            if thisEntry != lastEntry && !thisEntry.isEmpty {
                // Preverse headings: emitted when the option is on OR the heading is
                // canonical. Only the Preverse bucket — the Interverse ones already
                // reached the body through the markup filter (and are in the
                // record's own title tokens).
                for heading in headings[slot] ?? [] where heading.bucket == "Preverse" {
                    guard config.headingsOn || heading.canonical else { continue }
                    guard var html = headingHTML(heading) else { return nil }
                    html = html.replacingOccurrences(of: "*x", with: "x")
                    html = html.replacingOccurrences(of: "*n", with: "n")
                    guard !html.isEmpty else { continue }
                    verses += "<p><b>\(html)</b></p>"
                }

                switch config.kind {
                case .commentary:
                    if i == 0 {
                        verses += thisEntry
                    } else {
                        verses += "<p><a href=\"#verse\(i)\" id=\"vv\(i)\" class=\"verse\">\(i)</a><br />\(thisEntry)</p>\n"
                    }
                case .bible:
                    var entry = thisEntry
                    // Paragraphing hacks, verbatim: module creators differ.
                    entry = entry.replacingOccurrences(of: "<br /> <!P><br /><br />", with: "<br /> <br />")
                    entry = entry.replacingOccurrences(of: "<br /><!P><br /><br />", with: "<br /> <br />")
                    entry = entry.replacingOccurrences(of: "<br /> <!P><br /><!P><br />", with: "<br /> <br />")
                    entry = entry.replacingOccurrences(of: "</blockquote><br />", with: "</blockquote>")

                    if i == 0 {
                        if entry == "<br />" { entry = "" }
                    } else if config.versePerLine {
                        entry = "<a href=\"pocketsword:versemenu:\(i)\" id=\"vv\(i)\" class=\"verse\">\(i)</a>"
                            + "<span id=\"vvv\(i)\">\(entry)</span><br />\n"
                    } else {
                        var insertedVerse = false
                        // If this verse starts a blockquote, the verse number goes
                        // inside it. (Unreachable for the shipped modules.)
                        let lgOpen = "<blockquote class=\"lg\">"
                        if entry.hasPrefix(lgOpen) {
                            entry = lgOpen
                                + "<a href=\"pocketsword:versemenu:\(i)\" id=\"vv\(i)\" class=\"verse\">\(i)</a>"
                                + String(entry.dropFirst(lgOpen.count)) + "\n"
                            insertedVerse = true
                        }
                        if !insertedVerse {
                            entry = "<a href=\"pocketsword:versemenu:\(i)\" id=\"vv\(i)\" class=\"verse\">\(i)</a>\(entry)\n"
                        }
                    }

                    if let colour = highlightColour(i) {
                        entry = highlight(verse: entry, cssClass: colour)
                    }
                    verses += entry
                }
            }

            lastEntry = thisEntry
            i += 1
        }

        if verses.contains("<div class=\"indentedLineOfWidth-") {
            verses = hackChapterToAccommodateBrokenLG(verses)
        }
        if verses.contains("<blockquote class=\"lg\">") && !verses.contains("</blockquote>") {
            verses += "</blockquote>"
        }
        if verses.isEmpty {
            verses = emptyChapterMessage()
        }
        return Result(body: verses, entryCount: i)
    }

    // MARK: - Bookmark highlighting

    /// Wrap a verse in the highlight span, re-opening it around every block
    /// element. Not a simple wrap: `findNextBlockElement` treats ANY
    /// non-self-closing tag as a block, so each Strong's anchor produces another
    /// span pair — Ps 23's three highlighted verses yield 64 spans in total. That
    /// is what the engine does, so it is what this does.
    static func highlight(verse verseHTML: String, cssClass: String) -> String {
        let spanOpen = "<span class=\"highlightedVerse\" style=\"background-color:\(cssClass);color:black;\">"
        let spanClose = "</span>"
        // NSMutableString, because the algorithm is index-based insertion at UTF-16
        // offsets. Reimplementing it over String.Index would be a different
        // algorithm with different behaviour on non-BMP scalars.
        let currentVerse = NSMutableString(string: verseHTML)

        var currentBlockRange = findNextBlockElement(currentVerse, NSRange(location: 0, length: currentVerse.length))
        if currentBlockRange.location == NSNotFound {
            currentVerse.insert(spanOpen, at: 0)
        } else if currentBlockRange.location != 0 {
            currentVerse.insert(spanOpen, at: 0)
            currentBlockRange.location += (spanOpen as NSString).length
        } else {
            // Skip all consecutive blocks at the start of the verse.
            var testLoc = currentBlockRange.length
            var testRange = findNextBlockElement(currentVerse,
                                                 NSRange(location: testLoc, length: currentVerse.length - testLoc))
            while testRange.location == testLoc {
                testLoc += testRange.length
                testRange = findNextBlockElement(currentVerse,
                                                 NSRange(location: testLoc, length: currentVerse.length - testLoc))
            }
            currentVerse.insert(spanOpen, at: testLoc)
            let newStart = testLoc + (spanOpen as NSString).length
            currentBlockRange = findNextBlockElement(currentVerse,
                                                     NSRange(location: newStart, length: currentVerse.length - newStart))
        }

        while currentBlockRange.location != NSNotFound {
            currentVerse.insert(spanClose, at: currentBlockRange.location)
            currentBlockRange.location += (spanClose as NSString).length
            var newStart = currentBlockRange.location + currentBlockRange.length
            currentVerse.insert(spanOpen, at: newStart)
            newStart += (spanOpen as NSString).length
            currentBlockRange = findNextBlockElement(currentVerse,
                                                     NSRange(location: newStart, length: currentVerse.length - newStart))
        }

        currentVerse.insert(spanClose, at: currentVerse.length)
        return currentVerse as String
    }

    /// Returns the range of the next tag that is not self-closing, or NSNotFound.
    /// Loops past self-closing tags rather than recursing (a verse with many
    /// `<br />`s would otherwise recurse once per tag).
    private static func findNextBlockElement(_ searchString: NSString, _ range: NSRange) -> NSRange {
        var searchRange = range
        while true {
            guard searchRange.length > 0 else { return NSRange(location: NSNotFound, length: 0) }
            let start = searchString.range(of: "<", options: [], range: searchRange)
            if start.location == NSNotFound { return start }
            let tailRange = NSRange(location: start.location, length: searchString.length - start.location)
            let end = searchString.range(of: ">", options: [], range: tailRange)
            if end.location == NSNotFound {
                alog("\nERROR: could not find corresponding '>'")
                return start
            }
            if end.location > 0, searchString.character(at: end.location - 1) == UInt16(UnicodeScalar("/").value) {
                // Not a block element, just an empty tag — keep looking.
                searchRange = NSRange(location: end.location, length: searchString.length - end.location)
                continue
            }
            return NSRange(location: start.location, length: end.location + 1 - start.location)
        }
    }

    // MARK: - The broken-lg hack

    /// Moves a `<blockquote class="lg">` to the start of the verse when an
    /// `indentedLineOfWidth-` div opens outside one (a WEB-module shape).
    /// Unreachable for the shipped modules; kept so behaviour cannot silently
    /// change if that stops being true.
    private static func hackChapterToAccommodateBrokenLG(_ chapterString: String) -> String {
        let returnChapter = NSMutableString(string: chapterString)
        var inLG = false
        var currentTagRange = findNextBlockElement(returnChapter, NSRange(location: 0, length: returnChapter.length))

        // A 6-deep sliding window of previous tags and their offsets.
        var tags: [String?] = Array(repeating: nil, count: 6)
        var offsets = [Int](repeating: 0, count: 6)
        let lgOpen = "<blockquote class=\"lg\">"

        while currentTagRange.location != NSNotFound {
            var newStart = currentTagRange.location + currentTagRange.length
            let currentTag = returnChapter.substring(with: currentTagRange)

            if currentTag == lgOpen {
                inLG = true
            } else if currentTag == "</blockquote>" {
                inLG = false
            } else if !inLG && currentTag.hasPrefix("<div class=\"indentedLineOfWidth-") {
                if tags[0] == "</span>", tags[2] == "</a>",
                   let six = tags[5], six.hasPrefix("<a href=\"pocketsword:versemenu:") {
                    // Highlighted verse, and this is its start.
                    returnChapter.insert(lgOpen, at: offsets[5])
                } else if tags[0] == "</a>",
                          let two = tags[1], two.hasPrefix("<a href=\"pocketsword:versemenu:") {
                    returnChapter.insert(lgOpen, at: offsets[1])
                } else {
                    returnChapter.insert(lgOpen, at: currentTagRange.location)
                }
                inLG = true
                newStart += (lgOpen as NSString).length
            }

            for k in stride(from: 5, to: 0, by: -1) {
                tags[k] = tags[k - 1]
                offsets[k] = offsets[k - 1]
            }
            tags[0] = currentTag
            offsets[0] = currentTagRange.location

            currentTagRange = findNextBlockElement(returnChapter,
                                                   NSRange(location: newStart, length: returnChapter.length - newStart))
        }
        return returnChapter as String
    }
}
