import Foundation

public struct Passage: Sendable, Equatable {
    public let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }
}

public struct LineSegment: Identifiable, Sendable, Equatable {
    public let wordIndex: Int?
    public let openingMarks: String
    public let word: String
    public let closingMarks: String
    public let space: String

    public var id: String { "\(wordIndex ?? -1)-\(word)" }

    public var wordWithMarks: String { openingMarks + word + closingMarks }

    public var text: String { wordWithMarks + space }
}

public struct SpokenWord: Identifiable, Sendable, Equatable {
    public let lineIndex: Int
    public let indexInPassage: Int
    public let indexInLine: Int
    public let range: Range<String.Index>
    public let text: String

    public var id: Int { indexInPassage }

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
