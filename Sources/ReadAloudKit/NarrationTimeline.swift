import Foundation
import ReadAlign

/// The interval in which one word is spoken in a recording.
public struct WordTiming: Sendable, Equatable {
    /// The passage word occupying the interval.
    public let word: SpokenWord
    /// Start time in seconds.
    public let start: TimeInterval
    /// End time in seconds.
    public let end: TimeInterval
}

/// Builds and queries word-level timelines for recorded speech.
///
/// ``estimate(for:duration:tokenizer:weighting:)`` is fallback scaffolding for a
/// recording without measured alignment. Prefer ``NarrationAlignment`` whenever
/// measured word timings are available.
public enum NarrationTimeline {
    private static let minimumSpeechFraction = 0.5
    private static let binarySearchDivisor = 2
    /// Silence reserved before the first estimated word.
    public static let leadIn: TimeInterval = 0.35

    /// Time reserved for a breath at each line break in an estimated timeline.
    public static let linePause: TimeInterval = 0.35

    /// Estimates word timings by speech weight, reserving a pause at each line break.
    ///
    /// The tokenizer and the weighting belong to the language of the passage. An empty
    /// passage, nonpositive duration, or weighting with no positive total produces an
    /// empty timeline.
    ///
    /// - Precondition: `weighting` returns a nonnegative weight for every word.
    public static func estimate(
        for passage: Passage,
        duration: TimeInterval,
        tokenizer: WordTokenizer,
        weighting: some SpeechWeighting
    ) -> [WordTiming] {
        let words = tokenizer.words(in: passage)
        guard !words.isEmpty, duration > 0 else { return [] }

        let pauses = TimeInterval(max(passage.lines.count - 1, 0)) * linePause
        let speech = max(duration - leadIn - pauses, duration * minimumSpeechFraction)
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

    /// Extends each supplied word interval through its release and the silence that follows.
    ///
    /// After the scan encounters quiet, the end stops when sound resumes. If sound
    /// continues without reaching quiet, the underlying hold limit or next interval
    /// bounds the extension.
    ///
    /// - Preconditions:
    ///   - `timings` are sorted in passage and non-overlapping time order.
    ///   - `sampleRate` is positive.
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

    /// Moves a line boundary out of speech and into the first resting silence in reach.
    ///
    /// Both sides of the boundary move together. If no genuine rest is found, the
    /// measured boundary is preserved rather than replaced with a guess. The following
    /// word keeps at least 0.04 seconds and its start moves with the shared boundary.
    ///
    /// - Preconditions:
    ///   - `timings` are sorted in passage and non-overlapping time order.
    ///   - `sampleRate` is positive.
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

    /// Extends each word toward the next word, without passing it or exceeding `limit`.
    ///
    /// - Precondition: `timings` are sorted in non-overlapping time order.
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

    /// Returns the part of the recording occupied by one line.
    ///
    /// - Precondition: `timings` are in passage and non-overlapping time order.
    public static func range(
        ofLine lineIndex: Int,
        in timings: [WordTiming]
    ) -> ClosedRange<
        TimeInterval
    >? {
        range(ofLines: lineIndex...lineIndex, in: timings)
    }

    /// Returns the part of the recording occupied by a consecutive run of lines.
    ///
    /// - Precondition: `timings` are in passage and non-overlapping time order.
    public static func range(
        ofLines lines: ClosedRange<Int>,
        in timings: [WordTiming]
    ) -> ClosedRange<TimeInterval>? {
        let inside = timings.filter { lines.contains($0.word.lineIndex) }
        guard let start = inside.first?.start, let end = inside.last?.end else { return nil }
        return start...end
    }

    /// Returns the word at a fractional position through one line.
    ///
    /// This maps progress through an unaligned recording onto the shape of an aligned
    /// one; it is an estimate of position, not a measurement of the reader's speech.
    ///
    /// - Precondition: `timings` are sorted in passage and non-overlapping time order.
    public static func word(
        atFraction fraction: Double,
        ofLine lineIndex: Int,
        in timings: [WordTiming]
    ) -> SpokenWord? {
        word(atFraction: fraction, ofLines: lineIndex...lineIndex, in: timings)
    }

    /// Returns the word at a fractional position through a consecutive run of lines.
    ///
    /// - Precondition: `timings` are sorted in passage and non-overlapping time order.
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
            return isExactlyAtTheEnd
                ? timings.last { lines.contains($0.word.lineIndex) }?.word : nil
        }
        return timings[index].word
    }

    /// Returns the index of the word sounding at `time`.
    ///
    /// - Precondition: `timings` are sorted by non-overlapping start and end times.
    public static func index(at time: TimeInterval, in timings: [WordTiming]) -> Int? {
        guard let first = timings.first, let last = timings.last else { return nil }
        guard time >= first.start, time <= last.end else { return nil }
        var low = 0
        var high = timings.count - 1
        while low <= high {
            let middle = (low + high) / binarySearchDivisor
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

    /// Returns the word sounding at `time` when it belongs to `lines`.
    ///
    /// Constraining the result prevents a final playback tick from highlighting a word
    /// in the following piece.
    ///
    /// - Precondition: `timings` are sorted in passage and non-overlapping time order.
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
