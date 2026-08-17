//
//  SessionEngine.swift
//  Alpha Academy
//
//  One engine behind all five modes, so scoring, XP and progress feedback
//  cannot drift apart between them.
//

import Combine
import Foundation

// MARK: - Question

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
    /// The symbols this question exercises — drives the progress feedback.
    let targetSymbols: [String]
    /// "K", "Kilo", "BK7291", or empty for decode.
    let promptText: String
    var promptSubtitle: String?
    /// Canonical answer tokens, in order.
    let expected: [String]
    /// Pre-shuffled multiple-choice options.
    var options: [String] = []
    /// Per-position option pools, for Encode.
    var sequenceOptions: [[String]] = []
    /// The entries to speak, for Decode.
    var speechEntries: [PhoneticEntry] = []
    var scenarioCategory: ScenarioCategory?
}

enum SessionStage: Equatable {
    case running
    case summary
}

// MARK: - Scoring

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
        return max(0, 10 - responseMs / 500)      // 10 under 0.5 s, 0 at 5 s
    }

    /// Read before the combo is incremented, so the first correct answer
    /// is a plain 1.0×.
    static func multiplier(combo: Int) -> Double {
        min(1.0 + 0.10 * Double(combo), 3.0)      // caps at combo 20
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

    /// Accuracy bonuses need a real sample, or a one-question perfect
    /// session farms the top bonus.
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

// MARK: - Engine

final class SessionEngine: ObservableObject {

    @Published private(set) var stage: SessionStage = .running
    @Published private(set) var questions: [Question] = []
    @Published private(set) var index = 0
    @Published private(set) var combo = 0
    @Published private(set) var bestCombo = 0
    @Published private(set) var score = 0
    @Published private(set) var correctCount = 0
    /// Answers chosen so far in an Encode question.
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

    /// Speed Mode works from a deadline, not an accumulated tick count:
    /// ticks drift and stop while backgrounded, a deadline stays correct.
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

    // MARK: - Timer

    func tick(now: Date = Date()) {
        guard let deadline else { return }
        let remaining = deadline.timeIntervalSince(now)
        remainingSeconds = max(0, remaining)
        if remaining <= 0, stage == .running { finish() }
    }

    /// Extend the deadline by however long the app was away, so a phone
    /// call does not cost the learner their run.
    func extendDeadline(by interval: TimeInterval) {
        guard let deadline else { return }
        self.deadline = deadline.addingTimeInterval(interval)
    }

    // MARK: - Answering

    /// Multiple choice and flashcards.
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

    /// Encode: one position at a time. A wrong pick reveals the answer and
    /// still advances — trapping the learner teaches nothing.
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

    /// Decode: compare the typed string against the original.
    func submitTranscription(_ text: String) {
        guard let question = currentQuestion, feedback == nil else { return }
        let responseMs = elapsedMs()
        let expected = StringNormalizer.canonical(question.promptText)
        let given = StringNormalizer.canonical(text)
        let isCorrect = expected == given

        // Attribute per-symbol credit only where positions line up. Naive
        // alignment is fine here; edit distance would be over-engineering.
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

    /// Clears feedback without moving to the next question — used by Encode,
    /// which stays on the same string while stepping through its characters.
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
            // Speed Mode never runs out of questions — it runs out of time.
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

    // MARK: - Result

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

    // MARK: - Internals

    private func elapsedMs() -> Int {
        // Clamped so a backgrounded app cannot record a four-hour answer.
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

// MARK: - Normalisation

enum StringNormalizer {
    static func canonical(_ string: String) -> String {
        string
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .filter { !$0.isWhitespace }
    }
}
