//
//  AppState.swift
//  Alpha Academy
//
//  The single persisted root. Everything the app remembers lives here.
//

import Foundation

/// All-time totals that are never trimmed.
///
/// `answers` is capped, so any achievement counting past the cap would
/// silently become unreachable if it read from history. These counters are
/// the durable ground truth instead.
struct LifetimeCounters: Codable, Hashable {
    var totalSessions = 0
    var correctAnswers = 0
    var wrongAnswers = 0
    /// Keyed by `TrainingMode.rawValue`.
    var sessionsByMode: [String: Int] = [:]
    var correctByMode: [String: Int] = [:]
    var answeredByMode: [String: Int] = [:]
    /// Keyed by `ScenarioCategory.rawValue`.
    var scenarioCompletions: [String: Int] = [:]
    var digitsCorrect = 0
    var charactersEncoded = 0
    var encodeMillis = 0
    var stringsDecoded = 0
    var cleanDecodesNoReplay = 0
    var bestCombo = 0
    var bestSpeedScore = 0
    var totalPracticeSeconds: Double = 0
    var fastCorrectUnder1500ms = 0
    var maxCleanEncodeLength = 0
    var tookALetterZeroToMastered = false
    /// Hours of day at which sessions were completed, for the time badges.
    var sessionHours: Set<Int> = []
}

/// One day's rollup. Survives the trimming of raw answers, so long-range
/// trends never show a number that goes down.
struct DailyStat: Codable, Hashable, Identifiable {
    var day: Date
    var sessions = 0
    var answered = 0
    var correct = 0
    var xp = 0
    var practiceSeconds: Double = 0
    var encodedCharacters = 0
    var encodeMillis = 0

    var id: Date { day }

    var accuracy: Double {
        answered == 0 ? 0 : Double(correct) / Double(answered)
    }
}

struct UnlockedAchievement: Codable, Hashable, Identifiable {
    let achievementID: String
    let date: Date
    var id: String { achievementID }
}

struct AppState: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion = AppState.currentSchemaVersion
    var profile = UserProfile()

    /// Keyed by `AlphabetID.rawValue`, then by symbol.
    ///
    /// String keys are deliberate: `JSONEncoder` only writes a JSON object
    /// for dictionaries whose key is `String`, `Int`, or `CodingKeyRepresentable`.
    /// A raw-value enum gets none of those for free, so `[AlphabetID: …]`
    /// would silently serialise as a flat array of alternating keys and
    /// values — round-trippable, but unreadable and painful to migrate.
    var progress: [String: [String: LetterProgress]] = [:]

    var counters = LifetimeCounters()
    var dailyStats: [DailyStat] = []
    var sessions: [SessionResult] = []
    var answers: [AnswerRecord] = []
    var unlocked: [UnlockedAchievement] = []
    /// Anti-repeat ring for scenario strings.
    var recentScenarioStrings: [String] = []

    // MARK: - Retention caps, enforced on every commit

    enum Cap {
        static let answers = 2_000
        static let sessions = 200
        static let dailyStats = 400
        static let recentStrings = 40
    }

    // MARK: - Typed access

    func progress(_ alphabet: AlphabetID, _ symbol: String) -> LetterProgress {
        progress[alphabet.rawValue]?[symbol] ?? LetterProgress(symbol: symbol)
    }

    func progressMap(_ alphabet: AlphabetID) -> [String: LetterProgress] {
        progress[alphabet.rawValue] ?? [:]
    }

    mutating func setProgress(_ value: LetterProgress, for alphabet: AlphabetID) {
        progress[alphabet.rawValue, default: [:]][value.symbol] = value
    }

    /// Mastery 0…1 across the 36 trainable symbols of one alphabet.
    /// Symbols with no row yet count as level 0, which is what we want.
    func mastery(for alphabet: AlphabetID) -> Double {
        let map = progressMap(alphabet)
        let total = AlphabetCatalog.trainableSymbols.reduce(0) { sum, symbol in
            sum + (map[symbol]?.level ?? 0)
        }
        let maximum = AlphabetCatalog.trainableCount * LetterProgress.maxLevel
        return maximum == 0 ? 0 : Double(total) / Double(maximum)
    }

    static func freshInstall() -> AppState {
        // Deliberately no pre-populated progress rows: a missing row means
        // "never seen", which the scheduler already treats as top priority.
        // That also makes adding a fourth alphabet a zero-migration change.
        AppState()
    }
}
