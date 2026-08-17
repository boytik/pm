//
//  AchievementCatalog.swift
//  Alpha Academy
//
//  Thirty declarations. Each returns (current, target) so the same line
//  drives the unlock check and the progress bar on a locked badge.
//
//  Deliberately no coins, gems, chests or tiers — the badges are SF
//  Symbols in the academy palette, and rank-ups are surfaced separately
//  so XP is never awarded twice for the same thing.
//

import Foundation

enum AchievementCatalog {

    static let all: [Achievement] = [

        // MARK: Getting started

        Achievement(
            id: "first.contact",
            title: "First Contact",
            detail: "Complete your first session.",
            symbolName: "flag",
            category: .gettingStarted,
            xpReward: 20,
            evaluate: { (min($0.sessionsCompleted, 1), 1) }
        ),
        Achievement(
            id: "chart.explorer",
            title: "Chart Explorer",
            detail: "Answer every letter and digit at least once in one alphabet.",
            symbolName: "map",
            category: .gettingStarted,
            xpReward: 40,
            evaluate: { ($0.symbolsTouchedByAlphabet.values.max() ?? 0, 36) }
        ),
        Achievement(
            id: "cross.trained",
            title: "Cross-Trained",
            detail: "Complete a session in every training mode.",
            symbolName: "square.grid.2x2",
            category: .gettingStarted,
            xpReward: 90,
            evaluate: { ($0.modesTried, TrainingMode.allCases.count) }
        ),
        Achievement(
            id: "ground.school",
            title: "Ground School",
            detail: "Complete 10 Study sessions.",
            symbolName: "book",
            category: .gettingStarted,
            xpReward: 30,
            evaluate: { ($0.sessionsByMode[.study] ?? 0, 10) }
        ),

        // MARK: Mastery

        Achievement(
            id: "half.chart",
            title: "Half the Chart",
            detail: "Reach 50% mastery in any alphabet.",
            symbolName: "chart.bar",
            category: .mastery,
            xpReward: 75,
            evaluate: { (Int($0.bestMastery * 100), 50) }
        ),
        Achievement(
            id: "chart.complete",
            title: "Chart Complete",
            detail: "Reach 100% mastery in any alphabet.",
            symbolName: "checkmark.seal",
            category: .mastery,
            xpReward: 200,
            evaluate: { (Int($0.bestMastery * 100), 100) }
        ),
        Achievement(
            id: "triple.certified",
            title: "Triple Certified",
            detail: "Reach 100% mastery in all three alphabets.",
            symbolName: "rosette",
            category: .mastery,
            xpReward: 500,
            evaluate: { ($0.alphabetsFullyMastered, AlphabetID.allCases.count) }
        ),
        Achievement(
            id: "comeback",
            title: "The Comeback",
            detail: "Take a letter from level 0 all the way to mastered.",
            symbolName: "arrow.up.forward",
            category: .mastery,
            xpReward: 80,
            evaluate: { ($0.tookALetterZeroToMastered ? 1 : 0, 1) }
        ),
        Achievement(
            id: "thousand.words",
            title: "A Thousand Words",
            detail: "Answer correctly 1 000 times.",
            symbolName: "text.book.closed",
            category: .mastery,
            xpReward: 200,
            evaluate: { ($0.totalCorrect, 1_000) }
        ),
        Achievement(
            id: "numbers.too",
            title: "Numbers Too",
            detail: "Get 50 digits right — the half people always skip.",
            symbolName: "number",
            category: .mastery,
            xpReward: 30,
            evaluate: { ($0.digitsCorrect, 50) }
        ),

        // MARK: Accuracy

        Achievement(
            id: "perfect.ten",
            title: "Perfect Ten",
            detail: "Finish a session of 10 or more questions with no mistakes.",
            symbolName: "checkmark.circle",
            category: .accuracy,
            xpReward: 30,
            evaluate: {
                let ok = ($0.lastSession?.isPerfect ?? false)
                    && ($0.lastSession?.total ?? 0) >= 10
                return (ok ? 1 : 0, 1)
            }
        ),
        Achievement(
            id: "flawless.25",
            title: "Flawless Twenty-Five",
            detail: "Finish a session of 25 or more questions with no mistakes.",
            symbolName: "checkmark.seal.fill",
            category: .accuracy,
            xpReward: 80,
            evaluate: {
                let ok = ($0.lastSession?.isPerfect ?? false)
                    && ($0.lastSession?.total ?? 0) >= 25
                return (ok ? 1 : 0, 1)
            }
        ),
        Achievement(
            id: "precision.90",
            title: "Precision Ninety",
            detail: "Hold 90% accuracy across at least 200 answers.",
            symbolName: "scope",
            category: .accuracy,
            xpReward: 70,
            evaluate: {
                guard $0.totalAnswers >= 200 else { return (0, 1) }
                return ($0.overallAccuracy >= 0.90 ? 1 : 0, 1)
            }
        ),
        Achievement(
            id: "steady.hand",
            title: "Steady Hand",
            detail: "Complete 50 sessions.",
            symbolName: "hand.raised",
            category: .accuracy,
            xpReward: 100,
            evaluate: { ($0.sessionsCompleted, 50) }
        ),

        // MARK: Encoding

        Achievement(
            id: "clean.encode",
            title: "Clean Encode",
            detail: "Spell out a 6-character string with no mistakes.",
            symbolName: "text.cursor",
            category: .encoding,
            xpReward: 30,
            evaluate: { ($0.maxCleanEncodeLength, 6) }
        ),
        Achievement(
            id: "long.haul",
            title: "Long Haul",
            detail: "Spell out a 12-character string with no mistakes.",
            symbolName: "arrow.left.and.right",
            category: .encoding,
            xpReward: 120,
            evaluate: { ($0.maxCleanEncodeLength, 12) }
        ),
        Achievement(
            id: "frequent.flyer",
            title: "Frequent Flyer",
            detail: "Encode 25 flight numbers.",
            symbolName: "airplane",
            category: .encoding,
            xpReward: 60,
            evaluate: { ($0.scenarioCompletions[.flight] ?? 0, 25) }
        ),
        Achievement(
            id: "front.desk",
            title: "Front Desk",
            detail: "Encode 25 hotel booking references.",
            symbolName: "bed.double",
            category: .encoding,
            xpReward: 60,
            evaluate: { ($0.scenarioCompletions[.hotel] ?? 0, 25) }
        ),
        Achievement(
            id: "address.clerk",
            title: "Address Clerk",
            detail: "Encode 25 email addresses.",
            symbolName: "at",
            category: .encoding,
            xpReward: 60,
            evaluate: { ($0.scenarioCompletions[.email] ?? 0, 25) }
        ),
        Achievement(
            id: "serial.specialist",
            title: "Serial Specialist",
            detail: "Encode 25 serial numbers.",
            symbolName: "barcode",
            category: .encoding,
            xpReward: 60,
            evaluate: { ($0.scenarioCompletions[.serial] ?? 0, 25) }
        ),
        Achievement(
            id: "thousand.characters",
            title: "A Thousand Characters",
            detail: "Spell out 1 000 characters in total.",
            symbolName: "textformat.abc",
            category: .encoding,
            xpReward: 110,
            evaluate: { ($0.charactersEncoded, 1_000) }
        ),

        // MARK: Listening

        Achievement(
            id: "ears.on",
            title: "Ears On",
            detail: "Decode your first string by ear.",
            symbolName: "ear",
            category: .listening,
            xpReward: 25,
            evaluate: { (min($0.stringsDecoded, 1), 1) }
        ),
        Achievement(
            id: "ear.trained",
            title: "Ear Trained",
            detail: "Decode 25 strings by ear.",
            symbolName: "waveform",
            category: .listening,
            xpReward: 70,
            evaluate: { ($0.stringsDecoded, 25) }
        ),
        Achievement(
            id: "no.replay",
            title: "No Replay Needed",
            detail: "Decode 10 strings correctly on the first listen.",
            symbolName: "checkmark.diamond",
            category: .listening,
            xpReward: 130,
            evaluate: { ($0.cleanDecodesNoReplay, 10) }
        ),

        // MARK: Speed

        Achievement(
            id: "quick.draw",
            title: "Quick Draw",
            detail: "Answer correctly in under 1.5 seconds.",
            symbolName: "bolt",
            category: .speed,
            xpReward: 20,
            evaluate: { (min($0.fastCorrectAnswers, 1), 1) }
        ),
        Achievement(
            id: "rapid.fire",
            title: "Rapid Fire",
            detail: "Answer 50 times correctly in under 1.5 seconds.",
            symbolName: "bolt.fill",
            category: .speed,
            xpReward: 70,
            evaluate: { ($0.fastCorrectAnswers, 50) }
        ),
        Achievement(
            id: "combo.10",
            title: "Combo Ten",
            detail: "Answer 10 in a row without a mistake.",
            symbolName: "flame",
            category: .speed,
            xpReward: 25,
            evaluate: { ($0.bestCombo, 10) }
        ),
        Achievement(
            id: "combo.25",
            title: "Combo Twenty-Five",
            detail: "Answer 25 in a row without a mistake.",
            symbolName: "flame.fill",
            category: .speed,
            xpReward: 60,
            evaluate: { ($0.bestCombo, 25) }
        ),
        Achievement(
            id: "speed.1000",
            title: "Sixty Seconds Flat",
            detail: "Score 1 000 or more in a single Speed Mode run.",
            symbolName: "stopwatch",
            category: .speed,
            xpReward: 140,
            evaluate: { ($0.bestSpeedScore, 1_000) }
        ),

        // MARK: Consistency

        Achievement(
            id: "streak.3",
            title: "Three-Day Streak",
            detail: "Practise three days running.",
            symbolName: "calendar",
            category: .consistency,
            xpReward: 25,
            evaluate: { ($0.longestStreak, 3) }
        ),
        Achievement(
            id: "streak.7",
            title: "Week on Watch",
            detail: "Practise seven days running.",
            symbolName: "calendar.badge.clock",
            category: .consistency,
            xpReward: 70,
            evaluate: { ($0.longestStreak, 7) }
        ),
        Achievement(
            id: "streak.30",
            title: "Thirty-Day Streak",
            detail: "Practise thirty days running.",
            symbolName: "calendar.circle",
            category: .consistency,
            xpReward: 250,
            evaluate: { ($0.longestStreak, 30) }
        ),
        Achievement(
            id: "early.riser",
            title: "Early Riser",
            detail: "Finish a session before 07:00.",
            symbolName: "sunrise",
            category: .consistency,
            xpReward: 20,
            evaluate: { ($0.sessionHours.contains(where: { $0 < 7 }) ? 1 : 0, 1) }
        ),
        Achievement(
            id: "night.watch",
            title: "Night Watch",
            detail: "Finish a session after 23:00.",
            symbolName: "moon.stars",
            category: .consistency,
            xpReward: 20,
            evaluate: { ($0.sessionHours.contains(where: { $0 >= 23 }) ? 1 : 0, 1) }
        )
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    static func grouped() -> [(category: AchievementCategory, items: [Achievement])] {
        AchievementCategory.allCases.compactMap { category in
            let items = all.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }
}
