import Foundation
import ReadAlign

public enum SpokenWords {
    public struct Check: Sendable {
        public let matches: [WordMatch]
        public let faithful: Set<Int>

        public init(matches: [WordMatch], faithful: Set<Int>) {
            self.matches = matches
            self.faithful = faithful
        }

        public var pairs: [Int: Int] {
            faithful.reduce(into: [Int: Int]()) { result, index in
                let match = matches[index]
                for word in match.expected { result[word] = match.heard.lowerBound }
            }
        }
    }

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
