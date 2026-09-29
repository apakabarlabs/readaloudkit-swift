import Testing

struct CasesTests {
    @Test("a key no runner reads fails the case file")
    func refusesAKeyNoRunnerReads() {
        let misspelt = #"""
            {name: "a typo", line: "rose", interior_mark: "-", interior_marks: "-", words: ["rose"]}
            """#

        #expect(throws: Cases.UnreadKeys.self) {
            try Cases.decodeRefusingUnreadKeys(misspelt, at: "case", as: WordsCase.self)
        }
    }

    @Test("a key no runner reads fails the case file inside an allowance too")
    func refusesAKeyInsideAnAllowance() {
        let misspelt = #"""
            {name: "a typo", lines: ["in sense"], interior_marks: "-", line_lengths: [2],
             quirks: {"in sense": [{heard: "incense", before: "bring"}]}}
            """#

        #expect(throws: Cases.UnreadKeys.self) {
            try Cases.decodeRefusingUnreadKeys(misspelt, at: "case", as: TrackerCase.self)
        }
    }
}
