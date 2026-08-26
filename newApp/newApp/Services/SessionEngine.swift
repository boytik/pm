import Combine
import Foundation

enum QuestionKind {
    case flashcard
    case chooseWord
    case chooseLetter
    case buildSequence
    case transcribe
}

struct Question: Identifiable {
    let id = UUID()
    let kind: QuestionKind

    let targetSymbols: [String]

    let promptText: String
    var promptSubtitle: String?

    let expected: [String]

    var options: [String] = []

    var sequenceOptions: [[String]] = []

    var speechEntries: [PhoneticEntry] = []
    var scenarioCategory: ScenarioCategory?
}

enum SessionStage: Equatable {
    case running
    case summary
}

enum ScoringEngine {
    static func basePoints(_ kind: QuestionKind) -> Int {
        switch kind {
        case .flashcard:     return 0
        case .chooseWord,
             .chooseLetter:  return 10
        case .buildSequence: return 12
        case .transcribe:    return 14
        }
    }

    static func speedBonus(responseMs: Int, mode: TrainingMode) -> Int {
        guard mode == .speed else { return 0 }
        return max(0, 10 - responseMs / 500)
    }

    static func multiplier(combo: Int) -> Double {
        min(1.0 + 0.10 * Double(combo), 3.0)
    }

    static func itemScore(
        kind: QuestionKind,
        responseMs: Int,
        mode: TrainingMode,
        combo: Int
    ) -> Int {
        let base = Double(basePoints(kind) + speedBonus(responseMs: responseMs, mode: mode))
        return Int((base * multiplier(combo: combo)).rounded())
    }

    static func xp(for result: SessionResult) -> Int {
        var xp = result.correct * result.mode.baseXP

        if result.total >= 5 {
            switch result.accuracy {
            case 1.0...:       xp += 25
            case 0.90..<1.0:   xp += 15
            case 0.75..<0.90:  xp += 5
            default:           break
            }
        }

        if result.bestCombo >= 20 { xp += 20 }
        else if result.bestCombo >= 10 { xp += 10 }

        return xp
    }
}

final class SessionEngine: ObservableObject {
    @Published private(set) var stage: SessionStage = .running
    @Published private(set) var questions: [Question] = []
    @Published private(set) var index = 0
    @Published private(set) var combo = 0
    @Published private(set) var bestCombo = 0
    @Published private(set) var score = 0
    @Published private(set) var correctCount = 0

    @Published private(set) var sequenceProgress: [String] = []
    @Published private(set) var feedback: Feedback?
    @Published private(set) var remainingSeconds: Double?
    @Published private(set) var replayCount = 0

    struct Feedback: Equatable {
        let isCorrect: Bool
        let correctAnswer: String
    }

    let mode: TrainingMode
    let alphabet: PhoneticAlphabet
    private let alphabetID: AlphabetID
    private var records: [AnswerRecord] = []
    private var questionShownAt = Date()
    private let startedAt = Date()
    private var charactersEncoded = 0
    private var longestCleanString = 0
    private var currentStringClean = true
    private var scenarioCategory: ScenarioCategory?

    private var deadline: Date?

    var currentQuestion: Question? {
        index < questions.count ? questions[index] : nil
    }

    var progressFraction: Double {
        questions.isEmpty ? 0 : Double(index) / Double(questions.count)
    }

    init(mode: TrainingMode, alphabet: PhoneticAlphabet, progress: [String: LetterProgress], goalMinutes: Int = 10) {
        self.mode = mode
        self.alphabet = alphabet
        self.alphabetID = alphabet.id

        var generator = SystemRandomNumberGenerator()
        self.questions = QuestionFactory.make(
            mode: mode,
            alphabet: alphabet,
            progress: progress,
            goalMinutes: goalMinutes,
            using: &generator
        )
        self.scenarioCategory = questions.compactMap(\.scenarioCategory).first

        if mode == .speed {
            deadline = Date().addingTimeInterval(60)
            remainingSeconds = 60
        }
        questionShownAt = Date()
    }

    func tick(now: Date = Date()) {
        guard let deadline else { return }
        let remaining = deadline.timeIntervalSince(now)
        remainingSeconds = max(0, remaining)
        if remaining <= 0, stage == .running { finish() }
    }

    func extendDeadline(by interval: TimeInterval) {
        guard let deadline else { return }
        self.deadline = deadline.addingTimeInterval(interval)
    }

    func submit(option: String) {
        guard let question = currentQuestion, feedback == nil else { return }
        let responseMs = elapsedMs()
        let isCorrect = question.expected.first == option

        register(
            symbols: question.targetSymbols,
            isCorrect: isCorrect,
            responseMs: responseMs,
            kind: question.kind
        )
        feedback = Feedback(isCorrect: isCorrect, correctAnswer: question.expected.first ?? "")
    }

    func submitSequence(option: String) {
        guard let question = currentQuestion, feedback == nil else { return }
        let position = sequenceProgress.count
        guard position < question.expected.count else { return }

        let responseMs = elapsedMs()
        let expected = question.expected[position]
        let isCorrect = expected == option
        let symbol = position < question.targetSymbols.count
            ? question.targetSymbols[position] : expected

        register(symbols: [symbol], isCorrect: isCorrect, responseMs: responseMs, kind: question.kind)
        charactersEncoded += 1
        if !isCorrect { currentStringClean = false }

        sequenceProgress.append(expected)
        questionShownAt = Date()

        if !isCorrect {
            feedback = Feedback(isCorrect: false, correctAnswer: expected)
        } else if sequenceProgress.count == question.expected.count {
            if currentStringClean {
                longestCleanString = max(longestCleanString, question.expected.count)
            }
            feedback = Feedback(isCorrect: true, correctAnswer: question.promptText)
        }
    }

    func submitTranscription(_ text: String) {
        guard let question = currentQuestion, feedback == nil else { return }
        let responseMs = elapsedMs()
        let expected = StringNormalizer.canonical(question.promptText)
        let given = StringNormalizer.canonical(text)
        let isCorrect = expected == given

        if expected.count == given.count {
            for (index, symbol) in question.targetSymbols.enumerated() {
                let expectedChars = Array(expected)
                let givenChars = Array(given)
                guard index < expectedChars.count, index < givenChars.count else { break }
                appendRecord(
                    symbol: symbol,
                    isCorrect: expectedChars[index] == givenChars[index],
                    responseMs: responseMs / max(1, question.targetSymbols.count)
                )
            }
        } else {
            for symbol in question.targetSymbols {
                appendRecord(symbol: symbol, isCorrect: false, responseMs: responseMs)
            }
        }

        if isCorrect {
            correctCount += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            score += ScoringEngine.itemScore(
                kind: .transcribe, responseMs: responseMs, mode: mode, combo: combo - 1
            )
            Haptics.shared.correct()
        } else {
            combo = 0
            Haptics.shared.wrong()
        }

        feedback = Feedback(isCorrect: isCorrect, correctAnswer: question.promptText)
    }

    func registerReplay() {
        replayCount += 1
    }

    func clearFeedback() {
        feedback = nil
        questionShownAt = Date()
    }

    func advance() {
        feedback = nil
        sequenceProgress = []
        currentStringClean = true
        questionShownAt = Date()

        if mode == .speed {
            index = (index + 1) % max(1, questions.count)
            return
        }

        index += 1
        if index >= questions.count { finish() }
    }

    func finish() {
        guard stage == .running else { return }
        stage = .summary
        Haptics.shared.sessionComplete()
    }

    func makeResult() -> SessionResult {
        var result = SessionResult(
            mode: mode,
            alphabet: alphabetID,
            date: Date(),
            total: answeredCount,
            correct: correctCount,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            bestCombo: bestCombo,
            score: score,
            charactersEncoded: charactersEncoded,
            longestCleanString: longestCleanString,
            scenarioCategory: scenarioCategory,
            replayCount: replayCount,
            records: records
        )
        result.xpAwarded = ScoringEngine.xp(for: result)
        return result
    }

    private var answeredCount: Int {
        mode == .decode || mode == .encode ? max(records.count, 0) : records.count
    }

    private func elapsedMs() -> Int {
        let raw = Int(Date().timeIntervalSince(questionShownAt) * 1_000)
        return max(0, min(raw, 30_000))
    }

    private func register(symbols: [String], isCorrect: Bool, responseMs: Int, kind: QuestionKind) {
        for symbol in symbols {
            appendRecord(symbol: symbol, isCorrect: isCorrect, responseMs: responseMs)
        }

        if isCorrect {
            correctCount += 1
            score += ScoringEngine.itemScore(
                kind: kind, responseMs: responseMs, mode: mode, combo: combo
            )
            combo += 1
            bestCombo = max(bestCombo, combo)
            Haptics.shared.correct()
        } else {
            combo = 0
            Haptics.shared.wrong()
        }
    }

    private func appendRecord(symbol: String, isCorrect: Bool, responseMs: Int) {
        records.append(
            AnswerRecord(
                alphabet: alphabetID,
                mode: mode,
                symbol: symbol,
                wasCorrect: isCorrect,
                responseMs: responseMs
            )
        )
    }
}

enum StringNormalizer {
    static func canonical(_ string: String) -> String {
        string
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .filter { !$0.isWhitespace }
    }
}
