import Testing

@testable import ReadAloudKit

struct StageStateTests {
    @Test(arguments: try ProgressCases.all.stage)
    func readsTheStageFromItsPieces(_ example: StageCase) throws {
        let pieces = try example.pieces.map(PieceProgressState.named)

        #expect(StageState.read(pieces) == (try StageState.named(example.stage)))
    }
}
