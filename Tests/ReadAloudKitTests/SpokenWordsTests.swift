import ReadAlign
import Testing

@testable import ReadAloudKit

struct SpokenWordsCases: Codable {
    let tests: [SpokenWordsCase]
    let faithful: [FaithfulCase]

    static var all: Self {
        get throws { try Cases.loadRefusingUnreadKeys("spoken_words_tests.yaml") }
    }
}

struct ExpectedMatch: Codable, Sendable, Equatable {
    let expected: [Int]
    let heard: [Int]

    init(_ match: WordMatch) {
        expected = [match.expected.lowerBound, match.expected.upperBound]
        heard = [match.heard.lowerBound, match.heard.upperBound]
    }
}

struct SpokenWordsCase: NamedCase {
    let name: String
    let expected: [String]
    let heard: [String]
    let quirks: [String: [AllowanceEntry]]?
    let elisions: [String: String]?
    let matches: [ExpectedMatch]
    let faithful: Set<Int>
}

struct FaithfulCase: NamedCase {
    let name: String
    let heard: String
    let written: String
    let elisions: [String: String]?
    let faithful: Bool
}

struct SpokenWordsTests {
    @Test(arguments: try SpokenWordsCases.all.tests)
    func acceptsOnlyFaithfulWords(_ example: SpokenWordsCase) {
        let checked = SpokenWords.check(
            expected: example.expected,
            heard: example.heard,
            quirks: Cases.quirks(example.quirks),
            elisions: Cases.elisions(example.elisions)
        )

        #expect(checked.matches.map(ExpectedMatch.init) == example.matches)
        #expect(checked.faithful == example.faithful)
    }

    @Test(arguments: try SpokenWordsCases.all.faithful)
    func tellsAFaithfulSpelling(_ example: FaithfulCase) {
        let faithful = SpokenLineTracker.isFaithful(
            example.heard,
            to: example.written,
            elisions: Cases.elisions(example.elisions)
        )

        #expect(faithful == example.faithful)
    }

    @Test("the reader's word checks are that same pass")
    func progressAgrees() {
        let quirks = RecognizerQuirks(allowances: ["heir": ["air"], "O": ["oh"]])
        let tracker = SpokenLineTracker(
            line: "O heir of love",
            quirks: quirks,
            elisions: .none,
            tokenizer: Cases.sonnetsTokenizer
        )
        let progress = tracker.progress(heard: "oh air of dove")
        let checked = SpokenWords.check(
            expected: ["O", "heir", "of", "love"],
            heard: ["oh", "air", "of", "dove"],
            quirks: quirks,
            elisions: .none
        )
        let faithful = progress.checks.indices.filter { progress.checks[$0] == .correct }
        let byCheck = checked.matches.indices
            .filter { checked.faithful.contains($0) }
            .flatMap { checked.matches[$0].expected }
        #expect(faithful == byCheck.sorted())
    }
}
