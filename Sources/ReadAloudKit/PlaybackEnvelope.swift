public enum PlaybackEnvelope {
    public static func gain(
        at frame: Int,
        frameCount: Int,
        fadeFrameCount: Int,
        fadesIn: Bool,
        fadesOut: Bool
    ) -> Float {
        guard frameCount > 1, fadeFrameCount > 0 else { return 1 }
        var gain = 1.0
        if fadesIn { gain = min(gain, Double(frame) / Double(fadeFrameCount)) }
        if fadesOut {
            gain = min(gain, Double(frameCount - frame - 1) / Double(fadeFrameCount))
        }
        return Float(max(gain, 0))
    }
}
