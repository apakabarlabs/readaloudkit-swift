public enum StageState: Int, Equatable, Sendable {
    case untouched = 0
    case started = 1
    case complete = 2

    public init(stored raw: Int) {
        guard let state = Self(rawValue: raw) else {
            fatalError("A staged reading holds stage state \(raw), which this build cannot read.")
        }
        self = state
    }

    public static func read(_ states: [PieceProgressState]) -> Self {
        guard !states.isEmpty else { return .untouched }
        if states.allSatisfy({ $0 == .cleared }) { return .complete }
        return states.contains { $0 != .untouched } ? .started : .untouched
    }
}
