import Foundation
import ReadAlign

extension TranscriptAligner {
    /// Aligns recognized words with printed words and returns passage-aware timings.
    ///
    /// `weighting` shares time among words the recognizer missed and belongs to the
    /// language of the passage.
    public static func timings(
        for words: [SpokenWord],
        heard: [RecognizedWord],
        duration: TimeInterval,
        weighting: any SpeechWeighting
    ) -> [WordTiming] {
        let spans = align(
            expected: words.map(\.text),
            heard: heard,
            duration: duration,
            weighting: weighting
        )
        return zip(words, spans).map { word, span in
            WordTiming(word: word, start: span.start, end: span.end)
        }
    }
}
