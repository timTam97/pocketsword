//
//  PSVoiceRefParser.swift
//  PocketSword
//

import Foundation

struct PSVoiceRefBook {
    let names: [String]
    let displayName: String
    let chapters: Int
    let versesInChapter: (Int) -> Int

    init(names: [String],
         displayName: String,
         chapters: Int,
         versesInChapter: @escaping (Int) -> Int) {
        self.names = names
        self.displayName = displayName
        self.chapters = chapters
        self.versesInChapter = versesInChapter
    }
}

struct PSParsedRef: Equatable {
    let displayBookName: String
    let chapter: Int
    let verse: Int
}

struct PSVoiceRefParser {
    private struct BookAlias {
        let tokens: [String]
        let bookIndex: Int
    }

    private enum NumberToken: Equatable {
        case unit(Int)
        case teen(Int)
        case tens(Int)
        case hundred
    }

    private let books: [PSVoiceRefBook]
    private let aliases: [BookAlias]

    init(books: [PSVoiceRefBook]) {
        self.books = books
        self.aliases = Self.makeAliases(for: books)
    }

    func parse(candidates: [String]) -> PSParsedRef? {
        for candidate in candidates {
            if let parsed = parse(candidate: candidate) {
                return parsed
            }
        }
        return nil
    }

    func parse(candidate: String) -> PSParsedRef? {
        let tokens = Self.tokenize(candidate)
        guard !tokens.isEmpty,
              let match = matchBook(in: tokens) else {
            return nil
        }

        let book = books[match.bookIndex]
        guard book.chapters > 0,
              let numbers = Self.referenceNumbers(in: Array(tokens.dropFirst(match.tokenCount))),
              numbers.count <= 2 else {
            return nil
        }

        let chapter: Int
        let verse: Int
        switch numbers.count {
        case 0:
            chapter = 1
            verse = 1
        case 1 where book.chapters == 1:
            chapter = 1
            verse = numbers[0]
        case 1:
            chapter = numbers[0]
            verse = 1
        default:
            chapter = numbers[0]
            verse = numbers[1]
        }

        guard (1...book.chapters).contains(chapter) else {
            return nil
        }
        let verseCount = book.versesInChapter(chapter)
        guard verseCount > 0, (1...verseCount).contains(verse) else {
            return nil
        }

        return PSParsedRef(displayBookName: book.displayName,
                           chapter: chapter,
                           verse: verse)
    }

    private func matchBook(in tokens: [String]) -> (bookIndex: Int, tokenCount: Int)? {
        let maximumLength = min(4, tokens.count)
        guard maximumLength > 0 else { return nil }

        for length in stride(from: maximumLength, through: 1, by: -1) {
            let candidate = Array(tokens.prefix(length))
            var bestMatch: (bookIndex: Int, score: Int)?

            for alias in aliases where alias.tokens.count == length {
                guard let score = Self.matchScore(candidate, alias.tokens) else {
                    continue
                }
                if bestMatch == nil || score < bestMatch!.score {
                    bestMatch = (alias.bookIndex, score)
                }
            }

            if let bestMatch = bestMatch {
                return (bestMatch.bookIndex, length)
            }
        }
        return nil
    }

    private static func makeAliases(for books: [PSVoiceRefBook]) -> [BookAlias] {
        var result: [BookAlias] = []
        var seen: Set<String> = []

        func add(_ name: String, to bookIndex: Int) {
            let tokens = tokenize(name)
            guard !tokens.isEmpty, tokens.count <= 4 else { return }
            let key = "\(bookIndex):\(tokens.joined(separator: " "))"
            if seen.insert(key).inserted {
                result.append(BookAlias(tokens: tokens, bookIndex: bookIndex))
            }
        }

        for (index, book) in books.enumerated() {
            let allNames = book.names + [book.displayName]
            for name in allNames {
                add(name, to: index)
            }

            let normalizedNames = Set(allNames.map(normalized))
            if !normalizedNames.isDisjoint(with: ["psalm", "psalms"]) {
                add("psalm", to: index)
                add("psalms", to: index)
            }
            if !normalizedNames.isDisjoint(with: ["revelation", "revelations"]) {
                add("revelation", to: index)
                add("revelations", to: index)
            }
            if !normalizedNames.isDisjoint(with: [
                "song of solomon", "song of songs", "canticles"
            ]) {
                add("song of solomon", to: index)
                add("song of songs", to: index)
                add("canticles", to: index)
            }

            for name in normalizedNames {
                let parts = name.split(separator: " ").map(String.init)
                guard parts.count >= 2,
                      let ordinal = Int(parts[0]),
                      (1...3).contains(ordinal),
                      numberedBookFamilies.contains(parts[1]) else {
                    continue
                }
                let suffix = parts.dropFirst().joined(separator: " ")
                add("\(ordinalWords[ordinal] ?? "") \(suffix)", to: index)
                add("\(cardinalWords[ordinal] ?? "") \(suffix)", to: index)
            }
        }

        return result
    }

    private static func referenceNumbers(in tokens: [String]) -> [Int]? {
        let fillers: Set<String> = ["chapter", "chapters", "verse", "verses", "the", "book", "of"]
        let rangeMarkers: Set<String> = ["to", "through", "dash"]
        var numbers: [Int] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            if rangeMarkers.contains(token) {
                return numbers.isEmpty ? nil : numbers
            }
            if fillers.contains(token) {
                index += 1
                continue
            }
            if token == "and" {
                return nil
            }
            if let digit = Int(token) {
                numbers.append(digit)
                index += 1
                continue
            }
            guard let parsed = parseCardinal(from: tokens, at: index) else {
                return nil
            }
            numbers.append(parsed.value)
            index += parsed.consumed
        }

        return numbers
    }

    private static func parseCardinal(from tokens: [String], at start: Int)
        -> (value: Int, consumed: Int)? {
        guard start < tokens.count,
              let first = numberWords[tokens[start]] else {
            return nil
        }

        switch first {
        case .unit(let value):
            guard start + 1 < tokens.count,
                  numberWords[tokens[start + 1]] == .hundred else {
                return (value, 1)
            }

            var total = value * 100
            var index = start + 2
            if index < tokens.count, tokens[index] == "and" {
                index += 1
            }
            if index < tokens.count,
               let remainder = parseUnderHundred(from: tokens, at: index) {
                total += remainder.value
                index += remainder.consumed
            }
            return (total, index - start)

        case .teen(let value):
            return (value, 1)

        case .tens(let value):
            if start + 1 < tokens.count,
               case .unit(let unit)? = numberWords[tokens[start + 1]] {
                return (value + unit, 2)
            }
            return (value, 1)

        case .hundred:
            return nil
        }
    }

    private static func parseUnderHundred(from tokens: [String], at start: Int)
        -> (value: Int, consumed: Int)? {
        guard start < tokens.count,
              let first = numberWords[tokens[start]] else {
            return nil
        }
        switch first {
        case .unit(let value), .teen(let value):
            return (value, 1)
        case .tens(let value):
            if start + 1 < tokens.count,
               case .unit(let unit)? = numberWords[tokens[start + 1]] {
                return (value + unit, 2)
            }
            return (value, 1)
        case .hundred:
            return nil
        }
    }

    private static func matchScore(_ candidate: [String], _ alias: [String]) -> Int? {
        guard candidate.count == alias.count else { return nil }
        if candidate == alias {
            return 0
        }

        let isPrefixMatch = zip(candidate, alias).allSatisfy { input, expected in
            input == expected ||
                (min(input.count, expected.count) >= 3 &&
                 (input.hasPrefix(expected) || expected.hasPrefix(input)))
        }
        if isPrefixMatch {
            return 1
        }

        let isFuzzyMatch = zip(candidate, alias).allSatisfy { input, expected in
            if input == expected {
                return true
            }
            guard min(input.count, expected.count) >= 5 else {
                return false
            }
            return editDistance(input, expected, limit: 2) <= 2
        }
        return isFuzzyMatch ? 2 : nil
    }

    private static func editDistance(_ lhs: String, _ rhs: String, limit: Int) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        if abs(left.count - right.count) > limit {
            return limit + 1
        }

        var previous = Array(0...right.count)
        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1] + Array(repeating: 0, count: right.count)
            var rowMinimum = current[0]
            for (rightIndex, rightCharacter) in right.enumerated() {
                let substitution = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                current[rightIndex + 1] = min(
                    previous[rightIndex + 1] + 1,
                    current[rightIndex] + 1,
                    substitution
                )
                rowMinimum = min(rowMinimum, current[rightIndex + 1])
            }
            if rowMinimum > limit {
                return limit + 1
            }
            previous = current
        }
        return previous[right.count]
    }

    private static func tokenize(_ value: String) -> [String] {
        var prepared = value
            .replacingOccurrences(of: "-", with: " dash ")
            .replacingOccurrences(of: "\u{2013}", with: " dash ")
            .replacingOccurrences(of: "\u{2014}", with: " dash ")
        prepared = normalized(prepared)

        let scalars = prepared.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }
        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let numberedBookFamilies: Set<String> = [
        "samuel", "kings", "chronicles", "corinthians", "thessalonians",
        "timothy", "peter", "john"
    ]

    private static let ordinalWords = [1: "first", 2: "second", 3: "third"]
    private static let cardinalWords = [1: "one", 2: "two", 3: "three"]

    private static let numberWords: [String: NumberToken] = [
        "one": .unit(1), "two": .unit(2), "three": .unit(3),
        "four": .unit(4), "five": .unit(5), "six": .unit(6),
        "seven": .unit(7), "eight": .unit(8), "nine": .unit(9),
        "ten": .teen(10), "eleven": .teen(11), "twelve": .teen(12),
        "thirteen": .teen(13), "fourteen": .teen(14), "fifteen": .teen(15),
        "sixteen": .teen(16), "seventeen": .teen(17), "eighteen": .teen(18),
        "nineteen": .teen(19), "twenty": .tens(20), "thirty": .tens(30),
        "forty": .tens(40), "fifty": .tens(50), "sixty": .tens(60),
        "seventy": .tens(70), "eighty": .tens(80), "ninety": .tens(90),
        "hundred": .hundred
    ]
}
