public enum PieceProgressState: Equatable, Sendable {
    case untouched
    case tried
    case cleared
}

public enum PieceProgress {
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
