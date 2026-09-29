import Foundation
import Testing

@testable import ReadAloudKit

struct ReadmeTests {
    private static let usage = """
        let tracker = SpokenLineTracker(lines: printedLines, quirks: quirks, tokenizer: .latinScript)
        let saidEveryWord = tracker.progress(heard: transcript).isComplete
        """

    private func saidEveryWord(of printedLines: [String], in transcript: String) -> Bool {
        let quirks = RecognizerQuirks.none
        let tracker = SpokenLineTracker(
            lines: printedLines,
            quirks: quirks,
            tokenizer: .latinScript
        )
        let saidEveryWord = tracker.progress(heard: transcript).isComplete
        return saidEveryWord
    }

    @Test("the README shows the completeness check these tests run")
    func readmeShowsTheCheckedUsage() throws {
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)

        #expect(text.contains("```swift\n\(Self.usage)\n```"))
    }

    @Test("the README's completeness check tells a dropped word from a reading said whole")
    func readmeUsageCatchesADroppedWord() {
        let lines = ["From fairest creatures", "we desire increase"]

        #expect(saidEveryWord(of: lines, in: "From fairest creatures we desire increase"))
        #expect(!saidEveryWord(of: lines, in: "From fairest creatures desire increase"))
    }
}
