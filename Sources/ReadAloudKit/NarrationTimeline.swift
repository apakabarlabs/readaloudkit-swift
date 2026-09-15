import Foundation
import ReadAlign

public struct WordTiming: Sendable, Equatable {
    public let word: SpokenWord
    public let start: TimeInterval
    public let end: TimeInterval
}

public enum NarrationTimeline {
    public static let leadIn: TimeInterval = 0.35
    public static let linePause: TimeInterval = 0.35

    public static func estimate(
        for passage: Passage,
        duration: TimeInterval,
        tokenizer: WordTokenizer = .latinScript,
        weighting: some SpeechWeighting = EnglishSyllableWeighting()
    ) -> [WordTiming] {
        let words = tokenizer.words(in: passage)
        guard !words.isEmpty, duration > 0 else { return [] }

        let pauses = TimeInterval(max(passage.lines.count - 1, 0)) * linePause
        let speech = max(duration - leadIn - pauses, duration * 0.5)
        let weights = words.map { weighting.weight(of: $0.text) }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return [] }

        var timings: [WordTiming] = []
        timings.reserveCapacity(words.count)
        var cursor = leadIn
        var previousLine = words[0].lineIndex

        for (word, weight) in zip(words, weights) {
            if word.lineIndex != previousLine {
                cursor += linePause
                previousLine = word.lineIndex
            }
            let length = speech * weight / totalWeight
            timings.append(WordTiming(word: word, start: cursor, end: cursor + length))
            cursor += length
        }
        return timings
    }

    public static func heldThroughSilence(
        _ timings: [WordTiming],
        samples: [Float],
        sampleRate: Double
    ) -> [WordTiming] {
        let held = SilenceHold.held(
            timings.map { WordSpan(start: $0.start, end: $0.end) },
            samples: samples,
            sampleRate: sampleRate
        )
        return zip(timings, held).map { timing, span in
            WordTiming(word: timing.word, start: span.start, end: span.end)
        }
    }

    public static func settledBetweenLines(
        _ timings: [WordTiming],
        samples: [Float],
        sampleRate: Double,
        reach: TimeInterval = 0.25
    ) -> [WordTiming] {
        let frames = energyFrames(of: samples, sampleRate: sampleRate)
        guard !frames.isEmpty else { return timings }
        let speech = speechLevel(of: frames)
        func frame(at seconds: TimeInterval) -> Int {
            Int((seconds / frameLength).rounded())
        }
        func level(atFrame index: Int) -> Double {
            frames.indices.contains(index) ? frames[index] / speech : 0
        }

        var settled = timings
        for index in settled.indices.dropLast() {
            let word = settled[index]
            let following = settled[index + 1]
            guard word.word.lineIndex != following.word.lineIndex else { continue }
            let from = frame(at: word.end)
            guard level(atFrame: from) > insideASound else { continue }

            let room = frame(at: min(word.end + reach, following.end - shortestWord))
            guard room > from else { continue }

            var found: Int?
            for step in (from + 1)...room where level(atFrame: step) <= restingQuiet {
                found = step
                break
            }
            guard let chosen = found else { continue }
            let best = Double(chosen) * frameLength
            guard best > word.end else { continue }
            settled[index] = WordTiming(word: word.word, start: word.start, end: best)
            settled[index + 1] = WordTiming(
                word: following.word,
                start: max(following.start, best),
                end: following.end
            )
        }
        return settled
    }

    private static let insideASound = 0.5
    private static let restingQuiet = 0.3
    private static let shortestWord: TimeInterval = 0.04

    private static func speechLevel(of frames: [Double]) -> Double {
        SilenceHold.speechLevel(of: frames)
    }

    private static let frameLength = SilenceHold.frameSeconds

    private static func energyFrames(of samples: [Float], sampleRate: Double) -> [Double] {
        SilenceHold.energyFrames(of: samples, sampleRate: sampleRate)
    }

    public static func heldToTheNextWord(
        _ timings: [WordTiming],
        duration: TimeInterval,
        limit: TimeInterval = 0.4
    ) -> [WordTiming] {
        timings.indices.map { index in
            let timing = timings[index]
            let next = index + 1 < timings.count ? timings[index + 1].start : duration
            return WordTiming(
                word: timing.word,
                start: timing.start,
                end: max(timing.end, min(next, timing.end + limit))
            )
        }
    }

    public static func range(ofLine lineIndex: Int, in timings: [WordTiming]) -> ClosedRange<TimeInterval>? {
        range(ofLines: lineIndex...lineIndex, in: timings)
    }

    public static func range(
        ofLines lines: ClosedRange<Int>,
        in timings: [WordTiming]
    ) -> ClosedRange<TimeInterval>? {
        let inside = timings.filter { lines.contains($0.word.lineIndex) }
        guard let start = inside.first?.start, let end = inside.last?.end else { return nil }
        return start...end
    }

    public static func word(
        atFraction fraction: Double,
        ofLine lineIndex: Int,
        in timings: [WordTiming]
    ) -> SpokenWord? {
        word(atFraction: fraction, ofLines: lineIndex...lineIndex, in: timings)
    }

    public static func word(
        atFraction fraction: Double,
        ofLines lines: ClosedRange<Int>,
        in timings: [WordTiming]
    ) -> SpokenWord? {
        guard let range = range(ofLines: lines, in: timings) else { return nil }
        let clamped = min(max(fraction, 0), 1)
        let time = range.lowerBound + (range.upperBound - range.lowerBound) * clamped
        guard let index = index(at: time, in: timings) else {
            let isExactlyAtTheEnd = clamped >= 1
            return isExactlyAtTheEnd ? timings.last(where: { lines.contains($0.word.lineIndex) })?.word : nil
        }
        return timings[index].word
    }

    public static func index(at time: TimeInterval, in timings: [WordTiming]) -> Int? {
        guard let first = timings.first, let last = timings.last else { return nil }
        guard time >= first.start, time <= last.end else { return nil }
        var low = 0
        var high = timings.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let timing = timings[middle]
            if time < timing.start {
                high = middle - 1
            } else if time >= timing.end {
                low = middle + 1
            } else {
                return middle
            }
        }
        return nil
    }

    public static func word(
        at time: TimeInterval,
        ofLines lines: ClosedRange<Int>,
        in timings: [WordTiming]
    ) -> SpokenWord? {
        guard let index = index(at: time, in: timings) else { return nil }
        let word = timings[index].word
        return lines.contains(word.lineIndex) ? word : nil
    }
}
