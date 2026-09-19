import Foundation
import ReadAlign

extension TranscriptAligner {
    /// Aligns recognized words with printed words and returns passage-aware timings.
    public static func timings(
        for words: [SpokenWord],
        heard: [RecognizedWord],
        duration: TimeInterval
    ) -> [WordTiming] {
        let spans = align(
            expected: words.map(\.text),
            heard: heard,
            duration: duration
        )
        return zip(words, spans).map { word, span in
            WordTiming(word: word, start: span.start, end: span.end)
        }
    }
}
