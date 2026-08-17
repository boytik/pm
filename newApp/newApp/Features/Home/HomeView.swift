//
//  HomeView.swift
//  Alpha Academy
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: AppRouter
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.xl) {
                    rankHeader
                    drillCard
                    statRow
                    weakLetters
                    lastSession
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.l)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Alpha Academy")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: - Blocks

    private var rankHeader: some View {
        let profile = store.profile
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.s) {
                RankInsigniaView(rank: profile.rank)
                Text(profile.rank.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundColor(Theme.ink)
                Spacer()
                Text("\(profile.xp) XP")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.inkSecondary)
            }

            if !profile.callsign.isEmpty {
                Text(profile.callsign)
                    .font(.title3.weight(.semibold))
                    .tracking(1.5)
                    .foregroundColor(Theme.accent)
            }

            LinearMeter(fraction: profile.rankProgress, height: 6)

            if let next = profile.rank.next {
                Text("\(max(0, next.threshold - profile.xp)) XP to \(next.title)")
                    .font(.caption)
                    .foregroundColor(Theme.inkSecondary)
            } else {
                Text("Top rank reached.")
                    .font(.caption)
                    .foregroundColor(Theme.inkSecondary)
            }
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var drillCard: some View {
        let due = store.stats.dueCountByAlphabet[store.activeAlphabetID] ?? 0
        let done = store.hasCompletedDrillToday

        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: "Today's drill")

            HStack(spacing: Theme.Space.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "Done for today" : "\(due) due for review")
                        .font(.headline)
                        .foregroundColor(Theme.ink)
                    Text("About \(store.profile.dailyGoalMinutes) minutes")
                        .font(.caption)
                        .foregroundColor(Theme.inkSecondary)
                }
                Spacer()
                if done {
                    Image(systemName: "checkmark.seal")
                        .font(.title2)
                        .foregroundColor(Theme.correct)
                }
            }

            PrimaryButton(
                title: done ? "Practise again" : "Start drill",
                systemImage: "play.fill"
            ) {
                router.selectedTab = .practice
            }
        }
        .padding(Theme.Space.l)
        .cardSurface()
    }

    private var statRow: some View {
        HStack(spacing: Theme.Space.m) {
            StatTile(
                value: "\(store.profile.streakDays)",
                label: "Day streak",
                caption: store.profile.longestStreak > 0
                    ? "Best \(store.profile.longestStreak)" : nil,
                symbolName: "flame"
            )
            StatTile(
                value: store.stats.overallAccuracy > 0
                    ? "\(Int(store.stats.overallAccuracy * 100))%" : "—",
                label: "Accuracy",
                caption: trendCaption,
                symbolName: "scope"
            )
        }
    }

    private var trendCaption: String? {
        guard let delta = store.stats.trend.accuracyDeltaPoints else { return "New" }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Int(delta.rounded())) pts vs last week"
    }

    @ViewBuilder
    private var weakLetters: some View {
        // Only symbols actually attempted — a list of things never seen is
        // not "needs work", it is "not started".
        let weak = store.stats.weakestAttempted
        if !weak.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "Needs work")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.s) {
                        ForEach(weak, id: \.self) { symbol in
                            MasteryTile(
                                symbol: symbol,
                                level: store.progress(for: symbol).level
                            )
                        }
                    }
                }
                if store.stats.untouchedCount > 0 {
                    Text("\(store.stats.untouchedCount) symbols not started yet")
                        .font(.caption)
                        .foregroundColor(Theme.inkSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var lastSession: some View {
        if let session = store.state.sessions.last {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "Last session")
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.mode.title)
                            .font(.headline)
                            .foregroundColor(Theme.ink)
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(Theme.inkSecondary)
                    }
                    Spacer()
                    Text("\(session.correct)/\(session.total)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.accent)
                }
                .padding(Theme.Space.l)
                .cardSurface()
            }
        } else {
            EmptyStateView(
                symbolName: "chart.bar.doc.horizontal",
                title: "No sessions yet",
                message: "Finish a drill and your record will appear here."
            )
        }
    }
}
