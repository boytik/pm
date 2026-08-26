import Foundation

struct LifetimeCounters: Codable, Hashable {
    var totalSessions = 0
    var correctAnswers = 0
    var wrongAnswers = 0

    var sessionsByMode: [String: Int] = [:]
    var correctByMode: [String: Int] = [:]
    var answeredByMode: [String: Int] = [:]

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

    var sessionHours: Set<Int> = []
}

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

    var progress: [String: [String: LetterProgress]] = [:]

    var counters = LifetimeCounters()
    var dailyStats: [DailyStat] = []
    var sessions: [SessionResult] = []
    var answers: [AnswerRecord] = []
    var unlocked: [UnlockedAchievement] = []

    var recentScenarioStrings: [String] = []

    enum Cap {
        static let answers = 2_000
        static let sessions = 200
        static let dailyStats = 400
        static let recentStrings = 40
    }

    func progress(_ alphabet: AlphabetID, _ symbol: String) -> LetterProgress {
        progress[alphabet.rawValue]?[symbol] ?? LetterProgress(symbol: symbol)
    }

    func progressMap(_ alphabet: AlphabetID) -> [String: LetterProgress] {
        progress[alphabet.rawValue] ?? [:]
    }

    mutating func setProgress(_ value: LetterProgress, for alphabet: AlphabetID) {
        progress[alphabet.rawValue, default: [:]][value.symbol] = value
    }

    func mastery(for alphabet: AlphabetID) -> Double {
        let map = progressMap(alphabet)
        let total = AlphabetCatalog.trainableSymbols.reduce(0) { sum, symbol in
            sum + (map[symbol]?.level ?? 0)
        }
        let maximum = AlphabetCatalog.trainableCount * LetterProgress.maxLevel
        return maximum == 0 ? 0 : Double(total) / Double(maximum)
    }

    static func freshInstall() -> AppState {
        AppState()
    }
}
