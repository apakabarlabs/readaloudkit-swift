import Foundation
import Testing
import Yams

@testable import ReadAloudKit

enum Cases {
    static let within = 0.000_000_001

    static func loadRefusingUnreadKeys<T: Codable>(_ name: String, as type: T.Type = T.self) -> T {
        do {
            guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
                fatalError("\(name) is not among the test resources")
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            let decoded = try YAMLDecoder().decode(T.self, from: text)
            let read = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
            let unread = unreadKeys(in: try Yams.load(yaml: text), readAs: read, at: name)
            guard unread.isEmpty else {
                fatalError("\(name) has keys no case reads: \(unread.joined(separator: ", "))")
            }
            return decoded
        } catch {
            fatalError("\(name) cannot be read: \(error)")
        }
    }

    private static func unreadKeys(
        in written: Any?,
        readAs read: Any?,
        at path: String
    ) -> [String] {
        if let written = written as? [AnyHashable: Any] {
            let read = read as? [String: Any] ?? [:]
            return written.flatMap { key, value in
                let name = "\(path).\(key)"
                guard let match = read["\(key)"] else { return [name] }
                return unreadKeys(in: value, readAs: match, at: name)
            }
        }
        if let written = written as? [Any], let read = read as? [Any] {
            return zip(written, read).enumerated().flatMap { index, pair in
                unreadKeys(in: pair.0, readAs: pair.1, at: "\(path)[\(index)]")
            }
        }
        return []
    }

    static func tokenizer(interiorMarks: String) -> WordTokenizer {
        WordTokenizer(interiorMarks: CharacterSet(charactersIn: interiorMarks))
    }

    static func quirks(_ allowances: [String: [AllowanceEntry]]?) -> RecognizerQuirks {
        allowances.map { RecognizerQuirks(allowances: $0.mapValues { $0.map(\.allowance) }) }
            ?? .none
    }

    static func close(_ actual: Double, _ expected: Double) -> Bool {
        abs(actual - expected) <= within
    }
}

protocol NamedCase: Codable, Sendable, CustomTestStringConvertible {
    var name: String { get }
}

extension NamedCase {
    var testDescription: String { name }
}

struct AllowanceEntry: Codable, Sendable {
    let heard: String
    let after: String?
    let writtenAsPair: Bool

    private enum CodingKeys: String, CodingKey {
        case heard, after
    }

    init(from decoder: Decoder) throws {
        if let spelling = try? decoder.singleValueContainer().decode(String.self) {
            heard = spelling
            after = nil
            writtenAsPair = false
            return
        }
        let pair = try decoder.container(keyedBy: CodingKeys.self)
        heard = try pair.decode(String.self, forKey: .heard)
        after = try pair.decodeIfPresent(String.self, forKey: .after)
        writtenAsPair = true
    }

    func encode(to encoder: Encoder) throws {
        guard writtenAsPair else {
            var single = encoder.singleValueContainer()
            try single.encode(heard)
            return
        }
        var pair = encoder.container(keyedBy: CodingKeys.self)
        try pair.encode(heard, forKey: .heard)
        try pair.encodeIfPresent(after, forKey: .after)
    }

    var allowance: RecognizerQuirks.Allowance {
        RecognizerQuirks.Allowance(heard: heard, after: after)
    }
}

extension WordReadingState {
    static func named(_ name: String) throws -> Self {
        let states: [String: Self] = [
            "ahead": .ahead,
            "close": .close,
            "expected": .expected,
            "missed": .missed,
            "said": .said
        ]
        return try #require(states[name], "\(name) is not a word reading state")
    }
}

extension PieceProgressState {
    static func named(_ name: String) throws -> Self {
        let states: [String: Self] = ["untouched": .untouched, "tried": .tried, "cleared": .cleared]
        return try #require(states[name], "\(name) is not a piece progress state")
    }
}

extension StageState {
    static func named(_ name: String) throws -> Self {
        let states: [String: Self] = [
            "untouched": .untouched,
            "started": .started,
            "complete": .complete
        ]
        return try #require(states[name], "\(name) is not a stage state")
    }
}
