import Foundation
import ReadAlign

/// How one printed word is presented while a reading is in progress.
public enum WordReadingState: Sendable, Equatable {
    /// A later word not yet reached.
    case ahead
    /// A near miss aligned with this printed word.
    case close
    /// The next word expected before an attempt begins.
    case expected
    /// A printed word not faithfully heard.
    case missed
    /// A printed word faithfully heard.
    case said
}

/// The persisted result of checking one printed word.
///
/// These raw spellings are part of the stored-data contract.
public enum WordCheck: String, Codable, Sendable, Equatable {
    /// A near miss was aligned with the word.
    case close
    /// The word was faithfully heard.
    case correct
    /// No faithful or near matching word was heard.
    case wrong
}

/// A printed word paired with the result of one reading attempt.
public struct WordAttempt: Sendable, Equatable {
    /// Printed spelling from the passage.
    public let word: String
    /// Result assigned to the printed word.
    public let check: WordCheck

    /// Creates one printable attempt result.
    public init(word: String, check: WordCheck) {
        self.word = word
        self.check = check
    }
}

/// Checks a complete spoken attempt against one or more printed lines.
///
/// The whole transcript is aligned at once so one misrecognized word does not shift
/// every word that follows it.
public struct SpokenLineTracker: Sendable {
    /// The minimum similarity used to align a near miss with a printed word.
    ///
    /// This threshold decides which words are compared. A word is credited only when
    /// its spelling is faithful or an explicit recognizer quirk permits it.
    public static let closeSimilarityThreshold = 0.6

    /// The result for every expected word in one attempt.
    public struct Progress: Sendable, Equatable {
        /// One result per expected word, in passage order.
        public let checks: [WordCheck]

        /// Whether every expected word was said faithfully.
        public var isComplete: Bool { !checks.isEmpty && checks.allSatisfy { $0 == .correct } }

        /// Whether no expected word could be credited or aligned as a near miss.
        public var isAllWrong: Bool { !checks.isEmpty && checks.allSatisfy { $0 == .wrong } }

        /// The display state corresponding to each check.
        public var wordStates: [WordReadingState] {
            checks.map { check in
                switch check {
                case .correct: .said
                case .close: .close
                case .wrong: .missed
                }
            }
        }

        /// Creates progress from ordered word checks.
        public init(checks: [WordCheck]) {
            self.checks = checks
        }
    }

    /// Printed words in passage order.
    public let expected: [String]

    /// Model-specific transcription allowances applied while checking.
    public let quirks: RecognizerQuirks

    /// The number of expected words in each printed line.
    public let lineLengths: [Int]

    /// The full forms of the elided spellings the work prints, from the work's data.
    public let elisions: Elisions

    /// Splits both the printed lines and every transcript checked against them.
    public let tokenizer: WordTokenizer

    /// Creates a tracker for one printed line.
    ///
    /// `quirks`, `elisions` and `tokenizer` have no default: each comes from the
    /// recogniser's or the work's data, and ``RecognizerQuirks/none`` is passed by name.
    public init(
        line: String,
        quirks: RecognizerQuirks,
        elisions: Elisions,
        tokenizer: WordTokenizer
    ) {
        self.init(lines: [line], quirks: quirks, elisions: elisions, tokenizer: tokenizer)
    }

    /// Creates a tracker that checks all printed lines as one continuous attempt.
    public init(
        lines: [String],
        quirks: RecognizerQuirks,
        elisions: Elisions,
        tokenizer: WordTokenizer
    ) {
        let words = lines.map { line in tokenizer.wordRanges(in: line).map { String(line[$0]) } }
        expected = words.flatMap(\.self)
        lineLengths = words.map(\.count)
        self.quirks = quirks
        self.elisions = elisions
        self.tokenizer = tokenizer
    }

    /// Counts spoken words in each line using `tokenizer`.
    public static func wordsPerLine(of lines: [String], tokenizer: WordTokenizer) -> [Int] {
        lines.map { tokenizer.wordRanges(in: $0).count }
    }

    /// Returns the part of a passage-wide state array belonging to one line.
    public static func wordStates(
        _ states: [WordReadingState],
        forLineAt index: Int,
        wordsPerLine: [Int]
    ) -> [WordReadingState] {
        guard wordsPerLine.indices.contains(index) else { return [] }
        let start = wordsPerLine.prefix(index).reduce(0, +)
        let end = min(start + wordsPerLine[index], states.count)
        guard start < end else { return [] }
        return Array(states[start..<end])
    }

    /// Returns the part of a passage-wide state array belonging to one tracked line.
    public func wordStates(_ states: [WordReadingState], forLineAt index: Int) -> [WordReadingState]
    {
        Self.wordStates(states, forLineAt: index, wordsPerLine: lineLengths)
    }

    /// States shown before an attempt: the first word expected and later words ahead.
    public var untriedWordStates: [WordReadingState] {
        expected.indices.map { $0 == 0 ? .expected : .ahead }
    }

    /// Checks a complete recognized transcript against the tracked printed words.
    ///
    /// The transcript is split by the tracker's own ``tokenizer``, so printed and heard
    /// words are cut by one rule. Extra words outside the best alignment do not count
    /// against the printed words.
    public func progress(heard transcript: String) -> Progress {
        let heard = tokenizer.wordRanges(in: transcript).map { String(transcript[$0]) }
        let checked = SpokenWords.check(
            expected: expected,
            heard: heard,
            quirks: quirks,
            elisions: elisions
        )
        var checks = [WordCheck](repeating: .wrong, count: expected.count)
        for (index, match) in checked.matches.enumerated() {
            let check: WordCheck = checked.faithful.contains(index) ? .correct : .close
            for word in match.expected { checks[word] = check }
        }
        return Progress(checks: checks)
    }

    /// Pairs the original printed spellings with their check results.
    public func attempts(in progress: Progress) -> [WordAttempt] {
        zip(expected, progress.checks).map { word, check in
            WordAttempt(word: word, check: check)
        }
    }

    /// Reports whether a heard spelling faithfully represents a written word.
    ///
    /// Case and punctuation are ignored. An elided spelling also counts as said when the
    /// heard word is the full form `elisions` gives for it; nothing else is restored.
    public static func isFaithful(
        _ heard: String,
        to expected: String,
        elisions: Elisions
    ) -> Bool {
        let said = TranscriptAligner.normalize(heard)
        return said == TranscriptAligner.normalize(expected)
            || elisions.fullForms(of: expected).contains(said)
    }
}
