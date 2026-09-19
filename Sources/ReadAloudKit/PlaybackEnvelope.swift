/// Shapes the gain at the edges of a playback buffer.
public enum PlaybackEnvelope {
    /// Returns the gain for one frame, applying the requested linear edge fades.
    ///
    /// A buffer shorter than two frames or a nonpositive fade length returns unity.
    /// Frames outside the buffer are clamped to zero when an applicable fade is enabled.
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
