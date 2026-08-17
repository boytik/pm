//
//  Progress.swift
//  Alpha Academy
//

import Foundation

/// The five training modes. Raw values are persisted — do not rename.
enum TrainingMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case study
    case letterToWord
    case wordToLetter
    case encode
    case decode
    case speed
    case dailyDrill

    var id: String { rawValue }

    /// The five modes shown on the Practice hub. Daily Drill is launched
    /// from Home instead.
    static var practiceModes: [TrainingMode] {
        [.study, .letterToWord, .wordToLetter, .encode, .decode, .speed]
    }

    var title: String {
        switch self {
        case .study:        return "Study"
        case .letterToWord: return "Letter → Word"
        case .wordToLetter: return "Word → Letter"
        case .encode:       return "Encode a String"
        case .decode:       return "Decode by Ear"
        case .speed:        return "Speed Mode"
        case .dailyDrill:   return "Daily Drill"
        }
    }

    var subtitle: String {
        switch self {
        case .study:        return "Cards with audio and mnemonics"
        case .letterToWord: return "See a letter, pick its code word"
        case .wordToLetter: return "See a code word, pick its letter"
        case .encode:       return "Spell out a real string, in order"
        case .decode:       return "Listen, then write down what you heard"
        case .speed:        return "Sixty seconds. Build a combo."
        case .dailyDrill:   return "Your weak letters, plus one string"
        }
    }

    var symbolName: String {
        switch self {
        case .study:        return "rectangle.on.rectangle"
        case .letterToWord: return "a.square"
        case .wordToLetter: return "textformat.abc"
        case .encode:       return "text.cursor"
        case .decode:       return "ear"
        case .speed:        return "bolt"
        case .dailyDrill:   return "target"
        }
    }

    /// XP awarded per correct answer, before accuracy and combo bonuses.
    var baseXP: Int {
        switch self {
        case .study:                       return 2
        case .letterToWord, .wordToLetter: return 3
        case .encode:                      return 5
        case .decode:                      return 6
        case .speed:                       return 4
        case .dailyDrill:                  return 5
        }
    }

    /// Study is a browsing mode; it does not produce a score.
    var isScored: Bool { self != .study }
}

/// Retention state for a single symbol within a single alphabet.
struct LetterProgress: Codable, Hashable {
    var symbol: String
    var level: Int = 0
    var correct: Int = 0
    var wrong: Int = 0
    var answered: Int = 0
    /// Consecutive good answers at the current level. Resets on any mistake.
    var streak: Int = 0
    var lastSeen: Date?
    var lastCorrect: Date?
    var totalResponseMs: Int = 0
    /// Enables the double-demotion rule: missing the same letter twice in a
    /// row drops it two levels, not one.
    var lastAnswerWasWrong: Bool = false

    static let maxLevel = 5

    var accuracy: Double {
        answered == 0 ? 0 : Double(correct) / Double(answered)
    }

    var errorRate: Double {
        answered == 0 ? 0 : Double(wrong) / Double(answered)
    }

    var averageResponseMs: Int {
        answered == 0 ? 0 : totalResponseMs / answered
    }

    /// 0…1, used by the mastery grid fill.
    var mastery: Double { Double(level) / Double(Self.maxLevel) }

    var isMastered: Bool { level >= Self.maxLevel }
}

/// One answer, kept so stats and trends can be recomputed from raw history.
struct AnswerRecord: Codable, Hashable, Identifiable {
    var id = UUID()
    let date: Date
    let alphabet: AlphabetID
    let mode: TrainingMode
    let symbol: String
    let wasCorrect: Bool
    /// Clamped on write so a backgrounded app cannot record a four-hour
    /// answer and permanently mark a letter "shaky".
    let responseMs: Int

    var isDigit: Bool { symbol.first.map(\.isNumber) ?? false }

    init(
        date: Date = Date(),
        alphabet: AlphabetID,
        mode: TrainingMode,
        symbol: String,
        wasCorrect: Bool,
        responseMs: Int
    ) {
        self.date = date
        self.alphabet = alphabet
        self.mode = mode
        self.symbol = symbol
        self.wasCorrect = wasCorrect
        self.responseMs = max(0, min(responseMs, 30_000))
    }
}

/// The outcome of one finished session, handed to the summary screen and
/// then applied to the store in a single transaction.
struct SessionResult: Codable, Hashable, Identifiable {
    var id = UUID()
    let mode: TrainingMode
    let alphabet: AlphabetID
    let date: Date
    let total: Int
    let correct: Int
    let durationMs: Int
    let bestCombo: Int
    var score: Int = 0
    var xpAwarded: Int = 0
    /// Encode mode: how many characters were spelled out.
    var charactersEncoded: Int = 0
    /// Encode mode: the longest string completed without a mistake.
    var longestCleanString: Int = 0
    var scenarioCategory: ScenarioCategory?
    /// Decode mode: how many times the learner replayed the audio.
    var replayCount: Int = 0
    var records: [AnswerRecord] = []

    var accuracy: Double {
        total == 0 ? 0 : Double(correct) / Double(total)
    }

    var isPerfect: Bool { total > 0 && correct == total }

    var durationSeconds: Double { Double(durationMs) / 1_000 }
}
