import Foundation
import Testing

@testable import ReadAloudKit

struct QuirksCases: Codable {
    let tests: [QuirksCase]

    static var all: [QuirksCase] {
        get throws { try Cases.loadRefusingUnreadKeys("quirks_tests.yaml", as: Self.self).tests }
    }
}

struct QuirkQuery: Codable, Sendable {
    let heard: String
    let written: String
    let after: String?
    let allowed: Bool
}

struct WrongBuildCase: Codable, Sendable {
    let requested: String
    let published: String
}

struct QuirksCase: NamedCase {
    let name: String
    let served: String?
    let table: String?
    let encoding: String?
    let build: String?
    let allowances: [String: [AllowanceEntry]]?
    let wrongBuild: WrongBuildCase?
    let malformed: Bool?
    let notUTF8: Bool?
    let empty: Bool?
    let queries: [QuirkQuery]?

    private enum CodingKeys: String, CodingKey {
        case name, served, table, encoding, build, allowances, malformed, empty, queries
        case wrongBuild = "wrong_build"
        case notUTF8 = "not_utf8"
    }

    func quirks() throws -> RecognizerQuirks {
        let data: Data
        if let served {
            data = try Cases.served(served)
        } else if let table {
            data = try Cases.bytes(of: table, in: encoding)
        } else {
            return Cases.quirks(allowances)
        }
        let build = try #require(build, "\(name): a table is read for a build")
        return try RecognizerQuirks.decode(data, build: build)
    }
}

struct RecognizerQuirksTests {
    @Test(arguments: try QuirksCases.all)
    func allowsWhatTheTableSays(_ example: QuirksCase) throws {
        if let expected = example.wrongBuild {
            let refusal = RecognizerQuirks.WrongBuild(
                requested: expected.requested,
                published: expected.published
            )
            #expect(throws: refusal) { try example.quirks() }
            return
        }
        if example.malformed == true {
            #expect(throws: DecodingError.self) { try example.quirks() }
            return
        }
        if example.notUTF8 == true {
            #expect(throws: NotUTF8()) { try example.quirks() }
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
