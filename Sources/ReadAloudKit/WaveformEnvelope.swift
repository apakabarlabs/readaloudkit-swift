import Foundation

public enum WaveformEnvelope {
    private static let defaultBarCount = 48
    private static let decibelsPerBel = 20.0
    private static let minimumAmplitude = 0.000001
    private static let normalizationFloor = 50.0
    private static let normalizationRange = 45.0

    public static func make(from samples: [Float]) -> [Double] {
        make(from: samples, bars: defaultBarCount)
    }

    public static func make(from samples: [Float], bars: Int) -> [Double] {
        guard !samples.isEmpty, bars > 0 else { return [] }
        let count = min(bars, samples.count)
        return (0..<count).map { bar in
            let start = bar * samples.count / count
            let end = max((bar + 1) * samples.count / count, start + 1)
            let squareMean =
                samples[start..<end].reduce(0.0) { $0 + Double($1 * $1) } / Double(end - start)
            let decibels = decibelsPerBel * log10(max(squareMean.squareRoot(), minimumAmplitude))
            return min(max((decibels + normalizationFloor) / normalizationRange, 0), 1)
        }
    }
}
