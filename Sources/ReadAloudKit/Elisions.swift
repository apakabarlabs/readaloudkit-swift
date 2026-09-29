import ReadAlign

/// The full forms of each elided spelling a work prints, from the work's own data.
///
/// A recogniser writes out an elision in full: it hears `tattered` where the page has
/// `tatter’d`. Which spellings are elisions, and what they stand for, belongs to the
/// language and the edition, so the library holds no rule of its own and credits only
/// the full forms it is given. One spelling may stand for several full forms, any of
/// which counts as said. Spellings are compared as ReadAlign's `TranscriptAligner`
/// normalizes them, and spellings that normalize alike are merged into one.
public struct Elisions: Sendable, Equatable {
    private let fullForms: [String: Set<String>]

    /// No elided spelling is restored.
    public static let none = Self(fullForms: [:])

    /// Creates the table from printed elided spellings to the full forms they stand for.
    public init(fullForms: [String: [String]]) {
        self.fullForms = fullForms.reduce(into: [:]) { table, entry in
            table[TranscriptAligner.normalize(entry.key), default: []]
                .formUnion(entry.value.map(TranscriptAligner.normalize))
        }
    }

    /// The normalized full forms the work gives for `written`; empty if it lists none.
    public func fullForms(of written: String) -> Set<String> {
        fullForms[TranscriptAligner.normalize(written)] ?? []
    }
}
