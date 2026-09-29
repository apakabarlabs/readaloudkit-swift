import Testing

@testable import ReadAloudKit

struct SampleRun: Decodable, Sendable {
    let value: Float
    let count: Int
}

struct WaveformCase: NamedCase {
    let name: String
    let samples: [SampleRun]
    let bars: Int
    let count: Int
    let exactly: [[Double]]?
    let above: [[Double]]?

    var built: [Float] {
        samples.flatMap { Array(repeating: $0.value, count: $0.count) }
    }
}

struct WaveformEnvelopeTests {
    @Test(arguments: AudioCases.all.waveform)
    func keepsTheShape(_ example: WaveformCase) {
        let envelope = WaveformEnvelope.make(from: example.built, bars: example.bars)

        #expect(envelope.count == example.count)
        for pair in example.exactly ?? [] {
            #expect(envelope[Int(pair[0])] == pair[1], "bar \(pair[0])")
        }
        for pair in example.above ?? [] {
            #expect(envelope[Int(pair[0])] > pair[1], "bar \(pair[0])")
        }
    }
}
