public enum StageState: Int, Equatable, Sendable {
    case untouched = 0
    case started = 1
    case complete = 2

    public init(stored raw: Int) {
        guard let state = StageState(rawValue: raw) else {
            fatalError("A staged reading holds stage state \(raw), which this build cannot read.")
        }
        self = state
    }

    public static func read(_ states: [PieceProgressState]) -> StageState {
        guard !states.isEmpty else { return .untouched }
        if states.allSatisfy({ $0 == .cleared }) { return .complete }
        return states.contains(where: { $0 != .untouched }) ? .started : .untouched
    }
}
