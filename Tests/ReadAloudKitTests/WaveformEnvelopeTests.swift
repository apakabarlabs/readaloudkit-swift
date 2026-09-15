import Testing
@testable import ReadAloudKit

struct WaveformEnvelopeTests {
    @Test("silence stays flat and sound keeps its shape")
    func preservesShape() {
        let envelope = WaveformEnvelope.make(from: [Float](repeating: 0, count: 8) + [Float](repeating: 0.5, count: 8), bars: 4)

        #expect(envelope.count == 4)
        #expect(envelope[0] == 0)
        #expect(envelope[1] == 0)
        #expect(envelope[2] > 0.8)
        #expect(envelope[3] > 0.8)
    }

    @Test("a short recording does not invent empty bars")
    func boundsTheBarCount() {
        #expect(WaveformEnvelope.make(from: [0.1, 0.2], bars: 48).count == 2)
        #expect(WaveformEnvelope.make(from: [], bars: 48).isEmpty)
    }
}
