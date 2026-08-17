//
//  AppStore.swift
//  Alpha Academy
//
//  The single source of truth. Views read published state and call
//  methods; nothing else mutates AppState.
//

import Combine
import Foundation
import SwiftUI

final class AppStore: ObservableObject {

    @Published private(set) var state: AppState
    @Published private(set) var stats: DerivedStats

    /// Drained by the session summary, one card at a time.
    @Published var pendingAchievements: [Achievement] = []
    @Published var pendingRankUp: RankTier?

    private let persistence: PersistenceStore
    private var saveTask: Task<Void, Never>?

    init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        let loaded = persistence.load()
        self.state = loaded
        self.stats = StatsEngine.compute(loaded)
    }

    // MARK: - Reads

    var profile: UserProfile { state.profile }

    var activeAlphabetID: AlphabetID { state.profile.preferredAlphabet }

    var activeAlphabet: PhoneticAlphabet {
        AlphabetCatalog.alphabet(activeAlphabetID)
    }

    func alphabet(_ id: AlphabetID) -> PhoneticAlphabet {
        AlphabetCatalog.alphabet(id)
    }

    func progressMap(_ id: AlphabetID? = nil) -> [String: LetterProgress] {
        state.progressMap(id ?? activeAlphabetID)
    }

    func progress(for symbol: String, in id: AlphabetID? = nil) -> LetterProgress {
        state.progress(id ?? activeAlphabetID, symbol)
    }

    func mastery(_ id: AlphabetID? = nil) -> Double {
        state.mastery(for: id ?? activeAlphabetID)
    }

    var isAchievementUnlocked: (String) -> Bool {
        let unlocked = Set(state.unlocked.map(\.achievementID))
        return { unlocked.contains($0) }
    }

    var achievementSnapshot: StatsSnapshot {
        StatsEngine.snapshot(state, lastSession: state.sessions.last)
    }

    /// Whether today's drill has already been done.
    var hasCompletedDrillToday: Bool {
        guard let last = state.profile.lastDrillDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Profile mutation

    func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        mutate(&state.profile)
        scheduleSave()
    }

    func completeOnboarding(name: String, goalMinutes: Int, alphabet: AlphabetID) {
        state.profile.name = name
        state.profile.callsign = CallsignGenerator.callsign(
            from: name,
            alphabet: AlphabetCatalog.alphabet(alphabet)
        )
        state.profile.dailyGoalMinutes = goalMinutes
        state.profile.preferredAlphabet = alphabet
        state.profile.hasOnboarded = true
        recomputeStats()
        saveNow()
    }

    func setAlphabet(_ id: AlphabetID) {
        state.profile.preferredAlphabet = id
        if !state.profile.name.isEmpty {
            state.profile.callsign = CallsignGenerator.callsign(
                from: state.profile.name,
                alphabet: AlphabetCatalog.alphabet(id)
            )
        }
        recomputeStats()
        scheduleSave()
    }

    // MARK: - The commit funnel

    /// Everything a finished session changes, applied in one ordered pass.
    func commit(_ result: SessionResult) {
        var result = result
        let now = result.date
        let calendar = Calendar.current

        // 1 — raw history, trimmed.
        state.answers.append(contentsOf: result.records)
        trim(&state.answers, to: AppState.Cap.answers)

        // 2 — spaced repetition.
        var reachedMasteredFromZero = false
        for record in result.records {
            let before = state.progress(record.alphabet, record.symbol)
            let after = SpacedRepetitionEngine.apply(record: record, to: before, now: now)
            if before.level == 0, after.isMastered { reachedMasteredFromZero = true }
            state.setProgress(after, for: record.alphabet)
        }
        if reachedMasteredFromZero { state.counters.tookALetterZeroToMastered = true }

        // 3 — lifetime counters. These are never trimmed, so long-horizon
        //     achievements stay reachable after history is capped.
        applyCounters(result, hour: calendar.component(.hour, from: now))

        // 4 — today's rollup.
        applyDailyStat(result, on: calendar.startOfDay(for: now))

        // 5 — session history, trimmed.
        state.sessions.append(result)
        trim(&state.sessions, to: AppState.Cap.sessions)

        // 6 — streak.
        updateStreak(now: now)
        if result.mode == .dailyDrill { state.profile.lastDrillDate = now }

        // 7 — XP and rank.
        let rankBefore = state.profile.rank
        state.profile.xp += result.xpAwarded

        // 8 — achievements, which can award further XP and so can themselves
        //     push the learner over a rank threshold.
        let unlocked = evaluateAchievements(lastSession: result)
        for achievement in unlocked {
            state.unlocked.append(
                UnlockedAchievement(achievementID: achievement.id, date: now)
            )
            state.profile.xp += achievement.xpReward
            result.xpAwarded += achievement.xpReward
        }
        pendingAchievements = unlocked

        let rankAfter = state.profile.rank
        pendingRankUp = rankAfter != rankBefore ? rankAfter : nil

        // 9 — derived stats, computed once.
        recomputeStats(now: now)

        // 10 — persist.
        scheduleSave()
    }

    // MARK: - Commit steps

    private func applyCounters(_ result: SessionResult, hour: Int) {
        var counters = state.counters
        let modeKey = result.mode.rawValue

        counters.totalSessions += 1
        counters.sessionsByMode[modeKey, default: 0] += 1
        counters.sessionHours.insert(hour)
        counters.totalPracticeSeconds += Double(result.durationMs) / 1_000
        counters.bestCombo = max(counters.bestCombo, result.bestCombo)

        if result.mode == .speed {
            counters.bestSpeedScore = max(counters.bestSpeedScore, result.score)
        }

        for record in result.records {
            counters.answeredByMode[record.mode.rawValue, default: 0] += 1
            if record.wasCorrect {
                counters.correctAnswers += 1
                counters.correctByMode[record.mode.rawValue, default: 0] += 1
                if record.isDigit { counters.digitsCorrect += 1 }
                if record.responseMs < 1_500 { counters.fastCorrectUnder1500ms += 1 }
            } else {
                counters.wrongAnswers += 1
            }
        }

        if result.mode == .encode {
            counters.charactersEncoded += result.charactersEncoded
            counters.encodeMillis += result.durationMs
            if result.isPerfect {
                counters.maxCleanEncodeLength = max(
                    counters.maxCleanEncodeLength,
                    result.longestCleanString
                )
            }
            if let category = result.scenarioCategory {
                counters.scenarioCompletions[category.rawValue, default: 0] += 1
            }
        }

        if result.mode == .decode {
            counters.stringsDecoded += result.correct
            if result.replayCount == 0 { counters.cleanDecodesNoReplay += result.correct }
        }

        state.counters = counters
    }

    private func applyDailyStat(_ result: SessionResult, on day: Date) {
        var stat = state.dailyStats.first { $0.day == day } ?? DailyStat(day: day)
        stat.sessions += 1
        stat.answered += result.total
        stat.correct += result.correct
        stat.xp += result.xpAwarded
        stat.practiceSeconds += Double(result.durationMs) / 1_000
        if result.mode == .encode {
            stat.encodedCharacters += result.charactersEncoded
            stat.encodeMillis += result.durationMs
        }

        if let index = state.dailyStats.firstIndex(where: { $0.day == day }) {
            state.dailyStats[index] = stat
        } else {
            state.dailyStats.append(stat)
            state.dailyStats.sort { $0.day < $1.day }
        }
        trim(&state.dailyStats, to: AppState.Cap.dailyStats)
    }

    private func updateStreak(now: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        guard let last = state.profile.lastPracticeDay else {
            state.profile.streakDays = 1
            state.profile.longestStreak = max(state.profile.longestStreak, 1)
            state.profile.lastPracticeDay = today
            return
        }

        let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        switch days {
        case 0:
            break                                   // already counted today
        case 1:
            state.profile.streakDays += 1
        default:
            // Covers both a genuine gap and a clock rolled backwards.
            state.profile.streakDays = 1
        }

        state.profile.longestStreak = max(state.profile.longestStreak, state.profile.streakDays)
        state.profile.lastPracticeDay = today
    }

    private func evaluateAchievements(lastSession: SessionResult) -> [Achievement] {
        let snapshot = StatsEngine.snapshot(state, lastSession: lastSession)
        let already = Set(state.unlocked.map(\.achievementID))
        return AchievementCatalog.all.filter { achievement in
            !already.contains(achievement.id) && achievement.isUnlocked(snapshot)
        }
    }

    /// Recompute the streak on foreground so a broken streak shows before
    /// the learner practises, not after.
    func refreshStreakIfNeeded(now: Date = Date()) {
        guard let last = state.profile.lastPracticeDay else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        if days > 1, state.profile.streakDays != 0 {
            state.profile.streakDays = 0
            scheduleSave()
        }
    }

    private func recomputeStats(now: Date = Date()) {
        stats = StatsEngine.compute(state, now: now)
    }

    private func trim<T>(_ array: inout [T], to cap: Int) {
        if array.count > cap { array.removeFirst(array.count - cap) }
    }

    // MARK: - Reset

    func resetProgress(for id: AlphabetID) {
        state.progress[id.rawValue] = [:]
        recomputeStats()
        saveNow()
    }

    func resetEverything() {
        let keepOnboarded = state.profile.hasOnboarded
        var fresh = AppState.freshInstall()
        fresh.profile.hasOnboarded = keepOnboarded
        state = fresh
        recomputeStats()
        saveNow()
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = state          // value type: a later mutation cannot tear the write
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.persistence.save(snapshot)
            self?.saveTask = nil
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        persistence.save(state)
    }
}
