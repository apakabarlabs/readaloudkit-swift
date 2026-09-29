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

    /// Decodes `{"version": ..., "alignment": {...}}`, the document the server serves.
    ///
    /// A missing field or a value of another type is refused. A field the document does
    /// not know is read past, at any depth, so that a field the server adds later does
    /// not stop a build already installed. A key repeated within one object keeps one of
    /// its values; which one is not promised and may differ between ports.
    ///
    /// - Throws: `DecodingError` for JSON of another shape, or
    ///   ``NarrationAlignment/TimingError``.
    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
