//
//  PSVoiceRefParserTests.swift
//  PocketSwordTests
//

import XCTest
@testable import PocketSword

final class PSVoiceRefParserTests: XCTestCase {
    private var parser: PSVoiceRefParser!

    override func setUp() {
        super.setUp()

        let fixtures: [(String, [String], Int, [Int: Int])] = [
            ("Genesis", ["Genesis", "Gen"], 50, [1: 31]),
            ("Psalms", ["Psalms", "Ps"], 150, [23: 6, 119: 176]),
            ("Song of Solomon", ["Song of Solomon", "Song", "SongSol"], 8, [2: 17]),
            ("John", ["John", "Jn"], 21, [1: 51, 3: 36]),
            ("1 John", ["1 John", "1John"], 5, [2: 29]),
            ("2 Timothy", ["2 Timothy", "2Tim"], 4, [3: 17]),
            ("Hebrews", ["Hebrews", "Heb"], 13, [2: 18]),
            ("Jude", ["Jude"], 1, [1: 25]),
            ("Nahum", ["Nahum"], 3, [1: 15]),
            ("Revelation", ["Revelation", "Rev"], 22, [3: 22])
        ]

        parser = PSVoiceRefParser(books: fixtures.map { fixture in
            let defaultVerseCount = 200
            return PSVoiceRefBook(
                names: fixture.1,
                displayName: fixture.0,
                chapters: fixture.2,
                versesInChapter: { fixture.3[$0] ?? defaultVerseCount }
            )
        })
    }

    func testDigitsAndSpokenLabels() {
        assertParse("john 1 1", equals: "John", chapter: 1, verse: 1)
        assertParse("hebrews chapter 2 verse 4", equals: "Hebrews", chapter: 2, verse: 4)
    }

    func testNumberedBooksAndNumberWords() {
        assertParse("1 john 2 3", equals: "1 John", chapter: 2, verse: 3)
        assertParse("first john 2 3", equals: "1 John", chapter: 2, verse: 3)
        assertParse("one john two three", equals: "1 John", chapter: 2, verse: 3)
        assertParse("second timothy chapter three verse sixteen",
                    equals: "2 Timothy", chapter: 3, verse: 16)
    }

    func testCardinalNumbersThroughLargestPsalm() {
        assertParse("psalm twenty three", equals: "Psalms", chapter: 23, verse: 1)
        assertParse("psalms 119 176", equals: "Psalms", chapter: 119, verse: 176)
        assertParse("psalm one hundred nineteen verse one hundred seventy six",
                    equals: "Psalms", chapter: 119, verse: 176)
        assertParse("psalm one hundred and nineteen verse one hundred and seventy six",
                    equals: "Psalms", chapter: 119, verse: 176)
    }

    func testSingleChapterBookTreatsOneNumberAsVerse() {
        assertParse("jude 5", equals: "Jude", chapter: 1, verse: 5)
    }

    func testAliasesAndMultiwordBooks() {
        assertParse("revelations 3 20", equals: "Revelation", chapter: 3, verse: 20)
        assertParse("song of solomon 2 1", equals: "Song of Solomon", chapter: 2, verse: 1)
        assertParse("song of songs 2 1", equals: "Song of Solomon", chapter: 2, verse: 1)
        assertParse("canticles 2 1", equals: "Song of Solomon", chapter: 2, verse: 1)
    }

    func testRangesKeepFirstVerse() {
        assertParse("john 3 16 to 18", equals: "John", chapter: 3, verse: 16)
        assertParse("john 3 16 through 18", equals: "John", chapter: 3, verse: 16)
        assertParse("john 3 16-18", equals: "John", chapter: 3, verse: 16)
    }

    func testMissingChapterOrVerseDefaultsToOne() {
        assertParse("genesis", equals: "Genesis", chapter: 1, verse: 1)
        assertParse("john 3", equals: "John", chapter: 3, verse: 1)
    }

    func testFuzzyBookName() {
        assertParse("hebrews 2 4", equals: "Hebrews", chapter: 2, verse: 4)
        assertParse("hebreus 2 4", equals: "Hebrews", chapter: 2, verse: 4)
    }

    func testRejectsUnknownAndOutOfRangeReferences() {
        XCTAssertNil(parser.parse(candidate: "banana 4 5"))
        XCTAssertNil(parser.parse(candidate: "john 99 1"))
        XCTAssertNil(parser.parse(candidate: "john 3 99"))
    }

    func testUsesFirstValidAlternative() {
        XCTAssertEqual(
            parser.parse(candidates: ["gnome 1 1", "nahum 1 1"]),
            PSParsedRef(displayBookName: "Nahum", chapter: 1, verse: 1)
        )
    }

    private func assertParse(_ candidate: String,
                             equals book: String,
                             chapter: Int,
                             verse: Int,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        XCTAssertEqual(
            parser.parse(candidate: candidate),
            PSParsedRef(displayBookName: book, chapter: chapter, verse: verse),
            file: file,
            line: line
        )
    }
}
