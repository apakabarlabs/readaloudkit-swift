/// Where one stage of a staged reading stands.
public enum StageState: Int, Equatable, Sendable {
    /// No piece in the stage has been attempted.
    case untouched = 0
    /// At least one piece was attempted and the stage is not complete.
    case started = 1
    /// Every piece in the stage was cleared.
    case complete = 2

    /// Restores a persisted state.
    ///
    /// - Precondition: `raw` is `0`, `1`, or `2`. Any other stored value terminates the
    ///   process because this build cannot interpret the persisted state.
    public init(stored raw: Int) {
        guard let state = Self(rawValue: raw) else {
            fatalError("A staged reading holds stage state \(raw), which this build cannot read.")
        }
        self = state
    }

    /// Derives the stage state from the states of all its pieces.
    public static func read(_ states: [PieceProgressState]) -> Self {
        guard !states.isEmpty else { return .untouched }
        if states.allSatisfy({ $0 == .cleared }) { return .complete }
        return states.contains { $0 != .untouched } ? .started : .untouched
    }
}
