//
//  StatsEngine.swift
//  Alpha Academy
//
//  Pure functions over AppState. Computed once on commit and once at
//  launch — never from a SwiftUI body, because walking 2 000 records
//  every frame will visibly stutter the Progress tab.
//

import Foundation

struct HardLetter: Identifiable, Hashable {
    let symbol: String
    let errorRate: Double
    let level: Int
    let answered: Int
    var id: String { symbol }
}

struct ModeAccuracy: Hashable {
    let allTime: Double
    let last30Days: Double
    let sampleSize: Int
}

struct WeekAggregate: Hashable {
    var answered = 0
    var correct = 0
    var xp = 0
    var minutes: Double = 0

    var accuracy: Double {
        answered == 0 ? 0 : Double(correct) / Double(answered)
    }
}

struct TrendSnapshot: Hashable {
    var thisWeek = WeekAggregate()
    var lastWeek = WeekAggregate()
    /// Percentage points. Nil when there is no prior week to compare with —
    /// never a "+∞%".
    var accuracyDeltaPoints: Double?
    var xpDelta: Int?
    var isFirstWeek = true
}

struct DerivedStats {
    var masteryByAlphabet: [AlphabetID: Double] = [:]
    var dueCountByAlphabet: [AlphabetID: Int] = [:]
    var hardestLetters: [HardLetter] = []
    /// Weakest symbols overall — drives question selection.
    var weakestSymbols: [String] = []
    /// Weakest symbols the learner has actually attempted. "Needs work"
    /// must not be a list of things they have never seen.
    var weakestAttempted: [String] = []
    var untouchedCount: Int = 0
    var accuracyByMode: [TrainingMode: ModeAccuracy] = [:]
    var encodeCharsPerMinute: Double = 0
    var trend = TrendSnapshot()
    var last14Days: [DailyStat] = []
    var totalPracticeMinutes: Int = 0
    var overallAccuracy: Double = 0
    var achievementsUnlocked: Int = 0
    var achievementsTotal: Int = 0

    static let empty = DerivedStats()
}

enum StatsEngine {

    static func compute(_ state: AppState, now: Date = Date()) -> DerivedStats {
        var stats = DerivedStats()
        let alphabet = state.profile.preferredAlphabet
        let map = state.progressMap(alphabet)

        for id in AlphabetID.allCases {
            stats.masteryByAlphabet[id] = state.mastery(for: id)
            stats.dueCountByAlphabet[id] = SpacedRepetitionEngine.dueCount(
                in: state.progressMap(id), now: now
            )
        }

        stats.hardestLetters = hardestLetters(in: map)
        stats.weakestSymbols = SpacedRepetitionEngine.weakest(count: 6, in: map, now: now)

        let attempted = AlphabetCatalog.trainableSymbols.filter { (map[$0]?.answered ?? 0) > 0 }
        stats.weakestAttempted = SpacedRepetitionEngine.weakest(
            count: 6, in: map, symbols: attempted, now: now
        )
        stats.untouchedCount = AlphabetCatalog.trainableCount - attempted.count
        stats.accuracyByMode = accuracyByMode(state, now: now)
        stats.encodeCharsPerMinute = charsPerMinute(
            characters: state.counters.charactersEncoded,
            millis: state.counters.encodeMillis
        )
        stats.trend = trend(state, now: now)
        stats.last14Days = zeroFilledDays(state.dailyStats, days: 14, now: now)
        stats.totalPracticeMinutes = Int(state.counters.totalPracticeSeconds / 60)

        let answered = state.counters.correctAnswers + state.counters.wrongAnswers
        stats.overallAccuracy = answered == 0
            ? 0
            : Double(state.counters.correctAnswers) / Double(answered)

        stats.achievementsUnlocked = state.unlocked.count
        stats.achievementsTotal = AchievementCatalog.all.count

        return stats
    }

    // MARK: - Pieces

    /// Requiring at least three answers stops one unlucky miss from
    /// crowning a letter "hardest" forever.
    static func hardestLetters(in map: [String: LetterProgress], limit: Int = 5) -> [HardLetter] {
        var candidates: [HardLetter] = []
        for progress in map.values where progress.answered >= 3 {
            candidates.append(
                HardLetter(
                    symbol: progress.symbol,
                    errorRate: progress.errorRate,
                    level: progress.level,
                    answered: progress.answered
                )
            )
        }
        candidates.sort { lhs, rhs in
            if lhs.errorRate != rhs.errorRate { return lhs.errorRate > rhs.errorRate }
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return lhs.answered > rhs.answered
        }
        return Array(candidates.prefix(limit))
    }

    static func accuracyByMode(_ state: AppState, now: Date) -> [TrainingMode: ModeAccuracy] {
        let cutoff = now.addingTimeInterval(-30 * 24 * 3_600)
        var recentAnswered: [String: Int] = [:]
        var recentCorrect: [String: Int] = [:]

        for record in state.answers where record.date >= cutoff {
            let key = record.mode.rawValue
            recentAnswered[key, default: 0] += 1
            if record.wasCorrect { recentCorrect[key, default: 0] += 1 }
        }

        var result: [TrainingMode: ModeAccuracy] = [:]
        for mode in TrainingMode.allCases where mode.isScored {
            let key = mode.rawValue
            let lifetimeAnswered = state.counters.answeredByMode[key] ?? 0
            let lifetimeCorrect = state.counters.correctByMode[key] ?? 0
            let windowAnswered = recentAnswered[key] ?? 0
            let windowCorrect = recentCorrect[key] ?? 0

            result[mode] = ModeAccuracy(
                allTime: lifetimeAnswered == 0
                    ? 0 : Double(lifetimeCorrect) / Double(lifetimeAnswered),
                last30Days: windowAnswered == 0
                    ? 0 : Double(windowCorrect) / Double(windowAnswered),
                sampleSize: lifetimeAnswered
            )
        }
        return result
    }

    static func charsPerMinute(characters: Int, millis: Int) -> Double {
        guard millis > 0 else { return 0 }
        return Double(characters) / (Double(millis) / 60_000)
    }

    static func trend(_ state: AppState, now: Date) -> TrendSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let lastWeekStart = calendar.date(byAdding: .day, value: -13, to: today)
        else { return TrendSnapshot() }

        var snapshot = TrendSnapshot()
        for day in state.dailyStats {
            if day.day >= thisWeekStart {
                snapshot.thisWeek.answered += day.answered
                snapshot.thisWeek.correct += day.correct
                snapshot.thisWeek.xp += day.xp
                snapshot.thisWeek.minutes += day.practiceSeconds / 60
            } else if day.day >= lastWeekStart {
                snapshot.lastWeek.answered += day.answered
                snapshot.lastWeek.correct += day.correct
                snapshot.lastWeek.xp += day.xp
                snapshot.lastWeek.minutes += day.practiceSeconds / 60
            }
        }

        if snapshot.lastWeek.answered > 0 {
            snapshot.isFirstWeek = false
            snapshot.accuracyDeltaPoints =
                (snapshot.thisWeek.accuracy - snapshot.lastWeek.accuracy) * 100
            snapshot.xpDelta = snapshot.thisWeek.xp - snapshot.lastWeek.xp
        }

        return snapshot
    }

    /// Empty days must be inserted or the sparkline lies about consistency.
    static func zeroFilledDays(_ stats: [DailyStat], days: Int, now: Date) -> [DailyStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var byDay: [Date: DailyStat] = [:]
        for stat in stats { byDay[stat.day] = stat }

        var result: [DailyStat] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append(byDay[day] ?? DailyStat(day: day))
        }
        return result
    }

    // MARK: - Snapshot for achievements

    static func snapshot(_ state: AppState, lastSession: SessionResult?) -> StatsSnapshot {
        var snapshot = StatsSnapshot()
        let counters = state.counters

        snapshot.totalAnswers = counters.correctAnswers + counters.wrongAnswers
        snapshot.totalCorrect = counters.correctAnswers
        snapshot.sessionsCompleted = counters.totalSessions
        snapshot.bestCombo = counters.bestCombo
        snapshot.bestSpeedScore = counters.bestSpeedScore
        snapshot.streakDays = state.profile.streakDays
        snapshot.longestStreak = state.profile.longestStreak
        snapshot.xp = state.profile.xp
        snapshot.rank = state.profile.rank
        snapshot.digitsCorrect = counters.digitsCorrect
        snapshot.charactersEncoded = counters.charactersEncoded
        snapshot.stringsDecoded = counters.stringsDecoded
        snapshot.cleanDecodesNoReplay = counters.cleanDecodesNoReplay
        snapshot.fastCorrectAnswers = counters.fastCorrectUnder1500ms
        snapshot.maxCleanEncodeLength = counters.maxCleanEncodeLength
        snapshot.tookALetterZeroToMastered = counters.tookALetterZeroToMastered
        snapshot.sessionHours = counters.sessionHours
        snapshot.lastSession = lastSession

        for id in AlphabetID.allCases {
            snapshot.masteryByAlphabet[id] = state.mastery(for: id)
            let map = state.progressMap(id)
            snapshot.symbolsTouchedByAlphabet[id] = map.values.filter { $0.answered > 0 }.count
        }

        for mode in TrainingMode.allCases {
            snapshot.sessionsByMode[mode] = counters.sessionsByMode[mode.rawValue] ?? 0
            let answered = counters.answeredByMode[mode.rawValue] ?? 0
            let correct = counters.correctByMode[mode.rawValue] ?? 0
            snapshot.accuracyByMode[mode] = answered == 0
                ? 0 : Double(correct) / Double(answered)
        }

        for category in ScenarioCategory.allCases {
            snapshot.scenarioCompletions[category] =
                counters.scenarioCompletions[category.rawValue] ?? 0
        }

        return snapshot
    }
}
