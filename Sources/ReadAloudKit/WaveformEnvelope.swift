import Foundation

public enum WaveformEnvelope {
    public static func make(from samples: [Float], bars: Int = 48) -> [Double] {
        guard !samples.isEmpty, bars > 0 else { return [] }
        let count = min(bars, samples.count)
        return (0..<count).map { bar in
            let start = bar * samples.count / count
            let end = max((bar + 1) * samples.count / count, start + 1)
            let squareMean = samples[start..<end].reduce(0.0) { $0 + Double($1 * $1) } / Double(end - start)
            let decibels = 20 * log10(max(squareMean.squareRoot(), 0.000_001))
            return min(max((decibels + 50) / 45, 0), 1)
        }
    }
}
