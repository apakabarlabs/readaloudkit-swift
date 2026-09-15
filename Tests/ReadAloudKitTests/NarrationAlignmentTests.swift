import Foundation
import Testing
@testable import ReadAloudKit

struct NarrationAlignmentTests {
    private let passage = Passage(lines: ["From fairest creatures", "we desire increase,"])

    private func alignment(words: [NarrationAlignment.Word]) -> NarrationAlignment {
        NarrationAlignment(sonnet: 1, duration: 10, words: words)
    }

    private var measured: [NarrationAlignment.Word] {
        [
            .init(line: 0, text: "From", start: 0, end: 0.3),
            .init(line: 0, text: "fairest", start: 0.3, end: 0.9),
            .init(line: 0, text: "creatures", start: 0.9, end: 1.5),
            .init(line: 1, text: "we", start: 1.8, end: 2.0),
            .init(line: 1, text: "desire", start: 2.0, end: 2.5),
            .init(line: 1, text: "increase", start: 2.5, end: 3.2)
        ]
    }

    @Test("measured times land on the words of the passage")
    func marriesTimesToWords() throws {
        let timings = try alignment(words: measured).timings(for: passage)

        #expect(timings.count == 6)
        #expect(timings[0].word.text == "From")
        #expect(timings[0].start == 0)
        #expect(timings[3].word.lineIndex == 1)
        #expect(timings[3].start == 1.8)
    }

    @Test("a text edited after the markup was made is refused, not slid by one word")
    func refusesDriftedText() {
        let edited = Passage(lines: ["From fairest creatures", "we desire increase, and more"])

        #expect(throws: NarrationAlignment.AlignmentError.wordCountMismatch(expected: 8, found: 6)) {
            try alignment(words: measured).timings(for: edited)
        }
    }

    @Test("a word swapped in the text is caught by name")
    func refusesChangedWord() {
        let edited = Passage(lines: ["From fairest creatures", "we desire increases,"])

        #expect(throws: NarrationAlignment.AlignmentError.wordMismatch(index: 5, expected: "increases", found: "increase")) {
            try alignment(words: measured).timings(for: edited)
        }
    }

    @Test("alignment survives a round trip through json")
    func roundTrips() throws {
        let original = alignment(words: measured)
        let data = try JSONEncoder().encode(original)

        #expect(try NarrationAlignment.decode(data) == original)
    }
}
