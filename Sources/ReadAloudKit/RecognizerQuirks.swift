import Foundation
import ReadAlign

private enum AllowanceCodingKeys: String, CodingKey {
    case after
    case heard
}

private struct PublishedQuirks: Decodable {
    let build: String
    let version: String
    let words: [String: [RecognizerQuirks.Allowance]]

    private enum CodingKeys: String, CodingKey {
        case build, version, words
    }

    init(from decoder: Decoder) throws {
        try decoder.refuseKeys(otherThan: CodingKeys.self, of: "a published hearing table")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        build = try container.decode(String.self, forKey: .build)
        version = try container.decode(String.self, forKey: .version)
        words = try container.decode([String: [RecognizerQuirks.Allowance]].self, forKey: .words)
    }
}

/// Explicit spellings that one recognizer may return for particular written words.
///
/// Quirks repair a named build's repeatable transcription behavior; they are not
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

        /// Decodes `{"heard": ..., "after": ...}`, refusing any other field or shape.
        public init(from decoder: Decoder) throws {
            try decoder.refuseKeys(otherThan: AllowanceCodingKeys.self, of: "an allowance")
            let keyed = try decoder.container(keyedBy: AllowanceCodingKeys.self)
            self.init(
                heard: try keyed.decode(String.self, forKey: .heard),
                after: try keyed.decodeIfPresent(String.self, forKey: .after)
            )
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

    /// A published hearing table belongs to another recognizer build.
    public struct WrongBuild: Error, Equatable, CustomStringConvertible {
        /// The build the caller asked for.
        public let requested: String
        /// The build the table was published for.
        public let published: String
        public var description: String {
            "the hearing table was published for \(published), not \(requested)"
        }
    }

    /// Decodes the hearing table the server publishes for one recognizer build.
    ///
    /// The document is `{"build": ..., "version": ..., "words": {written: [allowance]}}`,
    /// each allowance `{"heard": ..., "after": ...}` with `after` optional. Any other
    /// field, shape or type is refused, and so is a table published for another build.
    ///
    /// - Throws: `DecodingError` for another shape, or ``WrongBuild``.
    public static func decode(_ data: Data, build: String) throws -> Self {
        let published = try JSONDecoder().decode(PublishedQuirks.self, from: data)
        guard published.build == build else {
            throw WrongBuild(requested: build, published: published.build)
        }
        return Self(allowances: published.words)
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
