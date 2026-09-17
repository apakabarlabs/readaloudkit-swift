import Foundation
import ReadAlign

public enum WordReadingState: Sendable, Equatable {
    case ahead
    case close
    case expected
    case missed
    case said
}

public enum WordCheck: String, Codable, Sendable, Equatable {
    case close
    case correct
    case wrong
}

public struct WordAttempt: Sendable, Equatable {
    public let word: String
    public let check: WordCheck

    public init(word: String, check: WordCheck) {
        self.word = word
        self.check = check
    }
}

public struct SpokenLineTracker: Sendable {
    public static let closeSimilarityThreshold = 0.6

    public struct Progress: Sendable, Equatable {
        public let checks: [WordCheck]

        public var isComplete: Bool { !checks.isEmpty && checks.allSatisfy { $0 == .correct } }
        public var isAllWrong: Bool { !checks.isEmpty && checks.allSatisfy { $0 == .wrong } }
        public var wordStates: [WordReadingState] {
            checks.map { check in
                switch check {
                case .correct: .said
                case .close: .close
                case .wrong: .missed
                }
            }
        }

        public init(checks: [WordCheck]) {
            self.checks = checks
        }
    }

    public let expected: [String]
    public let quirks: RecognizerQuirks
    public let lineLengths: [Int]

    public init(
        line: String,
        quirks: RecognizerQuirks = .none,
        tokenizer: WordTokenizer = .latinScript
    ) {
        self.init(lines: [line], quirks: quirks, tokenizer: tokenizer)
    }

    public init(
        lines: [String],
        quirks: RecognizerQuirks = .none,
        tokenizer: WordTokenizer = .latinScript
    ) {
        let words = lines.map { line in tokenizer.wordRanges(in: line).map { String(line[$0]) } }
        expected = words.flatMap(\.self)
        lineLengths = words.map(\.count)
        self.quirks = quirks
    }

    public static func wordsPerLine(
        of lines: [String],
        tokenizer: WordTokenizer = .latinScript
    )
        -> [Int]
    {
        lines.map { tokenizer.wordRanges(in: $0).count }
    }

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

    public func wordStates(_ states: [WordReadingState], forLineAt index: Int) -> [WordReadingState]
    {
        Self.wordStates(states, forLineAt: index, wordsPerLine: lineLengths)
    }

    public var untriedWordStates: [WordReadingState] {
        expected.indices.map { $0 == 0 ? .expected : .ahead }
    }

    public func progress(
        heard transcript: String,
        tokenizer: WordTokenizer = .latinScript
    )
        -> Progress
    {
        let heard = tokenizer.wordRanges(in: transcript).map { String(transcript[$0]) }
        let checked = SpokenWords.check(expected: expected, heard: heard, quirks: quirks)
        var checks = [WordCheck](repeating: .wrong, count: expected.count)
        for (index, match) in checked.matches.enumerated() {
            let check: WordCheck = checked.faithful.contains(index) ? .correct : .close
            for word in match.expected { checks[word] = check }
        }
        return Progress(checks: checks)
    }

    public func attempts(in progress: Progress) -> [WordAttempt] {
        zip(expected, progress.checks).map { word, check in
            WordAttempt(word: word, check: check)
        }
    }

    public static func isFaithful(_ heard: String, to expected: String) -> Bool {
        let said = TranscriptAligner.normalize(heard)
        return said == TranscriptAligner.normalize(expected) || writesOut(said, elidedIn: expected)
    }

    private static func writesOut(_ said: String, elidedIn written: String) -> Bool {
        let parts =
            written
            .components(separatedBy: CharacterSet(charactersIn: "’'"))
            .map(TranscriptAligner.normalize)
        guard parts.count > 1 else { return false }

        let vowels = "aeiou"
        let lettersAnApostropheMayStandFor = 1...2
        var rest = Substring(said)
        for (index, part) in parts.enumerated() {
            guard rest.hasPrefix(part) else { return false }
            rest = rest.dropFirst(part.count)
            guard index < parts.count - 1 else { break }
            let restored = rest.prefix { vowels.contains($0) }
            guard lettersAnApostropheMayStandFor.contains(restored.count) else { return false }
            rest = rest.dropFirst(restored.count)
        }
        return rest.isEmpty
    }
}
