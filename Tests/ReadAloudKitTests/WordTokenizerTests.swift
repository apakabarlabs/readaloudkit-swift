import Foundation
import Testing

@testable import ReadAloudKit

struct TokenizerCases: Codable {
    let words: [WordsCase]
    let segments: [SegmentsCase]
    let passage: [PassageCase]

    static let all = Cases.loadRefusingUnreadKeys("tokenizer_tests.yaml", as: Self.self)
}

struct WordsCase: NamedCase {
    let name: String
    let line: String
    let interiorMarks: String?
    let words: [String]

    private enum CodingKeys: String, CodingKey {
        case name, line, words
        case interiorMarks = "interior_marks"
    }
}

struct ExpectedSegment: Codable, Sendable {
    let index: Int?
    let opening: String?
    let word: String?
    let closing: String?
    let space: String?

    var segment: LineSegment {
        LineSegment(
            wordIndex: index,
            openingMarks: opening ?? "",
            word: word ?? "",
            closingMarks: closing ?? "",
            space: space ?? ""
        )
    }
}

struct SegmentsCase: NamedCase {
    let name: String
    let line: String
    let segments: [ExpectedSegment]
}

struct PassageCase: NamedCase {
    let name: String
    let lines: [String]
    let words: [String]
    let lineOfEach: [Int]
    let indexInLine: [Int]

    private enum CodingKeys: String, CodingKey {
        case name, lines, words
        case lineOfEach = "line_of_each"
        case indexInLine = "index_in_line"
    }
}

struct WordTokenizerTests {
    @Test(arguments: TokenizerCases.all.words)
    func findsTheWords(_ example: WordsCase) {
        let tokenizer = Cases.tokenizer(interiorMarks: example.interiorMarks)
        let words = tokenizer.wordRanges(in: example.line).map { String(example.line[$0]) }

        #expect(words == example.words)
    }

    @Test(arguments: TokenizerCases.all.segments)
    func cutsTheSegments(_ example: SegmentsCase) {
        let segments = WordTokenizer.latinScript.segments(in: example.line)

        #expect(segments == example.segments.map(\.segment))
        #expect(segments.map(\.text).joined() == example.line)
    }

    @Test(arguments: TokenizerCases.all.passage)
    func numbersThePassage(_ example: PassageCase) {
        let spoken = WordTokenizer.latinScript.words(in: Passage(lines: example.lines))

        #expect(spoken.map(\.text) == example.words)
        #expect(spoken.map(\.indexInPassage) == Array(example.words.indices))
        #expect(spoken.map(\.lineIndex) == example.lineOfEach)
        #expect(spoken.map(\.indexInLine) == example.indexInLine)
    }
}
