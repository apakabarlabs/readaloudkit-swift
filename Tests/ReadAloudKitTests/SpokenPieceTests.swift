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

    @Test("a piece is right only when every word of every line was said")
    func thePieceIsCheckedWhole() {
        let tracker = SpokenLineTracker(lines: quatrain)
        let said = quatrain.joined(separator: " ")

        #expect(tracker.progress(heard: said).isComplete)
        #expect(!tracker.progress(heard: quatrain[0]).isComplete)
    }

    @Test("a slip anywhere in the piece fails the piece")
    func oneSlipFailsTheWhole() {
        let tracker = SpokenLineTracker(lines: quatrain)
        let said = quatrain.joined(separator: " ").replacingOccurrences(of: "riper", with: "ripest")

        let progress = tracker.progress(heard: said)
        #expect(!progress.isComplete)
        #expect(progress.checks.filter { $0 != .correct }.count == 1)
        #expect(progress.checks.contains(.close))
        #expect(tracker.attempts(in: progress).filter { $0.check != .correct } == [
            WordAttempt(word: "riper", check: .close)
        ])
    }

    @Test("word attempts use the passage spelling and include correct words")
    func attemptsKeepTheExpectedWords() {
        let tracker = SpokenLineTracker(line: "Love is not love")
        let progress = tracker.progress(heard: "glove is love")

        #expect(
            tracker.attempts(in: progress) == [
                WordAttempt(word: "Love", check: .close),
                WordAttempt(word: "is", check: .correct),
                WordAttempt(word: "not", check: .wrong),
                WordAttempt(word: "love", check: .correct)
            ]
        )
    }

    @Test("the states come back apart line by line")
    func statesAreCutBackIntoLines() {
        let tracker = SpokenLineTracker(lines: quatrain)
        let progress = tracker.progress(heard: quatrain.joined(separator: " "))
        let states = progress.wordStates

        #expect(tracker.lineLengths == [6, 7, 8, 7])
        for (index, length) in tracker.lineLengths.enumerated() {
            #expect(tracker.wordStates(states, forLineAt: index).count == length)
        }
        #expect(tracker.wordStates(states, forLineAt: 4).isEmpty)
    }

    @Test("a line on its own is a piece of one line")
    func aLineIsStillAPiece() {
        let tracker = SpokenLineTracker(line: quatrain[0])
        #expect(tracker.lineLengths == [6])
        #expect(tracker.progress(heard: quatrain[0]).isComplete)
    }
}
