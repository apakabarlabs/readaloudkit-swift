import Testing

@testable import ReadAloudKit

struct StageStateTests {
    @Test(arguments: try ProgressCases.all.stage)
    func readsTheStageFromItsPieces(_ example: StageCase) throws {
        let pieces = try example.pieces.map(PieceProgressState.named)

        #expect(StageState.read(pieces) == (try StageState.named(example.stage)))
    }

    @Test(arguments: try ProgressCases.all.stored)
    func restoresAStoredStage(_ example: StoredCase) throws {
        if example.unknown == true {
            #expect(throws: UnknownStageState(raw: example.raw)) {
                try StageState(stored: example.raw)
            }
            return
        }
        let stage = try #require(example.stage, "a readable case pins the stage")
        #expect(try StageState(stored: example.raw) == StageState.named(stage))
    }
}
