import Foundation
import ReadAlign

public extension TranscriptAligner {
    static func timings(
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
