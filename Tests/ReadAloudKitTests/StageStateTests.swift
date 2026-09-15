import Testing
@testable import ReadAloudKit

struct StageStateTests {
    @Test func aStageOfNoPiecesIsUntouchedRatherThanComplete() {
        #expect(StageState.read([]) == .untouched)
    }

    @Test func everyPieceClearedMakesTheStageComplete() {
        #expect(StageState.read(Array(repeating: .cleared, count: 3)) == .complete)
    }

    @Test func oneTriedPieceMakesTheStageStarted() {
        #expect(StageState.read([.tried, .untouched]) == .started)
    }

    @Test func untouchedPiecesLeaveTheStageUntouched() {
        #expect(StageState.read(Array(repeating: .untouched, count: 3)) == .untouched)
    }
}
