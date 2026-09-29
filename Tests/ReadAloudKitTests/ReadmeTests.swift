import Foundation
import Testing

@testable import ReadAloudKit

private struct Work: Decodable {
    let interiorMarks: String
    let elisions: [String: String]

    private enum CodingKeys: String, CodingKey {
        case elisions
        case interiorMarks = "interior_marks"
    }

    static func sonnets() throws -> Self {
        let data = #"{"interior_marks": "'’-", "elisions": {"tatter’d": "tattered"}}"#
        return try JSONDecoder().decode(Self.self, from: Data(data.utf8))
    }
}

private struct Document: Sendable, CustomTestStringConvertible {
    let path: String
    let runBy: String

    var testDescription: String { path }

    static let all = [
        Self(path: "README.md", runBy: "saidEveryWord"),
        Self(
            path: "Sources/ReadAloudKit/ReadAloudKit.docc/ReadAloudKit.md",
            runBy: "completedReading"
        )
    ]
}

struct ReadmeTests {
    private func saidEveryWord(of lines: [String], in transcript: String) throws -> Bool {
        let work = try Work.sonnets()
        let quirks = RecognizerQuirks.none
        let tokenizer = WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))
        let elisions = Elisions(fullForms: work.elisions)
        let tracker = SpokenLineTracker(
            lines: lines,
            quirks: quirks,
            elisions: elisions,
            tokenizer: tokenizer
        )
        let saidEveryWord = tracker.progress(heard: transcript).isComplete
        return saidEveryWord
    }

    private func completedReading() throws -> Bool {
        let work = try Work.sonnets()
        let tokenizer = WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))
        let elisions = Elisions(fullForms: work.elisions)
        let tracker = SpokenLineTracker(
            lines: ["Will be a tatter’d weed", "of small worth held"],
            quirks: .none,
            elisions: elisions,
            tokenizer: tokenizer
        )
        let progress = tracker.progress(heard: "will be a tattered weed of small worth held")
        let completed = progress.isComplete
        return completed
    }

    @Test(
        "every Swift example in a document is code inside the function a test runs for it",
        arguments: Document.all
    )
    fileprivate func documentShowsOnlyCodeTheTestsRun(_ document: Document) throws {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shown = root.appendingPathComponent(document.path)
        let examples = Self.fencedBlocks(
            in: try String(contentsOf: shown, encoding: .utf8),
            language: "swift"
        )
        let source = try String(contentsOf: here, encoding: .utf8)
        let body = try #require(
            Self.body(of: document.runBy, in: source),
            "\(document.runBy) is not a function of this file"
        )

        #expect(!examples.isEmpty)
        for paragraph in examples.flatMap(Self.paragraphs) {
            let shown = paragraph.joined(separator: "\n")
            #expect(
                Self.contains(body, paragraph),
                "\(document.path) shows code \(document.runBy) does not run:\n\(shown)"
            )
        }
    }

    @Test("the README's completeness check tells a dropped word from a reading said whole")
    func readmeUsageCatchesADroppedWord() throws {
        let lines = ["Will be a tatter’d weed", "of small worth held"]

        #expect(try saidEveryWord(of: lines, in: "will be a tattered weed of small worth held"))
        #expect(try !saidEveryWord(of: lines, in: "will be a tattered weed of worth held"))
    }

    @Test("the DocC reading check completes a reading said whole")
    func docCUsageCompletes() throws {
        #expect(try completedReading())
    }

    private static func trimmedLines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func body(of function: String, in source: String) -> [String]? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let signature = "    private func \(function)("
        guard let start = lines.firstIndex(where: { $0.hasPrefix(signature) }),
            let open = lines[start...].firstIndex(where: { $0.hasSuffix("{") }),
            let close = lines[open...].firstIndex(of: "    }")
        else { return nil }
        return lines[(open + 1)..<close].map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func fencedBlocks(in markdown: String, language: String) -> [[String]] {
        var blocks: [[String]] = []
        var open: [String]?
        for line in trimmedLines(of: markdown) {
            if var block = open {
                if line == "```" {
                    blocks.append(block)
                    open = nil
                } else {
                    block.append(line)
                    open = block
                }
            } else if line == "```\(language)" {
                open = []
            }
        }
        return blocks
    }

    private static func paragraphs(_ block: [String]) -> [[String]] {
        block.split(separator: "", omittingEmptySubsequences: true).map(Array.init)
    }

    private static func contains(_ lines: [String], _ run: [String]) -> Bool {
        guard run.count <= lines.count else { return false }
        return (0...(lines.count - run.count)).contains { start in
            Array(lines[start..<(start + run.count)]) == run
        }
    }
}
