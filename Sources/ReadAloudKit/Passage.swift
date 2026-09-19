import Foundation

/// The printed lines read as one continuous passage.
public struct Passage: Sendable, Equatable {
    /// Printed lines in reading order.
    public let lines: [String]

    /// Creates a passage without changing its spelling, punctuation, or spacing.
    public init(lines: [String]) {
        self.lines = lines
    }
}

/// One drawable part of a line, preserving the marks and spacing around a word.
public struct LineSegment: Identifiable, Sendable, Equatable {
    /// Index of the word in its line, or `nil` for a wordless segment.
    public let wordIndex: Int?
    /// Punctuation that opens the word.
    public let openingMarks: String
    /// The spoken letters of the word.
    public let word: String
    /// Punctuation that closes the word.
    public let closingMarks: String
    /// Whitespace following the segment.
    public let space: String

    public var id: String { "\(wordIndex ?? -1)-\(word)" }

    /// The word with its opening and closing punctuation, but without trailing space.
    public var wordWithMarks: String { openingMarks + word + closingMarks }

    /// The complete original text represented by this segment.
    public var text: String { wordWithMarks + space }
}

/// One spoken word together with its position and source range in the passage.
public struct SpokenWord: Identifiable, Sendable, Equatable {
    /// Zero-based printed-line index.
    public let lineIndex: Int
    /// Zero-based word index across the complete passage.
    public let indexInPassage: Int
    /// Zero-based word index within the printed line.
    public let indexInLine: Int
    /// Source range occupied by the spoken letters in their line.
    public let range: Range<String.Index>
    /// Printed spelling inside ``range``.
    public let text: String

    public var id: Int { indexInPassage }

    /// Returns the same word associated with another line index.
    public func movedToLine(_ lineIndex: Int) -> Self {
        Self(
            lineIndex: lineIndex,
            indexInPassage: indexInPassage,
            indexInLine: indexInLine,
            range: range,
            text: text
        )
    }
}
