import Testing

@testable import ReadAloudKit

struct TrackerCases: Codable {
    let tests: [TrackerCase]

    static let all = Cases.loadRefusingUnreadKeys("tracker_tests.yaml", as: Self.self).tests
}

struct ExpectedAttempt: Codable, Sendable {
    let word: String
    let check: WordCheck
}

struct TrackerCase: NamedCase {
    let name: String
    let lines: [String]
    let quirks: [String: [AllowanceEntry]]?
    let interiorMarks: String?
    let lineLengths: [Int]
    let heard: String?
    let checks: [WordCheck]?
    let complete: Bool?
    let allWrong: Bool?
    let attempts: [ExpectedAttempt]?
    let untried: [String]?

    private enum CodingKeys: String, CodingKey {
        case name, lines, quirks, heard, checks, complete, attempts, untried
        case interiorMarks = "interior_marks"
        case allWrong = "all_wrong"
        case lineLengths = "line_lengths"
    }

    var tracker: SpokenLineTracker {
        SpokenLineTracker(
            lines: lines,
            quirks: Cases.quirks(quirks),
            tokenizer: Cases.tokenizer(interiorMarks: interiorMarks)
        )
    }
}

struct SpokenLineTrackerTests {
    @Test(arguments: TrackerCases.all)
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
}
