//
//  ProgressDashboardView.swift
//  Alpha Academy
//
//  Named ProgressDashboardView, not ProgressView — the latter shadows
//  SwiftUI's own spinner type and produces baffling errors everywhere.
//

import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAchievements = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    overview
                    masterySection
                    modeAccuracy
                    weekChart
                    achievementsPreview
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.l)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationDestination(isPresented: $showAchievements) {
                AchievementsView()
            }
        }
    }

    // MARK: - Blocks

    private var overview: some View {
        HStack(spacing: Theme.Space.l) {
            ProgressRing(fraction: store.mastery())

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.s) {
                    RankInsigniaView(rank: store.profile.rank)
                    Text(store.profile.rank.title)
                        .font(.headline)
                        .foregroundColor(Theme.ink)
                }
                Text("\(store.profile.xp) XP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(Theme.inkSecondary)
                Text("\(store.stats.totalPracticeMinutes) minutes practised")
                    .font(.caption)
                    .foregroundColor(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var masterySection: some View {
        MasteryGridView(
            alphabet: store.activeAlphabet,
            progress: store.progressMap()
        )
    }

    @ViewBuilder
    private var modeAccuracy: some View {
        let rows = TrainingMode.practiceModes.compactMap { mode -> (TrainingMode, ModeAccuracy)? in
            guard let accuracy = store.stats.accuracyByMode[mode], accuracy.sampleSize > 0
            else { return nil }
            return (mode, accuracy)
        }

        if rows.isEmpty {
            EmptyStateView(
                symbolName: "chart.bar",
                title: "No data yet",
                message: "Finish a few sessions and your per-mode accuracy shows up here."
            )
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(title: "Accuracy by mode")
                ForEach(rows, id: \.0) { mode, accuracy in
                    HStack(spacing: Theme.Space.m) {
                        Text(mode.title)
                            .font(.subheadline)
                            .foregroundColor(Theme.ink)
                            .frame(width: 120, alignment: .leading)
                        LinearMeter(fraction: accuracy.allTime, height: 6)
                        Text("\(Int(accuracy.allTime * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Theme.inkSecondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weekChart: some View {
        let days = store.stats.last14Days.suffix(7)
        if days.contains(where: { $0.answered > 0 }) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(title: "Last 7 days", trailingText: trendText)
                Chart(Array(days)) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Answers", day.answered)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(2)
                }
                .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                .frame(height: 120)
                .padding(Theme.Space.m)
                .cardSurface()
            }
        }
    }

    private var trendText: String {
        guard let delta = store.stats.trend.accuracyDeltaPoints else { return "New" }
        return "\(delta >= 0 ? "+" : "")\(Int(delta.rounded())) pts"
    }

    private var achievementsPreview: some View {
        Button { showAchievements = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.headline)
                        .foregroundColor(Theme.ink)
                    Text("\(store.stats.achievementsUnlocked) of \(store.stats.achievementsTotal) unlocked")
                        .font(.caption)
                        .foregroundColor(Theme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.rule)
            }
            .padding(Theme.Space.l)
            .cardSurface()
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Achievements

struct AchievementsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                ForEach(AchievementCatalog.grouped(), id: \.category) { group in
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        SectionHeader(title: group.category.title)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Space.m)],
                            spacing: Theme.Space.m
                        ) {
                            ForEach(group.items) { achievement in
                                badge(achievement)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func badge(_ achievement: Achievement) -> some View {
        let unlocked = store.isAchievementUnlocked(achievement.id)
        let progress = achievement.progress(store.achievementSnapshot)

        return VStack(spacing: Theme.Space.s) {
            Image(systemName: achievement.symbolName)
                .font(.title3)
                .foregroundColor(unlocked ? Theme.accent : Theme.inkSecondary.opacity(0.4))
                .frame(width: 48, height: 48)
                .overlay(
                    Circle().strokeBorder(
                        unlocked ? Theme.accent : Theme.rule,
                        style: unlocked
                            ? StrokeStyle(lineWidth: 1)
                            : StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                )

            Text(achievement.title)
                .font(.caption.weight(.medium))
                .foregroundColor(unlocked ? Theme.ink : Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Locked badges always show their criterion — a "???" is a game
            // trope and helps nobody learn.
            Text(achievement.detail)
                .font(.caption2)
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !unlocked, progress > 0 {
                LinearMeter(fraction: progress, height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.m)
        .cardSurface()
    }
}
