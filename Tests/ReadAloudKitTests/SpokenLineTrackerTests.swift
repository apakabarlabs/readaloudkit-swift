import Testing

@testable import ReadAloudKit

struct TrackerCases: Decodable {
    let tests: [TrackerCase]

    static let all = Cases.load("tracker_tests.yaml", as: Self.self).tests
}

struct ExpectedAttempt: Decodable, Sendable {
    let word: String
    let check: WordCheck
}

struct TrackerCase: NamedCase {
    let name: String
    let lines: [String]
    let quirks: [String: [RecognizerQuirks.Allowance]]?
    let interiorMarks: String?
    let heard: String?
    let checks: [WordCheck]?
    let checksAt: [String: WordCheck]?
    let rest: WordCheck?
    let statesAt: [String: String]?
    let complete: Bool?
    let allWrong: Bool?
    let attempts: [ExpectedAttempt]?
    let lineLengths: [Int]?
    let untried: [String]?

    private enum CodingKeys: String, CodingKey {
        case name, lines, quirks, heard, checks, rest, complete, attempts, untried
        case interiorMarks = "interior_marks"
        case checksAt = "checks_at"
        case statesAt = "states_at"
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
        if let lengths = example.lineLengths {
            #expect(tracker.lineLengths == lengths)
        }
        if let untried = example.untried {
            #expect(tracker.untriedWordStates == (try untried.map(WordReadingState.named)))
        }
        guard let heard = example.heard else { return }
        try check(tracker.progress(heard: heard), of: tracker, against: example)
    }

    private func check(
        _ progress: SpokenLineTracker.Progress,
        of tracker: SpokenLineTracker,
        against example: TrackerCase
    ) throws {
        if let checks = example.checks {
            #expect(progress.checks == checks)
        }
        let pinned = try (example.checksAt ?? [:]).reduce(into: [Int: WordCheck]()) {
            $0[try Cases.index($1.key, in: example.name)] = $1.value
        }
        for (index, check) in pinned {
            #expect(progress.checks[index] == check, "word \(index)")
        }
        if let rest = example.rest {
            for index in progress.checks.indices where pinned[index] == nil {
                #expect(progress.checks[index] == rest, "word \(index)")
            }
        }
        for (key, state) in example.statesAt ?? [:] {
            let index = try Cases.index(key, in: example.name)
            #expect(progress.wordStates[index] == (try WordReadingState.named(state)))
        }
        if let complete = example.complete {
            #expect(progress.isComplete == complete)
        }
        if let allWrong = example.allWrong {
            #expect(progress.isAllWrong == allWrong)
        }
        if let attempts = example.attempts {
            #expect(
                tracker.attempts(in: progress)
                    == attempts.map { WordAttempt(word: $0.word, check: $0.check) }
            )
        }
    }
}
