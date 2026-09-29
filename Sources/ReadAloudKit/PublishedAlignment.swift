import Foundation

/// A narration alignment as the server publishes it: the alignment and the version
/// it was published under.
public struct PublishedAlignment: Decodable, Sendable, Equatable {
    /// The version the server published the alignment under.
    public let version: String
    /// The published word timings.
    public let alignment: NarrationAlignment

    /// Creates a published alignment from its parts.
    public init(version: String, alignment: NarrationAlignment) {
        self.version = version
        self.alignment = alignment
    }

    private enum CodingKeys: String, CodingKey {
        case version, alignment
    }

    /// Decodes the published document, refusing a field it does not have.
    ///
    /// - Throws: `DecodingError` for another shape, or ``NarrationAlignment/TimingError``.
    public init(from decoder: Decoder) throws {
        try decoder.refuseKeys(otherThan: CodingKeys.self, of: "a published alignment")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try container.decode(String.self, forKey: .version),
            alignment: try container.decode(NarrationAlignment.self, forKey: .alignment)
        )
    }

    /// Decodes `{"version": ..., "alignment": {...}}`, the document the server serves.
    ///
    /// - Throws: `DecodingError` for JSON of another shape, or
    ///   ``NarrationAlignment/TimingError``.
    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
