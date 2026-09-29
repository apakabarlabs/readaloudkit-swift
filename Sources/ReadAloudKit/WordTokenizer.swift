import Foundation

/// Splits printed lines into the words a reader actually says.
///
/// Which marks may live inside a word is supplied by the language. A writing system
/// without spaces needs another tokenizer rather than a different set of marks.
///
/// A character, as Unicode clusters it, is a letter or a space by its base: the
/// scalar its combining marks sit on, past any sign prepended to it. A private-use
/// character is never a letter, whatever a font draws for it.
///
/// Where a character ends and whether it is a letter follow the Unicode data of the
/// Swift runtime the code runs on, so an older system can cut a newer character
/// differently.
public struct WordTokenizer: Sendable {
    /// Marks that remain part of a word after the word has begun.
    public let interiorMarks: CharacterSet

    /// Creates a tokenizer for a space-delimited writing system, keeping inside a word the
    /// marks the work's data names for its script, such as an apostrophe or a hyphen.
    public init(interiorMarks: CharacterSet) {
        self.interiorMarks = interiorMarks
    }

    /// Returns all spoken words with their positions in the passage.
    public func words(in passage: Passage) -> [SpokenWord] {
        var words: [SpokenWord] = []
        for (lineIndex, line) in passage.lines.enumerated() {
            for (indexInLine, range) in wordRanges(in: line).enumerated() {
                words.append(
                    SpokenWord(
                        lineIndex: lineIndex,
                        indexInPassage: words.count,
                        indexInLine: indexInLine,
                        range: range,
                        text: String(line[range])
                    )
                )
            }
        }
        return words
    }

    /// Splits every line into drawable word-and-punctuation segments.
    public func segments(in passage: Passage) -> [[LineSegment]] {
        passage.lines.map { segments(in: $0) }
    }

    /// Splits one line while preserving every original character and space.
    public func segments(in line: String) -> [LineSegment] {
        let ranges = wordRanges(in: line)
        guard !ranges.isEmpty else {
            let wordless = LineSegment(
                wordIndex: nil,
                openingMarks: "",
                word: "",
                closingMarks: line,
                space: ""
            )
            return line.isEmpty ? [] : [wordless]
        }

        let openings = ranges.enumerated().map { index, range in
            let gapStart = index == 0 ? line.startIndex : ranges[index - 1].upperBound
            return openingMarkStart(
                in: line,
                gap: gapStart..<range.lowerBound,
                isFirstWord: index == 0
            )
        }

        var segments: [LineSegment] = []
        let runIn = String(line[line.startIndex..<openings[0]])
        if !runIn.isEmpty {
            segments.append(
                LineSegment(
                    wordIndex: nil,
                    openingMarks: "",
                    word: "",
                    closingMarks: "",
                    space: runIn
                )
            )
        }
        for (index, range) in ranges.enumerated() {
            let untilNextWordsMarks = index + 1 < ranges.count ? openings[index + 1] : line.endIndex
            let after = line[range.upperBound..<untilNextWordsMarks]
            let closingMarks = after.prefix { !$0.base.properties.isWhitespace }
            segments.append(
                LineSegment(
                    wordIndex: index,
                    openingMarks: String(line[openings[index]..<range.lowerBound]),
                    word: String(line[range]),
                    closingMarks: String(closingMarks),
                    space: String(after.dropFirst(closingMarks.count))
                )
            )
        }
        return segments
    }

    private func openingMarkStart(
        in line: String,
        gap: Range<String.Index>,
        isFirstWord: Bool
    )
        -> String.Index
    {
        guard let lastSpace = line[gap].lastIndex(where: \.base.properties.isWhitespace) else {
            let marksStandWithTheWordBefore = !isFirstWord
            return marksStandWithTheWordBefore ? gap.upperBound : gap.lowerBound
        }
        return line.index(after: lastSpace)
    }

    /// Returns the source ranges of words in one line.
    public func wordRanges(in line: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        var index = line.startIndex

        while index < line.endIndex {
            if isWordCharacter(line[index], hasStarted: start != nil) {
                if start == nil { start = index }
            } else if let began = start {
                ranges.append(began..<index)
                start = nil
            }
            index = line.index(after: index)
        }
        if let began = start {
            ranges.append(began..<line.endIndex)
        }
        return ranges.map { trimInteriorMarks(in: line, range: $0) }
    }

    private func isWordCharacter(_ character: Character, hasStarted: Bool) -> Bool {
        if character.base.properties.isAlphabetic { return true }
        return hasStarted && character.unicodeScalars.allSatisfy(interiorMarks.contains)
    }

    private func trimInteriorMarks(
        in line: String,
        range: Range<String.Index>
    ) -> Range<
        String.Index
    > {
        var end = range.upperBound
        while end > range.lowerBound {
            let previous = line.index(before: end)
            if line[previous].base.properties.isAlphabetic { break }
            end = previous
        }
        return range.lowerBound..<end
    }
}
