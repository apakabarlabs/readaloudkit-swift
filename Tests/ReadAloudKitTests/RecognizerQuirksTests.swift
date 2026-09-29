import Foundation
import Testing

@testable import ReadAloudKit

struct QuirksCases: Decodable {
    let tests: [QuirksCase]

    static let all = Cases.load("quirks_tests.yaml", as: Self.self).tests
}

struct QuirkQuery: Decodable, Sendable {
    let heard: String
    let written: String
    let after: String?
    let allowed: Bool
}

struct QuirksCase: NamedCase {
    let name: String
    let table: String?
    let model: String?
    let allowances: [String: [RecognizerQuirks.Allowance]]?
    let refused: Bool?
    let empty: Bool?
    let queries: [QuirkQuery]?

    func quirks() throws -> RecognizerQuirks {
        guard let table else { return Cases.quirks(allowances) }
        let model = try #require(model, "\(name): a table is read for a model")
        return try RecognizerQuirks.decode(Data(table.utf8), model: model)
    }
}

struct RecognizerQuirksTests {
    @Test(arguments: QuirksCases.all)
    func allowsWhatTheTableSays(_ example: QuirksCase) throws {
        if example.refused == true {
            #expect(throws: RecognizerQuirks.UnknownModel.self) { try example.quirks() }
            return
        }
        let quirks = try example.quirks()
        if let empty = example.empty {
            #expect(quirks.isEmpty == empty)
        }
        for query in example.queries ?? [] {
            let allowed = quirks.allows(query.heard, forWritten: query.written, after: query.after)
            #expect(allowed == query.allowed, "\(query.heard) for \(query.written)")
        }
    }
}
