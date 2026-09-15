import Foundation

public struct NarrationAlignment: Codable, Sendable, Equatable {
    public struct Word: Codable, Sendable, Equatable {
        public let line: Int
        public let text: String
        public let start: TimeInterval
        public let end: TimeInterval

        public init(line: Int, text: String, start: TimeInterval, end: TimeInterval) {
            self.line = line
            self.text = text
            self.start = start
            self.end = end
        }
    }

    public let sonnet: Int
    public let duration: TimeInterval
    public let words: [Word]

    public let recording: String?

    public init(sonnet: Int, duration: TimeInterval, words: [Word], recording: String? = nil) {
        self.sonnet = sonnet
        self.duration = duration
        self.words = words
        self.recording = recording
    }

    public enum AlignmentError: LocalizedError, Equatable {
        case wordCountMismatch(expected: Int, found: Int)
        case wordMismatch(index: Int, expected: String, found: String)

        public var errorDescription: String? {
            switch self {
            case .wordCountMismatch(let expected, let found):
                return "The alignment lists \(found) words, the text has \(expected)."
            case .wordMismatch(let index, let expected, let found):
                return "Word \(index) is \"\(found)\" in the alignment and \"\(expected)\" in the text."
            }
        }
    }

    public static func decode(_ data: Data) throws -> NarrationAlignment {
        try JSONDecoder().decode(NarrationAlignment.self, from: data)
    }

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
                throw AlignmentError.wordMismatch(index: index, expected: word.text, found: measured.text)
            }
            return WordTiming(word: word, start: measured.start, end: measured.end)
        }
    }
}
