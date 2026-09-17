import Foundation
import Testing

@testable import ReadAloudKit

struct WordTokenizerTests {
    private let tokenizer = WordTokenizer.latinScript

    private func words(_ line: String) -> [String] {
        tokenizer.wordRanges(in: line).map { String(line[$0]) }
    }

    @Test("apostrophes hold elisions together, in either shape")
    func keepsElisions() {
        #expect(
            words("That thereby beauty’s rose might never die,")
                == ["That", "thereby", "beauty’s", "rose", "might", "never", "die"]
        )
        #expect(
            words("Feed'st thy light's flame")
                == ["Feed'st", "thy", "light's", "flame"]
        )
    }

    @Test("hyphens hold compounds together")
    func keepsCompounds() {
        #expect(words("with self-substantial fuel,") == ["with", "self-substantial", "fuel"])
    }

    @Test("punctuation between words is dropped")
    func dropsPunctuation() {
        #expect(
            words("Thy self thy foe, to thy sweet self too cruel:")
                == ["Thy", "self", "thy", "foe", "to", "thy", "sweet", "self", "too", "cruel"]
        )
    }

    @Test("quotation marks stay outside the words they wrap")
    func handlesQuotedSpeech() {
        #expect(
            words("If thou couldst answer ‘This fair child of mine")
                == ["If", "thou", "couldst", "answer", "This", "fair", "child", "of", "mine"]
        )
        #expect(
            words("Shall sum my count, and make my old excuse,’")
                == ["Shall", "sum", "my", "count", "and", "make", "my", "old", "excuse"]
        )
    }

    @Test("a line with no letters yields no words")
    func handlesEmptyLine() {
        #expect(words("").isEmpty)
        #expect(words("...").isEmpty)
    }

    @Test("words carry their line and their order")
    func numbersWords() {
        let passage = Passage(lines: ["From fairest creatures", "we desire increase,"])
        let spoken = tokenizer.words(in: passage)

        #expect(spoken.map(\.text) == ["From", "fairest", "creatures", "we", "desire", "increase"])
        #expect(spoken.map(\.indexInPassage) == [0, 1, 2, 3, 4, 5])
        #expect(spoken.map(\.lineIndex) == [0, 0, 0, 1, 1, 1])
    }

    @Test("a line splits into pieces that put it back together unchanged")
    func splitsIntoSegments() {
        let line = "Thy self thy foe, to thy sweet self too cruel:"
        let segments = tokenizer.segments(in: line)

        #expect(segments.map(\.text).joined() == line)
        #expect(segments.compactMap(\.wordIndex) == Array(0..<10))
        #expect(segments[3].word == "foe")
        #expect(segments[3].closingMarks == ",")
        #expect(segments[3].space == " ")
        #expect(segments.last?.closingMarks == ":")
    }

    @Test("a mark that opens a word goes with that word, not with the one before it")
    func keepsOpeningMarks() {
        let line = "she said: ‘go on’"
        let segments = tokenizer.segments(in: line)

        #expect(segments.map(\.text).joined() == line)
        #expect(segments[1].word == "said")
        #expect(segments[1].closingMarks == ":")
        #expect(segments[1].space == " ")
        #expect(segments[2].openingMarks == "‘")
        #expect(segments[2].word == "go")
        #expect(segments.last?.closingMarks == "’")
    }

    @Test("a line that opens with a quotation mark gives it to its first word")
    func keepsLeadingPunctuation() {
        let line = "‘go on’ she said"
        let segments = tokenizer.segments(in: line)

        #expect(segments.map(\.text).joined() == line)
        #expect(segments[0].wordIndex == 0)
        #expect(segments[0].openingMarks == "‘")
        #expect(segments[0].word == "go")
    }

    @Test("marks with no space around them stand with the word before")
    func keepsUnspacedMarksWithTheWordBefore() {
        let segments = tokenizer.segments(in: "here,—there")

        #expect(segments[0].word == "here")
        #expect(segments[0].closingMarks == ",—")
        #expect(segments[1].openingMarks.isEmpty)
        #expect(segments[1].word == "there")
    }

    @Test("a language without apostrophe elisions can say so")
    func respectsItsMarkSet() {
        let plain = WordTokenizer(interiorMarks: CharacterSet(charactersIn: "-"))

        #expect(
            plain.wordRanges(in: "beauty's rose").map { String("beauty's rose"[$0]) }
                == ["beauty", "s", "rose"]
        )
    }
}
