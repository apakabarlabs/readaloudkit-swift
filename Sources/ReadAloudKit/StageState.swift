/// A stored stage state this build does not know, perhaps written by a newer one.
///
/// Every port refuses such a value with this error; what to show instead is the
/// caller's decision.
public struct UnknownStageState: Error, Equatable, CustomStringConvertible {
    /// The stored value that was read.
    public let raw: Int

    public var description: String {
        "a staged reading holds stage state \(raw), which this build cannot read"
    }
}

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
    /// - Throws: ``UnknownStageState`` when `raw` is not `0`, `1` or `2`.
    public init(stored raw: Int) throws {
        guard let state = Self(rawValue: raw) else { throw UnknownStageState(raw: raw) }
        self = state
    }

    /// Derives the stage state from the states of all its pieces.
    public static func read(_ states: [PieceProgressState]) -> Self {
        guard !states.isEmpty else { return .untouched }
        if states.allSatisfy({ $0 == .cleared }) { return .complete }
        return states.contains { $0 != .untouched } ? .started : .untouched
    }
}
