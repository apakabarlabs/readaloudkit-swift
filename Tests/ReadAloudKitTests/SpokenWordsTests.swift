import Testing

@testable import ReadAloudKit

struct SpokenWordsCases: Decodable {
    let tests: [SpokenWordsCase]
    let faithful: [FaithfulCase]

    static let all = Cases.load("spoken_words_tests.yaml", as: Self.self)
}

struct SpokenWordsCase: NamedCase {
    let name: String
    let expected: [String]
    let heard: [String]
    let quirks: [String: [RecognizerQuirks.Allowance]]?
    let matches: Int?
    let faithful: Set<Int>
}

struct FaithfulCase: NamedCase {
    let name: String
    let heard: String
    let written: String
    let faithful: Bool
}

struct SpokenWordsTests {
    @Test(arguments: SpokenWordsCases.all.tests)
    func acceptsOnlyFaithfulWords(_ example: SpokenWordsCase) {
        let checked = SpokenWords.check(
            expected: example.expected,
            heard: example.heard,
            quirks: Cases.quirks(example.quirks)
        )

        if let matches = example.matches {
            #expect(checked.matches.count == matches)
        }
        #expect(checked.faithful == example.faithful)
    }

    @Test(arguments: SpokenWordsCases.all.faithful)
    func tellsAFaithfulSpelling(_ example: FaithfulCase) {
        let faithful = SpokenLineTracker.isFaithful(example.heard, to: example.written)

        #expect(faithful == example.faithful)
    }

    @Test("the reader's word checks are that same pass")
    func progressAgrees() {
        let quirks = RecognizerQuirks(allowances: ["heir": ["air"], "O": ["oh"]])
        let tracker = SpokenLineTracker(line: "O heir of love", quirks: quirks)
        let progress = tracker.progress(heard: "oh air of dove")
        let checked = SpokenWords.check(
            expected: ["O", "heir", "of", "love"],
            heard: ["oh", "air", "of", "dove"],
            quirks: quirks
        )
        let faithful = progress.checks.indices.filter { progress.checks[$0] == .correct }
        let byCheck = checked.matches.indices
            .filter { checked.faithful.contains($0) }
            .flatMap { checked.matches[$0].expected }
        #expect(faithful == byCheck.sorted())
    }
}
