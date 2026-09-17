import Testing

@testable import ReadAloudKit

struct PieceProgressTests {
    @Test("progress keeps non-consecutive pieces in their positions")
    func nonConsecutivePieces() {
        let states = PieceProgress.states(
            total: 7,
            tried: [1, 3, 5],
            cleared: [1, 5]
        )

        #expect(
            states == [
                .untouched,
                .cleared,
                .untouched,
                .tried,
                .untouched,
                .cleared,
                .untouched
            ]
        )
    }
}
