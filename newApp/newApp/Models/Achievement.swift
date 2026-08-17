//
//  Achievement.swift
//  Alpha Academy
//

import Foundation

enum AchievementCategory: String, CaseIterable, Identifiable, Hashable {
    case gettingStarted
    case mastery
    case accuracy
    case encoding
    case listening
    case speed
    case consistency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .mastery:        return "Mastery"
        case .accuracy:       return "Accuracy"
        case .encoding:       return "Encoding"
        case .listening:      return "Listening"
        case .speed:          return "Speed"
        case .consistency:    return "Consistency"
        }
    }
}

/// Everything an achievement condition might need, flattened and
/// precomputed so no condition ever walks the answer history.
///
/// Cumulative fields come from `LifetimeCounters`, never from `state.answers`
/// — that array is capped, so a "1 000 correct answers" badge fed from it
/// would silently become unreachable.
struct StatsSnapshot {
    var totalAnswers = 0
    var totalCorrect = 0
    var sessionsCompleted = 0
    var bestCombo = 0
    var bestSpeedScore = 0
    var streakDays = 0
    var longestStreak = 0
    var xp = 0
    var rank: RankTier = .cadet
    var digitsCorrect = 0
    var charactersEncoded = 0
    var stringsDecoded = 0
    var cleanDecodesNoReplay = 0
    var fastCorrectAnswers = 0
    var maxCleanEncodeLength = 0
    var tookALetterZeroToMastered = false
    var sessionHours: Set<Int> = []

    var masteryByAlphabet: [AlphabetID: Double] = [:]
    var symbolsTouchedByAlphabet: [AlphabetID: Int] = [:]
    var sessionsByMode: [TrainingMode: Int] = [:]
    var accuracyByMode: [TrainingMode: Double] = [:]
    var scenarioCompletions: [ScenarioCategory: Int] = [:]

    /// The session that just finished, for session-scoped conditions.
    var lastSession: SessionResult?

    var overallAccuracy: Double {
        totalAnswers == 0 ? 0 : Double(totalCorrect) / Double(totalAnswers)
    }

    var bestMastery: Double { masteryByAlphabet.values.max() ?? 0 }

    var alphabetsFullyMastered: Int {
        masteryByAlphabet.values.filter { $0 >= 1.0 }.count
    }

    var modesTried: Int {
        sessionsByMode.filter { $0.value > 0 }.count
    }
}

/// A definition returns `current` and `target` rather than a Bool, so the
/// same declaration drives both the unlock check and the "7 / 30" progress
/// bar on locked badges. No duplicated logic.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let category: AchievementCategory
    let xpReward: Int
    let evaluate: (StatsSnapshot) -> (current: Int, target: Int)

    func isUnlocked(_ snapshot: StatsSnapshot) -> Bool {
        let result = evaluate(snapshot)
        return result.current >= result.target
    }

    func progress(_ snapshot: StatsSnapshot) -> Double {
        let result = evaluate(snapshot)
        guard result.target > 0 else { return 0 }
        return min(1, Double(result.current) / Double(result.target))
    }
}

extension Achievement: Hashable {
    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
