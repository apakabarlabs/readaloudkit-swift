import Foundation
import Testing

@testable import ReadAloudKit

struct AlignmentCases: Codable {
    let decode: [DecodeCase]
    let timings: [TimingsCase]

    static var all: Self {
        get throws { try Cases.loadRefusingUnreadKeys("alignment_tests.yaml") }
    }
}

struct ExpectedTimingError: Codable, Sendable {
    let kind: String
    let word: Int
    let line: Int

    var error: NarrationAlignment.TimingError {
        get throws {
            switch kind {
            case "negative_start": return .negativeStart(word: word, line: line)
            case "end_before_start": return .endBeforeStart(word: word, line: line)
            case "start_before_previous": return .startBeforePrevious(word: word, line: line)
            default: throw ExpectationFailed(description: "\(kind) is not a timing error")
            }
        }
    }
}

struct ExpectationFailed: Error, CustomStringConvertible {
    let description: String
}

struct ExpectedPublished: Codable, Sendable {
    let version: String
    let alignment: NarrationAlignment

    var published: PublishedAlignment {
        PublishedAlignment(version: version, alignment: alignment)
    }
}

struct DecodeCase: NamedCase {
    let name: String
    let served: String?
    let json: String?
    let encoding: String?
    let published: ExpectedPublished?
    let malformed: Bool?
    let notUTF8: Bool?
    let timingError: ExpectedTimingError?

    private enum CodingKeys: String, CodingKey {
        case name, served, json, encoding, published, malformed
        case notUTF8 = "not_utf8"
        case timingError = "timing_error"
    }

    var data: Data {
        get throws {
            if let served { return try Cases.served(served) }
            let json = try #require(json, "\(name): a case reads served or json")
            return try Cases.bytes(of: json, in: encoding)
        }
    }
}

struct ExpectedTiming: Codable, Sendable, Equatable {
    let text: String
    let line: Int
    let start: TimeInterval
    let end: TimeInterval
}

struct CountMismatch: Codable, Sendable {
    let expected: Int
    let found: Int
}

struct WordMismatch: Codable, Sendable {
    let index: Int
    let expected: String
    let found: String
    let expectedLine: Int
    let foundLine: Int

    private enum CodingKeys: String, CodingKey {
        case index, expected, found
        case expectedLine = "expected_line"
        case foundLine = "found_line"
    }
}

struct TimingsCase: NamedCase {
    let name: String
    let lines: [String]
    let interiorMarks: String
    let words: [NarrationAlignment.Word]
    let timings: [ExpectedTiming]?
    let wordCountMismatch: CountMismatch?
    let wordMismatch: WordMismatch?

    private enum CodingKeys: String, CodingKey {
        case name, lines, words, timings
        case interiorMarks = "interior_marks"
        case wordCountMismatch = "word_count_mismatch"
        case wordMismatch = "word_mismatch"
    }

    var refusal: NarrationAlignment.AlignmentError? {
        if let mismatch = wordCountMismatch {
            return .wordCountMismatch(expected: mismatch.expected, found: mismatch.found)
        }
        if let mismatch = wordMismatch {
            return .wordMismatch(
                index: mismatch.index,
                expected: mismatch.expected,
                found: mismatch.found,
                expectedLine: mismatch.expectedLine,
                foundLine: mismatch.foundLine
            )
        }
        return nil
    }
}

struct NarrationAlignmentTests {
    @Test(arguments: try AlignmentCases.all.decode)
    func readsWhatAServerPublishes(_ example: DecodeCase) throws {
        let data = try example.data
        if let expected = example.timingError {
            let error = try expected.error
            #expect(throws: error) { try PublishedAlignment.decode(data) }
            return
        }
        if example.malformed == true {
            #expect(throws: DecodingError.self) { try PublishedAlignment.decode(data) }
            return
        }
        if example.notUTF8 == true {
            #expect(throws: NotUTF8()) { try PublishedAlignment.decode(data) }
            return
        }
        let expected = try #require(example.published, "a readable case pins the document")
        #expect(try PublishedAlignment.decode(data) == expected.published)
    }

    @Test(arguments: try AlignmentCases.all.timings)
    func marriesTimesToWords(_ example: TimingsCase) throws {
        let alignment = NarrationAlignment(piece: "1", duration: 10, words: example.words)
        let passage = Passage(lines: example.lines)
        let tokenizer = Cases.tokenizer(interiorMarks: example.interiorMarks)
        if let refusal = example.refusal {
            #expect(throws: refusal) {
                try alignment.timings(for: passage, tokenizer: tokenizer)
            }
            return
        }
        let timings = try alignment.timings(for: passage, tokenizer: tokenizer)
        let expected = try #require(example.timings, "a fitting case pins its timings")
        let actual = timings.map { timing in
            ExpectedTiming(
                text: timing.word.text,
                line: timing.word.lineIndex,
                start: timing.start,
                end: timing.end
            )
        }
        #expect(actual == expected)
    }

    @Test("alignment survives a round trip through json")
    func roundTrips() throws {
        let original = NarrationAlignment(
            piece: "1",
            duration: 10,
            words: [.init(line: 0, text: "From", start: 0, end: 0.3)],
            recording: "narration-001.mp3"
        )
        let data = try JSONEncoder().encode(original)

        #expect(try JSONDecoder().decode(NarrationAlignment.self, from: data) == original)
    }
}
