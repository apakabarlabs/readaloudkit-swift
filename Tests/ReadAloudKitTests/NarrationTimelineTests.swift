import Foundation
import ReadAlign
import Testing

@testable import ReadAloudKit

struct NarrationTimelineTests {
    private let passage = Passage(
        lines: [
            "From fairest creatures we desire increase,",
            "That thereby beauty’s rose might never die,",
            "But as the riper should by time decease,"
        ]
    )
    private let duration: TimeInterval = 12

    private var timings: [WordTiming] {
        NarrationTimeline.estimate(for: passage, duration: duration)
    }

    private enum TwoLines {
        static let passage = Passage(lines: ["one two", "three four"])
        static let rate = 1_000.0

        static var samples: [Float] {
            var result = [Float](repeating: 0, count: 1_000)
            for index in 0..<400 { result[index] = 0.5 }
            for index in 500..<700 { result[index] = 0.5 }
            return result
        }

        static func timings(_ marks: [(TimeInterval, TimeInterval)]) -> [WordTiming] {
            let words = WordTokenizer.latinScript.words(in: passage)
            return zip(words, marks).map { WordTiming(word: $0, start: $1.0, end: $1.1) }
        }

        static func settled(_ marks: [(TimeInterval, TimeInterval)]) -> [WordTiming] {
            NarrationTimeline.settledBetweenLines(
                timings(marks),
                samples: samples,
                sampleRate: rate
            )
        }
    }

    @Test("a line ending marked inside a sound is carried to where the sound stops")
    func carriesALineEndingOutOfTheSound() {
        let settled = TwoLines.settled([(0, 0.15), (0.15, 0.30), (0.30, 0.60), (0.60, 0.70)])

        #expect(abs(settled[1].end - 0.40) < 0.011)
        #expect(settled[2].start == settled[1].end)
    }

    @Test("a line ending marked in the quiet is left where it is")
    func leavesASettledEndingAlone() {
        let settled = TwoLines.settled([(0, 0.15), (0.15, 0.45), (0.45, 0.60), (0.60, 0.70)])

        #expect(settled[1].end == 0.45)
        #expect(settled[2].start == 0.45)
    }

    @Test("a mark inside a line is left alone however loud the recording is there")
    func leavesTheInsideOfALineAlone() {
        let settled = TwoLines.settled([(0, 0.35), (0.35, 0.60), (0.60, 0.65), (0.65, 0.70)])

        #expect(settled[0].end == 0.35)
        #expect(settled[1].start == 0.35)
    }

    @Test("a line ending with no quiet to be found is left where it was measured")
    func leavesARunOnAlone() {
        var samples = [Float](repeating: 0, count: 1_000)
        for index in 0..<900 { samples[index] = 0.5 }
        let settled = NarrationTimeline.settledBetweenLines(
            TwoLines.timings([(0, 0.15), (0.15, 0.30), (0.30, 0.60), (0.60, 0.70)]),
            samples: samples,
            sampleRate: TwoLines.rate
        )

        #expect(settled[1].end == 0.30)
        #expect(settled[2].start == 0.30)
    }

    @Test("a line ending with no room at all is left exactly where it was")
    func leavesAJoinWithNoRoomExactlyWhereItWas() {
        let settled = TwoLines.settled([(0, 0.15), (0.15, 0.306), (0.306, 0.308), (0.308, 0.70)])

        #expect(settled[1].end == 0.306)
        #expect(settled[2].start == 0.306)
        for (earlier, later) in zip(settled, settled.dropFirst()) {
            #expect(later.start >= earlier.end)
            #expect(later.end > later.start)
        }
    }

    @Test("carrying a line ending never leaves the next word without room")
    func neverEatsTheNextWord() {
        let settled = TwoLines.settled([(0, 0.15), (0.15, 0.30), (0.30, 0.33), (0.33, 0.70)])

        #expect(settled[1].end == 0.30)
        #expect(settled[2].start == 0.30)
        #expect(settled[2].end > settled[2].start)
    }

    @Test("the settled reading still runs forward and never overlaps itself")
    func staysATimeline() {
        let settled = TwoLines.settled([(0, 0.15), (0.15, 0.30), (0.30, 0.60), (0.60, 0.70)])

        for (earlier, later) in zip(settled, settled.dropFirst()) {
            #expect(later.start >= earlier.end)
            #expect(later.end > later.start)
        }
    }

    @Test("a word is held open after it, but never into the word that follows")
    func endsAreHeldShortOfTheNextWord() {
        let words = WordTokenizer.latinScript.words(in: passage)
        let clipped = [
            WordTiming(word: words[0], start: 0, end: 0.5),
            WordTiming(word: words[1], start: 2, end: 2.5),
            WordTiming(word: words[2], start: 2.6, end: 2.8)
        ]
        let held = NarrationTimeline.heldToTheNextWord(clipped, duration: 10, limit: 0.4)

        #expect(held[0].end == 0.9)
        #expect(held[1].end == 2.6)
        #expect(abs(held[2].end - 3.2) < 0.0001)
        for (earlier, later) in zip(held, held.dropFirst()) {
            #expect(earlier.end <= later.start)
        }
    }

    @Test("holding a word open never shortens it")
    func holdingNeverShortens() {
        let words = WordTokenizer.latinScript.words(in: passage)
        let overlapping = [
            WordTiming(word: words[0], start: 0, end: 1.5),
            WordTiming(word: words[1], start: 1, end: 1.4)
        ]
        let held = NarrationTimeline.heldToTheNextWord(overlapping, duration: 10)
        #expect(held[0].end == 1.5)
    }

    @Test("every word gets a timing inside the recording")
    func coversTheRecording() throws {
        let estimated = timings
        #expect(estimated.count == WordTokenizer.latinScript.words(in: passage).count)

        let first = try #require(estimated.first)
        let last = try #require(estimated.last)
        #expect(first.start >= NarrationTimeline.leadIn - 0.001)
        #expect(last.end <= duration + 0.001)
    }

    @Test("timings advance and never overlap")
    func advancesMonotonically() {
        for (previous, next) in zip(timings, timings.dropFirst()) {
            #expect(next.start >= previous.end - 0.001)
            #expect(next.end > next.start)
        }
    }

    @Test("the narrator breathes at the line end")
    func pausesBetweenLines() {
        let estimated = timings
        let firstLineCount = WordTokenizer.latinScript.wordRanges(in: passage.lines[0]).count
        let acrossBreak = estimated[firstLineCount].start - estimated[firstLineCount - 1].end
        let insideLine = estimated[1].start - estimated[0].end

        #expect(acrossBreak > insideLine)
    }

    @Test("longer words get more of the clock")
    func weightsBySpeech() throws {
        let estimated = timings
        let short = try #require(estimated.first { $0.word.text == "we" })
        let long = try #require(estimated.first { $0.word.text == "creatures" })

        #expect(long.end - long.start > short.end - short.start)
    }

    @Test("a weighting that treats every word alike splits the time evenly")
    func acceptsAnotherWeighting() throws {
        struct FlatWeighting: SpeechWeighting {
            func weight(of _: String) -> Double { 1 }
        }
        let estimated = NarrationTimeline.estimate(
            for: passage,
            duration: duration,
            weighting: FlatWeighting()
        )
        let first = try #require(estimated.first)
        let last = try #require(estimated.last)

        #expect(abs((first.end - first.start) - (last.end - last.start)) < 0.001)
    }

    @Test("lookup agrees with the spans it searches")
    func findsTheSpokenWord() {
        let estimated = timings
        #expect(NarrationTimeline.index(at: 0, in: estimated) == nil)
        #expect(NarrationTimeline.index(at: duration + 1, in: estimated) == nil)

        for (index, timing) in estimated.enumerated() {
            let middle = (timing.start + timing.end) / 2
            #expect(NarrationTimeline.index(at: middle, in: estimated) == index)
        }
    }

    @Test("playback never marks a word beyond the requested lines")
    func keepsPlaybackMarkInsideItsPiece() throws {
        let estimated = timings
        let firstWordOfNextLine = try #require(estimated.first { $0.word.lineIndex == 1 })
        let time = (firstWordOfNextLine.start + firstWordOfNextLine.end) / 2

        #expect(NarrationTimeline.word(at: time, ofLines: 0...0, in: estimated) == nil)
        #expect(
            NarrationTimeline.word(at: time, ofLines: 1...1, in: estimated)
                == firstWordOfNextLine.word
        )
    }

    @Test("a line covers its own words and nothing else")
    func findsLineRange() throws {
        let estimated = timings
        let second = try #require(NarrationTimeline.range(ofLine: 1, in: estimated))
        let wordsOfSecondLine = estimated.filter { $0.word.lineIndex == 1 }

        #expect(second.lowerBound == wordsOfSecondLine.first?.start)
        #expect(second.upperBound == wordsOfSecondLine.last?.end)
        #expect(NarrationTimeline.range(ofLine: 9, in: estimated) == nil)
    }

    @Test("a reader's own recording is followed by how far through it is")
    func followsAnAttemptByFraction() throws {
        let estimated = timings
        let line = 1

        let opening = try #require(
            NarrationTimeline.word(atFraction: 0, ofLine: line, in: estimated)
        )
        let closing = try #require(
            NarrationTimeline.word(atFraction: 1, ofLine: line, in: estimated)
        )
        let wordsOfTheLine = estimated.filter { $0.word.lineIndex == line }.map(\.word)

        #expect(opening == wordsOfTheLine.first)
        #expect(closing == wordsOfTheLine.last)
        for step in 0...10 {
            let word = try #require(
                NarrationTimeline.word(atFraction: Double(step) / 10, ofLine: line, in: estimated)
            )
            #expect(word.lineIndex == line)
        }
    }

    @Test("a line with no timings has no word to mark")
    func refusesAFractionOfNothing() {
        #expect(NarrationTimeline.word(atFraction: 0.5, ofLine: 9, in: timings) == nil)
    }

    @Test("a recording of unknown length yields no timings")
    func refusesZeroDuration() {
        #expect(NarrationTimeline.estimate(for: passage, duration: 0).isEmpty)
    }
}
