//
//  DebugSelfCheck.swift
//  Alpha Academy
//
//  A DEBUG-only end-to-end exercise of the data pipeline: spaced
//  repetition, the commit funnel, streaks, XP, achievements and
//  persistence. Run with:
//
//    SIMCTL_CHILD_AA_SELF_CHECK=1 xcrun simctl launch booted <bundle-id>
//
//  and read the results with `xcrun simctl spawn booted log stream`.
//

#if DEBUG
import Foundation
import UIKit

enum DebugSelfCheck {

    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["AA_SELF_CHECK"] == "1"
    }

    static func run(on store: AppStore) {
        var failures: [String] = []

        func check(_ name: String, _ condition: Bool, _ detail: String = "") {
            if condition {
                print("PASS \(name)")
            } else {
                failures.append(name)
                print("FAIL \(name) — \(detail)")
            }
        }

        // 0 — bundled fonts actually registered.
        //
        // SwiftUI's .custom() falls back to the system face silently when a
        // font is missing, so without this check a broken UIAppFonts entry
        // ships looking merely "a bit off".
        for family in ["Instrument Serif", "IBM Plex Mono", "IBM Plex Mono SemiBold"] {
            let names = UIFont.fontNames(forFamilyName: family)
            check("font registered: \(family)", !names.isEmpty,
                  "UIFont.fontNames returned empty — check UIAppFonts uses bare filenames")
        }

        // 1 — alphabet data integrity.
        for alphabet in AlphabetCatalog.all {
            check("\(alphabet.id.rawValue).letters==26", alphabet.letters.count == 26,
                  "got \(alphabet.letters.count)")
            check("\(alphabet.id.rawValue).digits==10", alphabet.digits.count == 10,
                  "got \(alphabet.digits.count)")
            let symbols = Set(alphabet.trainable.map(\.symbol))
            check("\(alphabet.id.rawValue).symbols unique", symbols.count == 36,
                  "got \(symbols.count)")
            check("\(alphabet.id.rawValue).covers catalog",
                  symbols == Set(AlphabetCatalog.trainableSymbols))
        }

        // 2 — spaced repetition promotion and demotion.
        var progress = LetterProgress(symbol: "Q")
        for _ in 0..<2 {
            progress = SpacedRepetitionEngine.apply(
                record: record(symbol: "Q", correct: true), to: progress
            )
        }
        check("SR promotes after 2 correct", progress.level == 1, "level \(progress.level)")

        progress = SpacedRepetitionEngine.apply(
            record: record(symbol: "Q", correct: false), to: progress
        )
        check("SR demotes one on first miss", progress.level == 0, "level \(progress.level)")

        var high = LetterProgress(symbol: "Z", level: 4)
        high.lastAnswerWasWrong = true
        high = SpacedRepetitionEngine.apply(
            record: record(symbol: "Z", correct: false), to: high
        )
        check("SR double-demotes on repeat miss", high.level == 2, "level \(high.level)")

        var shaky = LetterProgress(symbol: "X")
        shaky = SpacedRepetitionEngine.apply(
            record: record(symbol: "X", correct: true, ms: 9_000), to: shaky
        )
        check("SR holds streak on slow correct", shaky.streak == 0, "streak \(shaky.streak)")

        // 3 — weighting puts an unseen symbol above a mastered one.
        let unseen = SpacedRepetitionEngine.weight(for: nil, symbol: "J", recentlyAsked: [])
        var mastered = LetterProgress(symbol: "A", level: 5)
        mastered.lastSeen = Date()
        mastered.answered = 20
        mastered.correct = 20
        let masteredWeight = SpacedRepetitionEngine.weight(
            for: mastered, symbol: "A", recentlyAsked: []
        )
        check("unseen outweighs mastered", unseen > masteredWeight,
              "\(unseen) vs \(masteredWeight)")

        // 4 — question generation for every mode.
        var generator = SystemRandomNumberGenerator()
        for mode in TrainingMode.allCases {
            let questions = QuestionFactory.make(
                mode: mode,
                alphabet: AlphabetCatalog.alphabet(.nato),
                progress: [:],
                goalMinutes: 10,
                using: &generator
            )
            check("\(mode.rawValue) generates questions", !questions.isEmpty)
            if mode == .letterToWord, let first = questions.first {
                check("quiz has 4 options", first.options.count == 4,
                      "got \(first.options.count)")
                check("quiz options contain answer",
                      first.options.contains(first.expected[0]))
                check("quiz options unique",
                      Set(first.options).count == first.options.count)
            }
            if mode == .encode, let first = questions.first {
                check("encode pools match length",
                      first.sequenceOptions.count == first.expected.count)
                let allContain = zip(first.sequenceOptions, first.expected)
                    .allSatisfy { $0.contains($1) }
                check("encode pools contain answers", allContain)
            }
        }

        // 5 — the commit funnel.
        let xpBefore = store.profile.xp
        let sessionsBefore = store.state.sessions.count
        let result = syntheticSession()
        store.commit(result)

        check("commit awards XP", store.profile.xp > xpBefore,
              "\(xpBefore) -> \(store.profile.xp)")
        check("commit stores session", store.state.sessions.count == sessionsBefore + 1)
        check("commit records answers", !store.state.answers.isEmpty)
        check("commit sets streak", store.profile.streakDays >= 1)
        check("commit advances a letter",
              store.progress(for: "M").level > 0,
              "M level \(store.progress(for: "M").level)")
        check("commit writes a daily stat", !store.state.dailyStats.isEmpty)
        check("commit unlocks first achievement",
              store.state.unlocked.contains { $0.achievementID == "first.contact" })
        check("stats recomputed", store.stats.overallAccuracy > 0)

        // 6 — a second commit on the same day must not double the streak.
        let streakAfterFirst = store.profile.streakDays
        store.commit(syntheticSession())
        check("same-day commit keeps streak",
              store.profile.streakDays == streakAfterFirst,
              "\(streakAfterFirst) -> \(store.profile.streakDays)")

        // 7 — persistence round-trip.
        store.saveNow()
        let reloaded = PersistenceStore.shared.load()
        check("state survives a save/load", reloaded.profile.xp == store.profile.xp,
              "\(reloaded.profile.xp) vs \(store.profile.xp)")
        check("progress survives a save/load",
              reloaded.progress(.nato, "M").level == store.progress(for: "M").level)

        // 8 — callsign derivation, including Cyrillic input.
        let nato = AlphabetCatalog.alphabet(.nato)
        check("callsign from latin name",
              CallsignGenerator.callsign(from: "Evgenij", alphabet: nato) == "Echo Victor",
              CallsignGenerator.callsign(from: "Evgenij", alphabet: nato))
        check("callsign from cyrillic name",
              !CallsignGenerator.callsign(from: "Евгений", alphabet: nato).isEmpty,
              CallsignGenerator.callsign(from: "Евгений", alphabet: nato))
        check("callsign from two names",
              CallsignGenerator.callsign(from: "Maria Kaur", alphabet: nato) == "Mike Kilo",
              CallsignGenerator.callsign(from: "Maria Kaur", alphabet: nato))
        check("callsign from empty name",
              CallsignGenerator.callsign(from: "", alphabet: nato).isEmpty)

        // 9 — scoring behaves.
        check("combo multiplier caps at 3",
              ScoringEngine.multiplier(combo: 100) == 3.0)
        check("first answer is 1.0x",
              ScoringEngine.multiplier(combo: 0) == 1.0)

        // 10 — every achievement is reachable and uniquely identified.
        let ids = AchievementCatalog.all.map(\.id)
        check("achievement ids unique", Set(ids).count == ids.count)
        check("achievement count is 30+", ids.count >= 30, "got \(ids.count)")
        let emptySnapshot = StatsSnapshot()
        let unlockedOnEmpty = AchievementCatalog.all.filter { $0.isUnlocked(emptySnapshot) }
        check("nothing unlocks on an empty profile", unlockedOnEmpty.isEmpty,
              unlockedOnEmpty.map(\.id).joined(separator: ","))

        // 11 — the Pocket Alpha push contract decodes.
        //
        // Verbatim samples from §2 of Pocket_Alpha_iOS_Push_API.md. The one that
        // matters is `action: null`: it is legal, and a non-optional field there
        // would drop every actionless push on the floor at runtime.
        let emptyJSON = #"{"has_push": false, "next_poll_after_sec": 900, "reason": "in_app"}"#
        let empty = try? JSONDecoder().decode(
            PendingPushResponse.self, from: Data(emptyJSON.utf8)
        )
        check("push: empty response decodes",
              empty?.hasPush == false && empty?.nextPollAfterSec == 900,
              "got \(String(describing: empty))")

        let fullJSON = """
        {"has_push": true, "next_poll_after_sec": 900, "push": {
          "delivery_id": "fb1266a314944604b3f003803ba63b46", "post_id": 20,
          "title": "T", "body": "B", "action": null, "lang": "en"}}
        """
        let full = try? JSONDecoder().decode(
            PendingPushResponse.self, from: Data(fullJSON.utf8)
        )
        check("push: null action decodes",
              full?.hasPush == true && full?.push?.action == nil
                  && full?.push?.postID == 20,
              "got \(String(describing: full))")

        let actionJSON = """
        {"has_push": true, "next_poll_after_sec": 60, "push": {
          "delivery_id": "d1", "post_id": 1, "title": "T", "body": "B",
          "action": {"text": "GO", "url": "https://example.com/x"}, "lang": "es"}}
        """
        let withAction = try? JSONDecoder().decode(
            PendingPushResponse.self, from: Data(actionJSON.utf8)
        )
        check("push: action decodes",
              withAction?.push?.action?.url == "https://example.com/x",
              "got \(String(describing: withAction?.push?.action))")

        // The throttle must move forward on every response, push or not (§2).
        PushStore.clearThrottle()
        check("push: no throttle means due", PushStore.isPollDue)
        PushStore.noteResponse(nextPollAfterSec: 900)
        check("push: throttle blocks the next poll", !PushStore.isPollDue,
              "nextPollAllowedAt \(String(describing: PushStore.nextPollAllowedAt))")
        PushStore.clearThrottle()

        if failures.isEmpty {
            print("SELF-CHECK RESULT: ALL PASSED")
        } else {
            print("SELF-CHECK RESULT: \(failures.count) FAILED: \(failures.joined(separator: ", "))")
        }
    }

    // MARK: - Fixtures

    private static func record(
        symbol: String,
        correct: Bool,
        ms: Int = 1_200
    ) -> AnswerRecord {
        AnswerRecord(
            alphabet: .nato,
            mode: .letterToWord,
            symbol: symbol,
            wasCorrect: correct,
            responseMs: ms
        )
    }

    private static func syntheticSession() -> SessionResult {
        let symbols = ["M", "N", "O", "P", "Q", "R", "S", "T", "M", "N"]
        let records = symbols.enumerated().map { index, symbol in
            AnswerRecord(
                alphabet: .nato,
                mode: .letterToWord,
                symbol: symbol,
                wasCorrect: index % 5 != 4,
                responseMs: 1_100
            )
        }
        var result = SessionResult(
            mode: .letterToWord,
            alphabet: .nato,
            date: Date(),
            total: records.count,
            correct: records.filter(\.wasCorrect).count,
            durationMs: 42_000,
            bestCombo: 4,
            score: 120,
            records: records
        )
        result.xpAwarded = ScoringEngine.xp(for: result)
        return result
    }
}
#endif
