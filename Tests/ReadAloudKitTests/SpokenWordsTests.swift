import Testing

@testable import ReadAloudKit

struct SpokenWordsTests {
    private let quirks = RecognizerQuirks(allowances: ["heir": ["air"], "O": ["oh"]])

    @Test("a word said as written is faithful")
    func exact() {
        let checked = SpokenWords.check(expected: ["love"], heard: ["love"], quirks: .none)
        #expect(checked.faithful == [0])
    }

    @Test("a similar word is paired but not faithful")
    func similar() {
        let checked = SpokenWords.check(expected: ["love"], heard: ["dove"], quirks: .none)
        #expect(checked.matches.count == 1)
        #expect(checked.faithful.isEmpty)
    }

    @Test("an elision spelled out is faithful without a patch")
    func elision() {
        let checked = SpokenWords.check(expected: ["tatter’d"], heard: ["tattered"], quirks: .none)
        #expect(checked.faithful == [0])
    }

    @Test("a patched word is paired by the patch and then accepted by it")
    func patched() {
        let checked = SpokenWords.check(expected: ["heir"], heard: ["air"], quirks: quirks)
        #expect(checked.matches.count == 1)
        #expect(checked.faithful == [0])
    }

    @Test("without the table the same pair is not even put together")
    func patchedWithoutTable() {
        let checked = SpokenWords.check(expected: ["heir"], heard: ["air"], quirks: .none)
        #expect(checked.faithful.isEmpty)
    }

    @Test("a word nothing was heard for is neither paired nor faithful")
    func missing() {
        let checked = SpokenWords.check(expected: ["love", "is"], heard: ["love"], quirks: .none)
        #expect(checked.faithful == [0])
    }

    @Test("the reader's word checks are that same pass")
    func progressAgrees() {
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
