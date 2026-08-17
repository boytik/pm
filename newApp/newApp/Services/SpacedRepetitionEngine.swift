//
//  SpacedRepetitionEngine.swift
//  Alpha Academy
//
//  Two promotion rules and one weight formula. Kept small enough to
//  reason about in your head, because a scheduler you cannot debug is
//  worse than a simple one.
//

import Foundation

enum SpacedRepetitionEngine {

    /// How long a symbol rests at each level before it is due again.
    static let intervalHours: [Double] = [0, 4, 24, 72, 168, 336]

    /// Consecutive good answers needed to leave each level.
    /// Index 5 is unreachable on purpose — level 5 is the top.
    static let requiredStreak: [Int] = [2, 2, 3, 3, 4, 99]

    /// A correct answer this slow means the recall was not consolidated,
    /// so it does not advance the streak.
    static let shakyResponseMs = 6_000

    // MARK: - Applying an answer

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
                // Correct but shaky: credit the answer, hold the streak.
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

    // MARK: - Due state

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

    // MARK: - Selection weight

    /// Higher means "ask this sooner".
    ///
    /// Worked example: an unseen symbol scores 300. A level-0 symbol with
    /// 4 wrong out of 5, last seen two days ago, scores 100 × 3.0 × 2.0 =
    /// 600. A mastered symbol seen yesterday scores 9. So the worst symbol
    /// is roughly 67× more likely than the best one — weak letters clearly
    /// dominate without the session turning into a single-letter grind.
    static func weight(
        for progress: LetterProgress?,
        symbol: String,
        recentlyAsked: [String],
        now: Date = Date()
    ) -> Double {
        // A hard block on the last three keeps the rotation moving even
        // when one symbol is far and away the weakest.
        if recentlyAsked.suffix(3).contains(symbol) { return 0 }

        guard let progress, let lastSeen = progress.lastSeen else { return 300 }

        let level = min(progress.level, intervalHours.count - 1)
        let base = 100.0 * pow(0.62, Double(level))          // 100, 62, 38, 24, 15, 9

        let interval = intervalHours[level] * 3_600
        let dueBoost: Double
        if interval <= 0 {
            dueBoost = 3.0
        } else {
            let due = lastSeen.addingTimeInterval(interval)
            let overdueRatio = max(0, now.timeIntervalSince(due)) / interval
            dueBoost = 1.0 + min(overdueRatio, 2.0)          // 1.0 … 3.0
        }

        let errorBoost = 1.0 + min(1.0, progress.errorRate * 1.5)   // 1.0 … 2.0

        var w = base * dueBoost * errorBoost

        // Asked seconds ago — almost certainly still in short-term memory.
        if now.timeIntervalSince(lastSeen) < 60 { w *= 0.15 }

        return max(w, 1.0)
    }

    // MARK: - Picking symbols

    /// Weighted draw without replacement.
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
                // Everything is blocked by recency — fall back to random.
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

    /// The weakest symbols, for the Home screen and the daily drill.
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
