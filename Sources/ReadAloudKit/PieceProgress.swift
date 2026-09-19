/// What a reader has done with one piece of a staged reading.
public enum PieceProgressState: Equatable, Sendable {
    /// The piece has not been attempted.
    case untouched
    /// The piece was attempted but not cleared.
    case tried
    /// Every required word in the piece was cleared.
    case cleared
}

/// Derives ordered piece states from the pieces attempted and cleared.
public enum PieceProgress {
    /// Returns one state for each piece index in `0..<total`.
    public static func states(
        total: Int,
        tried: Set<Int>,
        cleared: Set<Int>
    ) -> [PieceProgressState] {
        (0..<total).map { piece in
            if cleared.contains(piece) { return .cleared }
            if tried.contains(piece) { return .tried }
            return .untouched
        }
    }
}
