import Foundation
import ReadAlign
import Testing

@testable import ReadAloudKit

struct TimelineCases: Codable {
    let settle: [SettleCase]
    let hold: [HoldCase]

    static let all = Cases.loadRefusingUnreadKeys("timeline_tests.yaml", as: Self.self)
}

func expectTimings(_ actual: [WordTiming], equal expected: [[TimeInterval]], in name: String) {
    #expect(actual.count == expected.count, "\(name): one timing per word")
    for (index, (timing, span)) in zip(actual, expected).enumerated() {
        #expect(Cases.close(timing.start, span[0]), "\(name): start of word \(index)")
        #expect(Cases.close(timing.end, span[1]), "\(name): end of word \(index)")
    }
}

struct SettleCase: NamedCase {
    let name: String
    let lines: [String]
    let sampleCount: Int
    let level: Float
    let loud: [[Int]]
    let rate: Double
    let marks: [[TimeInterval]]
    let timings: [[TimeInterval]]

    private enum CodingKeys: String, CodingKey {
        case name, lines, level, loud, rate, marks, timings
        case sampleCount = "sample_count"
    }

    var samples: [Float] {
        var samples = [Float](repeating: 0, count: sampleCount)
        for run in loud {
            for index in run[0]..<run[1] { samples[index] = level }
        }
        return samples
    }

    var marked: [WordTiming] {
        let words = WordTokenizer.latinScript.words(in: Passage(lines: lines))
        return zip(words, marks).map { WordTiming(word: $0, start: $1[0], end: $1[1]) }
    }
}

struct HoldCase: NamedCase {
    let name: String
    let spans: [[TimeInterval]]
    let duration: TimeInterval
    let limit: TimeInterval?
    let timings: [[TimeInterval]]

    var marked: [WordTiming] {
        let line = Array(repeating: "word", count: spans.count).joined(separator: " ")
        let words = WordTokenizer.latinScript.words(in: Passage(lines: [line]))
        return zip(words, spans).map { WordTiming(word: $0, start: $1[0], end: $1[1]) }
    }
}

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
        NarrationTimeline.estimate(
            for: passage,
            duration: duration,
            tokenizer: .latinScript,
            weighting: EnglishSyllableWeighting()
        )
    }

    @Test(arguments: TimelineCases.all.settle)
    func settlesLineEndings(_ example: SettleCase) {
        let settled = NarrationTimeline.settledBetweenLines(
            example.marked,
            samples: example.samples,
            sampleRate: example.rate
        )

        expectTimings(settled, equal: example.timings, in: example.name)
    }

    @Test(arguments: TimelineCases.all.hold)
    func holdsWordsOpen(_ example: HoldCase) {
        let held =
            example.limit.map {
                NarrationTimeline.heldToTheNextWord(
                    example.marked,
                    duration: example.duration,
                    limit: $0
                )
            } ?? NarrationTimeline.heldToTheNextWord(example.marked, duration: example.duration)

        expectTimings(held, equal: example.timings, in: example.name)
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
        let estimated = NarrationTimeline.estimate(
            for: passage,
            duration: duration,
            tokenizer: .latinScript,
            weighting: EvenWeighting()
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
        let estimated = NarrationTimeline.estimate(
            for: passage,
            duration: 0,
            tokenizer: .latinScript,
            weighting: EnglishSyllableWeighting()
        )

        #expect(estimated.isEmpty)
    }
}
