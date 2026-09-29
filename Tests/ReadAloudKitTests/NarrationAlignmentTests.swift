import Foundation
import Testing

@testable import ReadAloudKit

struct AlignmentCases: Decodable {
    let tests: [AlignmentCase]

    static let all = Cases.load("alignment_tests.yaml", as: Self.self).tests
}

struct ExpectedTiming: Decodable, Sendable {
    let index: Int
    let text: String
    let line: Int
    let start: TimeInterval
    let end: TimeInterval
}

struct CountMismatch: Decodable, Sendable {
    let expected: Int
    let found: Int
}

struct WordMismatch: Decodable, Sendable {
    let index: Int
    let expected: String
    let found: String
}

struct AlignmentCase: NamedCase {
    let name: String
    let lines: [String]
    let words: [NarrationAlignment.Word]
    let count: Int?
    let timingsAt: [ExpectedTiming]?
    let wordCountMismatch: CountMismatch?
    let wordMismatch: WordMismatch?

    private enum CodingKeys: String, CodingKey {
        case name, lines, words, count
        case timingsAt = "timings_at"
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
                found: mismatch.found
            )
        }
        return nil
    }
}

struct NarrationAlignmentTests {
    @Test(arguments: AlignmentCases.all)
    func marriesTimesToWords(_ example: AlignmentCase) throws {
        let alignment = NarrationAlignment(piece: "1", duration: 10, words: example.words)
        let passage = Passage(lines: example.lines)
        if let refusal = example.refusal {
            #expect(throws: refusal) { try alignment.timings(for: passage) }
            return
        }
        let timings = try alignment.timings(for: passage)
        if let count = example.count {
            #expect(timings.count == count)
        }
        for expected in example.timingsAt ?? [] {
            let timing = timings[expected.index]
            #expect(timing.word.text == expected.text)
            #expect(timing.word.lineIndex == expected.line)
            #expect(timing.start == expected.start)
            #expect(timing.end == expected.end)
        }
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

        #expect(try NarrationAlignment.decode(data) == original)
    }

    @Test("the alignment a server publishes is read as it is served")
    func readsTheServedShape() throws {
        let served = Data(
            """
            {"piece": "18", "duration": 4.5, "recording": "narration-018.mp3",
             "words": [{"line": 0, "text": "Shall", "start": 0.5, "end": 0.8}]}
            """.utf8
        )
        let alignment = try NarrationAlignment.decode(served)

        #expect(alignment.piece == "18")
        #expect(alignment.recording == "narration-018.mp3")
        #expect(alignment.words == [.init(line: 0, text: "Shall", start: 0.5, end: 0.8)])
    }
}
