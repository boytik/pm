import Foundation

enum SpacedRepetitionEngine {
    static let intervalHours: [Double] = [0, 4, 24, 72, 168, 336]

    static let requiredStreak: [Int] = [2, 2, 3, 3, 4, 99]

    static let shakyResponseMs = 6_000

    static func apply(
        record: AnswerRecord,
        to progress: LetterProgress,
        now: Date = Date()
    ) -> LetterProgress {
        var p = progress
        p.answered += 1
        p.lastSeen = now
        p.totalResponseMs += max(0, min(record.responseMs, 30_000))

        if record.wasCorrect {
            p.correct += 1
            p.lastCorrect = now
            p.lastAnswerWasWrong = false

            if record.responseMs > shakyResponseMs {
            } else {
                p.streak += 1
                let needed = requiredStreak[min(p.level, requiredStreak.count - 1)]
                if p.streak >= needed {
                    p.level = min(LetterProgress.maxLevel, p.level + 1)
                    p.streak = 0
                }
            }
        } else {
            p.wrong += 1
            p.streak = 0
            let drop = p.lastAnswerWasWrong ? 2 : 1
            p.level = max(0, p.level - drop)
            p.lastAnswerWasWrong = true
        }

        return p
    }

    static func isDue(_ progress: LetterProgress?, now: Date = Date()) -> Bool {
        guard let progress, let lastSeen = progress.lastSeen else { return true }
        let interval = intervalHours[min(progress.level, intervalHours.count - 1)] * 3_600
        return now.timeIntervalSince(lastSeen) >= interval
    }

    static func dueCount(
        in map: [String: LetterProgress],
        symbols: [String] = AlphabetCatalog.trainableSymbols,
        now: Date = Date()
    ) -> Int {
        symbols.filter { isDue(map[$0], now: now) }.count
    }

    static func weight(
        for progress: LetterProgress?,
        symbol: String,
        recentlyAsked: [String],
        now: Date = Date()
    ) -> Double {
        if recentlyAsked.suffix(3).contains(symbol) { return 0 }

        guard let progress, let lastSeen = progress.lastSeen else { return 300 }

        let level = min(progress.level, intervalHours.count - 1)
        let base = 100.0 * pow(0.62, Double(level))

        let interval = intervalHours[level] * 3_600
        let dueBoost: Double
        if interval <= 0 {
            dueBoost = 3.0
        } else {
            let due = lastSeen.addingTimeInterval(interval)
            let overdueRatio = max(0, now.timeIntervalSince(due)) / interval
            dueBoost = 1.0 + min(overdueRatio, 2.0)
        }

        let errorBoost = 1.0 + min(1.0, progress.errorRate * 1.5)

        var w = base * dueBoost * errorBoost

        if now.timeIntervalSince(lastSeen) < 60 { w *= 0.15 }

        return max(w, 1.0)
    }

    static func selectSymbols(
        count: Int,
        from symbols: [String],
        progress map: [String: LetterProgress],
        now: Date = Date(),
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        var pool = symbols
        var picked: [String] = []

        while picked.count < count, !pool.isEmpty {
            let weights = pool.map {
                weight(for: map[$0], symbol: $0, recentlyAsked: picked, now: now)
            }
            let total = weights.reduce(0, +)
            guard total > 0 else {
                if let symbol = pool.randomElement(using: &generator),
                   let index = pool.firstIndex(of: symbol) {
                    picked.append(symbol)
                    pool.remove(at: index)
                }
                continue
            }

            var roll = Double.random(in: 0..<total, using: &generator)
            var chosenIndex = pool.count - 1
            for (index, weight) in weights.enumerated() {
                roll -= weight
                if roll <= 0 { chosenIndex = index; break }
            }

            picked.append(pool[chosenIndex])
            pool.remove(at: chosenIndex)
        }

        return picked
    }

    static func weakest(
        count: Int,
        in map: [String: LetterProgress],
        symbols: [String] = AlphabetCatalog.trainableSymbols,
        now: Date = Date()
    ) -> [String] {
        var scored: [(symbol: String, weight: Double)] = []
        scored.reserveCapacity(symbols.count)
        for symbol in symbols {
            let w = weight(for: map[symbol], symbol: symbol, recentlyAsked: [], now: now)
            scored.append((symbol, w))
        }
        scored.sort { lhs, rhs in
            if lhs.weight == rhs.weight { return lhs.symbol < rhs.symbol }
            return lhs.weight > rhs.weight
        }
        return scored.prefix(count).map(\.symbol)
    }
}
