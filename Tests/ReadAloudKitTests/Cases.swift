import Foundation
import SwiftEmbed
import Testing

@testable import ReadAloudKit

enum Cases {
    static func load<T: Decodable>(_ path: String, as type: T.Type = T.self) -> T {
        Embedded.getYAML(Bundle.module, path: path, as: type)
    }

    static func tokenizer(interiorMarks: String?) -> WordTokenizer {
        interiorMarks.map { WordTokenizer(interiorMarks: CharacterSet(charactersIn: $0)) }
            ?? .latinScript
    }

    static func quirks(_ allowances: [String: [RecognizerQuirks.Allowance]]?) -> RecognizerQuirks {
        allowances.map { RecognizerQuirks(allowances: $0) } ?? .none
    }

    static func index(_ key: String, in name: String) throws -> Int {
        try #require(Int(key), "\(name): \(key) is not a word index")
    }
}

protocol NamedCase: Decodable, Sendable, CustomTestStringConvertible {
    var name: String { get }
}

extension NamedCase {
    var testDescription: String { name }
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
