import Foundation

public struct VerseLayoutPlan: Sendable, Equatable {
    public let columnWidth: Double
    public let rowStarts: [[Int]]

    public func rows(forLine index: Int) -> [Int] {
        precondition(
            rowStarts.indices.contains(index),
            "Line \(index) was laid out against a plan made for \(rowStarts.count) lines."
        )
        return rowStarts[index]
    }
}

public enum VerseLayoutPlanner {
    static let lonelyWordPenalty = 10_000.0
    static let minimumTurnoverFraction = 0.33
    static let shortTurnoverPenalty = 4_000.0
    static let narrowingPenaltyPerPoint = 3.0

    public static func plan(
        lines: [[Double]],
        spaceWidth: Double,
        candidateWidths: [Double],
        indent: Double
    ) -> VerseLayoutPlan {
        guard let widest = candidateWidths.max(), !candidateWidths.isEmpty else {
            return VerseLayoutPlan(columnWidth: 0, rowStarts: lines.map { _ in [0] })
        }

        struct Candidate {
            let width: Double
            let cost: Double
            let rows: [[Int]]
        }

        var best: Candidate?
        for width in candidateWidths.sorted(by: >) {
            var total = (widest - width) * narrowingPenaltyPerPoint
            var rows: [[Int]] = []
            for words in lines {
                let line = breakLine(words: words, spaceWidth: spaceWidth, width: width, indent: indent)
                total += line.cost
                rows.append(line.starts)
            }
            if best == nil || total < best!.cost {
                best = Candidate(width: width, cost: total, rows: rows)
            }
        }

        guard let chosen = best else {
            return VerseLayoutPlan(columnWidth: widest, rowStarts: lines.map { _ in [0] })
        }
        return VerseLayoutPlan(columnWidth: chosen.width, rowStarts: chosen.rows)
    }

    static func breakLine(
        words: [Double],
        spaceWidth: Double,
        width: Double,
        indent: Double
    ) -> (starts: [Int], cost: Double) {
        guard words.count > 1 else { return ([0], 0) }
        if run(words, from: 0, to: words.count, spaceWidth: spaceWidth) <= width {
            return ([0], 0)
        }

        let turnoverWidth = width - indent
        var bestBreak: (index: Int, cost: Double)?
        var fallback: (index: Int, overflow: Double)?

        for split in 1..<words.count {
            let head = run(words, from: 0, to: split, spaceWidth: spaceWidth)
            let tail = run(words, from: split, to: words.count, spaceWidth: spaceWidth)

            guard head <= width else { break }
            guard tail <= turnoverWidth else {
                let overflow = tail - turnoverWidth
                if fallback == nil || overflow < fallback!.overflow {
                    fallback = (split, overflow)
                }
                continue
            }

            var cost = abs(head - (tail + indent))
            if words.count - split == 1 { cost += lonelyWordPenalty }
            if tail < turnoverWidth * minimumTurnoverFraction { cost += shortTurnoverPenalty }

            if bestBreak == nil || cost < bestBreak!.cost {
                bestBreak = (split, cost)
            }
        }

        guard let chosen = bestBreak else {
            let split = fallback?.index ?? max(words.count - 1, 1)
            let rest = breakLine(
                words: Array(words[split...]),
                spaceWidth: spaceWidth,
                width: turnoverWidth,
                indent: 0
            )
            let starts = [0, split] + rest.starts.dropFirst().map { $0 + split }
            return (starts, lonelyWordPenalty + rest.cost)
        }
        return ([0, chosen.index], chosen.cost)
    }

    static func run(_ words: [Double], from: Int, to: Int, spaceWidth: Double) -> Double {
        guard to > from else { return 0 }
        let text = words[from..<to].reduce(0, +)
        return text + Double(to - from - 1) * spaceWidth
    }
}
