import Foundation
import Testing

@testable import ReadAloudKit

struct SpokenPieceTests {
    private let quatrain = [
        "From fairest creatures we desire increase,",
        "That thereby beauty's rose might never die,",
        "But as the riper should by time decease,",
        "His tender heir might bear his memory:"
    ]

    @Test("the states come back apart line by line")
    func statesAreCutBackIntoLines() {
        let tracker = SpokenLineTracker(
            lines: quatrain,
            quirks: .none,
            elisions: .none,
            tokenizer: Cases.sonnetsTokenizer
        )
        let progress = tracker.progress(heard: quatrain.joined(separator: " "))
        let states = progress.wordStates

        for (index, length) in tracker.lineLengths.enumerated() {
            #expect(tracker.wordStates(states, forLineAt: index).count == length)
        }
        #expect(tracker.wordStates(states, forLineAt: 4).isEmpty)
    }

    @Test("a check shows as the state a reader sees")
    func checksShowAsStates() {
        let progress = SpokenLineTracker.Progress(checks: [.correct, .close, .wrong])

        #expect(progress.wordStates == [.said, .close, .missed])
    }

    @Test("a tracker keeps the tokenizer it was made with")
    func keepsItsTokenizer() {
        let plain = WordTokenizer(interiorMarks: CharacterSet(charactersIn: "-"))
        let tracker = SpokenLineTracker(
            line: "beauty's rose",
            quirks: .none,
            elisions: .none,
            tokenizer: plain
        )

        #expect(tracker.tokenizer.interiorMarks == plain.interiorMarks)
    }

    @Test("a tracker keeps the elisions it was made with")
    func keepsItsElisions() {
        let listed = Elisions(fullForms: ["tatter’d": ["tattered"]])
        let tracker = SpokenLineTracker(
            line: "a tatter’d weed",
            quirks: .none,
            elisions: listed,
            tokenizer: Cases.sonnetsTokenizer
        )

        #expect(tracker.elisions == listed)
    }
}
