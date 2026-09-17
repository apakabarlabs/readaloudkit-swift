import Testing

@testable import ReadAloudKit

struct PlaybackEnvelopeTests {
    @Test("a cut segment reaches silence at both edges")
    func fadesBothEdges() {
        #expect(gain(at: 0) == 0)
        #expect(gain(at: 5) == 0.5)
        #expect(gain(at: 10) == 1)
        #expect(gain(at: 89) == 1)
        #expect(gain(at: 94) == 0.5)
        #expect(gain(at: 99) == 0)
    }

    @Test("an uncut recording keeps every sample")
    func keepsUncutRecording() {
        for frame in 0..<100 {
            #expect(gain(at: frame, fadesIn: false, fadesOut: false) == 1)
        }
    }

    private func gain(
        at frame: Int,
        fadesIn: Bool = true,
        fadesOut: Bool = true
    ) -> Float {
        PlaybackEnvelope.gain(
            at: frame,
            frameCount: 100,
            fadeFrameCount: 10,
            fadesIn: fadesIn,
            fadesOut: fadesOut
        )
    }
}
