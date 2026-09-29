import ReadAlign

/// The full form of each elided spelling a work prints, from the work's own data.
///
/// A recogniser writes out an elision in full: it hears `tattered` where the page has
/// `tatter’d`. Which spellings are elisions, and what they stand for, belongs to the
/// language and the edition, so the library holds no rule of its own and credits only
/// the full forms it is given. Spellings are compared as ReadAlign's `TranscriptAligner`
/// normalizes them.
public struct Elisions: Sendable, Equatable {
    private let fullForms: [String: String]

    /// No elided spelling is restored.
    public static let none = Self(fullForms: [:])

    /// Creates the table from printed elided spellings to the full forms they stand for.
    public init(fullForms: [String: String]) {
        self.fullForms = fullForms.reduce(into: [:]) { table, entry in
            table[TranscriptAligner.normalize(entry.key)] = TranscriptAligner.normalize(entry.value)
        }
    }

    /// The normalized full form the work gives for `written`, if it is a listed elision.
    public func fullForm(of written: String) -> String? {
        fullForms[TranscriptAligner.normalize(written)]
    }
}
