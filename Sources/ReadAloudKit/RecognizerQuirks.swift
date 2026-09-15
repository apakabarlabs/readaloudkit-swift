import Foundation
import ReadAlign

public struct RecognizerQuirks: Sendable {
    public struct Allowance: Sendable, Hashable {
        public let heard: String
        public let after: String?

        public init(heard: String, after: String? = nil) {
            self.heard = TranscriptAligner.normalize(heard)
            self.after = after.map(TranscriptAligner.normalize)
        }
    }

    private let variants: [String: Set<Allowance>]

    public static let none = RecognizerQuirks(allowances: [String: [Allowance]]())

    public init(allowances: [String: [Allowance]]) {
        variants = allowances.reduce(into: [:]) { table, entry in
            table[TranscriptAligner.normalize(entry.key), default: []].formUnion(entry.value)
        }
    }

    public init(allowances: [String: [String]]) {
        self.init(allowances: allowances.mapValues { $0.map { Allowance(heard: $0) } })
    }

    public var isEmpty: Bool { variants.isEmpty }

    public struct UnknownModel: Error, CustomStringConvertible {
        public let model: String
        public let known: [String]
        public var description: String {
            "no patches listed for \(model); the table has \(known.sorted().joined(separator: ", "))"
        }
    }

    public static func decode(_ data: Data, model: String) throws -> RecognizerQuirks {
        let table = try JSONDecoder().decode([String: [String: [Allowance]]].self, from: data)
        guard let allowances = table[model] else {
            throw UnknownModel(model: model, known: Array(table.keys))
        }
        return RecognizerQuirks(allowances: allowances)
    }

    public func allows(_ heard: String, forWritten written: String, after preceding: String? = nil) -> Bool {
        guard !variants.isEmpty, let allowed = variants[TranscriptAligner.normalize(written)] else { return false }
        let said = TranscriptAligner.normalize(heard)
        let company = preceding.map(TranscriptAligner.normalize)
        return allowed.contains { $0.heard == said && ($0.after == nil || $0.after == company) }
    }
}

extension RecognizerQuirks.Allowance: Decodable {
    public init(from decoder: Decoder) throws {
        let heard: String
        let after: String?
        do {
            heard = try decoder.singleValueContainer().decode(String.self)
            after = nil
        } catch DecodingError.typeMismatch {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            heard = try keyed.decode(String.self, forKey: .heard)
            after = try keyed.decodeIfPresent(String.self, forKey: .after)
        }
        self.init(heard: heard, after: after)
    }

    private enum CodingKeys: String, CodingKey {
        case heard
        case after
    }
}
