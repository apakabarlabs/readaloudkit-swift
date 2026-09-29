import Foundation
import Testing

@testable import ReadAloudKit

struct QuirksCases: Codable {
    let tests: [QuirksCase]

    static let all = Cases.loadRefusingUnreadKeys("quirks_tests.yaml", as: Self.self).tests
}

struct QuirkQuery: Codable, Sendable {
    let heard: String
    let written: String
    let after: String?
    let allowed: Bool
}

struct UnknownModelCase: Codable, Sendable {
    let model: String
    let known: [String]
}

struct QuirksCase: NamedCase {
    let name: String
    let table: String?
    let model: String?
    let allowances: [String: [AllowanceEntry]]?
    let unknownModel: UnknownModelCase?
    let malformed: Bool?
    let empty: Bool?
    let queries: [QuirkQuery]?

    private enum CodingKeys: String, CodingKey {
        case name, table, model, allowances, malformed, empty, queries
        case unknownModel = "unknown_model"
    }

    func quirks() throws -> RecognizerQuirks {
        guard let table else { return Cases.quirks(allowances) }
        let model = try #require(model, "\(name): a table is read for a model")
        return try RecognizerQuirks.decode(Data(table.utf8), model: model)
    }
}

struct RecognizerQuirksTests {
    @Test(arguments: QuirksCases.all)
    func allowsWhatTheTableSays(_ example: QuirksCase) throws {
        if let expected = example.unknownModel {
            let error = try #require(throws: RecognizerQuirks.UnknownModel.self) {
                try example.quirks()
            }
            #expect(error.model == expected.model)
            #expect(error.known.sorted() == expected.known)
            return
        }
        if example.malformed == true {
            #expect(throws: DecodingError.self) { try example.quirks() }
            return
        }
        let quirks = try example.quirks()
        #expect(quirks.isEmpty == (try #require(example.empty, "a readable case pins emptiness")))
        for query in example.queries ?? [] {
            let allowed = quirks.allows(query.heard, forWritten: query.written, after: query.after)
            #expect(allowed == query.allowed, "\(query.heard) for \(query.written)")
        }
    }
}
