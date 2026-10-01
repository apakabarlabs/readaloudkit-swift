import Testing

@testable import ReadAloudKit

struct TrackerCases: Codable {
    let tests: [TrackerCase]
    let corrections: [CorrectionCase]

    private static var file: Self {
        get throws { try Cases.loadRefusingUnreadKeys("tracker_tests.yaml", as: Self.self) }
    }

    static var all: [TrackerCase] {
        get throws { try file.tests }
    }

    static var allCorrections: [CorrectionCase] {
        get throws { try file.corrections }
    }
}

struct CorrectionCase: NamedCase {
    let name: String
    let lines: [String]
    let quirks: [String: [AllowanceEntry]]?
    let interiorMarks: String
    let elisions: [String: [String]]?
    let heard: String
    let corrected: String

    private enum CodingKeys: String, CodingKey {
        case name, lines, quirks, elisions, heard, corrected
        case interiorMarks = "interior_marks"
    }
}

struct ExpectedAttempt: Codable, Sendable {
    let word: String
    let check: WordCheck
}

struct TrackerCase: NamedCase {
    let name: String
    let lines: [String]
    let quirks: [String: [AllowanceEntry]]?
    let interiorMarks: String
    let elisions: [String: [String]]?
    let lineLengths: [Int]
    let heard: String?
    let checks: [WordCheck]?
    let complete: Bool?
    let allWrong: Bool?
    let attempts: [ExpectedAttempt]?
    let untried: [String]?

    private enum CodingKeys: String, CodingKey {
        case name, lines, quirks, elisions, heard, checks, complete, attempts, untried
        case interiorMarks = "interior_marks"
        case allWrong = "all_wrong"
        case lineLengths = "line_lengths"
    }

    var tracker: SpokenLineTracker {
        SpokenLineTracker(
            lines: lines,
            quirks: Cases.quirks(quirks),
            elisions: Cases.elisions(elisions),
            tokenizer: Cases.tokenizer(interiorMarks: interiorMarks)
        )
    }
}

struct SpokenLineTrackerTests {
    @Test(arguments: try TrackerCases.all)
    func checksTheReading(_ example: TrackerCase) throws {
        let tracker = example.tracker
        #expect(tracker.lineLengths == example.lineLengths)
        if let untried = example.untried {
            #expect(tracker.untriedWordStates == (try untried.map(WordReadingState.named)))
        }
        guard let heard = example.heard else { return }
        let progress = tracker.progress(heard: heard)

        let checks = try #require(example.checks, "a heard case pins its checks")
        let complete = try #require(example.complete, "and whether it is complete")
        let allWrong = try #require(example.allWrong, "and whether it is all wrong")
        #expect(progress.checks == checks)
        #expect(progress.isComplete == complete)
        #expect(progress.isAllWrong == allWrong)
        if let attempts = example.attempts {
            #expect(
                tracker.attempts(in: progress)
                    == attempts.map { WordAttempt(word: $0.word, check: $0.check) }
            )
        }
    }

    @Test(arguments: try TrackerCases.allCorrections)
    func answersWithTheTableApplied(_ example: CorrectionCase) {
        let tracker = SpokenLineTracker(
            lines: example.lines,
            quirks: Cases.quirks(example.quirks),
            elisions: Cases.elisions(example.elisions),
            tokenizer: Cases.tokenizer(interiorMarks: example.interiorMarks)
        )

        #expect(tracker.corrected(example.heard) == example.corrected)
    }
}
