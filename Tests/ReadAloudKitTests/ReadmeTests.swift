import Foundation
import ReadAlign
import Testing

@testable import ReadAloudKit

private struct Work: Decodable {
    let interiorMarks: String
    let elisions: [String: [String]]

    private enum CodingKeys: String, CodingKey {
        case elisions
        case interiorMarks = "interior_marks"
    }

    static func sonnets() throws -> Self {
        let data = #"{"interior_marks": "'’-", "elisions": {"tatter’d": ["tattered"]}}"#
        return try JSONDecoder().decode(Self.self, from: Data(data.utf8))
    }
}

private struct Document: Sendable, CustomTestStringConvertible {
    let path: String
    let runBy: [String]
    let onlyAfter: Bool

    var testDescription: String { path }

    static let all = [
        Self(path: "README.md", runBy: ["saidEveryWord"], onlyAfter: false),
        Self(
            path: "Sources/ReadAloudKit/ReadAloudKit.docc/ReadAloudKit.md",
            runBy: ["completedReading"],
            onlyAfter: false
        ),
        Self(
            path: "CHANGELOG.md",
            runBy: [
                "changelogRestoresAStoredStage",
                "changelogNamesThePiece",
                "changelogKeepsTheTokenizer",
                "changelogTakesTheLanguageFromData",
                "changelogRestoresListedElisions",
                "changelogReadsThePublishedAlignment",
                "changelogReadsTheHearingTable"
            ],
            onlyAfter: true
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

    private func changelogRestoresAStoredStage(_ raw: Int) throws -> StageState {
        let stage = try StageState(stored: raw)
        return stage
    }

    private func changelogNamesThePiece(
        words: [NarrationAlignment.Word],
        recording: String
    ) -> NarrationAlignment {
        NarrationAlignment(piece: "18", duration: 4, words: words, recording: recording)
    }

    private func changelogKeepsTheTokenizer(
        lines: [String],
        tokenizer: WordTokenizer,
        transcript: String
    ) -> SpokenLineTracker.Progress {
        let tracker = SpokenLineTracker(
            lines: lines,
            quirks: .none,
            elisions: .none,
            tokenizer: tokenizer
        )
        let progress = tracker.progress(heard: transcript)
        return progress
    }

    private func changelogTakesTheLanguageFromData(
        lines: [String],
        passage: Passage,
        duration: TimeInterval,
        quirks: RecognizerQuirks
    ) throws -> (tracker: SpokenLineTracker, timings: [WordTiming]) {
        let work = try Work.sonnets()
        let tokenizer = WordTokenizer(interiorMarks: CharacterSet(charactersIn: work.interiorMarks))
        let tracker = SpokenLineTracker(
            lines: lines,
            quirks: quirks,
            elisions: Elisions(fullForms: work.elisions),
            tokenizer: tokenizer
        )
        let timings = NarrationTimeline.estimate(
            for: passage,
            duration: duration,
            tokenizer: tokenizer,
            weighting: EnglishSyllableWeighting()
        )
        return (tracker, timings)
    }

    private func changelogRestoresListedElisions() -> Bool {
        SpokenLineTracker.isFaithful(
            "tattered",
            to: "tatter’d",
            elisions: Elisions(fullForms: ["tatter’d": ["tattered"]])
        )
    }

    private func changelogReadsThePublishedAlignment(_ data: Data) throws -> NarrationAlignment {
        let alignment = try PublishedAlignment.decode(data).alignment
        return alignment
    }

    private func changelogReadsTheHearingTable(_ data: Data) throws -> RecognizerQuirks {
        let quirks = try RecognizerQuirks.decode(data, build: "parakeet-tdt-0.6b-v3-sherpa-int8")
        return quirks
    }

    @Test("the CHANGELOG's examples of 0.3.0 run and answer as they say")
    func changelogExamplesRun() throws {
        let lines = ["Will be a tatter’d weed", "of small worth held"]
        let words = [NarrationAlignment.Word(line: 0, text: "Will", start: 0, end: 0.2)]
        let transcript = "will be a tattered weed of small worth held"

        #expect(try changelogRestoresAStoredStage(2) == .complete)
        #expect(changelogNamesThePiece(words: words, recording: "r").piece == "18")
        #expect(
            changelogKeepsTheTokenizer(
                lines: ["Shall I compare thee"],
                tokenizer: Cases.sonnetsTokenizer,
                transcript: "shall I compare thee"
            ).isComplete
        )
        let taken = try changelogTakesTheLanguageFromData(
            lines: lines,
            passage: Passage(lines: lines),
            duration: 4,
            quirks: .none
        )
        #expect(taken.tracker.progress(heard: transcript).isComplete)
        #expect(taken.timings.count == 9)
        #expect(changelogRestoresListedElisions())
        let alignment = try Cases.served("served_alignment.json")
        #expect(try changelogReadsThePublishedAlignment(alignment).piece == "18")
        #expect(try !changelogReadsTheHearingTable(Cases.served("served_hearing.json")).isEmpty)
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
            language: "swift",
            onlyAfter: document.onlyAfter
        )
        let source = try String(contentsOf: here, encoding: .utf8)
        let bodies = try document.runBy.map { function in
            try #require(
                Self.body(of: function, in: source),
                "\(function) is not a function of this file"
            )
        }

        #expect(!examples.isEmpty)
        for paragraph in examples.flatMap(Self.paragraphs) {
            let shown = paragraph.joined(separator: "\n")
            #expect(
                bodies.contains { Self.contains($0, paragraph) },
                "\(document.path) shows code no function a test runs holds:\n\(shown)"
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

    private static func fencedBlocks(
        in markdown: String,
        language: String,
        onlyAfter: Bool
    ) -> [[String]] {
        var blocks: [[String]] = []
        var fenced: [String]?
        var fenceLanguage = ""
        var lastProse = ""
        for line in trimmedLines(of: markdown) {
            if var block = fenced {
                if line == "```" {
                    let wanted = fenceLanguage == language && (!onlyAfter || lastProse == "After:")
                    if wanted { blocks.append(block) }
                    fenced = nil
                } else {
                    block.append(line)
                    fenced = block
                }
            } else if line.hasPrefix("```") {
                fenceLanguage = String(line.dropFirst(3))
                fenced = []
            } else if !line.isEmpty {
                lastProse = line
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
