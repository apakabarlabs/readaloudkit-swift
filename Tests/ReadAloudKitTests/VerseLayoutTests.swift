import Testing

@testable import ReadAloudKit

struct LayoutCases: Codable {
    let `break`: [BreakCase]
    let run: [RunCase]

    static var all: Self {
        get throws { try Cases.loadRefusingUnreadKeys("layout_tests.yaml") }
    }
}

struct BreakCase: NamedCase {
    let name: String
    let words: [Double]
    let space: Double
    let width: Double
    let indent: Double
    let starts: [Int]
}

struct RunCase: NamedCase {
    let name: String
    let words: [Double]
    let from: Int
    let end: Int
    let space: Double
    let width: Double

    private enum CodingKeys: String, CodingKey {
        case name, words, from, space, width
        case end = "to"
    }
}

struct VerseLayoutTests {
    private let space = 1.0
    private let indent = 8.0

    private func breakLine(_ words: [Double], width: Double) -> [Int] {
        VerseLayoutPlanner.breakLine(words: words, spaceWidth: space, width: width, indent: indent)
            .starts
    }

    @Test(arguments: try LayoutCases.all.break)
    func breaksWhereTheCaseSays(_ example: BreakCase) {
        let starts = VerseLayoutPlanner.breakLine(
            words: example.words,
            spaceWidth: example.space,
            width: example.width,
            indent: example.indent
        ).starts

        #expect(starts == example.starts)
    }

    @Test(arguments: try LayoutCases.all.run)
    func measuresRunsWithSpaces(_ example: RunCase) {
        let width = VerseLayoutPlanner.run(
            example.words,
            from: example.from,
            to: example.end,
            spaceWidth: example.space
        )

        #expect(width == example.width)
    }

    @Test("a line that does not fit is broken once")
    func breaksLongLine() {
        let starts = breakLine([20, 20, 20, 20], width: 50)

        #expect(starts.count == 2)
        #expect(starts[0] == 0)
    }

    @Test("a break that leaves one word alone is refused when another fits")
    func avoidsLonelyWord() {
        let words = [30.0, 30, 30, 6]
        let starts = breakLine(words, width: 70)

        #expect(starts.count == 2)
        #expect(starts[1] < words.count - 1)
    }

    @Test("the two parts come out balanced rather than lopsided")
    func balancesTheParts() {
        let words = Array(repeating: 10.0, count: 8)
        let starts = breakLine(words, width: 60)
        let split = starts[1]
        let head = VerseLayoutPlanner.run(words, from: 0, to: split, spaceWidth: space)
        let tail = VerseLayoutPlanner.run(words, from: split, to: words.count, spaceWidth: space)

        #expect(abs(head - (tail + indent)) < 20)
    }

    @Test("a turnover too short to read as a continuation is avoided")
    func avoidsScrapTurnover() {
        let words = [15.0, 15, 15, 15, 6, 6]
        let starts = breakLine(words, width: 70)
        let split = starts[1]
        let tail = VerseLayoutPlanner.run(words, from: split, to: words.count, spaceWidth: space)

        #expect(tail >= (70 - indent) * VerseLayoutPlanner.minimumTurnoverFraction)
    }

    @Test("a line too long for two rows keeps wrapping with the same indent")
    func wrapsMoreThanOnce() {
        let starts = breakLine(Array(repeating: 20.0, count: 9), width: 45)

        #expect(starts.count >= 3)
        #expect(starts == starts.sorted())
    }

    @Test("the poem picks one column width for all its lines")
    func choosesOneColumn() {
        let plan = VerseLayoutPlanner.plan(
            lines: [
                [10, 10, 10],
                [20, 20, 20, 20],
                [10, 10]
            ],
            spaceWidth: space,
            candidateWidths: [100, 92, 84],
            indent: indent
        )

        #expect(plan.rowStarts.count == 3)
        #expect(plan.rowStarts[0] == [0])
        #expect(plan.rowStarts[2] == [0])
        #expect([100, 92, 84].contains(plan.columnWidth))
    }

    @Test("a slightly narrower column is taken when it saves a stranded word")
    func narrowsToSaveALine() {
        let lines = [[30.0, 30, 30, 5]]
        let plan = VerseLayoutPlanner.plan(
            lines: lines,
            spaceWidth: space,
            candidateWidths: [66, 60],
            indent: indent
        )
        let split = plan.rowStarts[0][1]

        #expect(split < 3)
    }

    @Test("no candidate widths lay every line out as one row at width zero")
    func plansWithoutCandidates() {
        let plan = VerseLayoutPlanner.plan(
            lines: [[10, 10], [20]],
            spaceWidth: space,
            candidateWidths: [],
            indent: indent
        )

        #expect(plan == VerseLayoutPlan(columnWidth: 0, rowStarts: [[0], [0]]))
    }
}
