import Foundation
import ReadAlign

/// Decides whether recognized words faithfully represent the printed words.
public enum SpokenWords {
    /// The alignment between written and heard words and the aligned pairs accepted.
    public struct Check: Sendable {
        /// Every pair made by the aligner, including refused pairs.
        public let matches: [WordMatch]

        /// Indices into ``matches`` that count as faithfully spoken.
        public let faithful: Set<Int>

        /// Creates a check from aligner matches and indices into `matches` that passed.
        ///
        /// - Precondition: Every index in `faithful` exists in `matches`.
        public init(matches: [WordMatch], faithful: Set<Int>) {
            self.matches = matches
            self.faithful = faithful
        }

        /// Maps each accepted written-word index to the first heard index in its match.
        public var pairs: [Int: Int] {
            faithful.reduce(into: [Int: Int]()) { result, index in
                let match = matches[index]
                for word in match.expected { result[word] = match.heard.lowerBound }
            }
        }
    }

    /// Aligns heard words with expected words and applies explicit recognizer quirks.
    ///
    /// `threshold` decides which words may be compared; acceptance still requires a
    /// faithful spelling or an explicit quirk.
    public static func check(
        expected: [String],
        heard: [String],
        quirks: RecognizerQuirks,
        threshold: Double = SpokenLineTracker.closeSimilarityThreshold
    ) -> Check {
        let matches = TranscriptAligner.pair(
            expected: expected,
            heard: heard,
            threshold: threshold
        ) { written, said, preceding in
            quirks.allows(said, forWritten: written, after: preceding)
        }
        var faithful: Set<Int> = []
        for (index, match) in matches.enumerated() {
            let said = heard[match.heard].joined()
            let written = expected[match.expected].joined()
            let before =
                match.expected.lowerBound > 0 ? expected[match.expected.lowerBound - 1] : nil
            if SpokenLineTracker.isFaithful(said, to: written)
                || quirks.allows(said, forWritten: written, after: before)
            {
                faithful.insert(index)
            }
        }
        return Check(matches: matches, faithful: faithful)
    }
}
