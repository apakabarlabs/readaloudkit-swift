import Foundation
import Testing

@testable import ReadAloudKit

struct RecognizerQuirksTests {
    private let table = Data(
        """
        {
            "parakeet": {
                "tatter'd": ["tattered"],
                "in": [{"heard": "and", "after": "each"}]
            },
            "spotless": {}
        }
        """.utf8
    )

    @Test("a model's patches are read from its own section")
    func patchesComeFromTheModelSection() throws {
        let quirks = try RecognizerQuirks.decode(table, model: "parakeet")
        #expect(quirks.allows("tattered", forWritten: "tatter'd"))
        #expect(!quirks.allows("tattered", forWritten: "battered"))
    }

    @Test("a patch tied to a phrase fires there and nowhere else")
    func companyNarrowsThePatch() throws {
        let quirks = try RecognizerQuirks.decode(table, model: "parakeet")
        #expect(quirks.allows("and", forWritten: "in", after: "each"))
        #expect(!quirks.allows("and", forWritten: "in", after: "delights"))
        #expect(!quirks.allows("and", forWritten: "in"))
    }

    @Test("a model with an empty section needs no patches")
    func emptySectionIsAModelThatNeedsNothing() throws {
        let quirks = try RecognizerQuirks.decode(table, model: "spotless")
        #expect(quirks.isEmpty)
        #expect(!quirks.allows("tattered", forWritten: "tatter'd"))
    }

    @Test("two spellings of one key are added together, not one over the other")
    func keysThatNormalizeAlikeAreMerged() {
        let quirks = RecognizerQuirks(allowances: [
            "Whate’er": ["whatever"],
            "whate’er": ["what’er"]
        ])
        #expect(quirks.allows("whatever", forWritten: "Whate’er"))
        #expect(quirks.allows("whater", forWritten: "whate’er"))
        #expect(!quirks.allows("whenever", forWritten: "whate’er"))
    }

    @Test("a model the table says nothing about is refused, not treated as spotless")
    func unknownModelIsRefused() {
        #expect(throws: RecognizerQuirks.UnknownModel.self) {
            try RecognizerQuirks.decode(table, model: "parakeet-v4")
        }
    }
}
