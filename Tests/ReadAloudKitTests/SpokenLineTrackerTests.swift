import Testing

@testable import ReadAloudKit

struct SpokenLineTrackerTests {
    private let tracker = SpokenLineTracker(line: "From fairest creatures we desire increase,")

    @Test("a line said whole is complete")
    func acceptsWholeLine() {
        let progress = tracker.progress(heard: "from fairest creatures we desire increase")

        #expect(progress.checks.allSatisfy { $0 == .correct })
        #expect(progress.isComplete)
    }

    @Test("a line half said is a line not said")
    func refusesAPrefix() {
        let progress = tracker.progress(heard: "from fairest creatures")

        #expect(progress.checks.prefix(3) == [.correct, .correct, .correct])
        #expect(!progress.isComplete)
        #expect(progress.wordStates.suffix(3).allSatisfy { $0 == .missed })
    }

    @Test("nothing heard yet is no progress and no words to fix")
    func handlesSilence() {
        let progress = tracker.progress(heard: "")

        #expect(progress.checks == [.wrong, .wrong, .wrong, .wrong, .wrong, .wrong])
        #expect(!progress.isComplete)
    }

    @Test("a reading nobody could make out is told from a reading that went wrong")
    func tellsAWholeMissFromAMiss() {
        #expect(tracker.progress(heard: "").isAllWrong)
        #expect(tracker.progress(heard: "the quick brown fox jumped over").isAllWrong)
        #expect(!tracker.progress(heard: "from the quick brown fox jumped").isAllWrong)
        #expect(!tracker.progress(heard: "from fairest creatures we desire increase").isAllWrong)
    }

    @Test("a short word one letter apart is still put opposite the word it answers")
    func pairsAShortWordAcrossOneLetter() {
        let line = SpokenLineTracker(line: "Th’ expense of spirit in a waste of shame")
        let progress = line.progress(heard: "the expense of spirit in a waste of shame")

        #expect(progress.checks[0] == .close)
        #expect(progress.checks.dropFirst().allSatisfy { $0 == .correct })
    }

    @Test("a word spelt differently is a different word, however close it looks")
    func refusesAnAlmostWord() {
        let progress = tracker.progress(heard: "from farest creatures we desire increase")

        #expect(!progress.isComplete)
        #expect(progress.checks == [.correct, .close, .correct, .correct, .correct, .correct])
        #expect(progress.wordStates[1] == .close)
    }

    @Test("a word said with an ending that is not there is wrong, however close it looks")
    func refusesAnAddedConsonant() {
        let line = SpokenLineTracker(line: "But as the riper should by time decease,")
        let progress = line.progress(heard: "but as the ripers should by time decease")

        #expect(!progress.isComplete)
        #expect(progress.checks[3] == .close)
        #expect(progress.checks[4] == .correct)
    }

    @Test("an elision the recogniser spells out in full counts as said")
    func acceptsSpeltOutElision() {
        let line = SpokenLineTracker(line: "Will be a tatter’d weed of small worth held:")
        let progress = line.progress(heard: "will be a tattered weed of small worth held")

        #expect(progress.isComplete)
        #expect(progress.checks[3] == .correct)
    }

    @Test("a word patched for this recogniser passes as though it had been heard right")
    func acceptsAPatchedWord() {
        let line = SpokenLineTracker(
            line: "Will be a tatter’d weed of small worth held:",
            quirks: RecognizerQuirks(allowances: ["tatter’d": ["tattered"]])
        )
        let progress = line.progress(heard: "will be a tattered weed of small worth held")

        #expect(progress.isComplete)
    }

    @Test("two written words the recogniser runs into one are patched as the pair they make")
    func acceptsAPatchedPairOfWrittenWords() {
        let line = SpokenLineTracker(
            line: "For to thy sensual fault I bring in sense;",
            quirks: RecognizerQuirks(allowances: ["in sense": ["incense"]])
        )
        let progress = line.progress(heard: "for to thy sensual fault I bring incense")

        #expect(progress.isComplete)
    }

    @Test("a pair patched for one turn of phrase does not fire elsewhere")
    func keepsAPairPatchToItsOwnCompany() {
        let quirks = RecognizerQuirks(
            allowances: ["in sense": [RecognizerQuirks.Allowance(heard: "incense", after: "bring")]]
        )
        let itsOwn = SpokenLineTracker(line: "I bring in sense;", quirks: quirks)
        let elsewhere = SpokenLineTracker(line: "I burn in sense;", quirks: quirks)

        #expect(itsOwn.progress(heard: "I bring incense").isComplete)
        #expect(!elsewhere.progress(heard: "I burn incense").isComplete)
    }

    @Test("a patch fires only where its own word is expected")
    func keepsAPatchToItsOwnWord() {
        let quirks = RecognizerQuirks(allowances: ["th’": ["the"]])
        let elided = SpokenLineTracker(
            line: "Which, used, lives th’ executor to be.",
            quirks: quirks
        )
        let plain = SpokenLineTracker(line: "And only herald to the gaudy spring,", quirks: quirks)

        #expect(elided.progress(heard: "which used lives the executor to be").isComplete)
        #expect(plain.progress(heard: "and only herald to the gaudy spring").isComplete)
    }

    @Test("a dropped word leaves the line unfinished but does not cost the rest")
    func marksDroppedWord() {
        let progress = tracker.progress(heard: "from fairest creatures desire increase")

        #expect(!progress.isComplete)
        #expect(progress.checks == [.correct, .correct, .correct, .wrong, .correct, .correct])
    }

    @Test("a false start before the line is skipped rather than held against the reader")
    func skipsFalseStart() {
        let progress = tracker.progress(heard: "wait sorry from fairest creatures")

        #expect(progress.checks.prefix(3) == [.correct, .correct, .correct])
    }

    @Test("a word said as something else is the only one marked wrong")
    func marksTheWrongWordOnly() {
        let progress = tracker.progress(heard: "from fairest butterfly we desire increase")

        #expect(progress.checks == [.correct, .correct, .wrong, .correct, .correct, .correct])
        #expect(!progress.isComplete)
    }

    @Test("a mangled opening does not hide the words said correctly after it")
    func readsPastAnEarlyMistake() {
        let progress = tracker.progress(heard: "From Fair Screeches V desire increase.")

        #expect(progress.checks == [.correct, .wrong, .wrong, .wrong, .correct, .correct])
    }

    @Test("a hyphenated word heard as two words still counts as said")
    func joinsWordsTheRecogniserSplit() {
        let hyphenated = SpokenLineTracker(
            line: "Feed’st thy light’s flame with self-substantial fuel,"
        )
        let progress = hyphenated.progress(
            heard: "feedst thy lights flame with self substantial fuel"
        )

        #expect(progress.isComplete)
    }

    @Test("a patched word heard as two words still counts as said")
    func joinsTwoHeardWordsThroughThePatchTable() {
        let quirks = RecognizerQuirks(allowances: ["long-liv’d": ["longlived"]])
        let line = SpokenLineTracker(
            line: "And burn the long-liv’d phoenix, in her blood;",
            quirks: quirks
        )

        #expect(line.progress(heard: "and burn the long lived phoenix in her blood").isComplete)
    }

    @Test("two words heard as one still count as said")
    func splitsAWordTheRecogniserJoined() {
        let joined = SpokenLineTracker(line: "And do what ever thou wilt swift-footed Time")
        let progress = joined.progress(heard: "and do whatever thou wilt swift footed time")

        #expect(progress.isComplete)
    }

    @Test("elisions in the verse are matched the way they are heard")
    func matchesElisions() {
        let elided = SpokenLineTracker(
            line: "Feed’st thy light’s flame with self-substantial fuel,"
        )
        let progress = elided.progress(heard: "feedst thy lights flame with self substantial fuel")

        #expect(progress.checks.allSatisfy { $0 == .correct })
    }

    @Test("a line not yet attempted waits on its first word")
    func startsOnTheFirstWord() {
        #expect(tracker.untriedWordStates == [.expected, .ahead, .ahead, .ahead, .ahead, .ahead])
    }

    @Test("print elides a letter and the recogniser writes it back")
    func forgivesAnElisionWrittenOut() {
        #expect(SpokenLineTracker.isFaithful("tattered", to: "tatter’d"))
        #expect(SpokenLineTracker.isFaithful("crowned", to: "crown’d"))
        #expect(SpokenLineTracker.isFaithful("bestowest", to: "bestow’st"))
        #expect(SpokenLineTracker.isFaithful("beguiled", to: "beguil’d"))
        #expect(SpokenLineTracker.isFaithful("the", to: "th’"))
    }

    @Test("only a vowel may be written back, and only where the apostrophe stands")
    func refusesWhatIsNotAnElision() {
        #expect(!SpokenLineTracker.isFaithful("whatever", to: "whate’er"))
        #expect(!SpokenLineTracker.isFaithful("loves", to: "lov’st"))
        #expect(!SpokenLineTracker.isFaithful("crown", to: "crown’d"))
        #expect(!SpokenLineTracker.isFaithful("time", to: "times"))
    }
}
