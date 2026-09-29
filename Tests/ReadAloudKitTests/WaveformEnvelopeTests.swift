import Testing

@testable import ReadAloudKit

struct SampleRun: Codable, Sendable {
    let value: Float
    let count: Int
}

struct WaveformCase: NamedCase {
    let name: String
    let samples: [SampleRun]
    let bars: Int
    let envelope: [Double]

    var built: [Float] {
        samples.flatMap { Array(repeating: $0.value, count: $0.count) }
    }
}

struct WaveformEnvelopeTests {
    @Test(arguments: AudioCases.all.waveform)
    func keepsTheShape(_ example: WaveformCase) {
        let envelope = WaveformEnvelope.make(from: example.built, bars: example.bars)

        #expect(envelope.count == example.envelope.count)
        for (bar, (actual, expected)) in zip(envelope, example.envelope).enumerated() {
            #expect(Cases.close(actual, expected), "bar \(bar) is \(actual)")
        }
    }
}
