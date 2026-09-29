import Testing

@testable import ReadAloudKit

struct SampleRun: Codable, Sendable {
    let value: Float
    let count: Int
}

struct BarRun: Codable, Sendable {
    let value: Double
    let count: Int
}

struct WaveformCase: NamedCase {
    let name: String
    let samples: [SampleRun]
    let bars: Int
    let envelope: [BarRun]

    var built: [Float] {
        samples.flatMap { Array(repeating: $0.value, count: $0.count) }
    }

    var expected: [Double] {
        envelope.flatMap { Array(repeating: $0.value, count: $0.count) }
    }
}

struct WaveformEnvelopeTests {
    @Test(arguments: try AudioCases.all.waveform)
    func keepsTheShape(_ example: WaveformCase) {
        let envelope = WaveformEnvelope.make(from: example.built, bars: example.bars)
        let expected = example.expected

        #expect(envelope.count == expected.count)
        let wrong = zip(envelope, expected).enumerated()
            .filter { !Cases.close($0.element.0, $0.element.1) }
            .map { "bar \($0.offset) is \($0.element.0)" }
        #expect(wrong.isEmpty, "\(wrong.prefix(3).joined(separator: ", "))")
    }
}
