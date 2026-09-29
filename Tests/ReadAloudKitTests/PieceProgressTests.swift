import Testing

@testable import ReadAloudKit

struct ProgressCases: Decodable {
    let pieces: [PiecesCase]
    let stage: [StageCase]

    static let all = Cases.load("progress_tests.yaml", as: Self.self)
}

struct PiecesCase: NamedCase {
    let name: String
    let total: Int
    let tried: Set<Int>
    let cleared: Set<Int>
    let states: [String]
}

struct StageCase: NamedCase {
    let name: String
    let pieces: [String]
    let stage: String
}

struct PieceProgressTests {
    @Test(arguments: ProgressCases.all.pieces)
    func keepsPiecesInTheirPositions(_ example: PiecesCase) throws {
        let states = PieceProgress.states(
            total: example.total,
            tried: example.tried,
            cleared: example.cleared
        )

        #expect(states == (try example.states.map(PieceProgressState.named)))
    }
}
