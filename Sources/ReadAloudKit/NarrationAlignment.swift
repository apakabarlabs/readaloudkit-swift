import Foundation

private enum WordCodingKeys: String, CodingKey {
    case line, text, start, end
}

/// Word-timing metadata supplied for a recorded narration.
///
/// Unlike an estimated timeline, an alignment preserves the producer's supplied start
/// and end for every listed word. Decoding refuses times that cannot describe one
/// recording read in order: a negative start, an end before its start, or a word that
/// starts before the word listed ahead of it. It also refuses a field neither the
/// alignment nor its words have, and a value of another type than the field's. Values
/// created in code are not checked.
public struct NarrationAlignment: Codable, Sendable, Equatable {
    /// One word and its supplied interval in the recording.
    public struct Word: Codable, Sendable, Equatable {
        /// Zero-based index of the printed line containing the word.
        public let line: Int
        /// Printed spelling used when the alignment was produced.
        public let text: String
        /// Start time in seconds from the beginning of the recording.
        public let start: TimeInterval
        /// End time in seconds from the beginning of the recording.
        public let end: TimeInterval

        /// Creates one supplied word interval without validating its bounds.
        public init(line: Int, text: String, start: TimeInterval, end: TimeInterval) {
            self.line = line
            self.text = text
            self.start = start
            self.end = end
        }

        /// Decodes one word, refusing a field the word does not have.
        public init(from decoder: Decoder) throws {
            try decoder.refuseKeys(otherThan: WordCodingKeys.self, of: "a word")
            let container = try decoder.container(keyedBy: WordCodingKeys.self)
            self.init(
                line: try container.decode(Int.self, forKey: .line),
                text: try container.decode(String.self, forKey: .text),
                start: try container.decode(TimeInterval.self, forKey: .start),
                end: try container.decode(TimeInterval.self, forKey: .end)
            )
        }
    }

    /// Identifier of the aligned piece, as the work names it.
    public let piece: String
    /// Duration of the recording in seconds.
    public let duration: TimeInterval
    /// Supplied word intervals in passage order.
    public let words: [Word]

    /// An application-defined identifier for the recording these timings describe.
    public let recording: String?

    /// Creates the representation shared by the tool that measures a recording and
    /// the client that presents it.
    public init(piece: String, duration: TimeInterval, words: [Word], recording: String? = nil) {
        self.piece = piece
        self.duration = duration
        self.words = words
        self.recording = recording
    }

    private enum CodingKeys: String, CodingKey {
        case piece, duration, words, recording
    }

    /// Decodes an alignment and refuses times that are out of order or out of bounds.
    ///
    /// A field the alignment or one of its words does not have is refused, not skipped.
    ///
    /// - Throws: `DecodingError` for another shape, or ``TimingError`` naming the first
    ///   word whose times cannot stand.
    public init(from decoder: Decoder) throws {
        try decoder.refuseKeys(otherThan: CodingKeys.self, of: "an alignment")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let words = try container.decode([Word].self, forKey: .words)
        try Self.check(words)
        self.init(
            piece: try container.decode(String.self, forKey: .piece),
            duration: try container.decode(TimeInterval.self, forKey: .duration),
            words: words,
            recording: try container.decodeIfPresent(String.self, forKey: .recording)
        )
    }

    /// Supplied word times that cannot describe one recording read in order.
    public enum TimingError: LocalizedError, Equatable {
        /// The word at `word`, on printed line `line`, starts before the recording does.
        case negativeStart(word: Int, line: Int)
        /// The word at `word`, on printed line `line`, ends before it starts.
        case endBeforeStart(word: Int, line: Int)
        /// The word at `word`, on printed line `line`, starts before the word ahead of it.
        case startBeforePrevious(word: Int, line: Int)

        public var errorDescription: String? {
            switch self {
            case let .negativeStart(word, line):
                return "Word \(word) on line \(line) starts before the recording."

            case let .endBeforeStart(word, line):
                return "Word \(word) on line \(line) ends before it starts."

            case let .startBeforePrevious(word, line):
                return "Word \(word) on line \(line) starts before the word ahead of it."
            }
        }
    }

    private static func check(_ words: [Word]) throws {
        for (index, word) in words.enumerated() {
            guard word.start >= 0 else {
                throw TimingError.negativeStart(word: index, line: word.line)
            }
            guard word.end >= word.start else {
                throw TimingError.endBeforeStart(word: index, line: word.line)
            }
            guard index == 0 || word.start >= words[index - 1].start else {
                throw TimingError.startBeforePrevious(word: index, line: word.line)
            }
        }
    }

    /// A supplied alignment no longer describes the requested passage.
    public enum AlignmentError: LocalizedError, Equatable {
        /// The passage and alignment contain different numbers of spoken words.
        case wordCountMismatch(expected: Int, found: Int)
        /// The word at `index` or its line differs between the passage and alignment.
        case wordMismatch(
            index: Int,
            expected: String,
            found: String,
            expectedLine: Int,
            foundLine: Int
        )

        public var errorDescription: String? {
            switch self {
            case let .wordCountMismatch(expected, found):
                return "The alignment lists \(found) words, the text has \(expected)."

            case let .wordMismatch(index, expected, found, expectedLine, foundLine):
                return "Word \(index) is \"\(found)\" on line \(foundLine) in the alignment "
                    + "and \"\(expected)\" on line \(expectedLine) in the text."
            }
        }
    }

    /// Associates the supplied times with the words of a passage.
    ///
    /// The alignment carries the words it was built from. If the passage changes after
    /// timing, this method refuses it instead of shifting every later highlight.
    public func timings(for passage: Passage, tokenizer: WordTokenizer) throws -> [WordTiming] {
        let spoken = tokenizer.words(in: passage)
        guard spoken.count == words.count else {
            throw AlignmentError.wordCountMismatch(expected: spoken.count, found: words.count)
        }
        return try zip(spoken, words).enumerated().map { index, pair in
            let (word, measured) = pair
            guard word.text == measured.text, word.lineIndex == measured.line else {
                throw AlignmentError.wordMismatch(
                    index: index,
                    expected: word.text,
                    found: measured.text,
                    expectedLine: word.lineIndex,
                    foundLine: measured.line
                )
            }
            return WordTiming(word: word, start: measured.start, end: measured.end)
        }
    }
}
