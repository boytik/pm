//
//  SessionSummaryView.swift
//  Alpha Academy
//
//  Styled as a flight-log debrief, not a reward screen. No confetti, no
//  trophy animation, no sound.
//

import SwiftUI

struct SessionSummaryView: View {
    let result: SessionResult
    let unlocked: [Achievement]
    let rankUp: RankTier?
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xl) {
                headline
                stats

                if let rankUp {
                    rankCard(rankUp)
                }

                if !unlocked.isEmpty {
                    achievements
                }

                PrimaryButton(title: "Done") { onDone() }
            }
            .padding(Theme.Space.l)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 4)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.3)) { appeared = true }
            }
        }
    }

    private var headline: some View {
        VStack(spacing: Theme.Space.m) {
            Text("DEBRIEF")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundColor(Theme.ink2)

            VStack(spacing: 3) {
                Rectangle().fill(Theme.track).frame(height: Theme.hairline)
                Rectangle().fill(Theme.track).frame(height: Theme.hairline)
            }

            Text("\(result.correct) / \(result.total)")
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.ink)

            Text("\(Int(result.accuracy * 100))% accuracy")
                .font(.subheadline)
                .foregroundColor(Theme.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.l)
    }

    private var stats: some View {
        HStack(spacing: Theme.Space.m) {
            StatTile(value: durationText, label: "Time")
            StatTile(value: "+\(result.xpAwarded)", label: "XP")
            if result.bestCombo > 0 {
                StatTile(value: "\(result.bestCombo)", label: "Best combo")
            }
        }
    }

    private var durationText: String {
        let seconds = Int(result.durationSeconds.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func rankCard(_ rank: RankTier) -> some View {
        HStack(spacing: Theme.Space.m) {
            RankInsigniaView(rank: rank, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rank up").sectionHeaderStyle()
                Text(rank.title)
                    .font(.headline)
                    .foregroundColor(Theme.ink)
            }
            Spacer()
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: "Unlocked")
            ForEach(unlocked.prefix(3)) { achievement in
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: achievement.symbolName)
                        .font(.title3)
                        .foregroundColor(Theme.blue)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Theme.track, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.title)
                            .font(.headline)
                            .foregroundColor(Theme.ink)
                        Text(achievement.detail)
                            .font(.caption)
                            .foregroundColor(Theme.ink2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            }
            if unlocked.count > 3 {
                Text("+\(unlocked.count - 3) more")
                    .font(.caption)
                    .foregroundColor(Theme.ink2)
            }
        }
    }
}
