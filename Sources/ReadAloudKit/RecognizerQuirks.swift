import Foundation
import ReadAlign

private enum AllowanceCodingKeys: String, CodingKey {
    case after
    case heard
}

/// Explicit spellings that one recognizer may return for particular written words.
///
/// Quirks repair a named model's repeatable transcription behavior; they are not
/// general rules of pronunciation or language.
public struct RecognizerQuirks: Sendable {
    /// One permitted heard spelling, optionally limited by the preceding written word.
    public struct Allowance: Decodable, Sendable, Hashable {
        /// Spelling returned by the recognizer.
        public let heard: String
        /// Optional preceding written word required for this allowance.
        public let after: String?

        /// Creates and normalizes one allowance.
        public init(heard: String, after: String? = nil) {
            self.heard = TranscriptAligner.normalize(heard)
            self.after = after.map(TranscriptAligner.normalize)
        }

        public init(from decoder: Decoder) throws {
            let decodedHeard: String
            let decodedAfter: String?
            do {
                decodedHeard = try decoder.singleValueContainer().decode(String.self)
                decodedAfter = nil
            } catch DecodingError.typeMismatch {
                try decoder.refuseKeys(otherThan: AllowanceCodingKeys.self, of: "an allowance")
                let keyed = try decoder.container(keyedBy: AllowanceCodingKeys.self)
                decodedHeard = try keyed.decode(String.self, forKey: .heard)
                decodedAfter = try keyed.decodeIfPresent(String.self, forKey: .after)
            }
            self.init(heard: decodedHeard, after: decodedAfter)
        }
    }

    private let variants: [String: Set<Allowance>]

    /// A quirk set that permits no substitutions.
    public static let none = Self(allowances: [String: [Allowance]]())

    /// Creates quirks keyed by written spelling; keys and allowances are normalized.
    public init(allowances: [String: [Allowance]]) {
        variants = allowances.reduce(into: [:]) { table, entry in
            table[TranscriptAligner.normalize(entry.key), default: []].formUnion(entry.value)
        }
    }

    /// Creates context-free quirks keyed by written spelling.
    public init(allowances: [String: [String]]) {
        self.init(allowances: allowances.mapValues { $0.map { Allowance(heard: $0) } })
    }

    /// Whether this set permits no recognizer substitutions.
    public var isEmpty: Bool { variants.isEmpty }

    /// The requested model has no entry in a decoded quirk table.
    public struct UnknownModel: Error, CustomStringConvertible {
        /// Requested model identifier.
        public let model: String
        /// Model identifiers present in the table.
        public let known: [String]
        public var description: String {
            "no patches listed for \(model); the table has \(known.sorted().joined(separator: ", "))"
        }
    }

    /// Decodes the allowances for `model`, refusing a table that does not name it.
    ///
    /// The JSON root maps model identifiers to written words. Each written word maps
    /// to an array containing either a heard string or `{ "heard": ..., "after": ... }`.
    /// A pair with any other field is refused, as is a value of another type.
    public static func decode(_ data: Data, model: String) throws -> Self {
        let table = try JSONDecoder().decode([String: [String: [Allowance]]].self, from: data)
        guard let allowances = table[model] else {
            throw UnknownModel(model: model, known: Array(table.keys))
        }
        return Self(allowances: allowances)
    }

    /// Reports whether `heard` is an explicit allowance for `written` in this context.
    public func allows(
        _ heard: String,
        forWritten written: String,
        after preceding: String? = nil
    )
        -> Bool
    {
        guard !variants.isEmpty, let allowed = variants[TranscriptAligner.normalize(written)] else {
            return false
        }
        let said = TranscriptAligner.normalize(heard)
        let company = preceding.map(TranscriptAligner.normalize)
        return allowed.contains { $0.heard == said && ($0.after == nil || $0.after == company) }
    }
}
