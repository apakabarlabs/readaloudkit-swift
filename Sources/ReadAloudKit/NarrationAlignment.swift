import Foundation

/// Word-timing metadata supplied for a recorded narration.
///
/// Unlike an estimated timeline, an alignment preserves the producer's supplied start
/// and end for every listed word. The type trusts the producer to validate the spans.
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

    /// A supplied alignment no longer describes the requested passage.
    public enum AlignmentError: LocalizedError, Equatable {
        /// The passage and alignment contain different numbers of spoken words.
        case wordCountMismatch(expected: Int, found: Int)
        /// The word at `index` or its line differs between the passage and alignment.
        case wordMismatch(index: Int, expected: String, found: String)

        public var errorDescription: String? {
            switch self {
            case let .wordCountMismatch(expected, found):
                return "The alignment lists \(found) words, the text has \(expected)."

            case let .wordMismatch(index, expected, found):
                return
                    "Word \(index) is \"\(found)\" in the alignment and \"\(expected)\" in the text."
            }
        }
    }

    /// Decodes an alignment from its JSON representation.
    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    /// Associates the supplied times with the words of a passage.
    ///
    /// The alignment carries the words it was built from. If the passage changes after
    /// timing, this method refuses it instead of shifting every later highlight.
    public func timings(
        for passage: Passage,
        tokenizer: WordTokenizer = .latinScript
    ) throws -> [WordTiming] {
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
                    found: measured.text
                )
            }
            return WordTiming(word: word, start: measured.start, end: measured.end)
        }
    }
}
