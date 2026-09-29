import Testing

@testable import ReadAloudKit

struct AudioCases: Codable {
    let gain: [GainCase]
    let waveform: [WaveformCase]

    static let all = Cases.loadRefusingUnreadKeys("audio_tests.yaml", as: Self.self)
}

struct GainCase: NamedCase {
    let name: String
    let frameCount: Int
    let fadeFrameCount: Int
    let fadesIn: Bool
    let fadesOut: Bool
    let gains: [[Double]]?
    let everyFrame: Float?

    private enum CodingKeys: String, CodingKey {
        case name, gains
        case frameCount = "frame_count"
        case fadeFrameCount = "fade_frame_count"
        case fadesIn = "fades_in"
        case fadesOut = "fades_out"
        case everyFrame = "every_frame"
    }

    func gain(at frame: Int) -> Float {
        PlaybackEnvelope.gain(
            at: frame,
            frameCount: frameCount,
            fadeFrameCount: fadeFrameCount,
            fadesIn: fadesIn,
            fadesOut: fadesOut
        )
    }
}

struct PlaybackEnvelopeTests {
    @Test(arguments: AudioCases.all.gain)
    func fadesTheEdges(_ example: GainCase) {
        #expect((example.gains == nil) != (example.everyFrame == nil), "pins frames or all frames")
        for pair in example.gains ?? [] {
            #expect(example.gain(at: Int(pair[0])) == Float(pair[1]), "frame \(pair[0])")
        }
        if let every = example.everyFrame {
            for frame in 0..<example.frameCount {
                #expect(example.gain(at: frame) == every, "frame \(frame)")
            }
        }
    }
}
