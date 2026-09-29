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

    static let sonnets = #"{"interior_marks": "'’-", "elisions": {"tatter’d": "tattered"}}"#
}

struct ReadmeTests {
    private func saidEveryWord(of lines: [String], in transcript: String) throws -> Bool {
        let work = try JSONDecoder().decode(Work.self, from: Data(Work.sonnets.utf8))
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

    @Test("every Swift example in the README is code these tests run")
    func readmeShowsOnlyCodeTheTestsRun() throws {
        let here = URL(fileURLWithPath: #filePath)
        let readme = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let examples = Self.fencedBlocks(
            in: try String(contentsOf: readme, encoding: .utf8),
            language: "swift"
        )
        let run = Self.trimmedLines(of: try String(contentsOf: here, encoding: .utf8))

        #expect(!examples.isEmpty)
        for paragraph in examples.flatMap(Self.paragraphs) {
            #expect(
                Self.contains(run, paragraph),
                "the README shows code no test runs:\n\(paragraph.joined(separator: "\n"))"
            )
        }
    }

    @Test("the README's completeness check tells a dropped word from a reading said whole")
    func readmeUsageCatchesADroppedWord() throws {
        let lines = ["Will be a tatter’d weed", "of small worth held"]

        #expect(try saidEveryWord(of: lines, in: "will be a tattered weed of small worth held"))
        #expect(try !saidEveryWord(of: lines, in: "will be a tattered weed of worth held"))
    }

    private static func trimmedLines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
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
